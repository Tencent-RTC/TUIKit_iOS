import Foundation

enum LiveGiftLanguage {
    static var currentCode: String {
        let identifier = Bundle.main.preferredLocalizations.first
            ?? Locale.preferredLanguages.first
            ?? "en"
        let languageTag = identifier.replacingOccurrences(of: "_", with: "-").lowercased()
        guard languageTag == "zh" || languageTag.hasPrefix("zh-") else { return "en" }
        if languageTag.contains("hans")
            || languageTag == "zh"
            || languageTag.hasPrefix("zh-cn")
            || languageTag.hasPrefix("zh-sg")
            || languageTag.hasPrefix("zh-my")
        {
            return "zh-Hans"
        }
        return "zh-Hant"
    }
}
