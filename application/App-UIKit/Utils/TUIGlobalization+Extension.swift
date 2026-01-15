//
//  TUIGlobalization+Extension.swift
//  App-UIKit
//
//  Created by gg on 2025/1/9.
//

import Foundation
import TUICore

extension TUIGlobalization {
    private static let appLanguageKey = "AppleLanguages"
    private static let rtlLanguages = ["ar", "he", "fa", "ur"]
    
    @objc static func enableLanguageHook() {
        swizzleGetPreferredLanguage()
        swizzleSetPreferredLanguage()
        
        TUIGlobalization.setRTLOption(isCurrentLanguageRTL())
    }
    
    private static func isCurrentLanguageRTL() -> Bool {
        guard let language = hooked_getPreferredLanguage() else { return false }
        let baseCode = language.components(separatedBy: "-").first ?? language
        return rtlLanguages.contains(baseCode)
    }
    
    private static func swizzleGetPreferredLanguage() {
        let originalSelector = #selector(TUIGlobalization.getPreferredLanguage)
        let swizzledSelector = #selector(TUIGlobalization.hooked_getPreferredLanguage)
        
        guard let originalMethod = class_getClassMethod(TUIGlobalization.self, originalSelector),
              let swizzledMethod = class_getClassMethod(TUIGlobalization.self, swizzledSelector)
        else {
            return
        }
        method_exchangeImplementations(originalMethod, swizzledMethod)
    }
    
    @objc private static func hooked_getPreferredLanguage() -> String? {
        if let languages = UserDefaults.standard.array(forKey: appLanguageKey) as? [String],
           let first = languages.first
        {
            return first
        }
        return Locale.preferredLanguages.first
    }
    
    private static func swizzleSetPreferredLanguage() {
        let originalSelector = #selector(TUIGlobalization.setPreferredLanguage(_:))
        let swizzledSelector = #selector(TUIGlobalization.hooked_setPreferredLanguage(_:))
        
        guard let originalMethod = class_getClassMethod(TUIGlobalization.self, originalSelector),
              let swizzledMethod = class_getClassMethod(TUIGlobalization.self, swizzledSelector)
        else {
            return
        }
        method_exchangeImplementations(originalMethod, swizzledMethod)
    }
    
    @objc private static func hooked_setPreferredLanguage(_ language: String?) {
        guard let language = language else { return }
        UserDefaults.standard.set([language], forKey: appLanguageKey)
        UserDefaults.standard.synchronize()
        
        let baseCode = language.components(separatedBy: "-").first ?? language
        let isRTL = rtlLanguages.contains(baseCode)
        TUIGlobalization.setRTLOption(isRTL)
    }
}
