//
//  AppAssemblyBundle.swift
//  AppAssembly
//

import UIKit
import TUICore

// MARK: - AppAssemblyBundle

enum AppAssemblyBundle {

    static let bundle: Bundle = {
        let bundleName = "AppAssemblyBundle"

        let frameworkBundle = Bundle(for: BundleToken.self)
        if let url = frameworkBundle.url(forResource: bundleName, withExtension: "bundle"),
           let bundle = Bundle(url: url) {
            return bundle
        }

        if let url = Bundle.main.url(forResource: bundleName, withExtension: "bundle"),
           let bundle = Bundle(url: url) {
            return bundle
        }

        return Bundle.main
    }()

    // MARK: - Image

    static func image(named name: String) -> UIImage? {
        return UIImage(named: name, in: bundle, compatibleWith: nil)
    }

    // MARK: - Localized String

    static func localizedString(forKey key: String, table: String) -> String {
        if let language = TUIGlobalization.getPreferredLanguage(),
           !language.isEmpty,
           let path = bundle.path(forResource: language, ofType: "lproj"),
           let languageBundle = Bundle(path: path) {
            return languageBundle.localizedString(forKey: key, value: "", table: table)
        }
        return bundle.localizedString(forKey: key, value: "", table: table)
    }

    // MARK: - JSON

    static func path(forResource name: String, ofType ext: String = "json") -> String? {
        return bundle.path(forResource: name, ofType: ext)
    }
}

// MARK: - Private

private final class BundleToken {}
