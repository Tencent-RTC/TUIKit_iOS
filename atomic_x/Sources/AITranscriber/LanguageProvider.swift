//
//  LanguageProvider.swift
//  AtomicX
//
//  Created on 2026/1/19.
//

import Foundation
import AtomicXCore

enum LanguageProvider {
    
    static func getSourceLanguageDisplayName(_ language: SourceLanguage) -> String {
        switch language {
        case .chineseEnglish:
            return CallKitBundle.localizedString(forKey: "ai_source_lang_zh_en")
        case .chinese:
            return CallKitBundle.localizedString(forKey: "ai_source_lang_zh")
        case .english:
            return CallKitBundle.localizedString(forKey: "ai_source_lang_en")
        }
    }
    
    static func getTranslationLanguageDisplayName(_ language: TranslationLanguage?) -> String {
        guard let language = language else {
            return CallKitBundle.localizedString(forKey: "ai_trans_lang_none")
        }
        switch language {
        case .chinese:
            return CallKitBundle.localizedString(forKey: "ai_trans_lang_zh")
        case .english:
            return CallKitBundle.localizedString(forKey: "ai_trans_lang_en")
        case .vietnamese:
            return CallKitBundle.localizedString(forKey: "ai_trans_lang_vi")
        case .japanese:
            return CallKitBundle.localizedString(forKey: "ai_trans_lang_ja")
        case .korean:
            return CallKitBundle.localizedString(forKey: "ai_trans_lang_ko")
        case .indonesian:
            return CallKitBundle.localizedString(forKey: "ai_trans_lang_id")
        case .thai:
            return CallKitBundle.localizedString(forKey: "ai_trans_lang_th")
        case .portuguese:
            return CallKitBundle.localizedString(forKey: "ai_trans_lang_pt")
        case .arabic:
            return CallKitBundle.localizedString(forKey: "ai_trans_lang_ar")
        case .spanish:
            return CallKitBundle.localizedString(forKey: "ai_trans_lang_es")
        case .french:
            return CallKitBundle.localizedString(forKey: "ai_trans_lang_fr")
        case .malay:
            return CallKitBundle.localizedString(forKey: "ai_trans_lang_ms")
        case .german:
            return CallKitBundle.localizedString(forKey: "ai_trans_lang_de")
        case .italian:
            return CallKitBundle.localizedString(forKey: "ai_trans_lang_it")
        case .russian:
            return CallKitBundle.localizedString(forKey: "ai_trans_lang_ru")
        }
    }
    
    static func findSourceLanguage(_ value: String) -> SourceLanguage? {
        return SourceLanguage(rawValue: value)
    }
    
    static func findTranslationLanguage(_ value: String) -> TranslationLanguage? {
        return TranslationLanguage(rawValue: value)
    }
    
    static func getSourceLanguageList() -> [(value: String, displayName: String)] {
        return [
            (SourceLanguage.chineseEnglish.rawValue, getSourceLanguageDisplayName(.chineseEnglish)),
            (SourceLanguage.chinese.rawValue, getSourceLanguageDisplayName(.chinese)),
            (SourceLanguage.english.rawValue, getSourceLanguageDisplayName(.english))
        ]
    }
    
    static func getTranslationLanguageList() -> [(value: String, displayName: String)] {
        var list: [(value: String, displayName: String)] = []
        list.append(("", getTranslationLanguageDisplayName(nil)))
        for language in TranslationLanguage.allCases {
            list.append((language.rawValue, getTranslationLanguageDisplayName(language)))
        }
        return list
    }
}
