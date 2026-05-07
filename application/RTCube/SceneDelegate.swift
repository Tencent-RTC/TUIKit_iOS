//
//  SceneDelegate.swift
//  RTCube / TencentRTC / RTCubeLab
//

import AtomicX
import Login
import UIKit

class SceneDelegate: UIResponder, UIWindowSceneDelegate {
    var window: UIWindow?
    private var loginVC: UIViewController?

    func scene(_ scene: UIScene,
               willConnectTo session: UISceneSession,
               options connectionOptions: UIScene.ConnectionOptions)
    {
        guard let windowScene = (scene as? UIWindowScene) else { return }
        window = UIWindow(windowScene: windowScene)

        #if RTCUBE_OVERSEAS
        let rootVC = OverseasHomeViewController()
        #else
        let rootVC = EntranceViewController()
        #endif
        let navController = UINavigationController(rootViewController: rootVC)
        window?.rootViewController = navController
        window?.makeKeyAndVisible()

        initializeLoginModule()
        showLogin(animated: false)
    }

    func sceneDidDisconnect(_ scene: UIScene) {}
    func sceneDidBecomeActive(_ scene: UIScene) {}
    func sceneWillResignActive(_ scene: UIScene) {}

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

        loginVC = LoginEntry.shared.launch(mode: mode) { [weak self] result in
            guard let self = self else { return }
            switch result {
            case .success(let loginResult):
                AppLogger.App.info(" 登录成功: \(loginResult.userModel.userId)")
                PushLifecycleHandler.shared.reportDeviceToken()

                let appDelegate = UIApplication.shared.delegate as? AppDelegate
                #if !OPEN_SOURCE
                appDelegate?.updateBuglyUserIdentifier(loginResult.userModel.userId)
                #endif

                AppAnalytics.bindUser(loginResult.userModel.userId)

                if self.loginVC?.presentingViewController != nil {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1) { [weak self] in
                        guard let self = self else { return }
                        self.loginVC?.dismiss(animated: true) {
                            guard let appDelegate = UIApplication.shared.delegate as? AppDelegate else { return }
                            appDelegate.checkAppUpdateVersion()
                        }
                    }
                } else {
                    appDelegate?.checkAppUpdateVersion()
                }
            case .failure(let error):
                if case .tokenExpired = error {
                    guard let loginVC = loginVC else { return }
                    loginVC.modalPresentationStyle = .fullScreen
                    window?.rootViewController?.present(loginVC, animated: false)
                    AppLogger.App.info(" 自动登录失败，拉起登录页面")
                } else {
                    AppLogger.App.info(" 登录失败/取消: \(error)")
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
            default:
                return
            }
            PrivacyEntry.pushPrivacyPage(pageType, from: viewController)
        }

        LoginEntry.shared.onEnvironmentChanged = { env in
            EnvironmentOperation.switchEnvironment(testEnv: env == .test)
        }

        LoginEntry.shared.onPassiveLogout = { [weak self] in
            self?.showLogin()
        }
    }
}
