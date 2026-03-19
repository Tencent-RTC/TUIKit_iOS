//
//  SpriteBatcher.swift
//  TUILiveKit
//
//  Created on 2026/2/5.
//  High-Performance SVGA Player Core
//
//  Batch rendering system for SVGA sprites
//  Reduces DrawCalls by grouping sprites with same texture/state
//
//  OPTIMIZED VERSION:
//  - Zero per-frame allocations
//  - Pre-allocated ring buffers
//  - Inline sorting without COW
//

import Foundation
import Metal
import simd

// MARK: - Batch Key

/// Key for grouping sprites into batches (packed for cache efficiency)
/// Total size: 8 bytes (fits in single cache line access)
public struct SpriteBatchKey: Hashable {
    /// Packed data: [textureID: 24bit][blendMode: 4bit][stencilRef: 4bit]
    @usableFromInline
    internal let _packed: UInt32
    
    /// Mask texture ID (separate for hash distribution)
    @usableFromInline
    internal let _maskTextureID: UInt32
    
    public var textureID: UInt32 { _packed >> 8 }
    public var blendMode: BlendMode { BlendMode(rawValue: UInt8((_packed >> 4) & 0xF)) ?? .normal }
    public var stencilRef: UInt8 { UInt8(_packed & 0xF) }
    public var hasMask: Bool { _maskTextureID != 0 }
    public var maskTextureID: UInt32 { _maskTextureID }
    
    @inlinable
    public init(
        textureID: UInt32,
        blendMode: BlendMode = .normal,
        hasMask: Bool = false,
        maskTextureID: UInt32 = 0,
        stencilRef: UInt8 = 0
    ) {
        self._packed = (textureID << 8) | (UInt32(blendMode.rawValue) << 4) | UInt32(stencilRef & 0xF)
        self._maskTextureID = hasMask ? maskTextureID : 0
    }
    
    /// Fast comparison for sorting (single integer compare)
    @inlinable
    public var sortKey: UInt64 {
        UInt64(_packed) << 32 | UInt64(_maskTextureID)
    }
}

/// Blend modes supported
public enum BlendMode: UInt8, Hashable {
    case normal = 0      // Standard alpha blend
    case additive = 1    // Additive (light effects)
    case multiply = 2    // Multiply (darken)
    case screen = 3      // Screen (lighten)
}

// MARK: - Sprite Batch

/// A batch of sprites that can be rendered with a single draw call
public struct SpriteBatch {
    /// Batch key
    public let key: SpriteBatchKey
    
    /// Starting index in instance buffer
    public var startIndex: Int
    
    /// Number of sprites in batch
    public var count: Int
    
    /// Z-order for batch (average or min of sprites)
    public var zOrder: Int
    
    @inlinable
    public init(key: SpriteBatchKey, startIndex: Int = 0, count: Int = 0, zOrder: Int = 0) {
        self.key = key
        self.startIndex = startIndex
        self.count = count
        self.zOrder = zOrder
    }
}

// MARK: - Sprite Command (Packed for Cache)

/// A single sprite render command (before batching)
/// Size: 64 bytes (single cache line)
public struct SpriteCommand {
    /// Sprite transform (3x3 matrix) - 36 bytes
    public var transform: simd_float3x3
    
    /// Alpha/opacity - 4 bytes
    public var alpha: Float
    
    /// Texture region index in atlas - 2 bytes
    public var textureIndex: UInt16
    
    /// Mask sprite index (0 = no mask) - 2 bytes
    public var maskIndex: UInt16
    
    /// Z-order for sorting - 4 bytes
    public var zOrder: Int32
    
    /// Sort key (pre-computed for fast sorting) - 8 bytes
    public var sortKey: UInt64
    
    /// Padding to 64 bytes - 8 bytes
    @usableFromInline
    internal var _padding: UInt64
    
    @inlinable
    public init(
        transform: simd_float3x3 = matrix_identity_float3x3,
        alpha: Float = 1.0,
        textureIndex: UInt16 = 0,
        maskIndex: UInt16 = 0,
        zOrder: Int32 = 0,
        batchKey: SpriteBatchKey = SpriteBatchKey(textureID: 0)
    ) {
        self.transform = transform
        self.alpha = alpha
        self.textureIndex = textureIndex
        self.maskIndex = maskIndex
        self.zOrder = zOrder
        self.sortKey = batchKey.sortKey
        self._padding = 0
    }
    
    @inlinable
    public var batchKey: SpriteBatchKey {
        let packed = UInt32(sortKey >> 32)
        let maskTex = UInt32(sortKey & 0xFFFFFFFF)
        return SpriteBatchKey(
            textureID: packed >> 8,
            blendMode: BlendMode(rawValue: UInt8((packed >> 4) & 0xF)) ?? .normal,
            hasMask: maskTex != 0,
            maskTextureID: maskTex,
            stencilRef: UInt8(packed & 0xF)
        )
    }
}

// MARK: - Sprite Batcher (Zero-Allocation)

/// Batches sprites for efficient rendering
/// Groups sprites by texture/state to minimize draw calls
/// 
/// OPTIMIZATION: All buffers pre-allocated, zero malloc per frame
public final class SpriteBatcher {
    
    // MARK: - Configuration
    
    /// Maximum sprites per frame
    public let maxSprites: Int
    
    /// Maximum batches per frame
    public let maxBatches: Int
    
    /// Enable batch merging (aggressive optimization)
    public var enableBatchMerging: Bool = true
    
    // MARK: - Pre-allocated Buffers (ZERO per-frame allocation)
    
    /// Command buffer (pre-allocated, fixed size)
    @usableFromInline
    internal let commandBuffer: UnsafeMutablePointer<SpriteCommand>
    
    /// Batch buffer (pre-allocated, fixed size)
    @usableFromInline
    internal let batchBuffer: UnsafeMutablePointer<SpriteBatch>
    
    /// Current command count
    @usableFromInline
    internal var commandCount: Int = 0
    
    /// Current batch count
    @usableFromInline
    internal var batchCount: Int = 0
    
    // MARK: - Statistics
    
    /// Draw call count after batching
    @usableFromInline
    internal var _drawCallCount: Int = 0
    public var drawCallCount: Int { _drawCallCount }
    
    /// Original sprite count
    @usableFromInline
    internal var _spriteCount: Int = 0
    public var spriteCount: Int { _spriteCount }
    
    /// Batch efficiency (sprites / draw calls)
    @inlinable
    public var batchEfficiency: Float {
        drawCallCount > 0 ? Float(spriteCount) / Float(drawCallCount) : 0
    }
    
    // MARK: - Initialization
    
    public init(maxSprites: Int = 1024, maxBatches: Int = 256) {
        self.maxSprites = maxSprites
        self.maxBatches = maxBatches
        
        // Allocate command buffer (cache-line aligned)
        let commandAlignment = 64  // Cache line size
        let commandSize = maxSprites * MemoryLayout<SpriteCommand>.stride
        let alignedCommandSize = (commandSize + commandAlignment - 1) & ~(commandAlignment - 1)
        self.commandBuffer = UnsafeMutableRawPointer.allocate(
            byteCount: alignedCommandSize,
            alignment: commandAlignment
        ).bindMemory(to: SpriteCommand.self, capacity: maxSprites)
        
        // Allocate batch buffer
        self.batchBuffer = UnsafeMutablePointer<SpriteBatch>.allocate(capacity: maxBatches)
    }
    
    deinit {
        commandBuffer.deallocate()
        batchBuffer.deallocate()
    }
    
    // MARK: - Begin/End Frame
    
    /// Begin a new frame (zero allocation)
    @inlinable
    public func beginFrame() {
        commandCount = 0
        batchCount = 0
        _drawCallCount = 0
        _spriteCount = 0
    }
    
    /// Add a sprite command (inline, zero allocation)
    @inlinable
    public func addSprite(_ command: SpriteCommand) {
        guard commandCount < maxSprites else { return }
        commandBuffer[commandCount] = command
        commandCount += 1
    }
    
    /// Add sprite with parameters (inline)
    @inlinable
    public func addSprite(
        transform: simd_float3x3,
        alpha: Float,
        textureIndex: UInt16,
        maskIndex: UInt16 = 0,
        zOrder: Int32 = 0,
        textureID: UInt32 = 0,
        blendMode: BlendMode = .normal
    ) {
        guard commandCount < maxSprites else { return }
        
        let hasMask = maskIndex != 0
        let batchKey = SpriteBatchKey(
            textureID: textureID,
            blendMode: blendMode,
            hasMask: hasMask,
            maskTextureID: hasMask ? UInt32(maskIndex) : 0
        )
        
        commandBuffer[commandCount] = SpriteCommand(
            transform: transform,
            alpha: alpha,
            textureIndex: textureIndex,
            maskIndex: maskIndex,
            zOrder: zOrder,
            batchKey: batchKey
        )
        commandCount += 1
    }
    
    /// End frame and generate batches
    /// Returns UnsafeBufferPointer to avoid Array allocation
    @discardableResult
    public func endFrame() -> UnsafeBufferPointer<SpriteBatch> {
        _spriteCount = commandCount
        
        guard commandCount > 0 else {
            return UnsafeBufferPointer(start: batchBuffer, count: 0)
        }
        
        // Sort by batch key (radix sort - O(n), no allocation)
        radixSortCommands()
        
        // Generate batches (direct to pre-allocated buffer)
        generateBatchesDirect()
        
        // Merge adjacent batches if enabled
        if enableBatchMerging && batchCount > 1 {
            mergeBatchesInPlace()
        }
        
        _drawCallCount = batchCount
        
        return UnsafeBufferPointer(start: batchBuffer, count: batchCount)
    }
    
    // MARK: - Sort (No-op for SVGA)
    
    /// SVGA requires painter's algorithm ordering (original z-order).
    /// No sorting needed — consecutive sprites with same batch key are merged automatically.
    private func radixSortCommands() {
        // Intentionally empty: preserve original sprite order
    }
    
    // MARK: - Batch Generation (Zero Allocation)
    
    /// Generate batches directly to pre-allocated buffer
    private func generateBatchesDirect() {
        batchCount = 0
        
        guard commandCount > 0 else { return }
        
        let firstCommand = commandBuffer[0]
        var currentKey = firstCommand.sortKey
        var currentStart = 0
        var currentZOrder = firstCommand.zOrder
        
        for i in 1..<commandCount {
            let command = commandBuffer[i]
            
            if command.sortKey != currentKey {
                // Finalize current batch
                batchBuffer[batchCount] = SpriteBatch(
                    key: commandBuffer[currentStart].batchKey,
                    startIndex: currentStart,
                    count: i - currentStart,
                    zOrder: Int(currentZOrder)
                )
                batchCount += 1
                
                if batchCount >= maxBatches {
                    break
                }
                
                // Start new batch
                currentKey = command.sortKey
                currentStart = i
                currentZOrder = command.zOrder
            }
        }
        
        // Add final batch
        if batchCount < maxBatches {
            batchBuffer[batchCount] = SpriteBatch(
                key: commandBuffer[currentStart].batchKey,
                startIndex: currentStart,
                count: commandCount - currentStart,
                zOrder: Int(currentZOrder)
            )
            batchCount += 1
        }
    }
    
    /// Merge adjacent batches in-place
    private func mergeBatchesInPlace() {
        guard batchCount > 1 else { return }
        
        var writeIndex = 0
        var current = batchBuffer[0]
        
        for i in 1..<batchCount {
            let next = batchBuffer[i]
            
            // Check if batches are adjacent and compatible
            if current.key.sortKey == next.key.sortKey &&
               current.startIndex + current.count == next.startIndex {
                // Merge
                current.count += next.count
            } else {
                batchBuffer[writeIndex] = current
                writeIndex += 1
                current = next
            }
        }
        
        batchBuffer[writeIndex] = current
        batchCount = writeIndex + 1
    }
    
    // MARK: - GPU Buffer Write (Single Pass, Zero Intermediate)
    
    /// Write instance data directly to an MTLBuffer in a single pass.
    /// Converts SpriteCommand → SVGAInstance directly into GPU memory.
    /// No intermediate buffer — saves ~48 * maxSprites bytes of memory.
    ///
    /// OPTIMIZED: Uses 8x unrolling for better ILP on ARM cores.
    /// SpriteCommand (64 bytes) → SVGAInstance (48 bytes) conversion is memory-bound;
    /// unrolling increases instruction-level parallelism for the load/store pipeline.
    public func writeDirectlyToBuffer(_ buffer: MTLBuffer) {
        guard commandCount > 0 else { return }
        
        let dst = buffer.contents().assumingMemoryBound(to: SVGAInstance.self)
        let src = commandBuffer
        var i = 0
        // Unroll by 8 for better ILP on ARM (A-series cores have 6-wide dispatch)
        let count8 = commandCount & ~7
        while i < count8 {
            let c0 = src[i]; let c1 = src[i+1]; let c2 = src[i+2]; let c3 = src[i+3]
            let c4 = src[i+4]; let c5 = src[i+5]; let c6 = src[i+6]; let c7 = src[i+7]
            dst[i]   = SVGAInstance(transform: c0.transform, alpha: c0.alpha, textureIndex: c0.textureIndex, maskIndex: c0.maskIndex)
            dst[i+1] = SVGAInstance(transform: c1.transform, alpha: c1.alpha, textureIndex: c1.textureIndex, maskIndex: c1.maskIndex)
            dst[i+2] = SVGAInstance(transform: c2.transform, alpha: c2.alpha, textureIndex: c2.textureIndex, maskIndex: c2.maskIndex)
            dst[i+3] = SVGAInstance(transform: c3.transform, alpha: c3.alpha, textureIndex: c3.textureIndex, maskIndex: c3.maskIndex)
            dst[i+4] = SVGAInstance(transform: c4.transform, alpha: c4.alpha, textureIndex: c4.textureIndex, maskIndex: c4.maskIndex)
            dst[i+5] = SVGAInstance(transform: c5.transform, alpha: c5.alpha, textureIndex: c5.textureIndex, maskIndex: c5.maskIndex)
            dst[i+6] = SVGAInstance(transform: c6.transform, alpha: c6.alpha, textureIndex: c6.textureIndex, maskIndex: c6.maskIndex)
            dst[i+7] = SVGAInstance(transform: c7.transform, alpha: c7.alpha, textureIndex: c7.textureIndex, maskIndex: c7.maskIndex)
            i += 8
        }
        while i < commandCount {
            let c = src[i]
            dst[i] = SVGAInstance(transform: c.transform, alpha: c.alpha, textureIndex: c.textureIndex, maskIndex: c.maskIndex)
            i += 1
        }
    }
}

// MARK: - Masked Sprite Batcher (Zero-Allocation)

/// Extended batcher with stencil mask support
/// OPTIMIZED: Pre-allocated lookup tables, no Dictionary per frame
public final class MaskedSpriteBatcher {
    
    /// Mask pass type
    public enum MaskPassType {
        case writeMask      // Write to stencil buffer
        case renderMasked   // Render using stencil test
    }
    
    /// A mask group (mask + masked sprites)
    public struct MaskGroup {
        /// Mask sprite batch
        public var maskBatch: SpriteBatch
        
        /// Masked sprites batches (inline array to avoid allocation)
        public var maskedBatches: InlineArray8<SpriteBatch>
        
        /// Stencil reference value
        public let stencilRef: UInt8
        
        public init(maskBatch: SpriteBatch, stencilRef: UInt8) {
            self.maskBatch = maskBatch
            self.maskedBatches = InlineArray8()
            self.stencilRef = stencilRef
        }
    }
    
    /// Inline array (no heap allocation) - max 8 elements
    public struct InlineArray8<T> {
        private var storage: (T?, T?, T?, T?, T?, T?, T?, T?) = (nil, nil, nil, nil, nil, nil, nil, nil)
        public private(set) var count: Int = 0
        
        public mutating func append(_ element: T) {
            guard count < 8 else { return }
            switch count {
            case 0: storage.0 = element
            case 1: storage.1 = element
            case 2: storage.2 = element
            case 3: storage.3 = element
            case 4: storage.4 = element
            case 5: storage.5 = element
            case 6: storage.6 = element
            case 7: storage.7 = element
            default: break
            }
            count += 1
        }
        
        public subscript(index: Int) -> T {
            switch index {
            case 0: return storage.0!
            case 1: return storage.1!
            case 2: return storage.2!
            case 3: return storage.3!
            case 4: return storage.4!
            case 5: return storage.5!
            case 6: return storage.6!
            case 7: return storage.7!
            default: fatalError("Index out of bounds")
            }
        }
        
        public mutating func reset() {
            storage = (nil, nil, nil, nil, nil, nil, nil, nil)
            count = 0
        }
    }
    
    // MARK: - Properties
    
    /// Base sprite batcher
    @usableFromInline
    internal let baseBatcher: SpriteBatcher
    
    /// Maximum masks per frame
    public let maxMasks: Int
    
    /// Pre-allocated mask groups buffer
    private let maskGroupsBuffer: UnsafeMutablePointer<MaskGroup>
    @usableFromInline
    internal var maskGroupCount: Int = 0
    
    /// Pre-allocated unmasked batches buffer
    private let unmaskedBatchesBuffer: UnsafeMutablePointer<SpriteBatch>
    @usableFromInline
    internal var unmaskedBatchCount: Int = 0
    
    /// Mask lookup table (stencilRef -> maskGroupIndex)
    /// Fixed size array instead of Dictionary
    @usableFromInline
    internal var maskLookup: [Int16]  // -1 = not found
    
    /// Current stencil reference counter
    @usableFromInline
    internal var stencilRefCounter: UInt8 = 0
    
    // MARK: - Initialization
    
    public init(maxSprites: Int = 1024, maxMasks: Int = 32) {
        self.baseBatcher = SpriteBatcher(maxSprites: maxSprites, maxBatches: 256)
        self.maxMasks = maxMasks
        
        // Pre-allocate mask groups
        self.maskGroupsBuffer = UnsafeMutablePointer<MaskGroup>.allocate(capacity: maxMasks)
        
        // Pre-allocate unmasked batches
        self.unmaskedBatchesBuffer = UnsafeMutablePointer<SpriteBatch>.allocate(capacity: 256)
        
        // Pre-allocate lookup table (256 possible stencil refs)
        self.maskLookup = [Int16](repeating: -1, count: 256)
    }
    
    deinit {
        maskGroupsBuffer.deallocate()
        unmaskedBatchesBuffer.deallocate()
    }
    
    // MARK: - Frame Management
    
    @inlinable
    public func beginFrame() {
        baseBatcher.beginFrame()
        maskGroupCount = 0
        unmaskedBatchCount = 0
        stencilRefCounter = 0
        
        // Reset lookup table (faster than recreating Dictionary)
        for i in 0..<256 {
            maskLookup[i] = -1
        }
    }
    
    /// Add a mask sprite
    /// Returns stencil reference value for masked sprites
    @inlinable
    public func addMask(
        transform: simd_float3x3,
        alpha: Float,
        textureIndex: UInt16
    ) -> UInt8 {
        guard stencilRefCounter < maxMasks else { return 0 }
        
        stencilRefCounter += 1
        
        baseBatcher.addSprite(
            transform: transform,
            alpha: alpha,
            textureIndex: textureIndex,
            maskIndex: UInt16(stencilRefCounter),
            textureID: UInt32(textureIndex)
        )
        
        return stencilRefCounter
    }
    
    /// Add a masked sprite (uses stencil test)
    @inlinable
    public func addMaskedSprite(
        transform: simd_float3x3,
        alpha: Float,
        textureIndex: UInt16,
        stencilRef: UInt8
    ) {
        let batchKey = SpriteBatchKey(
            textureID: UInt32(textureIndex),
            hasMask: true,
            stencilRef: stencilRef
        )
        
        baseBatcher.addSprite(SpriteCommand(
            transform: transform,
            alpha: alpha,
            textureIndex: textureIndex,
            maskIndex: UInt16(stencilRef),
            batchKey: batchKey
        ))
    }
    
    /// Add unmasked sprite
    @inlinable
    public func addSprite(
        transform: simd_float3x3,
        alpha: Float,
        textureIndex: UInt16,
        blendMode: BlendMode = .normal
    ) {
        baseBatcher.addSprite(
            transform: transform,
            alpha: alpha,
            textureIndex: textureIndex,
            textureID: UInt32(textureIndex),
            blendMode: blendMode
        )
    }
    
    /// End frame and organize into mask groups
    /// Returns pointers instead of Arrays to avoid allocation
    public func endFrame() -> (
        maskGroups: UnsafeBufferPointer<MaskGroup>,
        unmaskedBatches: UnsafeBufferPointer<SpriteBatch>
    ) {
        let allBatches = baseBatcher.endFrame()
        
        // Reset counters
        maskGroupCount = 0
        unmaskedBatchCount = 0
        
        // Single pass: categorize batches
        for i in 0..<allBatches.count {
            let batch = allBatches[i]
            
            if batch.key.hasMask {
                let ref = batch.key.stencilRef
                
                // Check if this is the mask itself (maskTextureID == stencilRef)
                if batch.key.maskTextureID == UInt32(ref) {
                    // This is a mask - create new group
                    if maskGroupCount < maxMasks {
                        maskGroupsBuffer[maskGroupCount] = MaskGroup(
                            maskBatch: batch,
                            stencilRef: ref
                        )
                        maskLookup[Int(ref)] = Int16(maskGroupCount)
                        maskGroupCount += 1
                    }
                } else {
                    // This is masked content - add to existing group
                    let groupIndex = maskLookup[Int(ref)]
                    if groupIndex >= 0 && groupIndex < Int16(maskGroupCount) {
                        maskGroupsBuffer[Int(groupIndex)].maskedBatches.append(batch)
                    }
                }
            } else {
                // Unmasked batch
                if unmaskedBatchCount < 256 {
                    unmaskedBatchesBuffer[unmaskedBatchCount] = batch
                    unmaskedBatchCount += 1
                }
            }
        }
        
        return (
            UnsafeBufferPointer(start: maskGroupsBuffer, count: maskGroupCount),
            UnsafeBufferPointer(start: unmaskedBatchesBuffer, count: unmaskedBatchCount)
        )
    }
    
    /// Write instance data directly to an MTLBuffer
    public func writeDirectlyToBuffer(_ buffer: MTLBuffer) {
        baseBatcher.writeDirectlyToBuffer(buffer)
    }
    
    /// Get statistics
    public var drawCallCount: Int { baseBatcher.drawCallCount }
    public var spriteCount: Int { baseBatcher.spriteCount }
    public var batchEfficiency: Float { baseBatcher.batchEfficiency }
}

// MARK: - Batch Render Commands

/// Encodes batch render commands for Metal
public struct BatchRenderCommands {
    
    /// Render a batch with instanced drawing
    @inlinable
    public static func encodeBatch(
        _ batch: SpriteBatch,
        encoder: MTLRenderCommandEncoder,
        indexBuffer: MTLBuffer,
        pipelineState: MTLRenderPipelineState,
        depthStencilState: MTLDepthStencilState? = nil,
        stencilRef: UInt32 = 0
    ) {
        // Set pipeline
        encoder.setRenderPipelineState(pipelineState)
        
        // Set depth/stencil state
        if let depthStencil = depthStencilState {
            encoder.setDepthStencilState(depthStencil)
            encoder.setStencilReferenceValue(stencilRef)
        }
        
        // Draw instanced
        encoder.drawIndexedPrimitives(
            type: .triangle,
            indexCount: SVGAQuadMesh.indexCount,
            indexType: .uint16,
            indexBuffer: indexBuffer,
            indexBufferOffset: 0,
            instanceCount: batch.count,
            baseVertex: 0,
            baseInstance: batch.startIndex
        )
    }
    
    /// Render multiple batches with same texture
    @inlinable
    public static func encodeBatches(
        _ batches: UnsafeBufferPointer<SpriteBatch>,
        encoder: MTLRenderCommandEncoder,
        indexBuffer: MTLBuffer,
        pipelineState: MTLRenderPipelineState,
        texture: MTLTexture,
        sampler: MTLSamplerState
    ) {
        guard batches.count > 0 else { return }
        
        // Set pipeline once
        encoder.setRenderPipelineState(pipelineState)
        encoder.setFragmentTexture(texture, index: 0)
        encoder.setFragmentSamplerState(sampler, index: 0)
        
        // Draw all batches
        for i in 0..<batches.count {
            let batch = batches[i]
            encoder.drawIndexedPrimitives(
                type: .triangle,
                indexCount: SVGAQuadMesh.indexCount,
                indexType: .uint16,
                indexBuffer: indexBuffer,
                indexBufferOffset: 0,
                instanceCount: batch.count,
                baseVertex: 0,
                baseInstance: batch.startIndex
            )
        }
    }
}
