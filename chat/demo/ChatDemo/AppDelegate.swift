import AtomicX
import UIKit

@main
class AppDelegate: UIResponder, UIApplicationDelegate {
    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        setupAppConfiguration()
        return true
    }

    private func setupAppConfiguration() {
        if let configPath = Bundle.main.path(forResource: "appConfig", ofType: "json") {
            print("appConfig.json existed: \(configPath)")
            AppBuilderHelper.setJsonPath(path: configPath)
        } else {
            print("appConfig.json not found")
        }
    }

    func application(_ application: UIApplication, configurationForConnecting connectingSceneSession: UISceneSession, options: UIScene.ConnectionOptions) -> UISceneConfiguration {
        return UISceneConfiguration(name: "Default Configuration", sessionRole: connectingSceneSession.role)
    }

    func application(_ application: UIApplication, didDiscardSceneSessions sceneSessions: Set<UISceneSession>) {}
}
