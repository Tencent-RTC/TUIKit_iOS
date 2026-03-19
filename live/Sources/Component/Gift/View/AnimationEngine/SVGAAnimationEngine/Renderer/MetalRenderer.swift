//
//  MetalRenderer.swift
//  TUILiveKit
//
//  Created on 2026/2/5.
//  High-Performance SVGA Player Core
//
//  Core Metal renderer with batch rendering support
//  OPTIMIZED VERSION:
//  - Triple-buffered without blocking
//  - Zero per-frame allocation
//  - Async texture upload with timeout
//  - Texture memory budget management
//

import Foundation
import Metal
import MetalKit
import simd

// MARK: - Texture Memory Budget

/// Texture memory budget configuration
public struct TextureMemoryBudget {
    /// Maximum stencil texture size (default 4K)
    public var maxStencilWidth: Int = 4096
    public var maxStencilHeight: Int = 4096
    
    /// Shrink threshold - if view is smaller than this ratio, recreate texture
    public var shrinkThreshold: Float = 0.25
    
    /// Maximum total texture memory (bytes)
    public var maxTotalMemory: Int = 64 * 1024 * 1024  // 64MB
    
    public init() {}
}


// MARK: - MetalRenderer

/// Core Metal renderer for SVGA animation
/// Implements batch rendering and stencil masking for optimal performance
public final class MetalRenderer {
    
    // MARK: - Properties
    
    /// Renderer type identifier
    public let rendererType = "Metal"
    
    /// Shared Metal context (device, queue, pipeline are all shared globally)
    private let context: SharedMetalContext
    
    /// Convenience accessors
    public var device: MTLDevice { context.device }
    public var commandQueue: MTLCommandQueue { context.commandQueue }
    
    /// Render pipeline manager (shared via context)
    private var pipeline: SVGARenderPipeline? { context.pipeline }
    
    /// Whether renderer is ready
    public private(set) var isReady: Bool = false
    
    /// Current animation being rendered
    private weak var currentAnimation: SVGAAnimation?
    
    /// Current texture atlas (weak — lifecycle owned by PreparedAnimationCache + SVGAPlayerView)
    /// During playback, SVGAPlayerView holds the strong reference.
    /// MetalRenderer only needs the texture for encoding draw commands.
    private weak var textureAtlas: SVGATextureAtlas?
    
    /// Texture memory budget
    public var memoryBudget = TextureMemoryBudget()
    
    // MARK: - Batch Rendering
    
    /// Sprite batcher for DrawCall optimization
    private let spriteBatcher: MaskedSpriteBatcher
    
    /// Stencil mask renderer
    private let stencilMaskRenderer: StencilMaskRenderer
    
    // MARK: - Triple Buffered Resources (Non-Blocking)
    
    /// Ring buffer frame data
    private struct FrameResources {
        var instanceBuffer: MTLBuffer
        var uniformBuffer: MTLBuffer
    }
    
    /// Triple buffer index
    private var currentFrameIndex: Int = 0
    
    /// Frame resources ring buffer
    private var frameResources: [FrameResources] = []
    
    /// Shared vertex buffer (static, never changes)
    private var vertexBuffer: MTLBuffer?
    
    /// Shared index buffer (static, never changes)
    private var indexBuffer: MTLBuffer?
    
    /// UV regions buffer
    private var uvRegionsBuffer: MTLBuffer?
    
    /// Maximum sprites per frame (dynamically resized on prepare)
    private var maxSprites: Int
    
    /// Current viewport size
    private var viewportSize: CGSize = .zero
    
    /// Last stencil texture size (for shrink detection)
    private var lastStencilSize: CGSize = .zero
    
    /// Frame count for statistics
    private var frameCount: UInt64 = 0
    
    // MARK: - Statistics
    
    private var _statistics = SVGARendererStatistics()
    public var statistics: SVGARendererStatistics { _statistics }
    
    // MARK: - Initialization
    
    public init?(maxSprites: Int = SVGA_MAX_SPRITES) {
        guard let ctx = SharedMetalContext.shared else {
            return nil
        }
        
        self.context = ctx
        self.maxSprites = maxSprites
        self.spriteBatcher = MaskedSpriteBatcher(maxSprites: maxSprites)
        self.stencilMaskRenderer = StencilMaskRenderer(device: ctx.device)
    }
    
    /// Initialize with existing context
    public init(context: SharedMetalContext, maxSprites: Int = SVGA_MAX_SPRITES) {
        self.context = context
        self.maxSprites = maxSprites
        self.spriteBatcher = MaskedSpriteBatcher(maxSprites: maxSprites)
        self.stencilMaskRenderer = StencilMaskRenderer(device: context.device)
    }
    
    // MARK: - Setup
    
    /// Prepare renderer for rendering
    /// - Parameter pixelFormat: Target pixel format
    public func setup(pixelFormat: MTLPixelFormat = .bgra8Unorm) throws {
        // Setup shared render pipeline (no-op if already set up)
        try context.ensurePipeline(pixelFormat: pixelFormat)
        
        // Create static buffers
        try createStaticBuffers()
        
        // Create triple-buffered frame resources
        try createFrameResources()
        
        isReady = true
    }
    
    private func createStaticBuffers() throws {
        // Vertex buffer (quad mesh - never changes)
        guard let vb = SVGAVertexDescriptor.createVertexBuffer(device: device) else {
            throw NSError(domain: "SVGAEngine", code: 4002, userInfo: [NSLocalizedDescriptionKey: "Failed to create vertex buffer"])
        }
        vb.label = "SVGA Vertex Buffer (Static)"
        vertexBuffer = vb
        
        // Index buffer (quad indices - never changes)
        guard let ib = SVGAVertexDescriptor.createIndexBuffer(device: device) else {
            throw NSError(domain: "SVGAEngine", code: 4002, userInfo: [NSLocalizedDescriptionKey: "Failed to create index buffer"])
        }
        ib.label = "SVGA Index Buffer (Static)"
        indexBuffer = ib
        
        // UV regions buffer
        guard let uvB = SVGAVertexDescriptor.createUVRegionsBuffer(device: device, capacity: maxSprites) else {
            throw NSError(domain: "SVGAEngine", code: 4002, userInfo: [NSLocalizedDescriptionKey: "Failed to create UV regions buffer"])
        }
        uvB.label = "SVGA UV Regions Buffer"
        uvRegionsBuffer = uvB
    }
    
    private func createFrameResources() throws {
        // Return old buffers to the pool before creating new ones
        let pool = context.bufferPool
        for res in frameResources {
            pool.release(res.instanceBuffer)
            pool.release(res.uniformBuffer)
        }
        frameResources.removeAll()
        
        // Create 3 frame resource sets for triple buffering
        let instanceSize = MemoryLayout<SVGAInstance>.stride * maxSprites
        let uniformSize = MemoryLayout<SVGAUniforms>.stride
        
        for i in 0..<3 {
            guard let instB = pool.acquire(device: device, minSize: instanceSize) else {
                throw NSError(domain: "SVGAEngine", code: 4002, userInfo: [NSLocalizedDescriptionKey: "Failed to create instance buffer"])
            }
            instB.label = "SVGA Instance Buffer \(i)"
            
            guard let uniB = pool.acquire(device: device, minSize: uniformSize) else {
                throw NSError(domain: "SVGAEngine", code: 4002, userInfo: [NSLocalizedDescriptionKey: "Failed to create uniform buffer"])
            }
            uniB.label = "SVGA Uniform Buffer \(i)"
            
            // Pre-initialize viewMatrix and time once (shader doesn't use viewMatrix,
            // and updateUniformBufferDirect skips writing these fields for perf)
            let uniforms = uniB.contents().assumingMemoryBound(to: SVGAUniforms.self)
            uniforms.pointee.viewMatrix = matrix_identity_float4x4
            uniforms.pointee.time = 0
            
            frameResources.append(FrameResources(
                instanceBuffer: instB,
                uniformBuffer: uniB
            ))
        }
    }
    
    // MARK: - Prepare
    
    /// Prepare renderer for specific animation
    public func prepare(for animation: SVGAAnimation) throws {
        guard isReady else {
            throw NSError(domain: "SVGAEngine", code: 9002, userInfo: [NSLocalizedDescriptionKey: "Invalid state: expected ready, actual not ready"])
        }
        
        currentAnimation = animation
        
        // Dynamically resize buffers if sprite count differs from current capacity
        let neededSprites = max(animation.sprites.count + 8, 16) // +8 headroom for masks
        if neededSprites != maxSprites {
            maxSprites = neededSprites
            try recreateBuffersForCapacity(neededSprites)
        }
        
        // Setup texture atlas if available
        if let atlas = animation.textureAtlas as? SVGATextureAtlas {
            textureAtlas = atlas
            try updateUVRegionsBuffer(from: atlas)
        }
    }
    
    /// Recreate instance/UV buffers and batcher for a new sprite capacity
    private func recreateBuffersForCapacity(_ capacity: Int) throws {
        // Recreate UV regions buffer
        guard let uvB = SVGAVertexDescriptor.createUVRegionsBuffer(device: device, capacity: capacity) else {
            throw NSError(domain: "SVGAEngine", code: 4002, userInfo: [NSLocalizedDescriptionKey: "Failed to create UV regions buffer"])
        }
        uvB.label = "SVGA UV Regions Buffer (\(capacity))"
        uvRegionsBuffer = uvB
        
        // Recreate frame resources with new capacity
        try createFrameResources()
    }
    
    /// Clear rendered content
    public func clear() {
        spriteBatcher.beginFrame()
    }
    
    /// Release renderer resources
    public func release() {
        isReady = false
        currentAnimation = nil
        // textureAtlas is weak — no need to nil explicitly
        
        // Return buffers to the pool for future reuse
        let pool = context.bufferPool
        for res in frameResources {
            pool.release(res.instanceBuffer)
            pool.release(res.uniformBuffer)
        }
        
        // Release buffers (but NOT shared pipeline/device/queue)
        vertexBuffer = nil
        indexBuffer = nil
        frameResources.removeAll()
        uvRegionsBuffer = nil
        
        // Release subsystems
        stencilMaskRenderer.release()
        // pipeline is shared via context, do NOT release it here
    }
    
    // MARK: - Direct Batching API (Skip FrameData)
    
    /// Begin a new batch frame. Call this before addSpriteToBatch/addMaskedSpriteToBatch.
    public func beginBatch() {
        spriteBatcher.beginFrame()
    }
    
    /// Add an unmasked sprite directly to the batch (skips FrameData intermediate storage)
    @inline(__always)
    public func addSpriteToBatch(
        transform: simd_float3x3,
        alpha: Float,
        textureIndex: UInt16
    ) {
        spriteBatcher.addSprite(
            transform: transform,
            alpha: alpha,
            textureIndex: textureIndex
        )
    }
    
    /// Add a masked sprite directly to the batch.
    /// Internally adds both the mask sprite and the masked content sprite.
    @inline(__always)
    public func addMaskedSpriteToBatch(
        transform: simd_float3x3,
        alpha: Float,
        textureIndex: UInt16,
        maskTransform: simd_float3x3,
        maskTextureIndex: UInt16
    ) {
        let stencilRef = spriteBatcher.addMask(
            transform: maskTransform,
            alpha: 1.0,
            textureIndex: maskTextureIndex
        )
        spriteBatcher.addMaskedSprite(
            transform: transform,
            alpha: alpha,
            textureIndex: textureIndex,
            stencilRef: stencilRef
        )
    }
    
    // MARK: - Zero-Copy Direct Write API
    
    /// Get raw pointer to GPU instance buffer for direct writing.
    /// Caller writes SVGAInstance data directly — bypasses SpriteCommand entirely.
    /// MUST call `finishDirectWrite(count:bufferIndex:)` after writing.
    @inline(__always)
    public func getInstanceBufferPointer(bufferIndex: Int) -> UnsafeMutablePointer<SVGAInstance>? {
        guard bufferIndex < frameResources.count else { return nil }
        return frameResources[bufferIndex].instanceBuffer.contents()
            .assumingMemoryBound(to: SVGAInstance.self)
    }
    
    /// Maximum number of sprites that fit in the instance buffer.
    @inline(__always)
    public var maxSpriteCapacity: Int { maxSprites }
    
    /// Render a pre-batched frame. Call after beginBatch + addSpriteToBatch calls.
    public func renderPreBatched(
        commandBuffer: MTLCommandBuffer,
        renderPassDescriptor: MTLRenderPassDescriptor,
        viewportSize: CGSize,
        bufferIndex: Int = 0
    ) {
        guard isReady,
              let spritePipeline = pipeline?.spritePipeline,
              let vertexBuffer = vertexBuffer,
              let indexBuffer = indexBuffer,
              let uvRegionsBuffer = uvRegionsBuffer else {
            if let encoder = commandBuffer.makeRenderCommandEncoder(descriptor: renderPassDescriptor) {
                encoder.label = "SVGA Empty PreBatched Encoder"
                encoder.endEncoding()
            }
            return
        }
        
        // End batching (generates batch descriptors)
        let (maskGroups, unmaskedBatches) = spriteBatcher.endFrame()
        
        if spriteBatcher.spriteCount == 0 {
            if let encoder = commandBuffer.makeRenderCommandEncoder(descriptor: renderPassDescriptor) {
                encoder.label = "SVGA Empty Frame Encoder"
                encoder.endEncoding()
            }
            _statistics.drawCallCount = 0
            _statistics.vertexCount = 0
            _statistics.triangleCount = 0
            return
        }
        
        let safeBufferIndex = bufferIndex % frameResources.count
        let resources = frameResources[safeBufferIndex]
        
        self.viewportSize = viewportSize
        
        // Write sprite data directly to GPU buffer
        spriteBatcher.writeDirectlyToBuffer(resources.instanceBuffer)
        
        // Update uniform buffer (with projection caching)
        updateUniformBufferDirect(
            resources.uniformBuffer,
            viewportSize: viewportSize,
            spriteCount: UInt32(spriteBatcher.spriteCount)
        )
        
        // Ensure stencil texture
        if let colorTexture = renderPassDescriptor.colorAttachments[0].texture {
            ensureStencilTextureWithPhysicalSize(width: colorTexture.width, height: colorTexture.height)
        } else {
            ensureStencilTextureWithBudget(size: viewportSize)
        }
        
        if let stencilTexture = stencilMaskRenderer.getStencilTexture() {
            renderPassDescriptor.stencilAttachment.texture = stencilTexture
            renderPassDescriptor.stencilAttachment.loadAction = .clear
            renderPassDescriptor.stencilAttachment.storeAction = .dontCare
            renderPassDescriptor.stencilAttachment.clearStencil = 0
        }
        
        guard let encoder = commandBuffer.makeRenderCommandEncoder(descriptor: renderPassDescriptor) else {
            return
        }
        encoder.label = "SVGA PreBatched Encoder"
        
        // Use shared encoding logic
        encodeBatchedCommands(
            encoder: encoder,
            maskGroups: maskGroups,
            unmaskedBatches: unmaskedBatches,
            resources: resources,
            indexBuffer: indexBuffer,
            spritePipeline: spritePipeline
        )
        
        encoder.endEncoding()
        
        updateStatisticsAfterEncode(maskGroupCount: maskGroups.count, unmaskedBatchCount: unmaskedBatches.count)
    }
    
    /// Render with direct-write mode: caller already wrote SVGAInstance data into the
    /// instance buffer via getInstanceBufferPointer(). No SpriteCommand intermediate.
    /// This is the fastest path — zero data copying on the CPU side.
    ///
    /// - Parameters:
    ///   - spriteCount: Number of sprites the caller wrote
    ///   - bufferIndex: Triple-buffer index
    ///   - commandBuffer: Metal command buffer
    ///   - renderPassDescriptor: Render pass
    ///   - viewportSize: Viewport size in pixels
    public func renderDirectWrite(
        spriteCount: Int,
        commandBuffer: MTLCommandBuffer,
        renderPassDescriptor: MTLRenderPassDescriptor,
        viewportSize: CGSize,
        bufferIndex: Int = 0
    ) {
        guard isReady,
              spriteCount > 0,
              let spritePipeline = pipeline?.spritePipeline,
              let vertexBuffer = vertexBuffer,
              let indexBuffer = indexBuffer,
              let uvRegionsBuffer = uvRegionsBuffer else {
            if let encoder = commandBuffer.makeRenderCommandEncoder(descriptor: renderPassDescriptor) {
                encoder.label = "SVGA Empty DirectWrite Encoder"
                encoder.endEncoding()
            }
            return
        }
        
        let safeBufferIndex = bufferIndex % frameResources.count
        let resources = frameResources[safeBufferIndex]
        
        self.viewportSize = viewportSize
        
        // Update uniform buffer
        updateUniformBufferDirect(
            resources.uniformBuffer,
            viewportSize: viewportSize,
            spriteCount: UInt32(spriteCount)
        )
        
        // Ensure stencil texture
        if let colorTexture = renderPassDescriptor.colorAttachments[0].texture {
            ensureStencilTextureWithPhysicalSize(width: colorTexture.width, height: colorTexture.height)
        } else {
            ensureStencilTextureWithBudget(size: viewportSize)
        }
        
        if let stencilTexture = stencilMaskRenderer.getStencilTexture() {
            renderPassDescriptor.stencilAttachment.texture = stencilTexture
            renderPassDescriptor.stencilAttachment.loadAction = .clear
            renderPassDescriptor.stencilAttachment.storeAction = .dontCare
            renderPassDescriptor.stencilAttachment.clearStencil = 0
        }
        
        guard let encoder = commandBuffer.makeRenderCommandEncoder(descriptor: renderPassDescriptor) else {
            return
        }
        encoder.label = "SVGA DirectWrite Encoder"
        
        // Minimal state setup — single draw call for all unmasked sprites
        encoder.setVertexBuffer(vertexBuffer, offset: 0, index: SVGAVertexDescriptor.vertexBufferIndex)
        encoder.setVertexBuffer(resources.instanceBuffer, offset: 0, index: SVGAVertexDescriptor.instanceBufferIndex)
        encoder.setVertexBuffer(uvRegionsBuffer, offset: 0, index: SVGAVertexDescriptor.uvRegionsBufferIndex)
        encoder.setVertexBuffer(resources.uniformBuffer, offset: 0, index: SVGAVertexDescriptor.uniformBufferIndex)
        
        if let atlasTexture = textureAtlas?.texture {
            encoder.setFragmentTexture(atlasTexture, index: 0)
        }
        if let sampler = pipeline?.defaultSampler {
            encoder.setFragmentSamplerState(sampler, index: 0)
        }
        
        encoder.setRenderPipelineState(spritePipeline)
        if let defaultState = pipeline?.defaultDepthStencilState {
            encoder.setDepthStencilState(defaultState)
        }
        
        // Single draw call for ALL sprites (no batching overhead)
        encoder.drawIndexedPrimitives(
            type: .triangle,
            indexCount: SVGAQuadMesh.indexCount,
            indexType: .uint16,
            indexBuffer: indexBuffer,
            indexBufferOffset: 0,
            instanceCount: spriteCount,
            baseVertex: 0,
            baseInstance: 0
        )
        
        encoder.endEncoding()
        
        // Update statistics
        frameCount += 1
        _statistics.drawCallCount = 1
        _statistics.vertexCount = SVGAQuadMesh.vertexCount * spriteCount
        _statistics.triangleCount = 2 * spriteCount
        _statistics.textureBindCount = 1
    }
    
    // MARK: - Stencil Texture with Memory Budget
    
    /// Ensure stencil texture with physical pixel size
    private func ensureStencilTextureWithPhysicalSize(width: Int, height: Int) {
        let targetWidth = min(width, memoryBudget.maxStencilWidth)
        let targetHeight = min(height, memoryBudget.maxStencilHeight)
        
        // Check if we should shrink the texture
        let shrinkRatio = memoryBudget.shrinkThreshold
        let shouldShrink = lastStencilSize.width > 0 &&
            (CGFloat(targetWidth) < lastStencilSize.width * CGFloat(shrinkRatio) ||
             CGFloat(targetHeight) < lastStencilSize.height * CGFloat(shrinkRatio))
        
        if shouldShrink {
            stencilMaskRenderer.releaseStencilTexture()
        }
        
        stencilMaskRenderer.ensureStencilTexture(width: targetWidth, height: targetHeight)
        lastStencilSize = CGSize(width: targetWidth, height: targetHeight)
    }
    
    /// Ensure stencil texture with memory budget management
    /// Prevents texture memory explosion by:
    /// 1. Capping maximum size
    /// 2. Shrinking when view becomes significantly smaller
    private func ensureStencilTextureWithBudget(size: CGSize) {
        let targetWidth = min(Int(ceil(size.width)), memoryBudget.maxStencilWidth)
        let targetHeight = min(Int(ceil(size.height)), memoryBudget.maxStencilHeight)
        
        // Check if we should shrink the texture
        let shrinkRatio = memoryBudget.shrinkThreshold
        let shouldShrink = lastStencilSize.width > 0 &&
            (CGFloat(targetWidth) < lastStencilSize.width * CGFloat(shrinkRatio) ||
             CGFloat(targetHeight) < lastStencilSize.height * CGFloat(shrinkRatio))
        
        if shouldShrink {
            // Release old texture and create smaller one
            stencilMaskRenderer.releaseStencilTexture()
        }
        
        stencilMaskRenderer.ensureStencilTexture(
            size: CGSize(width: targetWidth, height: targetHeight)
        )
        lastStencilSize = CGSize(width: targetWidth, height: targetHeight)
    }
    
    // MARK: - Common Encoding (DRY: All render paths call this)
    
    /// Encode batched render commands into an existing encoder.
    /// Shared by renderPreBatched and future render paths.
    @inline(__always)
    private func encodeBatchedCommands(
        encoder: MTLRenderCommandEncoder,
        maskGroups: UnsafeBufferPointer<MaskedSpriteBatcher.MaskGroup>,
        unmaskedBatches: UnsafeBufferPointer<SpriteBatch>,
        resources: FrameResources,
        indexBuffer: MTLBuffer,
        spritePipeline: MTLRenderPipelineState
    ) {
        // Set vertex buffers (once)
        encoder.setVertexBuffer(vertexBuffer!, offset: 0, index: SVGAVertexDescriptor.vertexBufferIndex)
        encoder.setVertexBuffer(resources.instanceBuffer, offset: 0, index: SVGAVertexDescriptor.instanceBufferIndex)
        encoder.setVertexBuffer(uvRegionsBuffer!, offset: 0, index: SVGAVertexDescriptor.uvRegionsBufferIndex)
        encoder.setVertexBuffer(resources.uniformBuffer, offset: 0, index: SVGAVertexDescriptor.uniformBufferIndex)
        
        // Set fragment resources (once)
        if let atlasTexture = textureAtlas?.texture {
            encoder.setFragmentTexture(atlasTexture, index: 0)
        }
        if let sampler = pipeline?.defaultSampler {
            encoder.setFragmentSamplerState(sampler, index: 0)
        }
        
        // Render mask groups using stencil buffer
        for i in 0..<maskGroups.count {
            let maskGroup = maskGroups[i]
            
            // Pass 1: Write mask to stencil buffer
            if let maskPipeline = pipeline?.maskPipeline,
               let maskWriteState = pipeline?.maskWriteDepthStencilState {
                encoder.setRenderPipelineState(maskPipeline)
                encoder.setDepthStencilState(maskWriteState)
                encoder.setStencilReferenceValue(UInt32(maskGroup.stencilRef))
                
                let maskBatch = maskGroup.maskBatch
                if maskBatch.count > 0 {
                    encoder.drawIndexedPrimitives(
                        type: .triangle,
                        indexCount: SVGAQuadMesh.indexCount,
                        indexType: .uint16,
                        indexBuffer: indexBuffer,
                        indexBufferOffset: 0,
                        instanceCount: maskBatch.count,
                        baseVertex: 0,
                        baseInstance: maskBatch.startIndex
                    )
                }
            }
            
            // Pass 2: Render masked content with stencil test
            if let maskedState = pipeline?.maskedDepthStencilState {
                encoder.setRenderPipelineState(spritePipeline)
                encoder.setDepthStencilState(maskedState)
                encoder.setStencilReferenceValue(UInt32(maskGroup.stencilRef))
                
                for j in 0..<maskGroup.maskedBatches.count {
                    let batch = maskGroup.maskedBatches[j]
                    if batch.count > 0 {
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
        }
        
        // Render unmasked batches (no stencil test)
        encoder.setRenderPipelineState(spritePipeline)
        if let defaultState = pipeline?.defaultDepthStencilState {
            encoder.setDepthStencilState(defaultState)
        }
        
        for i in 0..<unmaskedBatches.count {
            let batch = unmaskedBatches[i]
            if batch.count > 0 {
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
    
    /// Update statistics after encoding
    @inline(__always)
    private func updateStatisticsAfterEncode(maskGroupCount: Int, unmaskedBatchCount: Int) {
        frameCount += 1
        _statistics.drawCallCount = maskGroupCount * 2 + unmaskedBatchCount
        _statistics.vertexCount = SVGAQuadMesh.vertexCount * spriteBatcher.spriteCount
        _statistics.triangleCount = 2 * spriteBatcher.spriteCount
        _statistics.textureBindCount = 1
    }
    
    // MARK: - Buffer Updates (Direct Pointer, Zero Allocation)
    
    /// Cached projection matrix to avoid recomputation when viewport doesn't change
    private var cachedProjectionViewportW: Float = 0
    private var cachedProjectionViewportH: Float = 0
    private var cachedProjectionMatrix: simd_float4x4 = matrix_identity_float4x4
    
    /// Update uniform buffer - direct pointer write, no allocation
    /// OPTIMIZED: Caches projection matrix when viewport size is unchanged.
    /// viewMatrix is always identity and only written once during buffer creation
    /// (shader code skips it entirely, kept for ABI compat).
    private func updateUniformBufferDirect(
        _ buffer: MTLBuffer,
        viewportSize: CGSize,
        spriteCount: UInt32
    ) {
        let w = Float(viewportSize.width)
        let h = Float(viewportSize.height)
        
        // Recompute projection only when viewport changes
        if w != cachedProjectionViewportW || h != cachedProjectionViewportH {
            cachedProjectionMatrix = SVGAUniforms.orthographic(width: w, height: h)
            cachedProjectionViewportW = w
            cachedProjectionViewportH = h
        }
        
        let uniforms = buffer.contents().assumingMemoryBound(to: SVGAUniforms.self)
        uniforms.pointee.projectionMatrix = cachedProjectionMatrix
        // viewMatrix 不再写入：shader 已不使用，buffer 创建时已初始化为 identity
        uniforms.pointee.viewportSize = SIMD2<Float>(w, h)
        uniforms.pointee.spriteCount = spriteCount
    }
    
    private func updateUVRegionsBuffer(from atlas: SVGATextureAtlas) throws {
        guard let buffer = uvRegionsBuffer else { return }
        
        let regions = buffer.contents().bindMemory(to: SVGAUVRegion.self, capacity: maxSprites)
        
        let allRegions = atlas.regions.allRegions
        for (index, region) in allRegions.enumerated() {
            guard index < maxSprites else { break }
            regions[index] = SVGAUVRegion(from: region)
        }
    }
    
}

// MARK: - SVGARendererStatistics

/// Renderer statistics
public struct SVGARendererStatistics {
    public var drawCallCount: Int = 0
    public var vertexCount: Int = 0
    public var triangleCount: Int = 0
    public var textureBindCount: Int = 0
    public var frameRenderTimeMs: Float = 0
    
    /// GPU frame time in milliseconds (from MTLCommandBuffer.GPUStartTime/GPUEndTime)
    public var gpuFrameTimeMs: Double = 0
    /// Rolling average GPU frame time (smoothed over recent frames)
    public var gpuFrameTimeAvgMs: Double = 0
    /// Peak GPU frame time observed
    public var gpuFrameTimePeakMs: Double = 0
    
    public init() {}
    
    /// Reset GPU timing stats
    public mutating func resetGPUTiming() {
        gpuFrameTimeMs = 0
        gpuFrameTimeAvgMs = 0
        gpuFrameTimePeakMs = 0
    }
}

// MARK: - MetalRenderer + Configuration

extension MetalRenderer {
    
    /// Configure renderer for animation
    public func configure(
        for animation: SVGAAnimation,
        contentMode: SVGAContentMode,
        viewSize: CGSize
    ) throws {
        try prepare(for: animation)
        
        // Calculate content transform based on content mode
        let contentTransform = contentMode.transformMatrix(
            contentSize: animation.videoSize,
            viewSize: viewSize
        )
        
        // Store for use in rendering
        self.viewportSize = viewSize
    }
}

// MARK: - MetalRenderer + Statistics

extension MetalRenderer {
    
    /// Get batch rendering statistics
    public var batchStatistics: (drawCalls: Int, sprites: Int, efficiency: Float) {
        (
            drawCalls: spriteBatcher.drawCallCount,
            sprites: spriteBatcher.spriteCount,
            efficiency: spriteBatcher.batchEfficiency
        )
    }
    
    // MARK: - GPU Timing
    
    /// Exponential moving average factor for GPU time smoothing
    private static let gpuTimeEMAFactor: Double = 0.1
    
    /// Update GPU timing statistics from a completed MTLCommandBuffer.
    /// Call this in `commandBuffer.addCompletedHandler`.
    public func updateGPUTiming(from commandBuffer: MTLCommandBuffer) {
        let gpuStart = commandBuffer.gpuStartTime
        let gpuEnd = commandBuffer.gpuEndTime
        guard gpuEnd > gpuStart else { return }
        
        let gpuTimeMs = (gpuEnd - gpuStart) * 1000.0
        _statistics.gpuFrameTimeMs = gpuTimeMs
        
        // Exponential moving average
        if _statistics.gpuFrameTimeAvgMs == 0 {
            _statistics.gpuFrameTimeAvgMs = gpuTimeMs
        } else {
            let alpha = MetalRenderer.gpuTimeEMAFactor
            _statistics.gpuFrameTimeAvgMs = alpha * gpuTimeMs + (1 - alpha) * _statistics.gpuFrameTimeAvgMs
        }
        
        // Peak tracking
        if gpuTimeMs > _statistics.gpuFrameTimePeakMs {
            _statistics.gpuFrameTimePeakMs = gpuTimeMs
        }
    }
    
    /// Reset GPU timing peak/average (call when starting a new test session)
    public func resetGPUTimingStats() {
        _statistics.resetGPUTiming()
    }
}
