import UIKit

private final class LiveKitBundleToken {}

enum LiveKitResources {
    static let presetCoverURLs = (1 ... 5).map {
        "https://liteav-test-1252463788.cos.ap-guangzhou.myqcloud.com/live/live_cover\($0).png"
    }
    static let defaultCoverURL = presetCoverURLs[0]

    static let defaultBackgroundURL = "https://liteav.sdk.qcloud.com/app/res/picture/livekit/coGuestBackGroud.png"

    static let bundle: Bundle = {
        let containingBundle = Bundle(for: LiveKitBundleToken.self)
        let candidates = [containingBundle, .main]
        for candidate in candidates {
            if let url = candidate.url(forResource: "TUILiveKitBundle", withExtension: "bundle"),
               let resourceBundle = Bundle(url: url) {
                return resourceBundle
            }
        }
        return containingBundle
    }()

    static func image(named name: String) -> UIImage? {
        UIImage(named: name, in: bundle, compatibleWith: nil)
    }

    // An empty translation is a valid override, so use a distinct missing-key marker.
    private static let missingLocalizationMarker = UUID().uuidString

    static func localizedString(_ key: String) -> String {
        let appValue = Bundle.main.localizedString(
            forKey: key,
            value: missingLocalizationMarker,
            table: "TUILiveKitLocalized"
        )
        if appValue != missingLocalizationMarker {
            return appValue
        }
        return bundle.localizedString(forKey: key, value: key, table: nil)
    }

    static func localizedFormat(_ key: String, _ arguments: CVarArg...) -> String {
        String(
            format: localizedString(key),
            locale: Locale.current,
            arguments: arguments
        )
    }
}
