import UIKit

final class CallKitResources {

    private static let bundle: Bundle = {
        #if SWIFT_PACKAGE
        return Bundle.module
        #else
        let candidates = [Bundle(for: CallKitResources.self), Bundle.main]
        for base in candidates {
            if let url = base.url(forResource: "TUICallKitBundle", withExtension: "bundle"),
               let bundle = Bundle(url: url) {
                return bundle
            }
        }
        return Bundle(for: CallKitResources.self)
        #endif
    }()

    static func image(named name: String) -> UIImage? {
        UIImage(named: name, in: bundle, compatibleWith: nil)
    }

    static func text(_ key: String) -> String {
        bundle.localizedString(forKey: key, value: nil, table: nil)
    }

    static func audioPath(_ name: String) -> String? {
        bundle.path(forResource: name, ofType: nil, inDirectory: "AudioFile")
    }

    static func badgeIconPath(_ name: String) -> String? {
        bundle.path(forResource: name, ofType: nil, inDirectory: "BadgeIcons")
    }
}
