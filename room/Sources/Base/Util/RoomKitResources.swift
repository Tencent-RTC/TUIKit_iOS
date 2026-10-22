import UIKit

private final class RoomKitBundleToken {}

public enum RoomKitResources {

    public enum Language: String {
        case simplifiedChinese = "zh-Hans"
        case english = "en"
    }

    public static let languageDidChangeNotification = Notification.Name("RoomKitResourcesLanguageDidChange")

    public static let bundle: Bundle = {
        let containingBundle = Bundle(for: RoomKitBundleToken.self)
        let candidates = [containingBundle, .main]
        for candidate in candidates {
            if let url = candidate.url(forResource: "TUIRoomKitBundle", withExtension: "bundle"),
               let resourceBundle = Bundle(url: url) {
                return resourceBundle
            }
        }
        return containingBundle
    }()

    public static var language: Language {
        if let languageOverride { return languageOverride }
        let preferred = bundle.preferredLocalizations.first ?? Language.english.rawValue
        return preferred.hasPrefix("zh") ? .simplifiedChinese : .english
    }

    private static var languageOverride: Language?

    private static var localizedBundle: Bundle {
        guard let languageOverride,
              let path = bundle.path(forResource: languageOverride.rawValue, ofType: "lproj"),
              let languageBundle = Bundle(path: path) else {
            return bundle
        }
        return languageBundle
    }

    public static func setLanguage(_ language: Language) {
        let changed = language != self.language
        languageOverride = language
        if changed {
            NotificationCenter.default.post(name: languageDidChangeNotification, object: nil)
        }
    }

    public static func image(named name: String) -> UIImage? {
        UIImage(named: name, in: bundle, compatibleWith: nil)
    }

    public static func localizedString(_ key: String) -> String {
        localizedBundle.localizedString(forKey: key, value: key, table: nil)
    }

    public static func localizedFormat(_ key: String, _ replacements: String...) -> String {
        String(format: localizedString(key), arguments: replacements)
    }
}
