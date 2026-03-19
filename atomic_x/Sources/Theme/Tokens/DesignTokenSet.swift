//
//  BuiltInThemes.swift
//  Runtime Theme & Design Tokens
//
//  Created: 2025-11-13
//  Feature: 001-runtime-theme-tokens (T014)
//

import UIKit

// MARK: - Token Sets

public struct DesignTokenSet {
    
    // MARK: - Token Categories
    public let color: ColorTokens
    public let space: SpaceTokens
    public let borderRadius: BorderRadiusToken
    public let typography: TypographyToken
    public let shadows: Shadows
    
    // MARK: - Initialization
    public init(mode: ThemeMode, primaryColor: String) {
        if mode == .light {
            self.color = ColorTokens.light(from: primaryColor)
        } else {
            self.color = ColorTokens.dark(from: primaryColor)
        }
        self.space = .standard
        self.borderRadius = .standard
        self.typography = TypographyToken.pingFangSC
        self.shadows = .standard
    }
}
