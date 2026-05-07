//
//  LanguageEntry.swift
//  language
//
//    LanguageEntry.shared.pushLanguageSelect(from: navigationController) { changed in
//    }
//

import UIKit

private let kAppPreferredLanguageKey = "app_preferred_language"
private let kDefaultLanguageID = "en"

public final class LanguageEntry {
    public static let shared = LanguageEntry()
    private init() {}
    
    public func pushLanguageSelect(
        from navigationController: UINavigationController,
        completion: ((Bool) -> Void)? = nil
    ) {
        let vc = LanguageSelectViewController()
        vc.onLanguageChanged = { [weak vc] languageID in
            completion?(true)
        }
        navigationController.pushViewController(vc, animated: true)
    }
    
    public func buildLanguageSelectViewController(
        completion: ((String) -> Void)? = nil
    ) -> UIViewController {
        let vc = LanguageSelectViewController()
        vc.onLanguageChanged = { languageID in
            completion?(languageID)
        }
        return vc
    }
    
    public var currentLanguageID: String {
        get {
            return UserDefaults.standard.string(forKey: kAppPreferredLanguageKey) ?? kDefaultLanguageID
        }
        set {
            UserDefaults.standard.set(newValue, forKey: kAppPreferredLanguageKey)
        }
    }
    
    public var isChinese: Bool {
        return currentLanguageID.hasPrefix("zh")
    }
}
