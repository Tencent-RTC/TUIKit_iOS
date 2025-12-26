//
//  TypographyToken.swift
//  Runtime Theme & Design Tokens
//
//  Created: 2025-11-13
//  Feature: 001-runtime-theme-tokens (T008)
//

import UIKit

public struct TypographyToken {
    public var fontFamilyName: String?
    
    public init(fontFamilyName: String? = nil) {
        self.fontFamilyName = fontFamilyName
    }
    // MARK: - Factory
    
    public func font(size: CGFloat, weight: UIFont.Weight = .regular) -> UIFont {
        if let family = fontFamilyName, !family.isEmpty {
            
            let fontName = getFontName(family: family, weight: weight)
            
            if let customFont = UIFont(name: fontName, size: size) {
                return customFont
            }
            print("Warning: Custom font '\(fontName)' not found. Falling back to system font.")
        }
        
        return UIFont.systemFont(ofSize: size, weight: weight)
    }
    
    private func getFontName(family: String, weight: UIFont.Weight) -> String {
        switch weight {
        case .regular: return "\(family)-Regular"
        case .medium:  return "\(family)-Medium"
        case .bold:    return "\(family)-Semibold"
        default:       return "\(family)-Regular"
        }
    }
}

extension TypographyToken {
    // MARK: - Bold Series
    public var Bold40: UIFont { font(size: 40, weight: .bold) }
    public var Bold36: UIFont { font(size: 36, weight: .bold) }
    public var Bold34: UIFont { font(size: 34, weight: .bold) }
    public var Bold32: UIFont { font(size: 32, weight: .bold) }
    public var Bold28: UIFont { font(size: 28, weight: .bold) }
    public var Bold24: UIFont { font(size: 24, weight: .bold) }
    public var Bold20: UIFont { font(size: 20, weight: .bold) }
    public var Bold18: UIFont { font(size: 18, weight: .bold) }
    public var Bold16: UIFont { font(size: 16, weight: .bold) }
    public var Bold14: UIFont { font(size: 14, weight: .bold) }
    public var Bold12: UIFont { font(size: 12, weight: .bold) }
    public var Bold10: UIFont { font(size: 10, weight: .bold) }

    // MARK: - Medium Series
    public var Medium40: UIFont { font(size: 40, weight: .medium) }
    public var Medium36: UIFont { font(size: 36, weight: .medium) }
    public var Medium34: UIFont { font(size: 34, weight: .medium) }
    public var Medium32: UIFont { font(size: 32, weight: .medium) }
    public var Medium28: UIFont { font(size: 28, weight: .medium) }
    public var Medium24: UIFont { font(size: 24, weight: .medium) }
    public var Medium20: UIFont { font(size: 20, weight: .medium) }
    public var Medium18: UIFont { font(size: 18, weight: .medium) }
    public var Medium16: UIFont { font(size: 16, weight: .medium) }
    public var Medium14: UIFont { font(size: 14, weight: .medium) }
    public var Medium12: UIFont { font(size: 12, weight: .medium) }
    public var Medium10: UIFont { font(size: 10, weight: .medium) }

    // MARK: - Regular Series
    public var Regular40: UIFont { font(size: 40, weight: .regular) }
    public var Regular36: UIFont { font(size: 36, weight: .regular) }
    public var Regular34: UIFont { font(size: 34, weight: .regular) }
    public var Regular32: UIFont { font(size: 32, weight: .regular) }
    public var Regular28: UIFont { font(size: 28, weight: .regular) }
    public var Regular24: UIFont { font(size: 24, weight: .regular) }
    public var Regular20: UIFont { font(size: 20, weight: .regular) }
    public var Regular18: UIFont { font(size: 18, weight: .regular) }
    public var Regular16: UIFont { font(size: 16, weight: .regular) }
    public var Regular14: UIFont { font(size: 14, weight: .regular) }
    public var Regular12: UIFont { font(size: 12, weight: .regular) }
    public var Regular10: UIFont { font(size: 10, weight: .regular) }
}
