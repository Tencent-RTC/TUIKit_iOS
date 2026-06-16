//
//  MiniProgramViewController.swift
//  TencentRTC（仅海外版）
//
//  行业场景小程序列表页 — 对齐旧工程 Tencent-RTC/MiniProgramViewController
//  四个行业入口：1v1 社交 / 在线教育 / 金融服务 / 娃娃机
//
//  ⚠️ 整文件仅在 RTCUBE_OVERSEAS（即 TencentRTC target）下编译。
//     - TCMPPSDK 仅在 Podfile `target 'TencentRTC'` 内声明
//     - 配置文件 `tcsas-configurations-iOS.json` 仅添加到 TencentRTC target Bundle
//     - 跳转入口由 `OverseasMainViewController.didSelectItemAt` /
//       `goScenarioExperience` 拦截 `scenes_application` 卡片后 push
//
//  本文件还包含 `MiniProgramSDKDelegate`：实现 `TMFMiniAppSDKDelegate` 协议的
//  Live License 注入回调，对齐 Android `MiniAppProxyImpl.configData(TYPE_LIVE)`。
//  实例由 `SceneDelegate.prepareMiniProgramSDKIfNeeded()` 持有并挂载到
//  `TMFMiniAppSDKManager.miniAppSdkDelegate`。
//

#if RTCUBE_OVERSEAS

import UIKit
import SnapKit
import TCMPPSDK
import TCMPPExtScanCode

// MARK: - MiniProgramViewController

final class MiniProgramViewController: UIViewController {

    // MARK: - Hidden Debug Switch

    /// 隐藏的扫码调试入口开关（与 Android `MiniProgramState.isScanVisible` 对齐）。
    ///
    /// 默认 `false` —— 正式包不展示 Scan 按钮。
    /// 连续点击 Title 5 次激活（由 `UITapGestureRecognizer.numberOfTapsRequired = 5` 识别），
    /// 通过 TCMPP 扫码能力扫小程序二维码进入对应小程序，避免每次硬编码 appId。
    private var isScanVisible: Bool = false

    // MARK: - Mini App 元数据

    /// 行业小程序枚举 — appId / 名称 / 资源名 / 文案 key 全部沿用旧工程 Tencent-RTC
    private enum MiniProgram: CaseIterable {
        case social
        case education
        case financial
        case clawMachine

        /// 旧工程 Tencent-RTC 的真实 appId（与 customId=T07724IR9831729JNKI 绑定）
        var appId: String {
            switch self {
            case .social:       return "mpxr4rw440r5qjvl"
            case .education:    return "mpyj90mwez4ow04p"
            case .financial:    return "mpwyrvbojp8xtanz"
            case .clawMachine:  return "mppdg601fbg5k69s"
            }
        }

        /// `searchApplets(withName:)` 探活时使用的小程序名称
        var appName: String {
            switch self {
            case .social:       return "1v1 Social"
            case .education:    return "education"
            case .financial:    return "financial"
            case .clawMachine:  return "Claw Machine"
            }
        }

        /// 资源图标名（位于 main/Resource/MiniProgram/MiniProgramAssets.xcassets）
        var iconAssetName: String {
            switch self {
            case .social:       return "module_mini_program_1v1_social"
            case .education:    return "module_mini_program_online_education"
            case .financial:    return "module_mini_program_financial_service"
            case .clawMachine:  return "module_mini_program_claw_machine"
            }
        }

        /// 国际化文案 key（写入 strings_main.csv → MainLocalized.xcstrings）
        var localizedKey: String {
            switch self {
            case .social:       return "main_mini_program_1v1_social"
            case .education:    return "main_mini_program_online_education"
            case .financial:    return "main_mini_program_financial_service"
            case .clawMachine:  return "main_mini_program_claw_machine"
            }
        }
    }

    // MARK: - Properties

    /// 探活后真正可见的小程序入口（探活失败的会被过滤掉）
    private var availablePrograms: [MiniProgram] = []
    private let availabilityGroup = DispatchGroup()

    // MARK: - UI Elements

    private lazy var headerImageView: UIImageView = {
        let imageView = UIImageView()
        imageView.image = UIImage(named: "module_mini_program_main")
        imageView.contentMode = .scaleAspectFill
        imageView.clipsToBounds = true
        return imageView
    }()

    private lazy var backButton: UIButton = {
        // 用 .custom 而非 .system，避免 .system 自动把 PNG 渲染成 template + tintColor，
        // 让原图（白色返回箭头）按本来颜色显示在 headerImageView 的深色 banner 上
        let button = UIButton(type: .custom)
        button.setImage(UIImage(named: "module_mini_program_ic_back"), for: .normal)
        button.imageView?.contentMode = .scaleAspectFit
        button.addTarget(self, action: #selector(backButtonTapped), for: .touchUpInside)
        return button
    }()

    private lazy var titleLabel: UILabel = {
        let label = UILabel()
        label.text = MainLocalize("main_mini_program_title")
        label.font = UIFont.boldSystemFont(ofSize: 24)
        label.textColor = UIColor(red: 0x19 / 255.0, green: 0x1D / 255.0, blue: 0x27 / 255.0, alpha: 1)
        return label
    }()

    private lazy var subtitleLabel: UILabel = {
        let label = UILabel()
        label.text = MainLocalize("main_mini_program_content")
        label.font = UIFont.systemFont(ofSize: 14)
        label.textColor = UIColor(red: 0x72 / 255.0, green: 0x7A / 255.0, blue: 0x8A / 255.0, alpha: 1)
        label.numberOfLines = 0
        return label
    }()

    private let stackView: UIStackView = {
        let stack = UIStackView()
        stack.axis = .vertical
        stack.spacing = 12
        return stack
    }()

    /// 扫码调试按钮（隐藏入口，仅 `isScanVisible == true` 时 append 到 stackView）
    private lazy var scanButton: UIButton = {
        let button = UIButton(type: .custom)
        button.setTitle("Scan", for: .normal)
        button.setTitleColor(UIColor(red: 0x4E / 255.0, green: 0x54 / 255.0, blue: 0x61 / 255.0, alpha: 1), for: .normal)
        button.titleLabel?.font = UIFont.boldSystemFont(ofSize: 18)
        button.backgroundColor = .white
        button.layer.cornerRadius = 8
        button.clipsToBounds = true
        button.addTarget(self, action: #selector(scanButtonTapped), for: .touchUpInside)
        return button
    }()

    private let scrollView: UIScrollView = {
        let sv = UIScrollView()
        sv.showsVerticalScrollIndicator = false
        return sv
    }()

    private let contentView = UIView()

    // MARK: - Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = UIColor(red: 0xF2 / 255.0, green: 0xF5 / 255.0, blue: 0xFC / 255.0, alpha: 1)
        constructViewHierarchy()
        activateConstraints()
        checkMiniProgramAvailability()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        navigationController?.setNavigationBarHidden(true, animated: false)
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        if isMovingFromParent {
            navigationController?.setNavigationBarHidden(false, animated: animated)
        }
    }

    // MARK: - View Setup

    private func constructViewHierarchy() {
        // headerImageView 整屏铺底（对齐 Android `Modifier.fillMaxSize()` 语义），
        // 必须先于 scrollView 挂入 view，并保证位于最底层。
        // 注意 scrollView 自身背景色透明（UIScrollView 默认即透明），
        // 加上 self.view.backgroundColor 已被设置为浅蓝白底色，所以即使背景图
        // 在某些机型被裁掉的区域，也仍然保持原本的纯色兜底，不会露出黑色。
        view.addSubview(headerImageView)
        view.addSubview(scrollView)
        scrollView.addSubview(contentView)
        contentView.addSubview(titleLabel)
        contentView.addSubview(subtitleLabel)
        contentView.addSubview(stackView)
        // backButton 直接挂到 view 上（不随 scrollView 滚动，固定悬浮在背景图左上角）。
        // 必须最后 addSubview 以确保层级在 scrollView 之上。
        view.addSubview(backButton)

        // 隐藏调试入口：连续点击 Title 5 次激活 Scan 按钮（对齐 Android）
        titleLabel.isUserInteractionEnabled = true
        let tap = UITapGestureRecognizer(target: self, action: #selector(handleTitleTap))
        tap.numberOfTapsRequired = 5
        titleLabel.addGestureRecognizer(tap)
    }

    private func activateConstraints() {
        // 整屏背景：盖到刘海与 Home 区域（与 Android 全屏背景一致）
        headerImageView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }

        scrollView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }

        contentView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
            make.width.equalToSuperview()
        }

        backButton.snp.makeConstraints { make in
            // 直接挂在 self.view 上，与 view.safeAreaLayoutGuide 在同一坐标系
            make.top.equalTo(view.safeAreaLayoutGuide.snp.top).offset(8)
            make.leading.equalTo(view.safeAreaLayoutGuide.snp.leading).offset(16)
            make.width.height.equalTo(40)
        }

        titleLabel.snp.makeConstraints { make in
            // 沿用旧布局的视觉基线：背景图顶到 title 顶部 = 220 + 24 = 244pt
            // 改为整屏背景后没有 headerImageView.bottom 可锚，显式写死该常量保持视觉一致
            make.top.equalToSuperview().offset(244)
            make.leading.trailing.equalToSuperview().inset(24)
        }

        subtitleLabel.snp.makeConstraints { make in
            make.top.equalTo(titleLabel.snp.bottom).offset(12)
            make.leading.trailing.equalToSuperview().inset(24)
        }

        stackView.snp.makeConstraints { make in
            make.top.equalTo(subtitleLabel.snp.bottom).offset(36)
            make.leading.trailing.equalToSuperview().inset(24)
            make.bottom.equalToSuperview().inset(40)
        }
    }

    // MARK: - Scan Entry Activation

    /// 激活扫码调试入口：将 scanButton 直接 append 到 stackView 末尾，
    /// 复用 stackView 的 spacing(12) 与统一 64pt 高度，与其他条目视觉一致。
    /// 幂等（重复调用不会重复挂载）。
    private func activateScanEntry() {
        guard scanButton.superview == nil else { return }

        scanButton.snp.makeConstraints { make in
            make.height.equalTo(64)
        }
        stackView.addArrangedSubview(scanButton)

        UIView.animate(withDuration: 0.2) {
            self.contentView.layoutIfNeeded()
        }
    }

    // MARK: - Availability Check

    /// 通过 TCMPPSDK searchApplets 探活，仅展示后台已上架的小程序。
    private func checkMiniProgramAvailability() {
        var availableSet: Set<String> = []
        for program in MiniProgram.allCases {
            availabilityGroup.enter()
            TMFMiniAppSDKManager.sharedInstance().searchApplets(withName: program.appName) { [weak self] results, _ in
                DispatchQueue.main.async {
                    defer { self?.availabilityGroup.leave() }
                    if let results = results, !results.isEmpty {
                        availableSet.insert(program.appId)
                    } else {
                        debugPrint("[MiniProgram] \(program.appName) unavailable, hidden")
                    }
                }
            }
        }
        availabilityGroup.notify(queue: .main) { [weak self] in
            guard let self = self else { return }
            self.availablePrograms = MiniProgram.allCases.filter { availableSet.contains($0.appId) }
            self.rebuildItems()
        }
    }

    // MARK: - Items

    private func rebuildItems() {
        stackView.arrangedSubviews.forEach {
            stackView.removeArrangedSubview($0)
            $0.removeFromSuperview()
        }
        for program in availablePrograms {
            stackView.addArrangedSubview(makeItemView(for: program))
        }
    }

    private func makeItemView(for program: MiniProgram) -> UIView {
        let container = UIView()
        container.backgroundColor = .white
        container.layer.cornerRadius = 8
        container.clipsToBounds = true

        let iconView = UIImageView()
        iconView.image = UIImage(named: program.iconAssetName)
        iconView.contentMode = .scaleAspectFit

        let label = UILabel()
        label.text = MainLocalize(program.localizedKey)
        label.font = UIFont.boldSystemFont(ofSize: 18)
        label.textColor = UIColor(red: 0x4E / 255.0, green: 0x54 / 255.0, blue: 0x61 / 255.0, alpha: 1)

        let arrowView = UIImageView()
        arrowView.image = UIImage(named: "module_mini_program_ic_arrow_right")
        arrowView.contentMode = .scaleAspectFit

        container.addSubview(iconView)
        container.addSubview(label)
        container.addSubview(arrowView)

        container.snp.makeConstraints { make in
            make.height.equalTo(64)
        }
        iconView.snp.makeConstraints { make in
            make.leading.equalToSuperview().offset(22)
            make.centerY.equalToSuperview()
            make.width.height.equalTo(20)
        }
        label.snp.makeConstraints { make in
            make.leading.equalTo(iconView.snp.trailing).offset(8)
            make.centerY.equalToSuperview()
            make.trailing.lessThanOrEqualTo(arrowView.snp.leading).offset(-8)
        }
        arrowView.snp.makeConstraints { make in
            make.trailing.equalToSuperview().inset(22)
            make.centerY.equalToSuperview()
            make.width.height.equalTo(16)
        }

        container.isUserInteractionEnabled = true
        container.accessibilityIdentifier = program.appId
        let tap = UITapGestureRecognizer(target: self, action: #selector(itemTapped(_:)))
        container.addGestureRecognizer(tap)

        return container
    }

    // MARK: - Actions

    @objc private func backButtonTapped() {
        navigationController?.popViewController(animated: true)
    }

    /// 连续点击 Title 5 次激活扫码调试入口
    /// 由 `UITapGestureRecognizer.numberOfTapsRequired = 5` 识别，对齐 Android `MiniProgramStore.clickTitleToShowScanItem`
    @objc private func handleTitleTap() {
        guard !isScanVisible else { return }
        isScanVisible = true
        activateScanEntry()
    }

    @objc private func itemTapped(_ gesture: UITapGestureRecognizer) {
        guard let appId = gesture.view?.accessibilityIdentifier else { return }
        startMiniApp(appId: appId)
    }

    /// 扫码调试入口（与 Android `TmfMiniSDK.scan(activity)` + `getScanResult` + `startMiniAppByLink` 三步对齐）
    ///
    /// 流程：
    ///   1. present `TCMPPScanCodeController`（来自 TCMPPExtScanCode）
    ///   2. 扫到二维码后回调 `scanResultHandler(results)` —— `results` 元素为 `TCMPPScanCodeResult`，取其 `stringValue`
    ///   3. dismiss 扫码页 → `TMFMiniAppSDKManager.startUpMiniAppWithLink:` 用扫到的 link 拉起小程序
    ///
    /// 注意：SDK 不会自动 dismiss 扫码页，必须由调用方手动 dismiss，否则后续 `startUpMiniAppWithLink:`
    /// 的 `parentVC` 会与扫码 VC 形成 present 链冲突。
    @objc private func scanButtonTapped() {
        let scanVC = TCMPPScanCodeController()
        scanVC.modalPresentationStyle = .fullScreen
        scanVC.scanResultHandler = { [weak self, weak scanVC] results in
            DispatchQueue.main.async {
                guard let self = self else { return }
                // 先关闭扫码页，再用扫到的 link 拉起小程序，避免 VC 叠加 present 冲突
                let dismissAndLaunch: () -> Void = {
                    guard let result = results?.first as? TCMPPScanCodeResult else {
                        debugPrint("[MiniProgram] scan result is empty")
                        return
                    }
                    let link = result.stringValue
                    guard !link.isEmpty else {
                        debugPrint("[MiniProgram] scan result is empty")
                        return
                    }
                    debugPrint("[MiniProgram] scan result: \(link)")
                    TMFMiniAppSDKManager.sharedInstance().startUpMiniApp(
                        withLink: link,
                        scene: .scanQRCode,
                        parentVC: self,
                        completion: { error in
                            if let error = error {
                                debugPrint("[MiniProgram] startUpMiniApp(byLink) error: \(error.localizedDescription)")
                            }
                        }
                    )
                }
                if let scanVC = scanVC, scanVC.presentingViewController != nil {
                    scanVC.dismiss(animated: true, completion: dismissAndLaunch)
                } else {
                    dismissAndLaunch()
                }
            }
        }
        present(scanVC, animated: true)
    }

    private func startMiniApp(appId: String) {
        debugPrint("[MiniProgram] startMiniApp: \(appId)")
        TMFMiniAppSDKManager.sharedInstance().startUpMiniApp(withAppID: appId, parentVC: self) { error in
            if let error = error {
                debugPrint("[MiniProgram] startMiniApp error: \(error.localizedDescription)")
            }
        }
    }
}

// MARK: - MiniProgramSDKDelegate

/// `TMFMiniAppSDKDelegate` 实现 — 向小程序 SDK 注入 Live License
///
/// 对齐 Android `MiniAppProxyImpl.configData(TYPE_LIVE)`：当小程序内部调用 TRTC 直播能力时，
/// SDK 会回调 `setLiveLicenceURL` / `setLiveLicenceKey` 拉取 license。
///
/// 直接读壳工程顶层全局常量 `LIVE_LICENSE_URL` / `LIVE_LICENSE_KEY`（位于
/// `Debug/GenerateTestUserSig.swift`），不引入额外的 Constant 单例做中转 ——
/// 与 Android 的 `SceneLicenseConstant` 不同，iOS 这边壳工程内部直接可见，
/// 无需跨模块边界传递。
///
/// 该 delegate 由 `SceneDelegate` 强引用持有（SDK 端是 `weak`）。
final class MiniProgramSDKDelegate: NSObject, TMFMiniAppSDKDelegate {

    func setLiveLicenceURL() -> String {
        return LIVE_LICENSE_URL
    }

    func setLiveLicenceKey() -> String {
        return LIVE_LICENSE_KEY
    }
}

#endif
