//
//  EntranceViewController.swift
//  main
//
//  首页主控制器 — 唯一入口类
//
//  从旧版 EntranceViewController.swift (~750 行) 重构迁移。
//  核心变化：
//    - 模块列表由 configData() 硬编码 → AppAssembly.shared.allModuleProviders() 统一获取
//    - 10 个 goto{Module}() 方法 → 统一 config.targetProvider()
//    - 权限检查散落在各 goto → 集中在 ModulePermissionService
//    - App 生命周期回调 → AppAssembly.shared.registerLifecycleHandlers() + AppLifecycleRegistry
//    - UI 布局完全保持旧版不变
//

import AppAssembly
import AtomicX
import Combine
import Login
#if !OPEN_SOURCE
import RTCExperienceRoom
#endif
import SnapKit
import Toast_Swift
import TUICore
import UIKit
#if !RTCUBE_OVERSEAS && !OPEN_SOURCE
import HuiYanPublicSDK
#endif

class EntranceViewController: UIViewController {
    // MARK: - Properties

    private let store = EntranceStore()
    private var cancellables = Set<AnyCancellable>()

    /// 标记当前登录会话是否已执行过高风险检查 & 安全提醒弹窗。
    /// 每次退出登录（重新 present 登录页）时重置为 false，
    /// 确保换账号后能再次触发检查。
    private var hasPerformedRiskCheck = false

    // MARK: - UI Elements

    private let safeReminderWarningView: SafetyReminderView = {
        let safeReminderView = SafetyReminderView()
        safeReminderView.confirmTimeCount = 5
        safeReminderView.clickConfirmBlock = {
            safeReminderView.removeFromSuperview()
        }
        return safeReminderView
    }()

    private lazy var mainNavigationView: MainNavigationView = {
        let view = MainNavigationView(frame: .zero)
        view.delegate = self
        return view
    }()

    private lazy var collectionView: UICollectionView = {
        let flowLayout = LeftAlignedFlowLayout()
        flowLayout.sectionInset = UIEdgeInsets(top: 0, left: 12, bottom: 0, right: 12)
        flowLayout.itemSize = CGSize(width: ScreenWidth / 2 - 12, height: 106)
        flowLayout.minimumLineSpacing = 0
        flowLayout.minimumInteritemSpacing = 0

        let cv = UICollectionView(frame: .zero, collectionViewLayout: flowLayout)
        cv.register(EntranceCollectionCell.self,
                    forCellWithReuseIdentifier: "EntranceCollectionCell")
        cv.register(EntranceFooterView.self,
                    forSupplementaryViewOfKind: UICollectionView.elementKindSectionFooter,
                    withReuseIdentifier: "footer")
        cv.backgroundColor = .clear
        cv.delegate = self
        cv.dataSource = self
        cv.isScrollEnabled = true
        cv.isPagingEnabled = true
        return cv
    }()

    private let reportView: EntranceReportView = {
        let view = EntranceReportView()
        view.backgroundColor = ThemeStore.shared.colorTokens.toastColorError
        view.reportHandler = {
            if let url = URL(string: "https://cloud.tencent.com/act/event/report-platform") {
                UIApplication.shared.open(url, options: [:], completionHandler: nil)
            }
        }
        return view
    }()

    // MARK: - Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()

        let appEnvironment = ModuleEnvironment(
            liveLicenseURL: LIVE_LICENSE_URL,
            liveLicenseKey: LIVE_LICENSE_KEY,
            effectLicenseURL: TENCENT_EFFECT_LICENSE_URL,
            effectLicenseKey: TENCENT_EFFECT_LICENSE_KEY,
            playerLicenseURL: PLAYER_LICENSE_URL,
            playerLicenseKey: PLAYER_LICENSE_KEY,
            copyrightedMusicLicenseKey: COPYRIGHTED_MUSIC_LICENSE_KEY,
            copyrightedMusicLicenseUrl: COPYRIGHTED_MUSIC_LICENSE_URL,
            getCurrentUserModel: {
                LoginEntry.shared.userModel
            },
            generateUserSig: { userId in
                GenerateTestUserSig.genTestUserSig(identifier: userId, sdkAppId: SDKAPPID, secretKey: SECRETKEY)
            }
        )

        // ① 注入 AppAssembly 回调
        // RTCubeLab / 开源版不注册 handler（所有安全弹窗跳过，privacy 模块在开源工程中物理剔除）
        #if !RTCUBE_LAB
        AppAssembly.shared.privacyActionHandler = { action in
            // MOA/IOA 内部账号统一跳过所有隐私/风控动作，对需要结果回调的动作直接放行
            if LoginManager.shared.getCurrentUser()?.isMoa() == true {
                switch action {
                case .checkRealNameAuth(_, _, let completion):
                    completion(true, "success")
                case .showFaceIdTokenVerify(_, _, let completion):
                    completion(true, "")
                default:
                    break
                }
                return
            }

            switch action {
            case .showAntifraudReminder:
                AntifraudAlertManager.showAntifraudReminder()
            case .checkRealNameAuth(let userId, let token, let completion):
                AntifraudAlertManager.checkRealNameAuth(userId: userId, token: token, completion: completion)
            case .showFaceIdTokenVerify(let userId, let token, let completion):
                AntifraudAlertManager.checkRealNameToAuthFace(userId: userId, token: token, completion: completion)
            case .showLiveTimeLimitAlert:
                TimeLimitPresenter.showLiveTimeLimitAlert()
            case .showLiveRemainingOneMinToast:
                TimeLimitPresenter.showRemainingOneMinToast()
            case .showHighRiskIPAlert:
                RoomRiskIPPresenter.showHighRiskIPAlert()
            case .showLiveTimeOutAlert(let onDismiss):
                TimeLimitPresenter.showLiveTimeOutAlert(onDismiss: onDismiss)
            }
        }
        AppAssembly.shared.analyticEventHandler = { action in
            switch action {
            case .liveEvent(let name, let params):
                AppAnalytics.trackModuleEvent(moduleId: "live", event: name, params: params)
            case .voiceRoomEvent(let name, let params):
                AppAnalytics.trackModuleEvent(moduleId: "voice_room", event: name, params: params)
            case .aiConversationEvent(let name, let params):
                AppAnalytics.trackModuleEvent(moduleId: "conversation_ai", event: name, params: params)
            case .interpretationEvent(let name, let params):
                AppAnalytics.trackModuleEvent(moduleId: "simultaneous_interpretation", event: name, params: params)
            }
        }
        #else
        // RTCubeLab 模式下禁用实名认证（与旧版行为一致）
        PrivacyEntry.enableIdCardVerification = false
        #endif

        #if RTCUBE_OVERSEAS
        let providers = AppAssembly.shared.allModuleProviders(target: .overseas)
        #elseif RTCUBE_LAB
        let providers = AppAssembly.shared.allModuleProviders(target: .lab)
        #else
        let providers = AppAssembly.shared.allModuleProviders(target: .domestic)
        #endif
        let registry = ModuleRegistry.shared
        for provider in providers {
            provider.setup(with: appEnvironment)
            registry.register(provider)
        }

        // ② 注册需要 App 生命周期回调的 handler
        AppAssembly.shared.registerLifecycleHandlers()

        // ③ 构建 UI
        setupUI()

        // ④ 加载模块数据
        store.loadModules()

        // ⑤ 订阅 Store 状态变化，驱动 UI 刷新
        bindStoreState()

        // ⑥ 加载权限数据（仅国内版需要拉取模块黑名单）
        #if !RTCUBE_OVERSEAS && !RTCUBE_LAB && !OPEN_SOURCE
        ModulePermissionService.shared.loadUserBlackList()
        #endif

        // ⑥.5 启动模块级埋点观察器 + 初始化埋点公共属性
        #if !DEBUG
        initAnalytics()
        ModuleAnalytics.start()
        #endif

        // ⑦ 初始化 HuiYanSDK（人脸核身）
        #if !RTCUBE_OVERSEAS && !OPEN_SOURCE
        HuiYanSDKKit.sharedInstance().initSDK(with: self)
        #endif

        // ⑧ 高风险用户检查 & 安全提醒弹窗
        //    时机延迟到 viewDidAppear，等登录页 dismiss 后首页真正可见时再触发，
        //    避免在 viewDidLoad 时弹窗被登录页遮盖导致倒计时失效。
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        navigationController?.setNavigationBarHidden(true, animated: true)
        setupToast()
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        performRiskCheckIfNeeded()
    }

    override var preferredStatusBarStyle: UIStatusBarStyle {
        if #available(iOS 13.0, *) {
            return .darkContent
        }
        return .default
    }

    override var prefersStatusBarHidden: Bool {
        return false
    }

    // MARK: - UI Setup

    private func setupUI() {
        view.backgroundColor = ThemeStore.shared.colorTokens.bgColorDefault

        constructViewHierarchy()
        activateConstraints()
    }

    private var shouldShowReportView: Bool {
        #if RTCUBE_LAB
        return false
        #else
        guard TUIGlobalization.isChineseAppLocale() else { return false }
        guard let userModel = LoginManager.shared.getCurrentUser() else { return true }
        return !userModel.isMoa()
        #endif
    }

    private func constructViewHierarchy() {
        view.addSubview(mainNavigationView)

        if shouldShowReportView {
            view.addSubview(reportView)
        }

        view.addSubview(collectionView)
    }

    private func activateConstraints() {
        let statusBarH = statusBarHeight()

        mainNavigationView.snp.makeConstraints { make in
            make.top.equalToSuperview().offset(statusBarH)
            make.height.equalTo(44)
            make.left.equalToSuperview().offset(20)
            make.right.equalToSuperview().offset(-20)
        }

        if shouldShowReportView {
            reportView.snp.makeConstraints { make in
                make.top.equalTo(mainNavigationView.snp.bottom)
                make.left.right.equalToSuperview()
                let height: CGFloat = TUIGlobalization.isChineseAppLocale() ? 52 : 0
                make.height.equalTo(height)
            }

            collectionView.snp.makeConstraints { make in
                make.top.equalTo(reportView.snp.bottom).offset(12)
                make.left.right.bottom.equalToSuperview()
            }
        } else {
            collectionView.snp.makeConstraints { make in
                make.top.equalTo(mainNavigationView.snp.bottom).offset(12)
                make.left.right.bottom.equalToSuperview()
            }
        }
    }

    // MARK: - State Binding

    private func bindStoreState() {
        store.$state
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.collectionView.reloadData()
            }
            .store(in: &cancellables)
    }

    // MARK: - Toast

    private func setupToast() {
        ToastManager.shared.position = .bottom
    }

    /// 显示被禁用的提示
    private func showBannedToast() {
        guard !ModulePermissionService.shared.isNeedFaceAuth else { return }
        view.makeToast(MainLocalize("main_module_banned_message"))
    }

    // MARK: - Risk Check Entry Point

    /// 高风险用户检查 & 安全提醒弹窗的统一入口
    ///
    /// 触发条件：首页真正可见（`viewDidAppear`）+ 尚未执行过检查 + 登录页已不在前台。
    /// 这样可以保证登录页 dismiss 后弹窗才出现，倒计时不会被遮盖失效。
    ///
    /// 与 v1 行为对齐：
    /// - 每次登录会话（含换账号 / Token 过期重登）执行 **1 次** 自动检查
    /// - 高风险用户点击模块时可 **无限次** 重新触发核身弹窗（由 didSelectItemAt 处理）
    private func performRiskCheckIfNeeded() {
        // RTCubeLab 模式下跳过所有安全提示弹窗
        #if RTCUBE_LAB
        return
        #endif

        // 登录页仍然 present 在上层 → 跳过，同时重置标记以便新账号登录后能再次触发
        if presentedViewController != nil {
            hasPerformedRiskCheck = false
            return
        }
        guard !hasPerformedRiskCheck else { return }
        guard let userModel = LoginManager.shared.getCurrentUser(), !userModel.isMoa() else { return }

        hasPerformedRiskCheck = true

        #if !RTCUBE_OVERSEAS
        if ModulePermissionService.shared.checkHighRiskUser() {
            showFaceAuthAlert(user: userModel)
        } else {
            showSafetyReminderAlert()
        }
        #endif
    }

    // MARK: - Face Auth (高风险用户人脸核身)

    #if !RTCUBE_OVERSEAS
    /// 弹出实名认证弹窗，获取人脸核身 Token
    ///
    /// 通过 `privacyActionHandler` 调用 privacy 模块获取 faceIdToken，
    /// 成功后启动 HuiYanSDK 人脸核身流程。
    private func showFaceAuthAlert(user: BSUserModel) {
        AppAssembly.shared.privacyActionHandler?(.showFaceIdTokenVerify(userId: user.userId, token: user.token, completion: { [weak self] isAuth, faceToken in
            guard let self = self else { return }
            if isAuth {
                getFaceAuth(token: faceToken)
            } else {
                DispatchQueue.main.async { [weak self] in
                    guard let self = self else { return }
                    showSafetyReminderAlert()
                }
            }
        }))
    }
    #endif

    #if !RTCUBE_OVERSEAS
    /// 启动 HuiYanSDK 人脸核身
    ///
    /// 对应旧版 `getFaceAuth(token:)`。
    /// - 核身成功：解除模块禁用，展示安全提醒弹窗
    /// - 核身失败：Toast 提示用户重试
    ///
    /// 开源版(OPEN_SOURCE)不链接 HuiYanPublicSDK，方法体空实现；
    /// 保留方法签名以维持 showFaceAuthAlert 的调用链编译通过。
    private func getFaceAuth(token: String) {
        #if !OPEN_SOURCE
        let config = AuthConfig()
        config.token = token
        if let path = Bundle.main.path(forResource: "HuiYanPublicSDK", ofType: "license") {
            config.licencePath = path
        }

        HuiYanSDKKit.sharedInstance().startHuiYanAuth(
            with: config,
            withProcessSucceed: { [weak self] resultInfo, _ in
                guard let self = self else { return }
                DispatchQueue.main.async {
                    self.dismiss(animated: true)
                    ModulePermissionService.shared.updateNeedFaceAuth(false)
                    self.showSafetyReminderAlert()
                }
                AppLogger.App.info(" startHuiYanAuth succeed: \(resultInfo)")
            },
            withProcessFailedBlock: { [weak self] error, _ in
                guard let self = self else { return }
                DispatchQueue.main.async {
                    self.view.makeToast(
                        MainLocalize("main_face_auth_failed_message"),
                        position: .bottom
                    )
                }
                AppLogger.App.info(" startHuiYanAuth error: \(error) - \(error.localizedDescription)")
            }
        )
        #endif
    }
    #endif

    // MARK: - Safety Reminder

    /// 显示安全提醒弹窗（5 秒倒计时，倒计时结束后方可关闭）
    ///
    /// 对应旧版 `showReminderWarningView()` + `SafetyReminderView`，
    /// 使用 v1 同款 SafetyReminderView 实现，保持样式完全一致：
    /// - 全屏半透明遮罩 + 居中圆角卡片
    /// - 富文本内容（首末段加粗）
    /// - 倒计时期间按钮灰色禁用，结束后变蓝色可点击
    private func showSafetyReminderAlert() {
        safeReminderWarningView.resetTimer()
        view.addSubview(safeReminderWarningView)
        safeReminderWarningView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }
    }
}

// MARK: - UICollectionViewDataSource

extension EntranceViewController: UICollectionViewDataSource {
    func collectionView(_ collectionView: UICollectionView,
                        numberOfItemsInSection section: Int) -> Int
    {
        return store.state.modules.filter { $0.isVisible }.count
    }

    func collectionView(_ collectionView: UICollectionView,
                        cellForItemAt indexPath: IndexPath) -> UICollectionViewCell
    {
        let cell = collectionView.dequeueReusableCell(
            withReuseIdentifier: "EntranceCollectionCell",
            for: indexPath
        ) as! EntranceCollectionCell

        let visibleModules = store.state.modules.filter { $0.isVisible }
        if indexPath.row < visibleModules.count {
            cell.config(visibleModules[indexPath.row])
        }
        return cell
    }

    func collectionView(_ collectionView: UICollectionView,
                        viewForSupplementaryElementOfKind kind: String,
                        at indexPath: IndexPath) -> UICollectionReusableView
    {
        if kind == UICollectionView.elementKindSectionFooter {
            let footerView = collectionView.dequeueReusableSupplementaryView(
                ofKind: kind,
                withReuseIdentifier: "footer",
                for: indexPath
            ) as! EntranceFooterView

            footerView.footerLabel.text = MainLocalize("main_trial_hint")
            return footerView
        }
        return UICollectionReusableView()
    }
}

// MARK: - UICollectionViewDelegate

extension EntranceViewController: UICollectionViewDelegate {
    func collectionView(_ collectionView: UICollectionView,
                        didSelectItemAt indexPath: IndexPath)
    {
        let visibleModules = store.state.modules.filter { $0.isVisible }
        guard indexPath.row < visibleModules.count else { return }
        let module = visibleModules[indexPath.row]

        // 权限检查
        guard ModulePermissionService.shared.isModuleEnabled(module) else {
            // 需要人脸核身时，重新弹出核身弹窗（与旧版 isModelEnable 行为一致）
            #if !RTCUBE_OVERSEAS
            if ModulePermissionService.shared.isNeedFaceAuth,
               let user = LoginManager.shared.getCurrentUser()
            {
                showFaceAuthAlert(user: user)
            } else {
                showBannedToast()
            }
            #endif
            return
        }

        // 埋点
        if !module.config.analyticsEvent.isEmpty {
            trackSensorData(module.config.analyticsEvent)
        }

        // 场景体验入口拦截：国内/Lab 打开外链，不创建 VC
        if module.config.identifier == "scenes_application" {
            if let url = URL(string: "https://trtc.io/exhibition/details?lang=zh&from=app") {
                UIApplication.shared.open(url, options: [:], completionHandler: nil)
            }
            return
        }

        // 创建并跳转目标 VC
        if let targetVC = module.config.targetProvider() {
            if targetVC.modalPresentationStyle == .fullScreen {
                present(targetVC, animated: true)
            } else {
                navigationController?.pushViewController(targetVC, animated: true)
            }
        }
    }
}

// MARK: - UICollectionViewDelegateFlowLayout

extension EntranceViewController: UICollectionViewDelegateFlowLayout {
    func collectionView(_ collectionView: UICollectionView,
                        layout collectionViewLayout: UICollectionViewLayout,
                        sizeForItemAt indexPath: IndexPath) -> CGSize
    {
        let visibleModules = store.state.modules.filter { $0.isVisible }
        guard indexPath.item < visibleModules.count else {
            return CGSize(width: ScreenWidth / 2 - 13, height: 106)
        }

        let module = visibleModules[indexPath.item]

        // Banner 卡片占据整行
        if module.config.cardStyle == .banner {
            return CGSize(width: ScreenWidth - 24, height: 58)
        }

        let cellWidth = ScreenWidth / 2 - 13

        // 计算当前 item 在非 banner 序列中的配对伙伴索引，使同一行两个卡片高度一致
        let rowHeight = calculateRowHeight(for: indexPath.item, visibleModules: visibleModules, cellWidth: cellWidth)

        return CGSize(width: cellWidth, height: rowHeight)
    }

    /// 计算指定 item 所在行的统一高度（取同行两个卡片中的最大值）
    private func calculateRowHeight(for itemIndex: Int,
                                    visibleModules: [ResolvedModule],
                                    cellWidth: CGFloat) -> CGFloat
    {
        // 收集非 banner 的 item 索引，确定配对关系
        var nonBannerIndices: [Int] = []
        for (i, m) in visibleModules.enumerated() {
            if m.config.cardStyle != .banner {
                nonBannerIndices.append(i)
            }
        }

        // 找到当前 item 在非 banner 列表中的位置
        guard let positionInNonBanner = nonBannerIndices.firstIndex(of: itemIndex) else {
            return 106
        }

        // 配对：0-1, 2-3, 4-5, ...
        let rowStartPosition = (positionInNonBanner / 2) * 2

        var maxHeight: CGFloat = 106
        for offset in 0..<2 {
            let pos = rowStartPosition + offset
            guard pos < nonBannerIndices.count else { break }
            let idx = nonBannerIndices[pos]
            let h = EntranceCollectionCell.calculateHeight(for: visibleModules[idx], cellWidth: cellWidth)
            maxHeight = max(maxHeight, h)
        }

        return maxHeight
    }

    func collectionView(_ collectionView: UICollectionView,
                        layout collectionViewLayout: UICollectionViewLayout,
                        referenceSizeForFooterInSection section: Int) -> CGSize
    {
        let text = MainLocalize("main_trial_hint")
        let font = ThemeStore.shared.typographyTokens.Regular12
        let attributes: [NSAttributedString.Key: Any] = [.font: font]
        let attributedString = NSAttributedString(string: text, attributes: attributes)
        let maxSize = CGSize(width: 200, height: CGFloat.greatestFiniteMagnitude)
        let options: NSStringDrawingOptions = [.usesLineFragmentOrigin, .usesFontLeading]
        let boundingRect = attributedString.boundingRect(with: maxSize,
                                                         options: options,
                                                         context: nil)
        let textHeight = ceil(boundingRect.height)
        return CGSize(width: collectionView.frame.width, height: textHeight)
    }
}

// MARK: - MainNavigationViewDelegate

extension EntranceViewController: MainNavigationViewDelegate {
    func jumpProfileController() {
        let mineVC = MineEntry.shared.buildMineViewController(
            onLogout: { [weak self] in
                guard let self = self else { return }
                hasPerformedRiskCheck = false
                LoginEntry.shared.logout { [weak self] result in
                    AppLogger.App.info(" logout result: \(result)")
                    guard let scene = UIApplication.shared.connectedScenes.first(where: { $0.activationState == .foregroundActive }) as? UIWindowScene,
                          let sceneDelegate = scene.delegate as? SceneDelegate else { return }
                    sceneDelegate.showLogin()
                    self?.navigationController?.popToRootViewController(animated: false)
                }
            },
            onLanguageChanged: { [weak self] languageID in
                self?.hasPerformedRiskCheck = false
                AppLogger.App.info(" language changed to: \(languageID)")
                // 语言切换后重建首页
                guard let scene = UIApplication.shared.connectedScenes.first(where: { $0.activationState == .foregroundActive }) as? UIWindowScene,
                      let sceneDelegate = scene.delegate as? SceneDelegate else { return }
                sceneDelegate.showLogin()
            },
            onExperienceRoomClicked: { [weak self] in
                #if !OPEN_SOURCE
                let vc = RTCExperienceRoomLoginViewController(
                    userId: TUILogin.getUserID() ?? "",
                    language: LanguageEntry.shared.currentLanguageID
                )
                self?.navigationController?.pushViewController(vc, animated: true)
                #endif
            }
        )
        navigationController?.pushViewController(mineVC, animated: true)
    }

    func showLogUploadView(pressGesture: UILongPressGestureRecognizer) {
        if pressGesture.state == .began {
            LogUploadManager.sharedInstance.startUpload(withSuccessHandler: nil) {
                AppLogger.App.info(" Log upload cancelled")
            }
        }
    }

    func dismissLogUploadView(tapGesture: UITapGestureRecognizer) {
        // No-op for now
    }
}

// MARK: - Analytics

extension EntranceViewController {
    private func initAnalytics() {
        let userId = LoginEntry.shared.userModel?.userId ?? ""
        let sdkAppId = LoginEntry.shared.config.sdkAppId
        let appVersion = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? ""
        let loginMode = LoginEntry.shared.loggedInMode?.rawValue ?? LoginMode.debugAuth.rawValue
        #if RTCUBE_OVERSEAS
        let appTarget = "overseas"
        #else
        let appTarget = "domestic"
        #endif
        AppAnalytics.initialize(sdkAppId: sdkAppId, userId: userId, appTarget: appTarget, appVersion: appVersion, loginMode: "\(loginMode)")
    }

    private func trackSensorData(_ event: String) {
        let loginType = resolveLoginType()
        #if RTCUBE_OVERSEAS
        let eventName = AnalyticName.tencentRTCMainClick
        #else
        let eventName = AnalyticName.rtcubeMainClick
        #endif
        AppAnalytics.trackMainClick(
            eventName: eventName,
            mainEvent: event,
            loginType: loginType
        )
    }

    private func resolveLoginType() -> String {
        guard let userModel = LoginManager.shared.getCurrentUser() else {
            return "external"
        }

        if userModel.isMoa() {
            return "internal_moa"
        }

        if !userModel.phone.isEmpty {
            let phone = userModel.phone.trimmingCharacters(in: .whitespaces)

            let phoneLength = 11
            let phoneToCheck: String
            if phone.count > phoneLength {
                phoneToCheck = String(phone.suffix(phoneLength))
            } else {
                phoneToCheck = phone
            }

            if let phoneNumber = Int64(phoneToCheck),
               phoneNumber >= 10000000001 && phoneNumber <= 10000000050
            {
                return "internal_test"
            }
        }

        return "external"
    }
}
