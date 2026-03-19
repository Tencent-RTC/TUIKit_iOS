//
//  FrameData.swift
//  TUILiveKit
//
//  Created on 2026/2/5.
//  High-Performance SVGA Player Core
//

import Foundation
import simd

// MARK: - Constants

/// Maximum number of sprites per frame
/// Limits memory usage and ensures fixed-size allocations
/// Increased to 256 to support complex SVGA animations with many sprites
public let SVGA_MAX_SPRITES: Int = 256

/// Frame data size in bytes (approximately 4KB)
/// Optimized for page alignment and cache efficiency
public let SVGA_FRAME_DATA_SIZE: Int = MemoryLayout<FrameDataHeader>.stride + SVGA_MAX_SPRITES * MemoryLayout<SpriteRenderData>.stride

// MARK: - FrameDataHeader

/// Header for frame data block
/// 16 bytes, cache-line aligned
public struct FrameDataHeader {
    /// Current frame index
    public var frameIndex: Int32
    
    /// Number of valid sprites in this frame
    public var spriteCount: Int32
    
    /// Timestamp when this frame was prepared (microseconds)
    public var timestamp: Int64
    
    public init(
        frameIndex: Int32 = 0,
        spriteCount: Int32 = 0,
        timestamp: Int64 = 0
    ) {
        self.frameIndex = frameIndex
        self.spriteCount = spriteCount
        self.timestamp = timestamp
    }
}

// MARK: - SpriteRenderData

/// Per-sprite render data (CPU-side)
/// Contains all data needed to render a single sprite instance
public struct SpriteRenderData {
    
    // MARK: - Transform
    
    /// 3x3 transformation matrix (content)
    public var transform: simd_float3x3
    
    /// 3x3 transformation matrix (mask/matte)
    /// 当 sprite 使用 matte 时，mask 需要使用 matte sprite 的 transform
    public var maskTransform: simd_float3x3
    
    // MARK: - Visual Properties
    
    /// Opacity [0.0, 1.0]
    public var alpha: Float
    
    /// Texture region index in atlas
    public var textureIndex: UInt16
    
    /// Mask/matte index (0 = no mask)
    public var maskIndex: UInt16
    
    // MARK: - Padding
    
    /// Reserved for future use / alignment
    private var _reserved: SIMD2<UInt32>
    
    // MARK: - Initialization
    
    public init(
        transform: simd_float3x3 = matrix_identity_float3x3,
        maskTransform: simd_float3x3 = matrix_identity_float3x3,
        alpha: Float = 1.0,
        textureIndex: UInt16 = 0,
        maskIndex: UInt16 = 0
    ) {
        self.transform = transform
        self.maskTransform = maskTransform
        self.alpha = alpha
        self.textureIndex = textureIndex
        self.maskIndex = maskIndex
        self._reserved = .zero
    }
    
    // MARK: - Factory
    
    /// Create identity sprite (no transformation)
    public static var identity: SpriteRenderData {
        SpriteRenderData()
    }
    
    /// Create from SpriteFrame
    public static func from(
        frame: SpriteFrame,
        textureIndex: UInt16,
        maskIndex: UInt16 = 0
    ) -> SpriteRenderData {
        SpriteRenderData(
            transform: frame.transform,
            maskTransform: frame.transform,
            alpha: frame.alpha,
            textureIndex: textureIndex,
            maskIndex: maskIndex
        )
    }
    
    // MARK: - Validation
    
    /// Check if data is valid for rendering
    public var isValid: Bool {
        // Alpha in valid range
        guard alpha >= 0 && alpha <= 1 else { return false }
        
        // Transform not NaN/Inf
        for col in 0..<3 {
            for row in 0..<3 {
                let v = transform[col][row]
                if v.isNaN || v.isInfinite { return false }
            }
        }
        // Mask transform not NaN/Inf
        for col in 0..<3 {
            for row in 0..<3 {
                let v = maskTransform[col][row]
                if v.isNaN || v.isInfinite { return false }
            }
        }
        
        return true
    }
    
    /// Check if sprite should be rendered (visible)
    public var isVisible: Bool {
        alpha > 0.001
    }
}

// Ensure alignment
#if DEBUG
private let _spriteRenderDataSizeCheck: Void = {
    assert(MemoryLayout<SpriteRenderData>.stride % 16 == 0,
           "SpriteRenderData must be 16-byte aligned")
}()
#endif

// MARK: - FrameData

/// Complete frame data for rendering
/// Uses raw memory (UnsafeMutableBufferPointer) instead of ContiguousArray
/// to eliminate ARC retain/release overhead during triple buffer rotation.
public struct FrameData {
    
    // MARK: - Properties
    
    /// Header information
    public var header: FrameDataHeader
    
    /// Sprite render data — raw memory, zero ARC overhead
    /// Only first `header.spriteCount` entries are valid
    @usableFromInline
    internal let _storage: UnsafeMutablePointer<SpriteRenderData>
    
    /// Capacity (max sprites this FrameData can hold)
    public let capacity: Int
    
    /// Subscript access to sprites (no bounds check for perf)
    public var sprites: UnsafeMutableBufferPointer<SpriteRenderData> {
        UnsafeMutableBufferPointer(start: _storage, count: capacity)
    }
    
    // MARK: - Initialization
    
    public init(capacity: Int = SVGA_MAX_SPRITES) {
        self.capacity = capacity
        self.header = FrameDataHeader()
        // Page-aligned allocation for GPU-friendly access
        let alignment = 4096
        let size = capacity * MemoryLayout<SpriteRenderData>.stride
        let alignedSize = (size + alignment - 1) & ~(alignment - 1)
        let raw = UnsafeMutableRawPointer.allocate(byteCount: max(alignedSize, alignment), alignment: alignment)
        self._storage = raw.bindMemory(to: SpriteRenderData.self, capacity: capacity)
        // Zero-fill (identity equivalent for render data)
        memset(raw, 0, alignedSize)
    }
    
    // MARK: - Properties
    
    /// Frame index
    public var frameIndex: Int {
        get { Int(header.frameIndex) }
        set { header.frameIndex = Int32(newValue) }
    }
    
    /// Number of valid sprites
    public var spriteCount: Int {
        get { Int(header.spriteCount) }
        set { header.spriteCount = Int32(min(newValue, capacity)) }
    }
    
    /// Timestamp
    public var timestamp: Int64 {
        get { header.timestamp }
        set { header.timestamp = newValue }
    }
    
    // MARK: - Sprite Access
    
    /// Get sprite at index with bounds checking
    public func sprite(at index: Int) -> SpriteRenderData? {
        guard index >= 0 && index < spriteCount else { return nil }
        return _storage[index]
    }
    
    /// Set sprite at index
    public mutating func setSprite(_ sprite: SpriteRenderData, at index: Int) {
        guard index >= 0 && index < capacity else { return }
        _storage[index] = sprite
        if index >= spriteCount {
            spriteCount = index + 1
        }
    }
    
    /// Append sprite (if room available)
    @discardableResult
    public mutating func appendSprite(_ sprite: SpriteRenderData) -> Bool {
        guard spriteCount < capacity else { return false }
        _storage[spriteCount] = sprite
        header.spriteCount += 1
        return true
    }
    
    // MARK: - Reset
    
    /// Reset frame data for reuse
    public mutating func reset() {
        header = FrameDataHeader()
        // Note: We don't reset sprite data for performance
        // Only header.spriteCount matters
    }
    
    /// Clear all sprite data
    public mutating func clear() {
        header = FrameDataHeader()
        memset(_storage, 0, capacity * MemoryLayout<SpriteRenderData>.stride)
    }
    
    /// Deallocate the underlying storage.
    /// MUST be called before discarding a FrameData instance to avoid memory leaks.
    /// (FrameData is a struct and has no deinit.)
    public func deallocate() {
        _storage.deallocate()
    }
    
    // MARK: - Subscript (direct memory access, no ARC)
    
    /// Direct subscript access to sprites (no bounds check for performance)
    @inline(__always)
    public subscript(index: Int) -> SpriteRenderData {
        get { _storage[index] }
        set { _storage[index] = newValue }
    }
}

// MARK: - FrameData + Unsafe Access

extension FrameData {
    
    /// Get raw pointer to sprite array for GPU upload
    /// - Warning: Pointer is valid for the lifetime of this FrameData
    public func withUnsafeSpritePointer<T>(_ body: (UnsafePointer<SpriteRenderData>) throws -> T) rethrows -> T {
        try body(UnsafePointer(_storage))
    }
    
    /// Get mutable pointer to sprite array for direct write
    /// - Warning: Pointer is valid for the lifetime of this FrameData
    public mutating func withUnsafeMutableSpritePointer<T>(_ body: (UnsafeMutablePointer<SpriteRenderData>) throws -> T) rethrows -> T {
        try body(_storage)
    }
}

// MARK: - FrameDataRef

/// Unsafe reference to frame data in object pool
/// Used for zero-copy access from pool
public struct FrameDataRef {
    
    /// Pointer to frame data in pool
    public let pointer: UnsafeMutablePointer<FrameData>
    
    /// Pool index (for returning to pool)
    public let poolIndex: Int
    
    public init(pointer: UnsafeMutablePointer<FrameData>, poolIndex: Int) {
        self.pointer = pointer
        self.poolIndex = poolIndex
    }
    
    /// Access frame data
    public var data: FrameData {
        get { pointer.pointee }
        nonmutating set { pointer.pointee = newValue }
    }
    
    /// Frame index shortcut
    public var frameIndex: Int {
        get { Int(pointer.pointee.header.frameIndex) }
        nonmutating set { pointer.pointee.header.frameIndex = Int32(newValue) }
    }
    
    /// Sprite count shortcut
    public var spriteCount: Int {
        get { Int(pointer.pointee.header.spriteCount) }
        nonmutating set { pointer.pointee.header.spriteCount = Int32(newValue) }
    }
    
    /// Reset for reuse
    public func reset() {
        pointer.pointee.reset()
    }
    
    /// Direct sprite access
    public subscript(spriteIndex: Int) -> SpriteRenderData {
        get { pointer.pointee._storage[spriteIndex] }
        nonmutating set { pointer.pointee._storage[spriteIndex] = newValue }
    }
}
