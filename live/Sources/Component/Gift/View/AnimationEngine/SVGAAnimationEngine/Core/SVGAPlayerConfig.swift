//
//  SVGAPlayerConfig.swift
//  TUILiveKit
//
//  Created on 2026/2/5.
//  High-Performance SVGA Player Core
//

import Foundation
import CoreGraphics

// MARK: - SVGAPlayerConfig

/// Configuration for SVGA player initialization and behavior
public struct SVGAPlayerConfig {
    
    /// Content mode for rendering
    public var contentMode: SVGAContentMode = .scaleAspectFit
    
    /// Default loop count (0 = infinite)
    public var defaultLoops: Int = 1
    
    /// Whether to auto-play after loading
    public var autoPlay: Bool = true
    
    /// Whether to clear view after playback finished
    public var clearAfterFinish: Bool = true
    
    public init() {}
    
    /// Default configuration
    public static var `default`: SVGAPlayerConfig {
        SVGAPlayerConfig()
    }
}

// MARK: - SVGAContentMode

/// Content display mode for SVGA animation
public enum SVGAContentMode: Int {
    /// Scale to fill entire view, may distort
    case scaleToFill = 0
    
    /// Scale to fit within view, preserving aspect ratio
    case scaleAspectFit = 1
    
    /// Scale to fill view, preserving aspect ratio, may crop
    case scaleAspectFill = 2
    
    /// Center at original size
    case center = 3
    
    /// Top-left aligned at original size
    case topLeft = 4
}

// MARK: - SVGAContentMode + Transform

extension SVGAContentMode {
    
    /// Calculate transform matrix for given content and view sizes
    public func transformMatrix(
        contentSize: CGSize,
        viewSize: CGSize
    ) -> CGAffineTransform {
        guard contentSize.width > 0 && contentSize.height > 0 else {
            return .identity
        }
        guard viewSize.width > 0 && viewSize.height > 0 else {
            return .identity
        }
        
        let scaleX = viewSize.width / contentSize.width
        let scaleY = viewSize.height / contentSize.height
        
        switch self {
        case .scaleToFill:
            return CGAffineTransform(scaleX: scaleX, y: scaleY)
            
        case .scaleAspectFit:
            let scale = min(scaleX, scaleY)
            let tx = (viewSize.width - contentSize.width * scale) / 2
            let ty = (viewSize.height - contentSize.height * scale) / 2
            return CGAffineTransform(scaleX: scale, y: scale)
                .translatedBy(x: tx / scale, y: ty / scale)
            
        case .scaleAspectFill:
            let scale = max(scaleX, scaleY)
            let tx = (viewSize.width - contentSize.width * scale) / 2
            let ty = (viewSize.height - contentSize.height * scale) / 2
            return CGAffineTransform(scaleX: scale, y: scale)
                .translatedBy(x: tx / scale, y: ty / scale)
            
        case .center:
            let tx = (viewSize.width - contentSize.width) / 2
            let ty = (viewSize.height - contentSize.height) / 2
            return CGAffineTransform(translationX: tx, y: ty)
            
        case .topLeft:
            return .identity
        }
    }
}
