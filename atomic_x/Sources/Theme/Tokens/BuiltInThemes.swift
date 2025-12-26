//
//  BuiltInThemes.swift
//  Runtime Theme & Design Tokens
//
//  Created: 2025-11-13
//  Feature: 001-runtime-theme-tokens (T014)
//

import UIKit

// MARK: - Built-in Token Sets

extension DesignTokenSet {
    
    public static var lightTokenSet: DesignTokenSet {
        return DesignTokenSet(
            id: "light-tokens",
            displayName: "Light Tokens",
            color: ColorTokens.light(),
            space: .standard,
            borderRadius: .standard,
            typography: TypographyToken(fontFamilyName: "PingFangSC"),
            shadows: .standard,
            isEnabled: true
        )
    }
    
    public static var darkTokenSet: DesignTokenSet {
        return DesignTokenSet(
            id: "dark-tokens",
            displayName: "Dark Tokens",
            color: ColorTokens.dark(),
            space: .standard,
            borderRadius: .standard,
            typography: TypographyToken(fontFamilyName: "PingFangSC"),
            shadows: Shadows(
                smallShadow: Shadow(
                    color: UIColor.black.withAlphaComponent(0.3),
                    radius: 4,
                    x: 0,
                    y: 2,
                    opacity: 1.0
                ),
                mediumShadow: Shadow(
                    color: UIColor.black.withAlphaComponent(0.4),
                    radius: 8,
                    x: 0,
                    y: 4,
                    opacity: 1.0
                )
            ),
            isEnabled: true
        )
    }
}

// MARK: - Built-in Themes

extension Theme {
    
    public static var lightTheme: Theme {
        return Theme(
            id: "light",
            displayName: "Light",
            tokens: .lightTokenSet
        )
    }
    
    public static var darkTheme: Theme {
        return Theme(
            id: "dark",
            displayName: "Dark",
            tokens: .darkTokenSet
        )
    }
}
