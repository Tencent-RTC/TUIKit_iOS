//
//  SVGASprite.swift
//  TUILiveKit
//
//  Created on 2026/2/5.
//  High-Performance SVGA Player Core
//
//  Merged from SpriteEntity.swift + SpriteFrame.swift
//

import Foundation
import simd
import CoreGraphics

// MARK: - SpriteFrame

/// Represents a sprite's state at a specific frame
/// Optimized for cache-line alignment and zero-copy operations
public struct SpriteFrame {
    
    // MARK: - Transform Properties
    
    /// 3x3 transformation matrix (translation, rotation, scale)
    /// Stored as simd_float3x3 for GPU compatibility
    public var transform: simd_float3x3
    
    /// Opacity value [0.0, 1.0]
    public var alpha: Float
    
    /// Anchor point X offset (normalized)
    public var nx: Float
    
    /// Anchor point Y offset (normalized)
    public var ny: Float
    
    // MARK: - Optional Properties
    
    /// Clip path for masking (optional)
    public var clipPath: BezierPath?
    
    /// Vector shapes for this frame (optional)
    public var shapes: [ShapeEntity]?
    
    // MARK: - Initialization
    
    public init(
        transform: simd_float3x3 = matrix_identity_float3x3,
        alpha: Float = 1.0,
        nx: Float = 0.0,
        ny: Float = 0.0,
        clipPath: BezierPath? = nil,
        shapes: [ShapeEntity]? = nil
    ) {
        self.transform = transform
        self.alpha = alpha
        self.nx = nx
        self.ny = ny
        self.clipPath = clipPath
        self.shapes = shapes
    }
    
    // MARK: - Factory Methods
    
    /// Create identity frame (no transformation)
    public static var identity: SpriteFrame {
        SpriteFrame()
    }
    
    /// Create frame from CGAffineTransform
    public static func from(affineTransform: CGAffineTransform, alpha: Float = 1.0) -> SpriteFrame {
        let matrix = simd_float3x3(
            SIMD3<Float>(Float(affineTransform.a), Float(affineTransform.b), 0),
            SIMD3<Float>(Float(affineTransform.c), Float(affineTransform.d), 0),
            SIMD3<Float>(Float(affineTransform.tx), Float(affineTransform.ty), 1)
        )
        return SpriteFrame(transform: matrix, alpha: alpha)
    }
    
    // MARK: - Validation
    
    /// Check if frame data is valid
    public var isValid: Bool {
        // Alpha must be in valid range
        guard alpha >= 0.0 && alpha <= 1.0 else { return false }
        
        // Transform must not contain NaN or Inf
        for col in 0..<3 {
            for row in 0..<3 {
                let value = transform[col][row]
                if value.isNaN || value.isInfinite {
                    return false
                }
            }
        }
        
        return true
    }
    
    // MARK: - Transform Helpers
    
    /// Extract translation from transform matrix
    public var translation: SIMD2<Float> {
        SIMD2<Float>(transform[2][0], transform[2][1])
    }
    
    /// Extract scale from transform matrix (approximate)
    public var scale: SIMD2<Float> {
        let scaleX = sqrt(transform[0][0] * transform[0][0] + transform[0][1] * transform[0][1])
        let scaleY = sqrt(transform[1][0] * transform[1][0] + transform[1][1] * transform[1][1])
        return SIMD2<Float>(scaleX, scaleY)
    }
    
    /// Extract rotation from transform matrix (radians)
    public var rotation: Float {
        atan2(transform[0][1], transform[0][0])
    }
}

// MARK: - SpriteFrame + Interpolation

extension SpriteFrame {
    
    /// Linear interpolation between two frames
    public func lerp(to other: SpriteFrame, t: Float) -> SpriteFrame {
        let t = max(0, min(1, t))
        let oneMinusT = 1.0 - t
        
        var resultTransform = simd_float3x3()
        for col in 0..<3 {
            for row in 0..<3 {
                resultTransform[col][row] = transform[col][row] * oneMinusT + other.transform[col][row] * t
            }
        }
        
        return SpriteFrame(
            transform: resultTransform,
            alpha: alpha * oneMinusT + other.alpha * t,
            nx: nx * oneMinusT + other.nx * t,
            ny: ny * oneMinusT + other.ny * t,
            clipPath: t < 0.5 ? clipPath : other.clipPath,
            shapes: t < 0.5 ? shapes : other.shapes
        )
    }
}

// MARK: - BezierPath

/// Simplified bezier path for clip masks
public struct BezierPath {
    
    /// Path element types
    public enum Element {
        case moveTo(CGPoint)
        case lineTo(CGPoint)
        case curveTo(CGPoint, control1: CGPoint, control2: CGPoint)
        case quadCurveTo(CGPoint, control: CGPoint)
        case close
    }
    
    /// Path elements
    public var elements: [Element]
    
    /// Closed path flag
    public var isClosed: Bool {
        guard let last = elements.last else { return false }
        if case .close = last { return true }
        return false
    }
    
    public init(elements: [Element] = []) {
        self.elements = elements
    }
    
    // MARK: - Factory Methods
    
    /// Create rectangular path
    public static func rect(_ rect: CGRect) -> BezierPath {
        BezierPath(elements: [
            .moveTo(CGPoint(x: rect.minX, y: rect.minY)),
            .lineTo(CGPoint(x: rect.maxX, y: rect.minY)),
            .lineTo(CGPoint(x: rect.maxX, y: rect.maxY)),
            .lineTo(CGPoint(x: rect.minX, y: rect.maxY)),
            .close
        ])
    }
    
    /// Create ellipse path
    public static func ellipse(in rect: CGRect) -> BezierPath {
        let cx = rect.midX
        let cy = rect.midY
        let rx = rect.width / 2
        let ry = rect.height / 2
        
        let kappa: CGFloat = 0.5522848
        let ox = rx * kappa
        let oy = ry * kappa
        
        return BezierPath(elements: [
            .moveTo(CGPoint(x: cx - rx, y: cy)),
            .curveTo(CGPoint(x: cx, y: cy - ry),
                    control1: CGPoint(x: cx - rx, y: cy - oy),
                    control2: CGPoint(x: cx - ox, y: cy - ry)),
            .curveTo(CGPoint(x: cx + rx, y: cy),
                    control1: CGPoint(x: cx + ox, y: cy - ry),
                    control2: CGPoint(x: cx + rx, y: cy - oy)),
            .curveTo(CGPoint(x: cx, y: cy + ry),
                    control1: CGPoint(x: cx + rx, y: cy + oy),
                    control2: CGPoint(x: cx + ox, y: cy + ry)),
            .curveTo(CGPoint(x: cx - rx, y: cy),
                    control1: CGPoint(x: cx - ox, y: cy + ry),
                    control2: CGPoint(x: cx - rx, y: cy + oy)),
            .close
        ])
    }
}

// MARK: - ShapeEntity

/// Vector shape entity for SVGA animations
public struct ShapeEntity {
    
    /// Shape type
    public enum ShapeType {
        case shape
        case rect
        case ellipse
        case keep
    }
    
    public var type: ShapeType
    public var path: BezierPath?
    public var fillColor: UInt32?
    public var strokeColor: UInt32?
    public var strokeWidth: Float?
    public var lineCap: LineCap?
    public var lineJoin: LineJoin?
    public var transform: simd_float3x3?
    
    public init(
        type: ShapeType = .shape,
        path: BezierPath? = nil,
        fillColor: UInt32? = nil,
        strokeColor: UInt32? = nil,
        strokeWidth: Float? = nil,
        lineCap: LineCap? = nil,
        lineJoin: LineJoin? = nil,
        transform: simd_float3x3? = nil
    ) {
        self.type = type
        self.path = path
        self.fillColor = fillColor
        self.strokeColor = strokeColor
        self.strokeWidth = strokeWidth
        self.lineCap = lineCap
        self.lineJoin = lineJoin
        self.transform = transform
    }
    
    public enum LineCap: Int {
        case butt = 0
        case round = 1
        case square = 2
    }
    
    public enum LineJoin: Int {
        case miter = 0
        case round = 1
        case bevel = 2
    }
}

// MARK: - SpriteEntity

/// Represents a single sprite/layer in an SVGA animation
/// Contains all frame data for the sprite across the animation timeline
public struct SpriteEntity {
    
    // MARK: - Properties
    
    /// Unique identifier for this sprite
    public let identifier: String
    
    /// Key to the associated texture in TextureAtlas
    public var imageKey: String?
    
    /// Key to the matte (mask) sprite
    public var matteKey: String?
    
    /// Frame data array - one entry per animation frame
    public var frames: [SpriteFrame]
    
    // MARK: - Initialization
    
    public init(
        identifier: String,
        imageKey: String? = nil,
        matteKey: String? = nil,
        frames: [SpriteFrame] = []
    ) {
        self.identifier = identifier
        self.imageKey = imageKey
        self.matteKey = matteKey
        self.frames = frames
    }
    
    // MARK: - Computed Properties
    
    public var frameCount: Int { frames.count }
    public var hasBitmapTexture: Bool { imageKey != nil }
    public var hasMatte: Bool { matteKey != nil }
    
    public var hasVectorShapes: Bool {
        frames.contains { $0.shapes != nil && !($0.shapes?.isEmpty ?? true) }
    }
    
    public var isValid: Bool {
        !identifier.isEmpty && frames.allSatisfy { $0.isValid }
    }
    
    // MARK: - Frame Access
    
    public func frame(at index: Int) -> SpriteFrame? {
        guard index >= 0 && index < frames.count else { return nil }
        return frames[index]
    }
    
    public func frameClamped(at index: Int) -> SpriteFrame {
        let clampedIndex = max(0, min(frames.count - 1, index))
        return frames[clampedIndex]
    }
    
    public func frameInterpolated(at fractionalIndex: Float) -> SpriteFrame {
        guard frames.count > 1 else {
            return frames.first ?? .identity
        }
        
        let floorIndex = Int(fractionalIndex)
        let ceilIndex = floorIndex + 1
        let fraction = fractionalIndex - Float(floorIndex)
        
        let frame0 = frameClamped(at: floorIndex)
        let frame1 = frameClamped(at: ceilIndex)
        
        return frame0.lerp(to: frame1, t: fraction)
    }
    
    // MARK: - Visibility Check
    
    public func isVisible(at index: Int) -> Bool {
        guard let frame = frame(at: index) else { return false }
        guard frame.alpha > 0.001 else { return false }
        let scale = frame.scale
        guard scale.x > 0.001 && scale.y > 0.001 else { return false }
        return true
    }
}

// MARK: - SpriteEntity Builder

extension SpriteEntity {
    
    public final class Builder {
        private var identifier: String = ""
        private var imageKey: String?
        private var matteKey: String?
        private var frames: [SpriteFrame] = []
        
        public init() {}
        
        @discardableResult
        public func setIdentifier(_ id: String) -> Builder {
            identifier = id
            return self
        }
        
        @discardableResult
        public func setImageKey(_ key: String?) -> Builder {
            imageKey = key
            return self
        }
        
        @discardableResult
        public func setMatteKey(_ key: String?) -> Builder {
            matteKey = key
            return self
        }
        
        @discardableResult
        public func addFrame(_ frame: SpriteFrame) -> Builder {
            frames.append(frame)
            return self
        }
        
        @discardableResult
        public func setFrames(_ frames: [SpriteFrame]) -> Builder {
            self.frames = frames
            return self
        }
        
        @discardableResult
        public func reserveFrames(_ count: Int) -> Builder {
            frames.reserveCapacity(count)
            return self
        }
        
        public func build() -> SpriteEntity {
            SpriteEntity(
                identifier: identifier,
                imageKey: imageKey,
                matteKey: matteKey,
                frames: frames
            )
        }
    }
    
    public static func builder(identifier: String) -> Builder {
        Builder().setIdentifier(identifier)
    }
}

// MARK: - SpriteEntity Array Extensions

extension Array where Element == SpriteEntity {
    
    public func sprite(withIdentifier id: String) -> SpriteEntity? {
        first { $0.identifier == id }
    }
    
    public func spriteIndex(withIdentifier id: String) -> Int? {
        firstIndex { $0.identifier == id }
    }
    
    public func visibleSprites(at frameIndex: Int) -> [SpriteEntity] {
        filter { $0.isVisible(at: frameIndex) }
    }
    
    public var sortedByZOrder: [SpriteEntity] {
        self
    }
    
    public var estimatedMemorySize: Int {
        reduce(0) { total, sprite in
            total + MemoryLayout<SpriteFrame>.stride * sprite.frameCount
        }
    }
}
