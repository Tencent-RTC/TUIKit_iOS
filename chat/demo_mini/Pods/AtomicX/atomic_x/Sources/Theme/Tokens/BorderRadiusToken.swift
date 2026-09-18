//
//  BorderRadiusToken.swift
//  Runtime Theme & Design Tokens
//
//  Created: 2025-11-13
//  Feature: 001-runtime-theme-tokens (T007)
//

import CoreGraphics

public struct BorderRadiusToken {
    public let none: CGFloat
    public let radius4: CGFloat
    public let radius6: CGFloat
    public let radius8: CGFloat
    public let radius12: CGFloat
    public let radius16: CGFloat
    public let radius20: CGFloat
    public let radiusCircle: CGFloat 
    
    public init(
        none: CGFloat,
        radius4: CGFloat,
        radius6: CGFloat,
        radius8: CGFloat,
        radius12: CGFloat,
        radius16: CGFloat,
        radius20: CGFloat,
        radiusCircle: CGFloat
    ) {
        self.none = none
        self.radius4 = radius4
        self.radius6 = radius6
        self.radius8 = radius8
        self.radius12 = radius12
        self.radius16 = radius16
        self.radius20 = radius20
        self.radiusCircle = radiusCircle
    }
    
    public static var standard: BorderRadiusToken {
        return BorderRadiusToken(
            none: 0,
            radius4: 4,
            radius6: 6,
            radius8: 8,
            radius12: 12,
            radius16: 16,
            radius20: 20,
            radiusCircle: 9999  // Large value to create circle
        )
    }
}
