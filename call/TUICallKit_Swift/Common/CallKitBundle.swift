//
//  CallKitBundle.swift
//  Pods
//
//  Created by vincepzhang on 2025/3/3.
//

import UIKit
import TUICore

private final class CallKitBundleToken {}

enum CallKitBundle {
    static let localizedTableName = "TUICallKitLocalized"
    
    private static let bundleName = "TUICallKitBundle"
    private static let frameworkName = "TUICallKit"
    private static let bundleExtension = "bundle"
    private static let frameworkExtension = "framework"
    private static let fallbackLanguage = "en"
    
    private static let resourceBundle: Bundle? = {
        return candidateBundleURLs()
            .compactMap { $0 }
            .compactMap { Bundle(url: $0) }
            .first
    }()
    
    static func getTUICallKitBundle() -> Bundle? {
        return resourceBundle
    }
    
    static func getBundleImage(name: String) -> UIImage? {
        return UIImage(named: name, in: resourceBundle, compatibleWith: nil)
    }
    
    static func localizedString(forKey key: String, table: String = localizedTableName) -> String {
        guard let bundle = resourceBundle else {
            return key
        }
        
        return preferredLanguages()
            .compactMap { localizedBundle(for: $0, in: bundle) }
            .lazy
            .compactMap { localizedString(forKey: key, table: table, in: $0) }
            .first
        ?? localizedString(forKey: key, table: table, in: bundle)
        ?? localizedString(forKey: key, table: table, in: Bundle.main)
        ?? key
    }
}

// MARK: - Bundle Lookup
private extension CallKitBundle {
    static func candidateBundleURLs() -> [URL?] {
        return [
            Bundle.main.url(forResource: bundleName, withExtension: bundleExtension),
            Bundle(for: CallKitBundleToken.self).url(forResource: bundleName, withExtension: bundleExtension),
            frameworkBundleURL()?.appendingPathComponent(bundleName).appendingPathExtension(bundleExtension)
        ]
    }
    
    static func frameworkBundleURL() -> URL? {
        guard let frameworksURL = Bundle.main.url(forResource: "Frameworks", withExtension: nil) else {
            return nil
        }
        return frameworksURL.appendingPathComponent(frameworkName).appendingPathExtension(frameworkExtension)
    }
}

// MARK: - Localization
private extension CallKitBundle {
    static func localizedBundle(for language: String, in bundle: Bundle) -> Bundle? {
        guard let path = bundle.path(forResource: language, ofType: "lproj") else {
            return nil
        }
        return Bundle(path: path)
    }
    
    static func localizedString(forKey key: String, table: String, in bundle: Bundle) -> String? {
        let value = bundle.localizedString(forKey: key, value: nil, table: table)
        return value == key ? nil : value
    }
    
    static func preferredLanguages() -> [String] {
        var languages: [String] = []
        var seenLanguages = Set<String>()
        
        appendLanguage(TUIGlobalization.getPreferredLanguage(), to: &languages, seenLanguages: &seenLanguages)
        Locale.preferredLanguages.forEach {
            appendLanguage($0, to: &languages, seenLanguages: &seenLanguages)
        }
        appendLanguage(fallbackLanguage, to: &languages, seenLanguages: &seenLanguages)
        
        return languages
    }
    
    static func appendLanguage(_ language: String?, to languages: inout [String], seenLanguages: inout Set<String>) {
        guard let language = language?.replacingOccurrences(of: "_", with: "-"), !language.isEmpty else {
            return
        }
        
        appendUnique(language, to: &languages, seenLanguages: &seenLanguages)
        
        let components = language.components(separatedBy: "-")
        if components.count >= 2 {
            appendUnique(components[0] + "-" + components[1], to: &languages, seenLanguages: &seenLanguages)
        }
        if let languageCode = components.first {
            appendUnique(languageCode, to: &languages, seenLanguages: &seenLanguages)
        }
    }
    
    static func appendUnique(_ language: String, to languages: inout [String], seenLanguages: inout Set<String>) {
        guard seenLanguages.insert(language).inserted else {
            return
        }
        languages.append(language)
    }
}

enum CallKitLocalization {
    static func localized(_ key: String) -> String {
        return CallKitBundle.localizedString(forKey: key)
    }
}

func TUICallKitLocalize(key: String) -> String {
    return CallKitBundle.localizedString(forKey: key)
}
