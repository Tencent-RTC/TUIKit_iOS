//
//  Shadows.swift
//  Runtime Theme & Design Tokens
//
//  Created: 2025-11-13
//  Feature: 001-runtime-theme-tokens (T009)
//

import UIKit

public struct Shadow {
    public let color: UIColor
    public let radius: CGFloat
    public let x: CGFloat
    public let y: CGFloat
    public let opacity: Float
    
    public init(color: UIColor, radius: CGFloat, x: CGFloat, y: CGFloat, opacity: Float = 1.0) {
        self.color = color
        self.radius = radius
        self.x = x
        self.y = y
        self.opacity = opacity
    }
    
    public func apply(to layer: CALayer) {
        layer.shadowColor = color.cgColor
        layer.shadowRadius = radius
        layer.shadowOffset = CGSize(width: x, height: y)
        layer.shadowOpacity = opacity
    }
}

public struct Shadows {
    public let smallShadow: Shadow
    public let mediumShadow: Shadow
    
    public init(smallShadow: Shadow, mediumShadow: Shadow) {
        self.smallShadow = smallShadow
        self.mediumShadow = mediumShadow
    }
    
    public static var standard: Shadows {
        return Shadows(
            smallShadow: Shadow(
                color: UIColor.black.withAlphaComponent(0.12),
                radius: 4,
                x: 0,
                y: 2,
                opacity: 1.0
            ),
            mediumShadow: Shadow(
                color: UIColor.black.withAlphaComponent(0.16),
                radius: 8,
                x: 0,
                y: 4,
                opacity: 1.0
            )
        )
    }
}
