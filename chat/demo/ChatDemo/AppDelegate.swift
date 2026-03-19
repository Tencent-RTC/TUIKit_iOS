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
        
        // Sync user settings from UserDefaults to AppBuilderConfig
        // This ensures user preferences persist across app restarts
        syncUserSettingsToAppConfig()
    }
    
    private func syncUserSettingsToAppConfig() {
        // Sync enableReadReceipt
        let readReceiptKey = "com.atomicx.enableReadReceipt"
        if UserDefaults.standard.object(forKey: readReceiptKey) != nil {
            AppBuilderConfig.shared.enableReadReceipt = UserDefaults.standard.bool(forKey: readReceiptKey)
        }
        
        // Sync translateTargetLanguage
        let translateKey = "com.atomicx.translateTargetLanguage"
        if let saved = UserDefaults.standard.string(forKey: translateKey), !saved.isEmpty {
            AppBuilderConfig.shared.translateTargetLanguage = saved
        } else if AppBuilderConfig.shared.translateTargetLanguage.isEmpty {
            // Use system language as default if not set, map to SDK language codes
            var systemLanguage = LanguageHelper.getCurrentLanguage()
            if systemLanguage == "zh-Hans" {
                systemLanguage = "zh"
            } else if systemLanguage == "zh-Hant" {
                systemLanguage = "zh-TW"
            }
            AppBuilderConfig.shared.translateTargetLanguage = systemLanguage
        }
    }

    func application(_ application: UIApplication, configurationForConnecting connectingSceneSession: UISceneSession, options: UIScene.ConnectionOptions) -> UISceneConfiguration {
        return UISceneConfiguration(name: "Default Configuration", sessionRole: connectingSceneSession.role)
    }

    func application(_ application: UIApplication, didDiscardSceneSessions sceneSessions: Set<UISceneSession>) {}
}
