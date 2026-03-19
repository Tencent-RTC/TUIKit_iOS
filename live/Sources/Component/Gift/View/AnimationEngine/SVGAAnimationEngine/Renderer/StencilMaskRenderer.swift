//
//  StencilMaskRenderer.swift
//  TUILiveKit
//
//  Created on 2026/2/5.
//  High-Performance SVGA Player Core
//
//  Stencil buffer based mask rendering
//  OPTIMIZED VERSION:
//  - Memory-budgeted stencil textures
//  - Texture shrinking for memory recovery
//  - Zero per-frame allocation
//

import Foundation
import Metal
import MetalKit
import simd

// MARK: - Stencil Mask Config

/// Configuration for stencil mask rendering
public struct StencilMaskConfig {
    /// Maximum number of nested masks
    public var maxNestingLevel: Int = 8
    
    /// Use inverted mask (render outside mask area)
    public var invertMask: Bool = false
    
    /// Alpha threshold for mask (discard below this)
    public var alphaThreshold: Float = 0.01
    
    /// Stencil clear value
    public var clearValue: UInt32 = 0
    
    /// Maximum stencil texture size (memory budget)
    public var maxTextureWidth: Int = 4096
    public var maxTextureHeight: Int = 4096
    
    /// Shrink threshold - recreate smaller texture if view is this much smaller
    public var shrinkThreshold: Float = 0.25
    
    public init() {}
}

// MARK: - Mask Operation

/// Mask operation type
public enum MaskOperation {
    /// Write mask to stencil buffer
    case writeMask
    
    /// Render content using stencil test
    case renderMasked
    
    /// Clear stencil buffer region
    case clearMask
    
    /// Push nested mask (increment stencil)
    case pushMask
    
    /// Pop nested mask (decrement stencil)
    case popMask
}

// MARK: - Stencil Mask Renderer

/// Handles mask rendering using stencil buffer
/// Zero off-screen rendering - all masking done in single render pass
public final class StencilMaskRenderer {
    
    // MARK: - Types
    
    /// Mask state for tracking nested masks (stack-allocated)
    private struct MaskState {
        var stencilRef: UInt32
        var nestingLevel: Int
        var boundsX: Float
        var boundsY: Float
        var boundsW: Float
        var boundsH: Float
    }
    
    /// Render pass for mask operations
    public struct MaskRenderPass {
        public let operation: MaskOperation
        public let stencilRef: UInt32
        public let spriteIndices: Range<Int>
        public var boundsX: Float
        public var boundsY: Float
        public var boundsW: Float
        public var boundsH: Float
        
        public var bounds: CGRect {
            CGRect(x: CGFloat(boundsX), y: CGFloat(boundsY), 
                   width: CGFloat(boundsW), height: CGFloat(boundsH))
        }
    }
    
    // MARK: - Properties
    
    /// Metal device
    private let device: MTLDevice
    
    /// Configuration
    public var config: StencilMaskConfig
    
    /// Stencil texture (lazy created, memory managed)
    private var stencilTexture: MTLTexture?
    
    /// Current stencil texture size
    private var stencilTextureWidth: Int = 0
    private var stencilTextureHeight: Int = 0
    
    /// Depth stencil states (created once)
    @usableFromInline
    internal var maskWriteState: MTLDepthStencilState?
    @usableFromInline
    internal var maskedRenderState: MTLDepthStencilState?
    @usableFromInline
    internal var maskClearState: MTLDepthStencilState?
    @usableFromInline
    internal var nestedMaskWriteState: MTLDepthStencilState?
    
    /// Mask stack (pre-allocated, fixed size)
    private let maskStackBuffer: UnsafeMutablePointer<MaskState>
    @usableFromInline
    internal var maskStackCount: Int = 0
    private let maxMaskStackSize: Int = 16
    
    /// Current stencil reference value
    @usableFromInline
    internal var currentStencilRef: UInt32 = 0
    
    /// Maximum stencil reference (2^8 - 1 for 8-bit stencil)
    private let maxStencilRef: UInt32 = 255
    
    /// Render passes buffer (pre-allocated)
    private let renderPassesBuffer: UnsafeMutablePointer<MaskRenderPass>
    @usableFromInline
    internal var renderPassCount: Int = 0
    private let maxRenderPasses: Int = 64
    
    // MARK: - Initialization
    
    public init(device: MTLDevice, config: StencilMaskConfig = StencilMaskConfig()) {
        self.device = device
        self.config = config
        
        // Pre-allocate mask stack
        self.maskStackBuffer = UnsafeMutablePointer<MaskState>.allocate(capacity: maxMaskStackSize)
        
        // Pre-allocate render passes buffer
        self.renderPassesBuffer = UnsafeMutablePointer<MaskRenderPass>.allocate(capacity: maxRenderPasses)
        
        createDepthStencilStates()
    }
    
    deinit {
        maskStackBuffer.deallocate()
        renderPassesBuffer.deallocate()
    }
    
    // MARK: - Depth Stencil States
    
    private func createDepthStencilStates() {
        // Mask write state: Write to stencil buffer (replace)
        let maskWriteDescriptor = MTLDepthStencilDescriptor()
        maskWriteDescriptor.label = "SVGA Mask Write"
        maskWriteDescriptor.isDepthWriteEnabled = false
        
        let maskWriteStencil = MTLStencilDescriptor()
        maskWriteStencil.stencilCompareFunction = .always
        maskWriteStencil.stencilFailureOperation = .keep
        maskWriteStencil.depthFailureOperation = .keep
        maskWriteStencil.depthStencilPassOperation = .replace
        maskWriteStencil.readMask = 0xFF
        maskWriteStencil.writeMask = 0xFF
        
        maskWriteDescriptor.frontFaceStencil = maskWriteStencil
        maskWriteDescriptor.backFaceStencil = maskWriteStencil
        maskWriteState = device.makeDepthStencilState(descriptor: maskWriteDescriptor)
        
        // Masked render state: Test stencil (equal)
        let maskedRenderDescriptor = MTLDepthStencilDescriptor()
        maskedRenderDescriptor.label = "SVGA Masked Render"
        maskedRenderDescriptor.isDepthWriteEnabled = false
        
        let maskedRenderStencil = MTLStencilDescriptor()
        maskedRenderStencil.stencilCompareFunction = .equal
        maskedRenderStencil.stencilFailureOperation = .keep
        maskedRenderStencil.depthFailureOperation = .keep
        maskedRenderStencil.depthStencilPassOperation = .keep
        maskedRenderStencil.readMask = 0xFF
        maskedRenderStencil.writeMask = 0x00
        
        maskedRenderDescriptor.frontFaceStencil = maskedRenderStencil
        maskedRenderDescriptor.backFaceStencil = maskedRenderStencil
        maskedRenderState = device.makeDepthStencilState(descriptor: maskedRenderDescriptor)
        
        // Mask clear state: Zero stencil
        let maskClearDescriptor = MTLDepthStencilDescriptor()
        maskClearDescriptor.label = "SVGA Mask Clear"
        maskClearDescriptor.isDepthWriteEnabled = false
        
        let maskClearStencil = MTLStencilDescriptor()
        maskClearStencil.stencilCompareFunction = .always
        maskClearStencil.stencilFailureOperation = .zero
        maskClearStencil.depthFailureOperation = .zero
        maskClearStencil.depthStencilPassOperation = .zero
        maskClearStencil.readMask = 0xFF
        maskClearStencil.writeMask = 0xFF
        
        maskClearDescriptor.frontFaceStencil = maskClearStencil
        maskClearDescriptor.backFaceStencil = maskClearStencil
        maskClearState = device.makeDepthStencilState(descriptor: maskClearDescriptor)
        
        // Nested mask write state: Increment stencil
        let nestedMaskDescriptor = MTLDepthStencilDescriptor()
        nestedMaskDescriptor.label = "SVGA Nested Mask"
        nestedMaskDescriptor.isDepthWriteEnabled = false
        
        let nestedMaskStencil = MTLStencilDescriptor()
        nestedMaskStencil.stencilCompareFunction = .equal
        nestedMaskStencil.stencilFailureOperation = .keep
        nestedMaskStencil.depthFailureOperation = .keep
        nestedMaskStencil.depthStencilPassOperation = .incrementClamp
        nestedMaskStencil.readMask = 0xFF
        nestedMaskStencil.writeMask = 0xFF
        
        nestedMaskDescriptor.frontFaceStencil = nestedMaskStencil
        nestedMaskDescriptor.backFaceStencil = nestedMaskStencil
        nestedMaskWriteState = device.makeDepthStencilState(descriptor: nestedMaskDescriptor)
    }
    
    // MARK: - Stencil Texture Management (Memory Budgeted)
    
    /// Ensure stencil texture exists and matches physical size
    /// - Parameters:
    ///   - width: Physical pixel width
    ///   - height: Physical pixel height
    public func ensureStencilTexture(width: Int, height: Int) {
        // 如果尺寸没变，直接返回
        if let existing = stencilTexture, 
           existing.width == width, 
           existing.height == height {
            return
        }
        
        // 释放旧纹理并创建新纹理
        stencilTexture = nil
        
        let descriptor = MTLTextureDescriptor.texture2DDescriptor(
            pixelFormat: .stencil8,
            width: width,
            height: height,
            mipmapped: false
        )
        descriptor.usage = [.renderTarget]
        
        // 使用 memoryless storage（A8+ GPU）：stencil 纹理只存在于 tile memory，
        // 不占用系统/显存。条件：loadAction=.clear + storeAction=.dontCare（已满足）。
        // 对于不支持 memoryless 的旧设备，fallback 到 private。
        if #available(iOS 10.0, *), device.supportsFamily(.apple1) {
            descriptor.storageMode = .memoryless
        } else {
            descriptor.storageMode = .private
        }
        
        stencilTexture = device.makeTexture(descriptor: descriptor)
        stencilTexture?.label = "SVGA Stencil Texture (\(width)x\(height), memoryless)"
        stencilTextureWidth = width
        stencilTextureHeight = height
    }
    
    /// Ensure stencil texture exists and matches size (Legacy, uses float size)
    public func ensureStencilTexture(size: CGSize) {
        // 使用 ceil 确保覆盖所有像素，但最好还是用物理尺寸
        ensureStencilTexture(width: Int(ceil(size.width)), height: Int(ceil(size.height)))
    }
    
    /// Release stencil texture to free memory
    public func releaseStencilTexture() {
        stencilTexture = nil
        stencilTextureWidth = 0
        stencilTextureHeight = 0
    }
    
    /// Get stencil texture for render pass descriptor
    public func getStencilTexture() -> MTLTexture? {
        stencilTexture
    }
    
    /// Get current stencil texture memory usage in bytes
    public var stencilTextureMemoryUsage: Int {
        // Stencil8 = 1 byte per pixel
        stencilTextureWidth * stencilTextureHeight
    }
    
    // MARK: - Frame Management
    
    /// Begin a new frame (zero allocation)
    public func beginFrame() {
        maskStackCount = 0
        renderPassCount = 0
        currentStencilRef = 0
    }
    
    /// End frame and return render passes
    public func endFrame() -> UnsafeBufferPointer<MaskRenderPass> {
        // Ensure all masks are popped
        while maskStackCount > 0 {
            popMask()
        }
        return UnsafeBufferPointer(start: renderPassesBuffer, count: renderPassCount)
    }
    
    // MARK: - Mask Operations
    
    /// Push a new mask onto the stack
    /// - Parameters:
    ///   - spriteIndices: Indices of mask sprites
    ///   - bounds: Mask bounds
    /// - Returns: Stencil reference value for masked content
    @discardableResult
    public func pushMask(spriteIndices: Range<Int>, bounds: CGRect) -> UInt32 {
        guard maskStackCount < config.maxNestingLevel,
              maskStackCount < maxMaskStackSize else {
            return currentStencilRef
        }
        
        // Increment stencil reference
        currentStencilRef += 1
        
        // Push state (direct memory write, no allocation)
        maskStackBuffer[maskStackCount] = MaskState(
            stencilRef: currentStencilRef,
            nestingLevel: maskStackCount + 1,
            boundsX: Float(bounds.origin.x),
            boundsY: Float(bounds.origin.y),
            boundsW: Float(bounds.size.width),
            boundsH: Float(bounds.size.height)
        )
        maskStackCount += 1
        
        // Add render pass for mask write
        guard renderPassCount < maxRenderPasses else {
            return currentStencilRef
        }
        
        renderPassesBuffer[renderPassCount] = MaskRenderPass(
            operation: maskStackCount == 1 ? .writeMask : .pushMask,
            stencilRef: currentStencilRef,
            spriteIndices: spriteIndices,
            boundsX: Float(bounds.origin.x),
            boundsY: Float(bounds.origin.y),
            boundsW: Float(bounds.size.width),
            boundsH: Float(bounds.size.height)
        )
        renderPassCount += 1
        
        return currentStencilRef
    }
    
    /// Add masked content render pass
    public func renderMasked(spriteIndices: Range<Int>) {
        guard maskStackCount > 0,
              renderPassCount < maxRenderPasses else {
            return
        }
        
        let currentMask = maskStackBuffer[maskStackCount - 1]
        
        renderPassesBuffer[renderPassCount] = MaskRenderPass(
            operation: .renderMasked,
            stencilRef: currentMask.stencilRef,
            spriteIndices: spriteIndices,
            boundsX: currentMask.boundsX,
            boundsY: currentMask.boundsY,
            boundsW: currentMask.boundsW,
            boundsH: currentMask.boundsH
        )
        renderPassCount += 1
    }
    
    /// Pop the current mask
    public func popMask() {
        guard maskStackCount > 0 else { return }
        
        let poppedMask = maskStackBuffer[maskStackCount - 1]
        maskStackCount -= 1
        currentStencilRef = maskStackCount > 0 ? maskStackBuffer[maskStackCount - 1].stencilRef : 0
        
        // Add render pass for mask clear/pop
        guard renderPassCount < maxRenderPasses else { return }
        
        renderPassesBuffer[renderPassCount] = MaskRenderPass(
            operation: maskStackCount == 0 ? .clearMask : .popMask,
            stencilRef: poppedMask.stencilRef,
            spriteIndices: 0..<0,  // No sprites, just state change
            boundsX: poppedMask.boundsX,
            boundsY: poppedMask.boundsY,
            boundsW: poppedMask.boundsW,
            boundsH: poppedMask.boundsH
        )
        renderPassCount += 1
    }
    
    // MARK: - Encoding
    
    /// Get depth stencil state for operation
    public func getDepthStencilState(for operation: MaskOperation) -> MTLDepthStencilState? {
        switch operation {
        case .writeMask:
            return maskWriteState
        case .renderMasked:
            return maskedRenderState
        case .clearMask:
            return maskClearState
        case .pushMask:
            return nestedMaskWriteState
        case .popMask:
            return maskedRenderState  // Use stencil test to restore previous level
        }
    }
    
    /// Encode mask operations for a render pass
    public func encodeMaskPass(
        _ pass: MaskRenderPass,
        encoder: MTLRenderCommandEncoder,
        maskPipeline: MTLRenderPipelineState,
        spritePipeline: MTLRenderPipelineState,
        indexBuffer: MTLBuffer,
        instanceBuffer: MTLBuffer,
        uniformBuffer: MTLBuffer,
        texture: MTLTexture?,
        sampler: MTLSamplerState?
    ) {
        guard let depthStencilState = getDepthStencilState(for: pass.operation) else {
            return
        }
        
        encoder.setDepthStencilState(depthStencilState)
        encoder.setStencilReferenceValue(pass.stencilRef)
        
        switch pass.operation {
        case .writeMask, .pushMask:
            // Write mask to stencil buffer
            encoder.setRenderPipelineState(maskPipeline)
            
            if !pass.spriteIndices.isEmpty {
                let count = pass.spriteIndices.count
                let baseInstance = pass.spriteIndices.lowerBound
                
                encoder.drawIndexedPrimitives(
                    type: .triangle,
                    indexCount: SVGAQuadMesh.indexCount,
                    indexType: .uint16,
                    indexBuffer: indexBuffer,
                    indexBufferOffset: 0,
                    instanceCount: count,
                    baseVertex: 0,
                    baseInstance: baseInstance
                )
            }
            
        case .renderMasked:
            // Render sprites with stencil test
            encoder.setRenderPipelineState(spritePipeline)
            
            if let tex = texture { encoder.setFragmentTexture(tex, index: 0) }
            if let samp = sampler { encoder.setFragmentSamplerState(samp, index: 0) }
            
            if !pass.spriteIndices.isEmpty {
                let count = pass.spriteIndices.count
                let baseInstance = pass.spriteIndices.lowerBound
                
                encoder.drawIndexedPrimitives(
                    type: .triangle,
                    indexCount: SVGAQuadMesh.indexCount,
                    indexType: .uint16,
                    indexBuffer: indexBuffer,
                    indexBufferOffset: 0,
                    instanceCount: count,
                    baseVertex: 0,
                    baseInstance: baseInstance
                )
            }
            
        case .clearMask, .popMask:
            // Clear stencil region (render fullscreen quad with zero)
            // This is handled by the next frame's clear or by explicit clear pass
            break
        }
    }
    
    // MARK: - Cleanup
    
    /// Release resources
    public func release() {
        stencilTexture = nil
        stencilTextureWidth = 0
        stencilTextureHeight = 0
        maskStackCount = 0
        renderPassCount = 0
    }
}

// MARK: - Shader-Based Alpha Mask

/// Alpha mask shader implementation (alternative to stencil)
/// Uses fragment shader discard for mask testing
public struct AlphaMaskShaderConfig {
    /// Uniform buffer for mask parameters
    public struct MaskUniforms {
        /// Mask texture UV offset
        var maskUVOffset: SIMD2<Float>
        
        /// Mask texture UV scale
        var maskUVScale: SIMD2<Float>
        
        /// Alpha threshold
        var alphaThreshold: Float
        
        /// Invert mask flag
        var invertMask: UInt32
        
        /// Padding
        var _padding: SIMD2<Float>
        
        public init(
            uvOffset: SIMD2<Float> = .zero,
            uvScale: SIMD2<Float> = SIMD2<Float>(1, 1),
            alphaThreshold: Float = 0.01,
            invertMask: Bool = false
        ) {
            self.maskUVOffset = uvOffset
            self.maskUVScale = uvScale
            self.alphaThreshold = alphaThreshold
            self.invertMask = invertMask ? 1 : 0
            self._padding = .zero
        }
    }
    
    /// Create uniform buffer for mask
    public static func createUniformBuffer(device: MTLDevice) -> MTLBuffer? {
        let size = MemoryLayout<MaskUniforms>.stride
        return device.makeBuffer(length: size, options: .storageModeShared)
    }
}

// MARK: - Mask Batch Builder

/// Builds render passes for masked sprites
public final class MaskBatchBuilder {
    
    /// Mask definition
    public struct MaskDefinition {
        public let maskSpriteIndex: Int
        public var maskedSpriteIndices: [Int]  // TODO: Replace with inline buffer
        public var boundsX: Float
        public var boundsY: Float
        public var boundsW: Float
        public var boundsH: Float
        
        public var bounds: CGRect {
            CGRect(x: CGFloat(boundsX), y: CGFloat(boundsY),
                   width: CGFloat(boundsW), height: CGFloat(boundsH))
        }
        
        public init(maskSpriteIndex: Int, bounds: CGRect) {
            self.maskSpriteIndex = maskSpriteIndex
            self.maskedSpriteIndices = []
            self.boundsX = Float(bounds.origin.x)
            self.boundsY = Float(bounds.origin.y)
            self.boundsW = Float(bounds.size.width)
            self.boundsH = Float(bounds.size.height)
        }
    }
    
    /// Render order item
    public enum RenderItem {
        case unmasked(spriteIndices: Range<Int>)
        case masked(maskIndex: Int, maskSprite: Int, contentIndices: [Int])
    }
    
    // MARK: - Properties
    
    private var masks: [MaskDefinition] = []
    private var unmaskedIndices: [Int] = []
    
    // MARK: - Building
    
    public init() {
        masks.reserveCapacity(16)
        unmaskedIndices.reserveCapacity(256)
    }
    
    /// Reset for new frame
    public func reset() {
        masks.removeAll(keepingCapacity: true)
        unmaskedIndices.removeAll(keepingCapacity: true)
    }
    
    /// Add mask with masked content
    public func addMask(maskSpriteIndex: Int, maskedSpriteIndices: [Int], bounds: CGRect) {
        var def = MaskDefinition(maskSpriteIndex: maskSpriteIndex, bounds: bounds)
        def.maskedSpriteIndices = maskedSpriteIndices
        masks.append(def)
    }
    
    /// Add unmasked sprite
    public func addUnmasked(spriteIndex: Int) {
        unmaskedIndices.append(spriteIndex)
    }
    
    /// Build render order
    public func build() -> [RenderItem] {
        var items: [RenderItem] = []
        items.reserveCapacity(masks.count + 16)
        
        // Group consecutive unmasked sprites
        if !unmaskedIndices.isEmpty {
            unmaskedIndices.sort()
            
            var rangeStart = unmaskedIndices[0]
            var rangeEnd = rangeStart + 1
            
            for i in 1..<unmaskedIndices.count {
                let index = unmaskedIndices[i]
                if index == rangeEnd {
                    rangeEnd += 1
                } else {
                    items.append(.unmasked(spriteIndices: rangeStart..<rangeEnd))
                    rangeStart = index
                    rangeEnd = index + 1
                }
            }
            
            items.append(.unmasked(spriteIndices: rangeStart..<rangeEnd))
        }
        
        // Add masked groups
        for (index, mask) in masks.enumerated() {
            items.append(.masked(
                maskIndex: index,
                maskSprite: mask.maskSpriteIndex,
                contentIndices: mask.maskedSpriteIndices
            ))
        }
        
        return items
    }
}
