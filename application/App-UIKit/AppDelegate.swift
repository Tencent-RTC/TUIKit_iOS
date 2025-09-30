//
//  AppDelegate.swift
//  App-UIKit
//
//  Created by yukiwwwang on 2025/8/7.
//

import UIKit
import TUICore
import RTCRoomEngine
import AtomicX

@main
class AppDelegate: UIResponder, UIApplicationDelegate {
    func initKaraokeConfig() {
        KaraokeConfig.shared.updateConfig(SDKAPPID: Int32(SDKAPPID), SECRETKEY: SECRETKEY)
    }

    func application(_ application: UIApplication,
                     didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        initKaraokeConfig()
        return true
    }

    // MARK: UISceneSession Lifecycle

    func application(_ application: UIApplication,
                     configurationForConnecting connectingSceneSession: UISceneSession,
                     options: UIScene.ConnectionOptions) -> UISceneConfiguration {
        // Called when a new scene session is being created.
        // Use this method to select a configuration to create the new scene with.
        return UISceneConfiguration(name: "Default Configuration", sessionRole: connectingSceneSession.role)
    }

    func application(_ application: UIApplication, didDiscardSceneSessions sceneSessions: Set<UISceneSession>) {
    }
    
    func showMainViewController() {
        let mainViewController = MainViewController()
        let rootVC = AppNavigationController(rootViewController: mainViewController)

        if let keyWindow = SceneDelegate.getCurrentWindow() {
            keyWindow.rootViewController = rootVC
            keyWindow.makeKeyAndVisible()
        } else {
            debugPrint("window show MainViewController error")
        }
    }
    
    func showLoginViewController() {
        let loginVC = LoginViewController()
        let nav = AppNavigationController(rootViewController: loginVC)
        if let keyWindow = SceneDelegate.getCurrentWindow() {
            keyWindow.rootViewController = nav
            keyWindow.makeKeyAndVisible()
        }
        else {
            debugPrint("window error")
        }
    }
}
