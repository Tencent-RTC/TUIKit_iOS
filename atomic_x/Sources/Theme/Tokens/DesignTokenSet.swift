//
//  DesignTokenSet.swift
//  Runtime Theme & Design Tokens
//
//  Created: 2025-11-13
//  Feature: 001-runtime-theme-tokens (T004)
//

import Foundation

public struct DesignTokenSet {
    
    // MARK: - Identity
    public let id: String
    public let displayName: String
    
    // MARK: - Token Categories
    public let color: ColorTokens
    public let space: SpaceTokens
    public let borderRadius: BorderRadiusToken
    public let typography: TypographyToken
    public let shadows: Shadows
    
    // MARK: - State
    public var isEnabled: Bool
    
    // MARK: - Initialization
    public init(
        id: String,
        displayName: String,
        color: ColorTokens,
        space: SpaceTokens,
        borderRadius: BorderRadiusToken,
        typography: TypographyToken,
        shadows: Shadows,
        isEnabled: Bool = true
    ) {
        self.id = id
        self.displayName = displayName
        self.color = color
        self.space = space
        self.borderRadius = borderRadius
        self.typography = typography
        self.shadows = shadows
        self.isEnabled = isEnabled
    }
    
    // MARK: - Validation
    
    public func validate() -> Bool {
        return true
    }
}

// MARK: - Identifiable

extension DesignTokenSet: Identifiable {}

// MARK: - Equatable

extension DesignTokenSet: Equatable {
    public static func == (lhs: DesignTokenSet, rhs: DesignTokenSet) -> Bool {
        return lhs.id == rhs.id
    }
}
