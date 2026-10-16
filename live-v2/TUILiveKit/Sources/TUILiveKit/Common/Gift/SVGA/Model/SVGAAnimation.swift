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
final class SVGAAnimation {

    // MARK: - Properties

    /// Unique identifier (typically file hash)
    let identifier: String

    /// SVGA format version
    let version: UInt32

    /// Canvas/video size in points
    let videoSize: CGSize

    /// Frame rate (frames per second)
    let frameRate: Int

    /// Total number of frames
    let frameCount: Int

    /// All sprite entities in z-order
    /// Later sprites are rendered on top
    let sprites: [SpriteEntity]

    /// Reference to texture atlas (set after texture preparation)
    internal(set) var textureAtlas: TextureAtlas?

    /// Audio entities (optional)
    let audios: [AudioEntity]?

    // MARK: - Computed Properties

    /// Total duration in seconds
    var duration: TimeInterval {
        TimeInterval(frameCount) / TimeInterval(frameRate)
    }

    /// Duration per frame in seconds
    var frameDuration: TimeInterval {
        1.0 / TimeInterval(frameRate)
    }

    /// Number of sprites
    var spriteCount: Int {
        sprites.count
    }

    /// Whether animation has audio
    var hasAudio: Bool {
        !(audios?.isEmpty ?? true)
    }

    /// Whether texture atlas is ready
    var isTextureReady: Bool {
        textureAtlas != nil
    }

    // MARK: - Initialization

    init(
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
    func sprite(withIdentifier id: String) -> SpriteEntity? {
        sprites.first { $0.identifier == id }
    }

    /// Get sprite by index
    func sprite(at index: Int) -> SpriteEntity? {
        guard index >= 0 && index < sprites.count else { return nil }
        return sprites[index]
    }

    /// Get all sprites visible at specific frame
    func visibleSprites(at frameIndex: Int) -> [SpriteEntity] {
        sprites.filter { $0.isVisible(at: frameIndex) }
    }

    // MARK: - Frame Access

    /// Get frame index for time offset
    /// - Parameter time: Time offset in seconds
    /// - Returns: Frame index (clamped to valid range)
    func frameIndex(at time: TimeInterval) -> Int {
        let rawIndex = Int(time * TimeInterval(frameRate))
        return max(0, min(frameCount - 1, rawIndex))
    }

    /// Get fractional frame index for smooth interpolation
    /// - Parameter time: Time offset in seconds
    /// - Returns: Fractional frame index
    func fractionalFrameIndex(at time: TimeInterval) -> Float {
        let rawIndex = Float(time * TimeInterval(frameRate))
        return max(0, min(Float(frameCount - 1), rawIndex))
    }

    // MARK: - Validation

    /// Validate animation data
    func validate() -> Result<Void, Error> {
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
    var estimatedMemorySize: Int {
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
struct AudioEntity {

    /// Audio data (raw bytes)
    let data: Data

    /// Start frame for audio playback
    let startFrame: Int

    /// End frame for audio playback
    let endFrame: Int

    /// Audio format identifier
    let format: String?

    /// Total samples
    let totalSamples: Int?

    init(
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
    var frameDuration: Int {
        endFrame - startFrame
    }
}

// MARK: - TextureAtlas (Forward Declaration)

/// Placeholder for TextureAtlas (implemented in TextureAtlas.swift)
class TextureAtlas {

    var estimatedMemorySize: Int { 0 }

    init() {}
}

// MARK: - SVGAAnimation Builder

extension SVGAAnimation {

    /// Builder for creating SVGAAnimation instances
    final class Builder {
        private var identifier: String = ""
        private var version: UInt32 = 2
        private var videoSize: CGSize = .zero
        private var frameRate: Int = 30
        private var frameCount: Int = 0
        private var sprites: [SpriteEntity] = []
        private var audios: [AudioEntity]?

        init() {}

        @discardableResult
        func setIdentifier(_ id: String) -> Builder {
            identifier = id
            return self
        }

        @discardableResult
        func setVersion(_ v: UInt32) -> Builder {
            version = v
            return self
        }

        @discardableResult
        func setVideoSize(_ size: CGSize) -> Builder {
            videoSize = size
            return self
        }

        @discardableResult
        func setFrameRate(_ rate: Int) -> Builder {
            frameRate = rate
            return self
        }

        @discardableResult
        func setFrameCount(_ count: Int) -> Builder {
            frameCount = count
            return self
        }

        @discardableResult
        func addSprite(_ sprite: SpriteEntity) -> Builder {
            sprites.append(sprite)
            return self
        }

        @discardableResult
        func setSprites(_ sprites: [SpriteEntity]) -> Builder {
            self.sprites = sprites
            return self
        }

        @discardableResult
        func setAudios(_ audios: [AudioEntity]?) -> Builder {
            self.audios = audios
            return self
        }

        func build() -> SVGAAnimation {
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
    static func builder() -> Builder {
        Builder()
    }
}

// MARK: - SVGAAnimationData Protocol Conformance

extension SVGAAnimation: SVGAAnimationData {}

/// Protocol for read-only animation data access
protocol SVGAAnimationData {
    var identifier: String { get }
    var videoSize: CGSize { get }
    var frameRate: Int { get }
    var frameCount: Int { get }
    var duration: TimeInterval { get }
}
