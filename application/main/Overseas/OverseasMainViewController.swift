//
//  OverseasMainViewController.swift
//  main
//
//  海外版首页内容页（双 Tab）— 从 Tencent-RTC/MainViewController.swift 迁移
//
//  变更说明：
//    - 数据源从硬编码 MainMenuItemModel 数组改为 EntranceStore + ResolvedModule
//    - 模块按 identifier 分组：discoveryIdentifiers 归入 Discovery Lab，其余归入 Products
//    - 移除 `import RTCCommon`、`import BusinessService` 等直接依赖
//    - 跳转逻辑统一使用 config.targetProvider()，不再硬编码各模块跳转
//    - 埋点事件名使用 "tencent_rtc_main_click_event"
//    - 其他 UI 布局完全保持旧版不变
//

import UIKit
import Combine
import SnapKit
import Toast_Swift
import ImSDK_Plus
import TUICore
import AppAssembly
import Login
import AtomicX

class OverseasMainViewController: UIViewController {

    // MARK: - Properties

    private let store = EntranceStore()
    private var cancellables = Set<AnyCancellable>()

    /// Discovery Lab Tab 中展示的模块 identifier
    private let discoveryIdentifiers: Set<String> = ["player", "ugsv"]

    /// Products Tab 的模块列表
    private var productsModules: [ResolvedModule] = []
    /// Discovery Lab Tab 的模块列表
    private var discoveryModules: [ResolvedModule] = []

    // MARK: - UI Elements

    private let topSegmentedView: UISegmentedControl = {
        let segmentedView = UISegmentedControl(items: [
            MainLocalize("main_overseas_tab_products"),
            MainLocalize("main_overseas_tab_discovery"),
        ])
        segmentedView.selectedSegmentIndex = 0
        segmentedView.setTitleTextAttributes([
            .foregroundColor: ThemeStore.shared.colorTokens.textColorSecondary,
            .font: ThemeStore.shared.typographyTokens.Regular12,
        ], for: .normal)
        segmentedView.setTitleTextAttributes([
            .foregroundColor: ThemeStore.shared.colorTokens.textColorLink,
            .font: UIFont.boldSystemFont(ofSize: 12),
        ], for: .selected)
        return segmentedView
    }()

    private lazy var scrollView: UIScrollView = {
        let scrollView = UIScrollView(frame: .zero)
        scrollView.backgroundColor = .clear
        scrollView.isPagingEnabled = true
        scrollView.bounces = true
        scrollView.delegate = self
        scrollView.showsHorizontalScrollIndicator = false
        return scrollView
    }()

    private let containerView: UIView = {
        let view = UIView()
        return view
    }()

    private lazy var productsCollectionView: UICollectionView = {
        let flowLayout = UICollectionViewFlowLayout()
        flowLayout.sectionInset = UIEdgeInsets(top: 0, left: 0, bottom: 12, right: 0)
        flowLayout.minimumLineSpacing = 8
        flowLayout.minimumInteritemSpacing = 0

        let collectionView = UICollectionView(frame: .zero, collectionViewLayout: flowLayout)
        collectionView.register(OverseasCollectionCell.self,
                                forCellWithReuseIdentifier: "OverseasCollectionCell")
        collectionView.register(OverseasFooterView.self,
                                forSupplementaryViewOfKind: UICollectionView.elementKindSectionFooter,
                                withReuseIdentifier: "OverseasFooter")
        collectionView.backgroundColor = .clear
        collectionView.delegate = self
        collectionView.dataSource = self
        collectionView.showsVerticalScrollIndicator = false
        return collectionView
    }()

    private lazy var discoveryCollectionView: UICollectionView = {
        let flowLayout = UICollectionViewFlowLayout()
        flowLayout.sectionInset = UIEdgeInsets(top: 0, left: 0, bottom: 12, right: 0)
        flowLayout.minimumLineSpacing = 8
        flowLayout.minimumInteritemSpacing = 0

        let collectionView = UICollectionView(frame: .zero, collectionViewLayout: flowLayout)
        collectionView.register(OverseasCollectionCell.self,
                                forCellWithReuseIdentifier: "OverseasCollectionCell")
        collectionView.backgroundColor = .clear
        collectionView.delegate = self
        collectionView.dataSource = self
        collectionView.showsVerticalScrollIndicator = false
        return collectionView
    }()

    private let contactUsTipsView: ContactUsTipsView = {
        let view = ContactUsTipsView()
        view.contactUsHandler = {
            TUICore.callService(TUICore_ContactUsService,
                                method: TUICore_ContactService_gotoContactUS,
                                param: [:])
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
                return LoginEntry.shared.userModel
            },
            generateUserSig: { userId in
                GenerateTestUserSig.genTestUserSig(identifier: userId, sdkAppId: SDKAPPID, secretKey: SECRETKEY)
            }
        )

        // ① 从 AppAssembly 获取所有场景模块并注册到首页
        // 海外版禁用实名认证（与旧版 Tencent-RTC/AppDelegate.configApp() 行为一致）
        PrivacyEntry.enableIdCardVerification = false

        #if !OPEN_SOURCE
        // 注入隐私模块统一动作回调（UI 由 privacy 模块提供）
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
            case .showHighRiskIPAlert:
                RoomRiskIPPresenter.showHighRiskIPAlert()
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
        constructViewHierarchy()
        activateConstraints()
        bindInteraction()

        // ④ 加载模块数据
        store.loadModules()
        splitModules()

        // ⑤ 订阅 Store 状态变化，驱动 UI 刷新
        bindStoreState()

        // ⑤.5 启动模块级埋点观察器 + 初始化埋点公共属性
        #if !DEBUG
        initAnalytics()
        ModuleAnalytics.start()
        #endif

        setupToast()
    }

    override var preferredStatusBarStyle: UIStatusBarStyle {
        if #available(iOS 13.0, *) {
            return .darkContent
        }
        return .default
    }

    override var prefersStatusBarHidden: Bool {
        false
    }

    // MARK: - Module Split

    /// 将全部模块按 identifier 分为 Products / Discovery 两组
    private func splitModules() {
        let allModules = store.state.modules.filter { $0.isVisible }
        productsModules = allModules.filter { !discoveryIdentifiers.contains($0.config.identifier) }
        discoveryModules = allModules.filter { discoveryIdentifiers.contains($0.config.identifier) }
    }

    // MARK: - State Binding

    private func bindStoreState() {
        store.$state
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                guard let self = self else { return }
                self.splitModules()
                self.productsCollectionView.reloadData()
                self.discoveryCollectionView.reloadData()
            }
            .store(in: &cancellables)
    }

    // MARK: - Public

    /// 更新未读消息红点
    func updateUnreadCount(_ totalUnreadCount: UInt64) {
        guard !productsModules.isEmpty else { return }
        // 未读数更新到第一个模块（Call 模块）
        let identifier = productsModules[0].config.identifier
        store.updateBadgeCount(for: identifier, count: totalUnreadCount)
        splitModules()
        DispatchQueue.main.async {
            self.productsCollectionView.reloadItems(at: [IndexPath(item: 0, section: 0)])
        }
    }
}

// MARK: - UI Setup

extension OverseasMainViewController {

    private func constructViewHierarchy() {
        view.addSubview(topSegmentedView)
        view.addSubview(scrollView)
        scrollView.addSubview(containerView)
        containerView.addSubview(productsCollectionView)
        containerView.addSubview(contactUsTipsView)
        containerView.addSubview(discoveryCollectionView)
    }

    private func activateConstraints() {
        topSegmentedView.snp.makeConstraints { make in
            make.leading.equalToSuperview().offset(16)
            make.trailing.equalToSuperview().offset(-16)
            make.top.equalToSuperview().offset(44 + statusBarHeight() + 8)
            make.height.equalTo(32)
        }

        scrollView.snp.makeConstraints { make in
            make.top.equalTo(topSegmentedView.snp.bottom).offset(8)
            make.leading.trailing.equalToSuperview()
            make.bottom.equalToSuperview()
        }

        containerView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
            make.height.equalToSuperview()
        }

        productsCollectionView.snp.makeConstraints { make in
            make.top.equalToSuperview()
            make.width.equalTo(ScreenWidth)
            make.left.equalToSuperview()
            make.bottom.equalToSuperview().offset(-12)
        }

        contactUsTipsView.snp.makeConstraints { make in
            make.top.equalToSuperview()
            make.leading.equalTo(productsCollectionView.snp.trailing)
            make.trailing.equalToSuperview()
        }

        discoveryCollectionView.snp.makeConstraints { make in
            make.top.equalTo(contactUsTipsView.snp.bottom).offset(4)
            make.width.equalTo(ScreenWidth)
            make.leading.equalTo(productsCollectionView.snp.trailing)
            make.trailing.equalToSuperview()
            make.bottom.equalToSuperview().offset(-12)
        }
    }

    private func bindInteraction() {
        topSegmentedView.addTarget(self, action: #selector(segmentChanged(_:)), for: .valueChanged)
    }

    @objc private func segmentChanged(_ sender: UISegmentedControl) {
        let page = sender.selectedSegmentIndex
        let targetOffset = CGPoint(x: CGFloat(page) * scrollView.frame.width, y: 0)
        scrollView.setContentOffset(scrollView.contentOffset, animated: false)

        UIView.animate(withDuration: 0.3, delay: 0, options: .curveEaseOut) {
            self.scrollView.contentOffset = targetOffset
        }
    }

    private func setupToast() {
        ToastManager.shared.position = .bottom
    }
}

// MARK: - UIScrollViewDelegate

extension OverseasMainViewController: UIScrollViewDelegate {
    func scrollViewDidScroll(_ scrollView: UIScrollView) {
        guard scrollView == self.scrollView else { return }
        let page = scrollView.contentOffset.x / scrollView.frame.width
        topSegmentedView.selectedSegmentIndex = Int(round(page))
    }
}

// MARK: - UICollectionViewDelegateFlowLayout

extension OverseasMainViewController: UICollectionViewDelegateFlowLayout {

    func collectionView(_ collectionView: UICollectionView,
                        layout collectionViewLayout: UICollectionViewLayout,
                        sizeForItemAt indexPath: IndexPath) -> CGSize {
        return CGSize(width: view.bounds.width - 40.0, height: 74)
    }

    func collectionView(_ collectionView: UICollectionView,
                        layout collectionViewLayout: UICollectionViewLayout,
                        referenceSizeForFooterInSection section: Int) -> CGSize {
        if collectionView == productsCollectionView {
            return CGSize(width: view.bounds.width - 40.0, height: 92)
        }
        return .zero
    }
}

// MARK: - UICollectionViewDelegate

extension OverseasMainViewController: UICollectionViewDelegate {

    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        let module: ResolvedModule
        if collectionView == productsCollectionView {
            guard indexPath.item < productsModules.count else { return }
            module = productsModules[indexPath.item]
        } else {
            guard indexPath.item < discoveryModules.count else { return }
            module = discoveryModules[indexPath.item]
        }

        // 埋点
        if !module.config.analyticsEvent.isEmpty {
            trackSensorData(module.config.analyticsEvent)
        }

        // 场景体验入口拦截：海外版 push MiniProgramViewController
        // 仅 TencentRTC（RTCUBE_OVERSEAS）target 真实编译进 MiniProgramViewController；
        // RTCube / RTCubeLab 虽然也编译此文件，但 Banner 卡片仅在海外配置中存在，
        // 加宏守卫主要解决符号查找问题
        if module.config.identifier == "scenes_application" {
            #if RTCUBE_OVERSEAS
            let miniVC = MiniProgramViewController()
            navigationController?.pushViewController(miniVC, animated: true)
            #endif
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

// MARK: - UICollectionViewDataSource

extension OverseasMainViewController: UICollectionViewDataSource {

    func collectionView(_ collectionView: UICollectionView,
                        numberOfItemsInSection section: Int) -> Int {
        if collectionView == productsCollectionView {
            return productsModules.count
        } else {
            return discoveryModules.count
        }
    }

    func collectionView(_ collectionView: UICollectionView,
                        cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCell(
            withReuseIdentifier: "OverseasCollectionCell",
            for: indexPath
        ) as! OverseasCollectionCell

        if collectionView == productsCollectionView {
            if indexPath.item < productsModules.count {
                cell.config(productsModules[indexPath.item])
            }
        } else {
            if indexPath.item < discoveryModules.count {
                cell.config(discoveryModules[indexPath.item])
            }
        }
        return cell
    }

    func collectionView(_ collectionView: UICollectionView,
                        viewForSupplementaryElementOfKind kind: String,
                        at indexPath: IndexPath) -> UICollectionReusableView {
        if collectionView == productsCollectionView,
           kind == UICollectionView.elementKindSectionFooter {
            let footerView = collectionView.dequeueReusableSupplementaryView(
                ofKind: kind,
                withReuseIdentifier: "OverseasFooter",
                for: indexPath
            ) as! OverseasFooterView
            let tap = UITapGestureRecognizer(target: self, action: #selector(goScenarioExperience))
            footerView.isUserInteractionEnabled = true
            footerView.addGestureRecognizer(tap)
            return footerView
        }
        return UICollectionReusableView()
    }
}

// MARK: - Navigation

extension OverseasMainViewController {

    @objc private func goScenarioExperience() {
        // 场景体验跳转 — 海外版直接 push MiniProgramViewController
        // （与 collectionView didSelectItemAt 中 scenes_application 拦截分支一致）
        // MiniProgramViewController 仅 TencentRTC（RTCUBE_OVERSEAS）target 编译，
        // 加宏守卫保证 RTCube / RTCubeLab 编译时能找到符号
        #if RTCUBE_OVERSEAS
        let miniVC = MiniProgramViewController()
        miniVC.title = MainLocalize("main_overseas_scenario_experience")
        navigationController?.pushViewController(miniVC, animated: true)
        #endif
    }
}

// MARK: - Analytics

extension OverseasMainViewController {

    private func initAnalytics() {
        let userId = LoginEntry.shared.userModel?.userId ?? ""
        let sdkAppId = LoginEntry.shared.config.sdkAppId
        let appVersion = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? ""
        let loginMode = LoginEntry.shared.loggedInMode?.rawValue ?? LoginMode.debugAuth.rawValue
        let appTarget = "overseas"
        AppAnalytics.initialize(sdkAppId: sdkAppId, userId: userId, appTarget: appTarget, appVersion: appVersion, loginMode: "\(loginMode)")
    }

    private func trackSensorData(_ event: String) {
        let loginType = resolveLoginType()
        AppAnalytics.trackMainClick(
            eventName: .tencentRTCMainClick,
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

        return "external"
    }
}
