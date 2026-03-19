//
//  ThemeModels..swift
//  Runtime Theme & Design Tokens
//
//  Created: 2025-11-13
//  Feature: 001-runtime-theme-tokens
//

import Foundation
import Combine

public struct Theme {
    public let id: String
    public let mode: ThemeMode
    public let primaryColor: String
    public let tokens: DesignTokenSet
    
    public init(mode: ThemeMode, primaryColor: String, tokens: DesignTokenSet) {
        self.mode = mode
        self.primaryColor = primaryColor
        self.tokens = tokens
        self.id = "\(mode.rawValue)_\(primaryColor.hash)"
    }
    
    public var color: ColorTokens {
        return self.tokens.color
    }
    
    public var typography: TypographyToken {
        return self.tokens.typography
    }
    
    public var shadows: Shadows {
        return self.tokens.shadows
    }
    
    public var borderRadius: BorderRadiusToken {
        return self.tokens.borderRadius
    }
}

extension Theme: Identifiable, Equatable {
    public static func == (lhs: Theme, rhs: Theme) -> Bool {
        return lhs.id == rhs.id
    }
}

extension Theme {
    public static var lightTheme: Theme {
        return makeTheme(mode: .light, primaryColor: "1C66E5")
    }
    
    public static var darkTheme: Theme {
        return makeTheme(mode: .dark, primaryColor: "4086FF")
    }
    
    static func makeTheme(mode: ThemeMode, primaryColor: String) -> Theme {
        let tokenSet = DesignTokenSet(mode: mode, primaryColor: primaryColor)
        return Theme(mode: mode, primaryColor: primaryColor, tokens: tokenSet)
    }
}

