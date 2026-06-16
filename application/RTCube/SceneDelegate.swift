//
//  SceneDelegate.swift
//  RTCube / TencentRTC / RTCubeLab
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

        initializeLoginModule()
        prepareMiniProgramSDKIfNeeded()

        window?.makeKeyAndVisible()

        showLogin(animated: false)

        handleOpenURLContexts(connectionOptions.urlContexts)
    }

    func sceneDidDisconnect(_ scene: UIScene) {}
    func sceneDidBecomeActive(_ scene: UIScene) {}
    func sceneWillResignActive(_ scene: UIScene) {}

    func scene(_ scene: UIScene, openURLContexts URLContexts: Set<UIOpenURLContext>) {
        handleOpenURLContexts(URLContexts)
    }

    private func handleOpenURLContexts(_ contexts: Set<UIOpenURLContext>) {
        AppLifecycleRegistry.shared.handleOpenURLContexts(contexts)
        contexts.forEach { _ = AppAnalytics.handleSchemeURL($0.url) }
    }

    func sceneWillEnterForeground(_ scene: UIScene) {
        ThemeStore.shared.refreshSystemThemeIfNeeded()

        if let appDelegate = UIApplication.shared.delegate as? AppDelegate {
            appDelegate.clearAllNotifications()
        }
        AppLifecycleRegistry.shared.applicationWillEnterForeground(UIApplication.shared)
    }

    func sceneDidEnterBackground(_ scene: UIScene) {
        AppLifecycleRegistry.shared.applicationDidEnterBackground(UIApplication.shared)
    }
}

extension SceneDelegate {
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

        loginVC = LoginEntry.shared.launch(mode: mode) { [weak self] result in
            guard let self = self else { return }
            switch result {
            case .success(let loginResult):
                AppLogger.App.info("SceneDelegate.showLogin SUCCESS userId=\(loginResult.userModel.userId)")
                PushLifecycleHandler.shared.reportDeviceToken()

                let appDelegate = UIApplication.shared.delegate as? AppDelegate
                #if !OPEN_SOURCE
                appDelegate?.updateBuglyUserIdentifier(loginResult.userModel.userId)
                #endif

                AppAnalytics.bindUser(loginResult.userModel.userId)

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

        LoginEntry.shared.onPrivacyAgreed = { isAgree in
            if isAgree {
                AppLogger.App.info(" 用户同意隐私协议")
            }
        }

        LoginEntry.shared.onPassiveLogout = { [weak self] in
            self?.showLogin()
        }

        LoginEntry.shared.onTokenExpired = {
            LaunchAnimationCoordinator.resetForReLogin()
        }
    }
}

extension SceneDelegate {
    func playLaunchAnimationOnLoginSuccess(then: @escaping () -> Void) {
        guard LaunchAnimationCoordinator.tryAcquirePlaybackForCurrentLaunch(),
              let videoURL = LaunchAnimationCoordinator.videoURL(),
              let window = window
        else {
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
            window.rootViewController?.dismiss(animated: false) {
                playAnimation()
            }
        } else {
            playAnimation()
        }
    }
}

extension SceneDelegate {
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
