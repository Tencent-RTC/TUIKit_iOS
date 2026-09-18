//
//  TypographyToken.swift
//  Runtime Theme & Design Tokens
//
//  Created: 2025-11-13
//  Feature: 001-runtime-theme-tokens (T008)
//

import UIKit

public struct TypographyToken {
    
    // MARK: - Configuration Types
    
    public typealias FontResolver = (UIFont.Weight) -> String
    
    // MARK: - Properties
    
    private let fontResolver: FontResolver
    private let fontScaleFactor: CGFloat
    
    // MARK: - Initialization
    
    public init(fontScaleFactor: CGFloat = 1.0, resolver: @escaping FontResolver) {
        self.fontResolver = resolver
        self.fontScaleFactor = fontScaleFactor
    }

    // MARK: - Core Factory
    
    public func font(size: CGFloat, weight: UIFont.Weight = .regular) -> UIFont {
        let finalSize = floor(size * fontScaleFactor)
        
        let fontName = fontResolver(weight)
        
        if let customFont = UIFont(name: fontName, size: finalSize) {
            return customFont
        }
        
        return UIFont.systemFont(ofSize: finalSize, weight: weight)
    }
}

// MARK: - Presets

extension TypographyToken {
    // Pingfang-SC
    public static var pingFangSC: TypographyToken {
        return TypographyToken { weight in
            switch weight {
            case .regular:         return "PingFangSC-Regular"
            case .medium:          return "PingFangSC-Medium"
            case .semibold, .bold: return "PingFangSC-Semibold"
            default:               return "PingFangSC-Regular"
            }
        }
    }
    
    // System Font
    public static var system: TypographyToken {
        return TypographyToken { _ in
            return ""
        }
    }
}

// MARK: - Semantic / Primitive Tokens

extension TypographyToken {
    private func bold(_ size: CGFloat) -> UIFont { font(size: size, weight: .bold) }
    private func medium(_ size: CGFloat) -> UIFont { font(size: size, weight: .medium) }
    private func regular(_ size: CGFloat) -> UIFont { font(size: size, weight: .regular) }
    
    public var Bold40: UIFont { bold(40) }
    public var Bold36: UIFont { bold(36) }
    public var Bold34: UIFont { bold(34) }
    public var Bold32: UIFont { bold(32) }
    public var Bold28: UIFont { bold(28) }
    public var Bold24: UIFont { bold(24) }
    public var Bold20: UIFont { bold(20) }
    public var Bold18: UIFont { bold(18) }
    public var Bold16: UIFont { bold(16) }
    public var Bold14: UIFont { bold(14) }
    public var Bold12: UIFont { bold(12) }
    public var Bold10: UIFont { bold(10) }
    
    // MARK: - Medium Series
    public var Medium40: UIFont { medium(40) }
    public var Medium36: UIFont { medium(36) }
    public var Medium34: UIFont { medium(34) }
    public var Medium32: UIFont { medium(32) }
    public var Medium28: UIFont { medium(28) }
    public var Medium24: UIFont { medium(24) }
    public var Medium20: UIFont { medium(20) }
    public var Medium18: UIFont { medium(18) }
    public var Medium16: UIFont { medium(16) }
    public var Medium14: UIFont { medium(14) }
    public var Medium12: UIFont { medium(12) }
    public var Medium10: UIFont { medium(10) }
    
    // MARK: - Regular Series
    public var Regular40: UIFont { regular(40) }
    public var Regular36: UIFont { regular(36) }
    public var Regular34: UIFont { regular(34) }
    public var Regular32: UIFont { regular(32) }
    public var Regular28: UIFont { regular(28) }
    public var Regular24: UIFont { regular(24) }
    public var Regular20: UIFont { regular(20) }
    public var Regular18: UIFont { regular(18) }
    public var Regular16: UIFont { regular(16) }
    public var Regular14: UIFont { regular(14) }
    public var Regular12: UIFont { regular(12) }
    public var Regular10: UIFont { regular(10) }
}
