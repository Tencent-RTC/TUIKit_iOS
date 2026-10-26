import Foundation
import UIKit
class BundleHelper {
    static func atomicXBundle() -> Bundle {
        let bundlePath = getBundlePath(bundleName: "TUIChatKitBundle", classType: BundleHelper.self, frameworkName: "")
        guard let atomicXBundle = Bundle(path: bundlePath) else {
            return Bundle.main
        }
        return atomicXBundle
    }

    static func findLocalizableBundle(bundleName: String, classType: AnyClass, language: String, frameworkName: String) -> Bundle? {
        var bundleCache: [String: Bundle] = [:]
        let languageDir = "Localizable/\(language)"
        let cacheKey = "\(bundleName)_\(languageDir)"
        var bundle = bundleCache[cacheKey]
        if bundle == nil {
            let bundlePath = getBundlePath(bundleName: bundleName, classType: classType, frameworkName: frameworkName)
            if let path = Bundle(path: bundlePath)?.path(forResource: languageDir, ofType: "lproj") {
                bundle = Bundle(path: path)
                if let bundle = bundle {
                    bundleCache[cacheKey] = bundle
                }
            }
        }
        return bundle
    }

    static func getBundlePath(bundleName: String, classType: AnyClass, frameworkName: String) -> String {
#if SWIFT_PACKAGE
        if let spmPath = spmBundlePaths[bundleName] {
            return spmPath
        }
        if let found = findBundleInModule(named: bundleName), !spmBundlePaths.keys.contains(bundleName) {
            spmBundlePaths[bundleName] = found
            return found
        }
        return ""
#else
        var bundlePathCache: [String: String] = [:]
        let classTypeString = NSStringFromClass(classType)
        let bundlePathKey = "\(bundleName)_\(classTypeString)"
        if let bundlePath = bundlePathCache[bundlePathKey] {
            return bundlePath
        }

        var bundlePath = Bundle.main.path(forResource: bundleName, ofType: "bundle")

        if bundlePath == nil || bundlePath?.isEmpty == true {
            let frameworkBundlePath = Bundle(for: classType).path(forResource: frameworkName, ofType: "bundle")
            if let frameworkBundle = Bundle(path: frameworkBundlePath ?? "") {
                bundlePath = frameworkBundle.path(forResource: bundleName, ofType: "bundle")
            }
        }

        if (bundlePath == nil || bundlePath?.isEmpty == true) && !frameworkName.isEmpty {
            var path = Bundle.main.bundlePath
            path = (path as NSString).appendingPathComponent("Frameworks")
            path = (path as NSString).appendingPathComponent(frameworkName)
            path = (path as NSString).appendingPathExtension("framework") ?? path
            path = (path as NSString).appendingPathComponent(bundleName)
            bundlePath = (path as NSString).appendingPathExtension("bundle")
        }
        if let finalPath = bundlePath {
            bundlePathCache[bundlePathKey] = finalPath
        }
        return bundlePath ?? ""
#endif
    }

#if SWIFT_PACKAGE
    private static var spmBundlePaths: [String: String] = [:]

    private static func findBundleInModule(named bundleName: String) -> String? {
        let root = Bundle.module.bundleURL
        guard let enumerator = FileManager.default.enumerator(at: root, includingPropertiesForKeys: nil) else { return nil }
        let target = "\(bundleName).bundle"
        while let url = enumerator.nextObject() as? URL {
            if url.lastPathComponent == target {
                return url.path
            }
        }
        return nil
    }
#endif
}

public class AtomicXChatResources {
    static let frameworkBundle = Bundle(for: AtomicXChatResources.self)
    static var resourceBundle: Bundle {
#if SWIFT_PACKAGE
        return Bundle.module
#else
        if let bundlePath = frameworkBundle.path(forResource: "TUIChatKitBundle", ofType: "bundle"),
           let bundle = Bundle(path: bundlePath)
        {
            return bundle
        }
        return frameworkBundle
#endif
    }

    private static let rtlMirroredImageNames: Set<String> = [
        "contact_info_back",
        "contact_info_arrow_right",
        "message_forward",
        "message_recall",
        "message_multi_forward_separate",
        "message_multi_forward_merge",
        "message_call_audio",
        "message_call_video"
    ]

    public static func image(named name: String) -> UIImage? {
        let image = UIImage(named: name, in: resourceBundle, compatibleWith: nil)
        guard let image = image, rtlMirroredImageNames.contains(name) else { return image }
        return image.imageFlippedForRightToLeftLayoutDirection()
    }
}
