//
//  SVGAAnimation.swift
//  TUILiveKit
//
//  Created on 2026/2/5.
//  High-Performance SVGA Player Core
//

import Foundation
import CoreGraphics

// MARK: - SVGAAnimation

/// Represents a complete SVGA animation resource
/// Immutable after parsing, safe for concurrent read access
public final class SVGAAnimation {
    
    // MARK: - Properties
    
    /// Unique identifier (typically file hash)
    public let identifier: String
    
    /// SVGA format version
    public let version: UInt32
    
    /// Canvas/video size in points
    public let videoSize: CGSize
    
    /// Frame rate (frames per second)
    public let frameRate: Int
    
    /// Total number of frames
    public let frameCount: Int
    
    /// All sprite entities in z-order
    /// Later sprites are rendered on top
    public let sprites: [SpriteEntity]
    
    /// Reference to texture atlas (set after texture preparation)
    public internal(set) var textureAtlas: TextureAtlas?
    
    /// Audio entities (optional)
    public let audios: [AudioEntity]?
    
    // MARK: - Computed Properties
    
    /// Total duration in seconds
    public var duration: TimeInterval {
        TimeInterval(frameCount) / TimeInterval(frameRate)
    }
    
    /// Duration per frame in seconds
    public var frameDuration: TimeInterval {
        1.0 / TimeInterval(frameRate)
    }
    
    /// Number of sprites
    public var spriteCount: Int {
        sprites.count
    }
    
    /// Whether animation has audio
    public var hasAudio: Bool {
        !(audios?.isEmpty ?? true)
    }
    
    /// Whether texture atlas is ready
    public var isTextureReady: Bool {
        textureAtlas != nil
    }
    
    // MARK: - Initialization
    
    public init(
        identifier: String,
        version: UInt32 = 2,
        videoSize: CGSize,
        frameRate: Int,
        frameCount: Int,
        sprites: [SpriteEntity],
        audios: [AudioEntity]? = nil
    ) {
        self.identifier = identifier
        self.version = version
        self.videoSize = videoSize
        self.frameRate = max(1, min(120, frameRate)) // Clamp to valid range
        self.frameCount = max(1, frameCount)
        self.sprites = sprites
        self.audios = audios
    }
    
    // MARK: - Sprite Access
    
    /// Get sprite by identifier
    public func sprite(withIdentifier id: String) -> SpriteEntity? {
        sprites.first { $0.identifier == id }
    }
    
    /// Get sprite by index
    public func sprite(at index: Int) -> SpriteEntity? {
        guard index >= 0 && index < sprites.count else { return nil }
        return sprites[index]
    }
    
    /// Get all sprites visible at specific frame
    public func visibleSprites(at frameIndex: Int) -> [SpriteEntity] {
        sprites.filter { $0.isVisible(at: frameIndex) }
    }
    
    // MARK: - Frame Access
    
    /// Get frame index for time offset
    /// - Parameter time: Time offset in seconds
    /// - Returns: Frame index (clamped to valid range)
    public func frameIndex(at time: TimeInterval) -> Int {
        let rawIndex = Int(time * TimeInterval(frameRate))
        return max(0, min(frameCount - 1, rawIndex))
    }
    
    /// Get fractional frame index for smooth interpolation
    /// - Parameter time: Time offset in seconds
    /// - Returns: Fractional frame index
    public func fractionalFrameIndex(at time: TimeInterval) -> Float {
        let rawIndex = Float(time * TimeInterval(frameRate))
        return max(0, min(Float(frameCount - 1), rawIndex))
    }
    
    // MARK: - Validation
    
    /// Validate animation data
    public func validate() -> Result<Void, Error> {
        // Check basic properties
        guard frameRate >= 1 && frameRate <= 120 else {
            return .failure(NSError(domain: "SVGAEngine", code: 2001, userInfo: [NSLocalizedDescriptionKey: "Invalid frame rate: \(frameRate)"]))
        }
        
        guard frameCount >= 1 else {
            return .failure(NSError(domain: "SVGAEngine", code: 2001, userInfo: [NSLocalizedDescriptionKey: "Invalid frame count: \(frameCount)"]))
        }
        
        guard videoSize.width > 0 && videoSize.height > 0 else {
            return .failure(NSError(domain: "SVGAEngine", code: 2001, userInfo: [NSLocalizedDescriptionKey: "Invalid video size: \(videoSize)"]))
        }
        
        // Validate sprites
        for sprite in sprites {
            guard sprite.isValid else {
                return .failure(NSError(domain: "SVGAEngine", code: 2001, userInfo: [NSLocalizedDescriptionKey: "Invalid sprite: \(sprite.identifier)"]))
            }
            
            guard sprite.frameCount == frameCount else {
                return .failure(NSError(domain: "SVGAEngine", code: 2001, userInfo: [NSLocalizedDescriptionKey: "Sprite frame count mismatch: \(sprite.identifier)"]))
            }
        }
        
        return .success(())
    }
    
    // MARK: - Memory Estimation
    
    /// Estimated memory usage in bytes
    public var estimatedMemorySize: Int {
        // Base properties
        var size = MemoryLayout<SVGAAnimation>.size
        
        // Sprites
        size += sprites.estimatedMemorySize
        
        // Texture atlas (estimate)
        if let atlas = textureAtlas {
            size += atlas.estimatedMemorySize
        }
        
        return size
    }
}

// MARK: - AudioEntity

/// Represents an audio track in SVGA animation
public struct AudioEntity {
    
    /// Audio data (raw bytes)
    public let data: Data
    
    /// Start frame for audio playback
    public let startFrame: Int
    
    /// End frame for audio playback
    public let endFrame: Int
    
    /// Audio format identifier
    public let format: String?
    
    /// Total samples
    public let totalSamples: Int?
    
    public init(
        data: Data,
        startFrame: Int,
        endFrame: Int,
        format: String? = nil,
        totalSamples: Int? = nil
    ) {
        self.data = data
        self.startFrame = startFrame
        self.endFrame = endFrame
        self.format = format
        self.totalSamples = totalSamples
    }
    
    /// Duration in frames
    public var frameDuration: Int {
        endFrame - startFrame
    }
}

// MARK: - TextureAtlas (Forward Declaration)

/// Placeholder for TextureAtlas (implemented in TextureAtlas.swift)
public class TextureAtlas {
    
    public var estimatedMemorySize: Int { 0 }
    
    public init() {}
}

// MARK: - SVGAAnimation Builder

extension SVGAAnimation {
    
    /// Builder for creating SVGAAnimation instances
    public final class Builder {
        private var identifier: String = ""
        private var version: UInt32 = 2
        private var videoSize: CGSize = .zero
        private var frameRate: Int = 30
        private var frameCount: Int = 0
        private var sprites: [SpriteEntity] = []
        private var audios: [AudioEntity]?
        
        public init() {}
        
        @discardableResult
        public func setIdentifier(_ id: String) -> Builder {
            identifier = id
            return self
        }
        
        @discardableResult
        public func setVersion(_ v: UInt32) -> Builder {
            version = v
            return self
        }
        
        @discardableResult
        public func setVideoSize(_ size: CGSize) -> Builder {
            videoSize = size
            return self
        }
        
        @discardableResult
        public func setFrameRate(_ rate: Int) -> Builder {
            frameRate = rate
            return self
        }
        
        @discardableResult
        public func setFrameCount(_ count: Int) -> Builder {
            frameCount = count
            return self
        }
        
        @discardableResult
        public func addSprite(_ sprite: SpriteEntity) -> Builder {
            sprites.append(sprite)
            return self
        }
        
        @discardableResult
        public func setSprites(_ sprites: [SpriteEntity]) -> Builder {
            self.sprites = sprites
            return self
        }
        
        @discardableResult
        public func setAudios(_ audios: [AudioEntity]?) -> Builder {
            self.audios = audios
            return self
        }
        
        public func build() -> SVGAAnimation {
            SVGAAnimation(
                identifier: identifier,
                version: version,
                videoSize: videoSize,
                frameRate: frameRate,
                frameCount: frameCount,
                sprites: sprites,
                audios: audios
            )
        }
    }
    
    /// Create builder
    public static func builder() -> Builder {
        Builder()
    }
}

// MARK: - SVGAAnimationData Protocol Conformance

extension SVGAAnimation: SVGAAnimationData {}

/// Protocol for read-only animation data access
public protocol SVGAAnimationData {
    var identifier: String { get }
    var videoSize: CGSize { get }
    var frameRate: Int { get }
    var frameCount: Int { get }
    var duration: TimeInterval { get }
}
