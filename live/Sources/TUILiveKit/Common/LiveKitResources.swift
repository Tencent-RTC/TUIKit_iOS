import UIKit

private final class LiveKitBundleToken {}

enum LiveKitResources {
    static let presetCoverURLs = (1...5).map {
        "https://liteav-test-1252463788.cos.ap-guangzhou.myqcloud.com/live/live_cover\($0).png"
    }
    static let defaultCoverURL = presetCoverURLs[0]
    static let defaultBackgroundURL = "https://liteav.sdk.qcloud.com/app/res/picture/livekit/coGuestBackGroud.png"

    static let bundle: Bundle = {
        // SwiftPM: Bundle.module -> TUILiveKit_TUILiveKit.bundle
        // CocoaPods: resource bundle is named TUILiveKitBundle
        #if SWIFT_PACKAGE
            return Bundle.module
        #else
            let containingBundle = Bundle(for: LiveKitBundleToken.self)
            let candidates = [containingBundle, .main]
            for candidate in candidates {
                if let url = candidate.url(forResource: "TUILiveKitBundle", withExtension: "bundle"),
                    let resourceBundle = Bundle(url: url)
                {
                    return resourceBundle
                }
            }
            return containingBundle
        #endif
    }()

    static func image(named name: String) -> UIImage? { UIImage(named: name, in: bundle, compatibleWith: nil) }

    static var giftLanguageCode: String {
        let identifier = Bundle.main.preferredLocalizations.first ?? Locale.preferredLanguages.first ?? "en"
        let languageTag = identifier.replacingOccurrences(of: "_", with: "-").lowercased()
        guard languageTag == "zh" || languageTag.hasPrefix("zh-") else { return "en" }
        if languageTag.contains("hans") || languageTag == "zh" || languageTag.hasPrefix("zh-cn")
            || languageTag.hasPrefix("zh-sg") || languageTag.hasPrefix("zh-my")
        {
            return "zh-Hans"
        }
        return "zh-Hant"
    }

    // An empty translation is a valid override, so use a distinct missing-key marker.
    private static let missingLocalizationMarker = UUID().uuidString

    static func localizedString(_ key: String) -> String {
        let appValue = Bundle.main.localizedString(
            forKey: key, value: missingLocalizationMarker, table: "TUILiveKitLocalized")
        if appValue != missingLocalizationMarker { return appValue }
        return bundle.localizedString(forKey: key, value: key, table: nil)
    }

    static func localizedFormat(_ key: String, _ arguments: CVarArg...) -> String {
        String(format: localizedString(key), locale: Locale.current, arguments: arguments)
    }
}

// Platform-only leases allow overlapping Feed players to release in any order.
@MainActor enum LiveScreenAwake {
    private static var owners = Set<UUID>()
    private static var previousValue: Bool?

    static func setEnabled(_ owner: UUID, _ enabled: Bool) {
        if enabled {
            if owners.isEmpty { previousValue = UIApplication.shared.isIdleTimerDisabled }
            owners.insert(owner)
            UIApplication.shared.isIdleTimerDisabled = true
        } else {
            owners.remove(owner)
            if owners.isEmpty, let previousValue {
                UIApplication.shared.isIdleTimerDisabled = previousValue
                self.previousValue = nil
            }
        }
    }
}
