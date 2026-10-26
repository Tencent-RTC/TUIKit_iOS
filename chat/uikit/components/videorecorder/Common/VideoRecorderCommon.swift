import UIKit

final class VideoRecorderCommon {
    private static let chatEngineLanguageKey = "AtomicXLanguageKey"

    private static let bundleResourceUrlPrefix = "file:///asset/"

    private static let hexComponentMaxValue: CGFloat = 255

    static var assetsBundle: Bundle? {
        guard let modleBundle = modleNSBundle else {
            print("error: can not find TUIChatKitBundle")
            return nil
        }
        guard let videoRecorderURL = modleBundle.url(forResource: "VideoRecorder", withExtension: "bundle") else {
            print("error: can not find VideoRecorder.bundle")
            return nil
        }
        guard let videoRecorderBundle = Bundle(url: videoRecorderURL) else {
            print("error: can not load VideoRecorder.bundle")
            return nil
        }
        return videoRecorderBundle
    }

    static var stringBundle: Bundle? {
        guard let modleBundle = modleNSBundle else {
            print("error: can not find TUIChatKitBundle")
            return nil
        }
        guard let localizableURL = modleBundle.url(forResource: "VideoRecorderLocalizable", withExtension: "bundle") else {
            print("error: can not find VideoRecorderLocalizable.bundle")
            return nil
        }
        guard let localizableBundle = Bundle(url: localizableURL) else {
            print("error: can not load VideoRecorderLocalizable.bundle")
            return nil
        }
        return localizableBundle
    }

    static var modleNSBundle: Bundle? {
        let mainBundle = Bundle(for: VideoRecorderCommon.self)
        guard let atomicBundleURL = mainBundle.url(forResource: "TUIChatKitBundle", withExtension: "bundle") else {
            return nil
        }
        return Bundle(url: atomicBundleURL)
    }

    static func bundleImageByName(_ name: String) -> UIImage? {
        guard let bundle = modleNSBundle else { return nil }
        return UIImage(named: name, in: bundle, compatibleWith: nil)
    }

    static func bundleRawImageByName(_ name: String) -> UIImage? {
        guard let bundle = assetsBundle, let resourcePath = bundle.resourcePath else { return nil }
        return UIImage(contentsOfFile: "\(resourcePath)/\(name)")
    }

    static func localizedStringForKey(_ key: String) -> String {
        let language = getPreferredLanguage()
        var path = stringBundle?.path(forResource: language, ofType: "lproj")
        if path == nil {
            path = stringBundle?.path(forResource: "en", ofType: "lproj")
        }
        let languageBundle = path.flatMap { Bundle(path: $0) }
        return languageBundle?.localizedString(forKey: key, value: nil, table: nil) ?? key
    }

    static func colorFromHex(_ hex: String) -> UIColor {
        return tui_colorWithHex(hex)
    }

    static func sortedBundleResourcesIn(_ directory: String, withExtension ext: String) -> [String]? {
        guard let bundle = assetsBundle, let basePath = bundle.resourcePath else { return nil }
        let resources = bundle.paths(forResourcesOfType: ext, inDirectory: directory).map { path in
            String(path.dropFirst(basePath.count + 1))
        }
        return resources.sorted { $0.compare($1) == .orderedAscending }
    }

    static func getURLByResourcePath(_ path: String?) -> URL? {
        guard let path = path, let bundle = assetsBundle else { return nil }
        guard path.hasPrefix(bundleResourceUrlPrefix) else {
            guard let url = URL(string: path), url.scheme != nil else {
                return URL(fileURLWithPath: path)
            }
            return url
        }
        return URL(string: String(path.dropFirst(bundleResourceUrlPrefix.count)), relativeTo: bundle.resourceURL)
    }

    static func dynamicImage(_ imageKey: String, defaultImageName image: String) -> UIImage? {
        guard let bundle = modleNSBundle else { return nil }
        return UIImage(named: image, in: bundle, compatibleWith: nil)
    }

    static func dynamicColor(_ colorKey: String, defaultColor hex: String) -> UIColor {
        return tui_colorWithHex(hex)
    }

    static func tui_colorWithHex(_ hex: String) -> UIColor {
        if hex.isEmpty {
            return .clear
        }

        var hexString = hex
        if hexString.hasPrefix("#") {
            hexString = String(hexString.dropFirst(1))
        } else if hexString.hasPrefix("0x") {
            hexString = String(hexString.dropFirst(2))
        }

        let length = hexString.count
        guard length == 3 || length == 6 || length == 8 else {
            return UIColor()
        }

        if length == 3 {
            hexString = hexString.map { "\($0)\($0)" }.joined() + "ff"
        } else if length == 6 {
            hexString += "ff"
        }

        let red = hexComponent(hexString, offset: 0)
        let green = hexComponent(hexString, offset: 2)
        let blue = hexComponent(hexString, offset: 4)
        let alpha = hexComponent(hexString, offset: 6)
        return UIColor(red: red, green: green, blue: blue, alpha: alpha)
    }

    static func getPreferredLanguage() -> String {
        if let customLanguage = UserDefaults.standard.object(forKey: chatEngineLanguageKey) as? String,
           !customLanguage.isEmpty {
            return customLanguage
        }

        let language = Locale.preferredLanguages.first ?? ""
        if language.hasPrefix("en") {
            return "en"
        }
        if language.hasPrefix("zh") {
            return language.contains("Hans") ? "zh-Hans" : "zh-Hant"
        }
        if language.hasPrefix("ar") {
            return "ar"
        }
        return "en"
    }

    private static func hexComponent(_ hexString: String, offset: Int) -> CGFloat {
        let start = hexString.index(hexString.startIndex, offsetBy: offset)
        let end = hexString.index(start, offsetBy: 2)
        let value = UInt(hexString[start..<end], radix: 16) ?? 0
        return CGFloat(value) / hexComponentMaxValue
    }
}
