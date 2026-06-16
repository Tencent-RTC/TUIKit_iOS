//
//  SceneDelegate.swift
//  RTCube / TencentRTC / RTCubeLab
//
//  壳工程场景入口 — 通过 LoginEntry 发起登录流程
//  根据编译宏区分不同 target 的登录方式：
//    - RTCube（国内版）→ 手机号 + iOA
//    - TencentRTC（海外版）→ 邮箱登录，默认英文
//    - RTCubeLab（开发测试）→ 登录方式选择面板
//

import AtomicX
import Login
import SnapKit
import UIKit
#if RTCUBE_OVERSEAS
import TCMPPSDK
#endif

class SceneDelegate: UIResponder, UIWindowSceneDelegate {
    var window: UIWindow?
    private var loginVC: UIViewController?

    /// TCMPP 小程序 SDK 的 delegate 实例（仅 TencentRTC target 真正持有）
    ///
    /// SDK 端 `miniAppSdkDelegate` 是 weak 引用，必须由 SceneDelegate 强持有避免 dealloc。
    /// 用 `Any?` 而非具体类型，避免非 RTCUBE_OVERSEAS target 编译时引用 `MiniProgramSDKDelegate` 符号。
    private var miniProgramDelegate: Any?

    func scene(_ scene: UIScene,
               willConnectTo session: UISceneSession,
               options connectionOptions: UIScene.ConnectionOptions)
    {
        AppLogger.App.info("SceneDelegate.scene(willConnectTo:)")
        guard let windowScene = (scene as? UIWindowScene) else { return }
        window = UIWindow(windowScene: windowScene)

        #if RTCUBE_OVERSEAS
        let rootVC = OverseasHomeViewController()
        #else
        let rootVC = EntranceViewController()
        #endif
        let navController = UINavigationController(rootViewController: rootVC)
        window?.rootViewController = navController

        // 登录模块/小程序 SDK 必须在 makeKeyAndVisible() 之前完成初始化：
        // makeKeyAndVisible() 会同步触发 rootVC 的 viewWillAppear，首页路径会读取
        // LoginEntry.shared.hasLoggedIn 决定是否播放开屏动画——此时若 LoginEntry 尚未
        // initialize，部分依赖 pendingLaunchActions 的能力会延后跑，启动期语义不一致。
        initializeLoginModule()
        prepareMiniProgramSDKIfNeeded()

        window?.makeKeyAndVisible()

        // showLogin 内部在未登录态会同步 present 登录页，必须在 window 成为 key 之后调用，
        // 否则 present 会被系统拒绝/告警。已登录态分支只跑后台自动登录，不依赖 key window。
        showLogin(animated: false)

        // 冷启动 URL 转发：App 被外部 URL Scheme 唤起冷启动时（如 ITLogin SSO 回跳），
        // URL 通过 connectionOptions.urlContexts 投递，必须主动消费，否则 SSO 流程会断链。
        handleOpenURLContexts(connectionOptions.urlContexts)
    }

    func sceneDidDisconnect(_ scene: UIScene) {}
    func sceneDidBecomeActive(_ scene: UIScene) {}
    func sceneWillResignActive(_ scene: UIScene) {}

    /// 热启动 URL 转发：App 已运行时被 URL Scheme 唤起（如 ITLogin SSO 回跳）。
    ///
    /// Scene 架构下，系统不再调用 `AppDelegate.application(_:open:options:)`，
    /// 必须在此实现并转发到 `AppLifecycleRegistry`，否则已注册的模块 handler（IOAAuth 等）收不到 URL。
    func scene(_ scene: UIScene, openURLContexts URLContexts: Set<UIOpenURLContext>) {
        handleOpenURLContexts(URLContexts)
    }

    /// 统一的 URL 转发入口：与 AppDelegate.application(_:open:options:) 行为对齐。
    ///
    /// 链路：
    /// 1. 模块级 handler（ITLogin SSO 等，由 Login 模块通过 `AppLifecycleRegistry` 内部封装拆解上下文）
    /// 2. 埋点 SDK 的 URL Scheme 处理（与上一步并列调用，互不抢占）
    ///
    /// 说明：此处作为**转发层**不感知环境，是否在 Debug 下静默由 `AppAnalytics` 门面内部负责
    /// （Debug 下神策 SDK 未初始化，`sharedInstance()` 返回 nil，调用自动短路）。
    private func handleOpenURLContexts(_ contexts: Set<UIOpenURLContext>) {
        AppLifecycleRegistry.shared.handleOpenURLContexts(contexts)
        contexts.forEach { _ = AppAnalytics.handleSchemeURL($0.url) }
    }

    func sceneWillEnterForeground(_ scene: UIScene) {
        // 刷新主题：当用户在系统设置中切换了外观模式后回到 App
        ThemeStore.shared.refreshSystemThemeIfNeeded()

        // #7 进前台时清除所有推送通知
        if let appDelegate = UIApplication.shared.delegate as? AppDelegate {
            appDelegate.clearAllNotifications()
        }
        // 转发给 AppLifecycleRegistry（供已注册的模块 handler 接收）
        AppLifecycleRegistry.shared.applicationWillEnterForeground(UIApplication.shared)
    }

    func sceneDidEnterBackground(_ scene: UIScene) {
        // 转发给 AppLifecycleRegistry
        AppLifecycleRegistry.shared.applicationDidEnterBackground(UIApplication.shared)
    }
}

extension SceneDelegate {
    /// 启动入口：rootVC 始终为主页，根据登录状态决定是否弹出登录页
    ///
    /// - 已登录：直接展示主页，后台静默自动登录；自动登录失败再弹出登录页
    /// - 未登录：主页上 present 登录页（视觉上直接看到登录页）
    func showLogin(animated: Bool = true) {
        let mode: LoginMode
        #if OPEN_SOURCE
        mode = .debugAuth
        #elseif RTCUBE_LAB
        mode = .menu
        #elseif RTCUBE_OVERSEAS
        mode = .emailVerify
        #else
        mode = .phoneVerify
        #endif

        AppLogger.App.info("SceneDelegate.showLogin mode=\(mode) hasLoggedIn=\(LoginEntry.shared.hasLoggedIn) autoLoginEnabled=\(LoginEntry.shared.isAutoLoginEnabled)")

        // 按需弹出登录页面
        loginVC = LoginEntry.shared.launch(mode: mode) { [weak self] result in
            guard let self = self else { return }
            switch result {
            case .success(let loginResult):
                AppLogger.App.info("SceneDelegate.showLogin SUCCESS userId=\(loginResult.userModel.userId)")
                // IM 登录成功后上报 deviceToken，恢复离线推送能力
                PushLifecycleHandler.shared.reportDeviceToken()

                let appDelegate = UIApplication.shared.delegate as? AppDelegate
                // #9 更新 Bugly 用户标识（不依赖 UI，立即执行）
                #if !OPEN_SOURCE
                appDelegate?.updateBuglyUserIdentifier(loginResult.userModel.userId)
                #endif

                // 埋点：绑定登录用户身份（门面内部封装神策 login(userId)）
                AppAnalytics.bindUser(loginResult.userModel.userId)

                // 登录成功后统一处理开屏动画 + 版本检测
                // 无论自动登录还是手动登录，都在此回调中决策是否播放：
                //   - 登录页在前台 → dismiss 整个呈现链 + 播放动画
                //   - 自动登录（无登录页） → 直接在 window 上播放动画
                self.playLaunchAnimationOnLoginSuccess {
                    guard let appDelegate = UIApplication.shared.delegate as? AppDelegate else { return }
                    appDelegate.checkAppUpdateVersion()
                }
            case .failure(let error):
                if case .tokenExpired = error {
                    AppLogger.App.warn("SceneDelegate.showLogin tokenExpired, present loginVC")
                    guard let loginVC = loginVC else { return }
                    loginVC.modalPresentationStyle = .fullScreen
                    window?.rootViewController?.present(loginVC, animated: false)
                } else {
                    AppLogger.App.warn("SceneDelegate.showLogin FAILED error=\(error)")
                }
            }
        }
        loginVC?.modalPresentationStyle = .fullScreen

        if !LoginEntry.shared.hasLoggedIn {
            if let loginVC = loginVC {
                window?.rootViewController?.present(loginVC, animated: animated)
            }
        }
    }

    private func initializeLoginModule() {
        #if RTCUBE_LAB
        LoginEntry.shared.initialAutoLoginEnabled = false
        #else
        LoginEntry.shared.initialAutoLoginEnabled = true
        #endif

        LoginEntry.shared.initialize(
            baseUrl: SERVERLESSURL,
            testBaseUrl: TEST_SERVERLESSURL,
            sdkAppId: SDKAPPID,
            secretKey: SECRETKEY,
            debugSdkAppId: DEBUG_SDKAPPID,
            debugSecretKey: DEBUG_SECRETKEY,
            isSetupService: true,
            apaasAppId: APAAS_APP_ID,
            ioaAppKey: IOAAPPKEY,
            ioaAppId: IOAAPPID
        )

        LoginEntry.shared.userSigGenerator = { identifier, sdkAppId, secretKey in
            GenerateTestUserSig.genTestUserSig(identifier: identifier, sdkAppId: sdkAppId, secretKey: secretKey)
        }

        // 注入隐私协议链接点击处理器
        LoginEntry.shared.privacyLinkHandler = { linkType, viewController in
            let pageType: PrivacyPageType
            switch linkType {
            case "privacy":
                pageType = .privacy
            case "privacySummary":
                pageType = .privacySummary
            case "agreement":
                pageType = .agreement
            case "dataCollection":
                pageType = .dataCollection
            case "thirdShare":
                pageType = .thirdShare
            default:
                return
            }
            PrivacyEntry.pushPrivacyPage(pageType, from: viewController)
        }

        LoginEntry.shared.onEnvironmentChanged = { env in
            EnvironmentOperation.switchEnvironment(testEnv: env == .test)
        }

        // 注入隐私协议同意回调
        LoginEntry.shared.onPrivacyAgreed = { isAgree in
            if isAgree {
                // 用户同意后初始化数据采集 SDK（如 Bugly、神策等）
                // 目前 v2 已在启动时初始化，此处留作合规扩展点
                AppLogger.App.info(" 用户同意隐私协议")
            }
        }

        LoginEntry.shared.onPassiveLogout = { [weak self] in
            self?.showLogin()
        }

        LoginEntry.shared.onTokenExpired = {
            // Token / UserSig 过期（精确语义事件）：清除开屏动画播放记录，
            // 让本次"过期重登成功"后重新进入首页时再次播放。
            LaunchAnimationCoordinator.resetForReLogin()
        }
    }
}

// MARK: - 开屏动画

extension SceneDelegate {
    /// 登录成功后的开屏动画统一入口。
    ///
    /// 无论自动登录还是手动登录，都在 `LoginEntry.shared.launch` 的 success 回调中调用本方法。
    /// 根据登录页是否在前台，自动选择处理策略：
    ///   - 登录页在前台：从 rootViewController dismiss 整个呈现链（animated: false），
    ///     然后在 window 上铺动画层并起播
    ///   - 自动登录（无登录页）：直接在 window 上铺动画层并起播
    ///
    /// - Parameter then: 动画播放完成（或不播放）后调用，用于推进 `checkAppUpdateVersion` 等后续业务
    func playLaunchAnimationOnLoginSuccess(then: @escaping () -> Void) {
        guard LaunchAnimationCoordinator.tryAcquirePlaybackForCurrentLaunch(),
              let videoURL = LaunchAnimationCoordinator.videoURL(),
              let window = window
        else {
            // 不需要播放动画（资源缺失 / 已播过本版本）：仅 dismiss 登录页（如有）
            if loginVC?.presentingViewController != nil {
                window?.rootViewController?.dismiss(animated: true) {
                    then()
                }
            } else {
                then()
            }
            return
        }

        let playAnimation = { [weak self] in
            guard let self = self, let window = self.window else {
                then()
                return
            }
            let animationView = LaunchAnimationPlayerView(videoURL: videoURL)
            window.addSubview(animationView)
            animationView.snp.makeConstraints { make in
                make.edges.equalToSuperview()
            }
            animationView.onFinished = { [weak animationView] reason in
                guard case .finished = reason, let view = animationView else {
                    animationView?.removeFromSuperview()
                    then()
                    return
                }
                LaunchAnimationCoordinator.markPlayedForCurrentVersion()
                view.isUserInteractionEnabled = false
                then()
                UIView.animate(
                    withDuration: 0.3,
                    animations: { view.alpha = 0 },
                    completion: { _ in view.removeFromSuperview() }
                )
            }
            animationView.play()
        }

        if loginVC?.presentingViewController != nil {
            // 登录页在前台：从 rootViewController dismiss 整个呈现链（loginVC + IOAAuthVC），
            // dismiss 完成后再铺动画层，避免 UIKit 转场重建 subview 层级导致动画层丢失。
            window.rootViewController?.dismiss(animated: false) {
                playAnimation()
            }
        } else {
            // 自动登录（无登录页）：直接铺动画层
            playAnimation()
        }
    }
}

// MARK: - TCMPP / 小程序 SDK 初始化

extension SceneDelegate {
    /// 初始化 TCMPP 小程序 SDK（仅 TencentRTC target 编译此分支）
    ///
    /// 1. 加载 `tcsas-configurations-iOS.json`（仅添加到 TencentRTC target main bundle）
    /// 2. 挂载 `MiniProgramSDKDelegate` —— 向 SDK 提供 Live License URL/Key（对齐 Android
    ///    `MiniAppProxyImpl.configData(TYPE_LIVE)`）。SDK 端是 weak 引用，必须由
    ///    SceneDelegate 强持有 delegate 实例。
    private func prepareMiniProgramSDKIfNeeded() {
        #if RTCUBE_OVERSEAS
        guard let filePath = Bundle.main.path(forResource: "tcsas-configurations-iOS", ofType: "json") else {
            AppLogger.App.info("[MiniProgram] tcsas-configurations-iOS.json 不存在，跳过 TCMPP 初始化")
            return
        }
        let config = TMAServerConfig(file: filePath)
        TMFMiniAppSDKManager.sharedInstance().setConfiguration(config)

        let delegate = MiniProgramSDKDelegate()
        miniProgramDelegate = delegate
        TMFMiniAppSDKManager.sharedInstance().miniAppSdkDelegate = delegate

        AppLogger.App.info("[MiniProgram] TCMPP SDK 已配置 + Live License delegate 已挂载")
        #endif
    }
}
