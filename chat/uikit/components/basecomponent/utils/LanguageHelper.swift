import Foundation
import UIKit

let AppLanguageKey = "AtomicXLanguageKey"
let AppLanguageChangedNotification = "AtomicXLanguageChangedKey"

@inline(__always)
public func LocalizedChatString(_ key: String) -> String {
    LanguageHelper.localizedChatString(key)
}

public class LanguageHelper {
    class func getLocalizedString(forKey key: String, bundle bundleName: String, classType: AnyClass, frameworkName: String) -> String {
        let currentLanguage = getCurrentLanguage()
        if let bundle = BundleHelper.findLocalizableBundle(
            bundleName: bundleName,
            classType: classType,
            language: currentLanguage,
            frameworkName: frameworkName
        ) {
            return bundle.localizedString(forKey: key, value: key, table: nil)
        }
        return key
    }

    class func localizedChatString(_ key: String) -> String {
        return getLocalizedString(forKey: key, bundle: "ChatLocalizable", classType: LanguageHelper.self, frameworkName: "ChatUIKitBundle")
    }


    public static func getCurrentLanguage() -> String {
        if let savedLanguage = UserDefaults.standard.string(forKey: AppLanguageKey), !savedLanguage.isEmpty {
            return savedLanguage
        }
        return getSystemLanguage()
    }

    public static var isRTL: Bool {
        let language = getCurrentLanguage()
        return ["ar", "he", "fa", "ur"].contains { language.hasPrefix($0) }
    }

    public static var currentSemanticContentAttribute: UISemanticContentAttribute {
        isRTL ? .forceRightToLeft : .forceLeftToRight
    }

    public static func applyLayoutDirection(to view: UIView) {
        view.semanticContentAttribute = currentSemanticContentAttribute
    }

    public static func saveLanguage(_ languageCode: String) {
        UserDefaults.standard.set(languageCode, forKey: AppLanguageKey)
        UserDefaults.standard.synchronize()
        NotificationCenter.default.post(name: Notification.Name(AppLanguageChangedNotification), object: nil)
    }

    private static func getSystemLanguage() -> String {
        let preferredLanguage = Locale.preferredLanguages.first ?? "en"
        if preferredLanguage.hasPrefix("en") {
            return "en"
        } else if preferredLanguage.hasPrefix("zh") {
            if preferredLanguage.contains("Hans") {
                return "zh-Hans"
            } else {
                return "zh-Hant"
            }
        } else if preferredLanguage.hasPrefix("ar") {
            return "ar"
        } else {
            return "en"
        }
    }
}

