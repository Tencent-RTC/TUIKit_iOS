import AlbumPickerCore
import UIKit

private let AlbumPickerLocalizeTableName = "AlbumPickerLocalized"

internal extension String {
    func albumPickerLocalized() -> String {
        AlbumPickerBundleHelper.localizedString(forKey: self)
    }
}

internal extension UIImage {
    static func albumPickerIcon(named name: String) -> UIImage? {
        for bundle in AlbumPickerBundleHelper.allResourceBundles {
            if let image = UIImage(named: name, in: bundle, compatibleWith: nil) {
                return image
            }
        }
        return nil
    }
}

private class AlbumPickerBundleToken {}

internal enum AlbumPickerBundleHelper {    
    static var version: String {
        let bundle = findResourceBundle(named: "AlbumPickerBundle")
        return bundle?.infoDictionary?["CFBundleShortVersionString"] as? String ?? "unknown"
    }

    static let allResourceBundles: [Bundle] = {
        var bundles: [Bundle] = []
        if let uiBundle = findResourceBundle(named: "AlbumPickerBundle") {
            bundles.append(uiBundle)
        }
        if let coreBundle = findResourceBundle(named: "AlbumPickerStoreBundle")
            ?? findResourceBundle(named: "AlbumPickerCoreBundle") {
            bundles.append(coreBundle)
        }
        if bundles.isEmpty {
            bundles.append(.main)
        }
        return bundles
    }()

    static func localizedString(forKey key: String) -> String {
        for resourceBundle in allResourceBundles {
            let localizedBundle = findLocalizedBundle(in: resourceBundle) ?? resourceBundle
            let result = localizedBundle.localizedString(
                forKey: key, value: "", table: AlbumPickerLocalizeTableName
            )
            if !result.isEmpty, result != key {
                return result
            }
            let fallback = resourceBundle.localizedString(
                forKey: key, value: "", table: AlbumPickerLocalizeTableName
            )
            if !fallback.isEmpty, fallback != key {
                return fallback
            }
        }
        return key
    }
    

    private static func findLocalizedBundle(in bundle: Bundle) -> Bundle? {
        guard let lprojPath = findLprojPath(in: bundle) else { return nil }
        return Bundle(path: lprojPath)
    }

    private static func findLprojPath(in bundle: Bundle) -> String? {
        let preferredLanguages = AlbumPickerCoreLanguage.shared.current.languageIdentifiers
        for language in preferredLanguages {
            let candidates = lprojCandidates(for: language)
            for candidate in candidates {
                if let path = bundle.path(forResource: candidate, ofType: "lproj") {
                    return path
                }
            }
        }
        if let path = bundle.path(forResource: "en", ofType: "lproj") {
            return path
        }
        return nil
    }

    private static func lprojCandidates(for language: String) -> [String] {
        var candidates: [String] = [language]
        let replaced = language.replacingOccurrences(of: "-", with: "_")
        if replaced != language { candidates.append(replaced) }
        var remaining = language
        while let hyphenRange = remaining.range(of: "-", options: .backwards) {
            remaining = String(remaining[..<hyphenRange.lowerBound])
            if !candidates.contains(remaining) {
                candidates.append(remaining)
            }
        }
        remaining = language
        while let underscoreRange = remaining.range(of: "_", options: .backwards) {
            remaining = String(remaining[..<underscoreRange.lowerBound])
            if !candidates.contains(remaining) {
                candidates.append(remaining)
            }
        }
        return candidates
    }

    private static func findResourceBundle(named name: String) -> Bundle? {
        let candidates = [
            Bundle(for: AlbumPickerBundleToken.self)
                .url(forResource: name, withExtension: "bundle"),
            Bundle.main
                .url(forResource: name, withExtension: "bundle"),
        ]
        for case let url? in candidates {
            if let bundle = Bundle(url: url) {
                return bundle
            }
        }
        return nil
    }
}
