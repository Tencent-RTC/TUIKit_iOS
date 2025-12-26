//
//  SpaceTokens.swift
//  Runtime Theme & Design Tokens
//
//  Created: 2025-11-13
//  Feature: 001-runtime-theme-tokens (T006)
//

import CoreGraphics

/// SpaceTokens - Spacing system
public struct SpaceTokens {
    public let space4: CGFloat
    public let space8: CGFloat
    public let space16: CGFloat
    public let space20: CGFloat
    public let space24: CGFloat
    public let space32: CGFloat
    public let space40: CGFloat
    
    public init(
        space4: CGFloat,
        space8: CGFloat,
        space16: CGFloat,
        space20: CGFloat,
        space24: CGFloat,
        space32: CGFloat,
        space40: CGFloat
    ) {
        self.space4 = space4
        self.space8 = space8
        self.space16 = space16
        self.space20 = space20
        self.space24 = space24
        self.space32 = space32
        self.space40 = space40
    }
    
    public static var standard: SpaceTokens {
        return SpaceTokens(
            space4: 4,
            space8: 8,
            space16: 16,
            space20: 20,
            space24: 24,
            space32: 32,
            space40: 40
        )
    }
}
