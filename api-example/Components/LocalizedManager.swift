import UIKit

/**
 * Localization manager
 * Supports switching between Simplified Chinese and English
 * Follows the system language by default: zh-Hans for Simplified Chinese systems and English for all other system languages
 */
class LocalizedManager {

    static let shared = LocalizedManager()

    private let userDefaultsKey = "SelectedLanguage"
    
    /// The bundle for the current language, used to load localized strings
    private var currentBundle: Bundle?

    private init() {
        // Load the bundle for the current language during initialization
        loadBundle(for: currentLanguage)
    }

    // MARK: - Public Properties

    /// The current language, which follows the system language by default
    var currentLanguage: String {
        get {
            // If the user has selected a language, use the user's selection
            if let saved = UserDefaults.standard.string(forKey: userDefaultsKey) {
                return saved
            }
            // Otherwise, follow the system language by default
            return defaultLanguage
        }
        set {
            UserDefaults.standard.set(newValue, forKey: userDefaultsKey)
            UserDefaults.standard.synchronize()
            loadBundle(for: newValue)
            restartApp()
        }
    }

    /// Default language: zh-Hans for Simplified Chinese systems, English for others
    var defaultLanguage: String {
        let systemLang = Locale.current.language.languageCode?.identifier
        return systemLang == "zh" ? "zh-Hans" : "en"
    }

    var isChinese: Bool {
        return currentLanguage == "zh-Hans"
    }
    
    // MARK: - Private Methods
    
    private func loadBundle(for language: String) {
        if let path = Bundle.main.path(forResource: language, ofType: "lproj"),
           let bundle = Bundle(path: path) {
            currentBundle = bundle
        } else {
            // If the bundle for the target language cannot be found, use the main bundle
            currentBundle = Bundle.main
        }
    }

    // MARK: - Public Methods

    func localizedString(forKey key: String) -> String {
        // Load strings using the bundle for the current language
        return currentBundle?.localizedString(forKey: key, value: nil, table: nil) ?? key
    }

    func localizedString(forKey key: String, arguments: CVarArg...) -> String {
        let format = localizedString(forKey: key)
        return String(format: format, arguments: arguments)
    }

    func switchLanguage() {
        if currentLanguage == "zh-Hans" {
            currentLanguage = "en"
        } else {
            currentLanguage = "zh-Hans"
        }
    }

    /// Restart the app after switching the language
    func restartApp() {
        guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let window = windowScene.windows.first else {
            return
        }

        // Navigate directly to the login screen after switching the language
        let newRoot = UINavigationController(rootViewController: LoginViewController())
        
        window.rootViewController = newRoot
        window.makeKeyAndVisible()
    }

    func showLanguageSwitchAlert(in viewController: UIViewController) {
        let alert = UIAlertController(
            title: localizedString(forKey: "featureList.language"),
            message: nil,
            preferredStyle: .actionSheet
        )

        let chineseAction = UIAlertAction(title: "简体中文", style: .default) { [weak self] _ in
            self?.currentLanguage = "zh-Hans"
        }

        let englishAction = UIAlertAction(title: "English", style: .default) { [weak self] _ in
            self?.currentLanguage = "en"
        }

        let cancelAction = UIAlertAction(title: localizedString(forKey: "common.cancel"), style: .cancel)

        alert.addAction(chineseAction)
        alert.addAction(englishAction)
        alert.addAction(cancelAction)

        if let popover = alert.popoverPresentationController {
            popover.barButtonItem = viewController.navigationItem.rightBarButtonItem
        }

        viewController.present(alert, animated: true)
    }
}

// MARK: - Notification Name Extension

extension Notification.Name {
    static let languageChanged = Notification.Name("languageChanged")
}

// MARK: - String Extension for Localization

extension String {
    var localized: String {
        return LocalizedManager.shared.localizedString(forKey: self)
    }
}
