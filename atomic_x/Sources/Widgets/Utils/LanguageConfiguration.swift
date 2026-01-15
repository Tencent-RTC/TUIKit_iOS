//
//  LanguageConfiguration.swift
//  TUILiveKit
//
//  Created by gg on 2025/1/9.
//

import UIKit

private let rtlLanguages = ["ar", "he", "fa", "ur"]

// MARK: - Unicode Bidirectional Isolate Characters (Unicode 6.3+)
// Used for bidirectional text (BiDi) isolation to prevent different text directions from affecting each other

/// First Strong Isolate - Automatically determines text direction based on the first strong directional character
public let FSI = "\u{2068}"

/// Pop Directional Isolate - Terminates the most recent directional isolation region
public let PDI = "\u{2069}"

/// Left-to-Right Mark - Zero-width LTR marker that affects the direction of adjacent neutral characters
public let LRM = "\u{200E}"

/// Right-to-Left Mark - Zero-width RTL marker that affects the direction of adjacent neutral characters
public let RLM = "\u{200F}"

public func getPreferredLanguage() -> String {
    return Locale.preferredLanguages.first ?? "en"
}

public func isRTLLanguage() -> Bool {
    let language = getPreferredLanguage()
    let baseCode = getBaseLanguageCode(language)
    return rtlLanguages.contains(baseCode)
}

private func getBaseLanguageCode(_ language: String) -> String {
    let components = language.components(separatedBy: "-")
    return components.first ?? language
}
