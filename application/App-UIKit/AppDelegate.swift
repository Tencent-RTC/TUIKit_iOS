import AtomicXCore
import Combine
import Network
import TUIRoomKit
import UIKit

@main final class AppDelegate: UIResponder, UIApplicationDelegate {
    private var loginEvents: AnyCancellable?

    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
    ) -> Bool {
        // 必须与 TUIKitReplay/SampleHandler.swift 的 APPGROUP 保持一致。
        RoomScreenShareLauncher.shared.configure(
            appGroup: "group.com.tencent.liveadapter.demo",
            preferredExtension: (Bundle.main.bundleIdentifier ?? "") + ".upload"
        )
        loginEvents = LoginStore.shared.loginEventPublisher.receive(on: DispatchQueue.main).sink { [weak self] event in
            switch event {
            case .kickedOffline: self?.showLoginViewController()
            case .loginExpired: self?.showLoginViewController()
            @unknown default: self?.showLoginViewController()
            }
        }
        return true
    }

    func application(
        _ application: UIApplication, configurationForConnecting connectingSceneSession: UISceneSession,
        options: UIScene.ConnectionOptions
    ) -> UISceneConfiguration {
        UISceneConfiguration(name: "Default Configuration", sessionRole: connectingSceneSession.role)
    }

    func showMainViewController() { show(MainViewController()) }
    func showLoginViewController() {
        let controller = LoginViewController()
        controller.allowsAutomaticLogin = false
        show(controller)
    }

    private func show(_ controller: UIViewController) {
        guard let window = SceneDelegate.getCurrentWindow() else { return }
        window.rootViewController = AppNavigationController(rootViewController: controller)
        window.makeKeyAndVisible()
    }
}
