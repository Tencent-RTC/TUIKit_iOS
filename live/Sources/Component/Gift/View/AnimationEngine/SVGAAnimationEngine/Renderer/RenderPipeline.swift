//
//  RenderPipeline.swift
//  TUILiveKit
//
//  Created on 2026/2/5.
//  High-Performance SVGA Player Core
//

import Foundation
import Metal
import MetalKit

// MARK: - SVGARenderPipeline

/// Manages Metal render pipeline states for SVGA rendering
public final class SVGARenderPipeline {
    
    // MARK: - Properties
    
    /// Metal device
    public let device: MTLDevice
    
    /// Shader library
    public private(set) var library: MTLLibrary?
    
    /// Main sprite rendering pipeline
    public private(set) var spritePipeline: MTLRenderPipelineState?
    
    /// Mask rendering pipeline (stencil only)
    public private(set) var maskPipeline: MTLRenderPipelineState?
    
    /// Shape rendering pipeline (solid colors)
    public private(set) var shapePipeline: MTLRenderPipelineState?
    
    /// Debug rendering pipeline
    public private(set) var debugPipeline: MTLRenderPipelineState?
    
    /// Depth stencil state for masked rendering
    public private(set) var maskedDepthStencilState: MTLDepthStencilState?
    
    /// Depth stencil state for mask writing
    public private(set) var maskWriteDepthStencilState: MTLDepthStencilState?
    
    /// Default depth stencil state (no depth/stencil test)
    public private(set) var defaultDepthStencilState: MTLDepthStencilState?
    
    /// Default sampler state
    public private(set) var defaultSampler: MTLSamplerState?
    
    /// Whether pipeline is ready
    public var isReady: Bool {
        spritePipeline != nil
    }
    
    // MARK: - Initialization
    
    public init(device: MTLDevice) {
        self.device = device
    }
    
    // MARK: - Setup
    
    /// Setup all render pipelines
    /// - Parameter pixelFormat: Target pixel format
    /// - Throws: Error if setup fails
    public func setup(pixelFormat: MTLPixelFormat = .bgra8Unorm) throws {
        // Load shader library
        try loadShaderLibrary()
        
        // Create pipelines
        try createSpritePipeline(pixelFormat: pixelFormat)
        try createMaskPipeline(pixelFormat: pixelFormat)
        try createShapePipeline(pixelFormat: pixelFormat)
        try createDebugPipeline(pixelFormat: pixelFormat)
        
        // Create depth stencil states
        try createDepthStencilStates()
        
        // Create sampler
        try createDefaultSampler()
    }
    
    // MARK: - Shader Library
    
    private func loadShaderLibrary() throws {
        // Method 1: Try to load from TUILiveKitBundle (CocoaPods resource bundle)
        if let bundlePath = Bundle(for: type(of: self)).path(forResource: "TUILiveKitBundle", ofType: "bundle"),
           let resourceBundle = Bundle(path: bundlePath),
           let libraryURL = resourceBundle.url(forResource: "default", withExtension: "metallib") {
            do {
                self.library = try device.makeLibrary(URL: libraryURL)
                print("[SVGARenderPipeline] Loaded shader library from TUILiveKitBundle")
                return
            } catch {
                print("[SVGARenderPipeline] Failed to load from TUILiveKitBundle: \(error)")
            }
        }
        
        // Method 2: Try default library from current bundle
        if let bundleLibrary = try? device.makeDefaultLibrary(bundle: Bundle(for: type(of: self))) {
            self.library = bundleLibrary
            print("[SVGARenderPipeline] Loaded shader library from class bundle")
            return
        }
        
        // Method 3: Try main bundle's default library
        if let defaultLibrary = device.makeDefaultLibrary() {
            self.library = defaultLibrary
            print("[SVGARenderPipeline] Loaded shader library from main bundle")
            return
        }
        
        // Method 4: Try to compile from source at runtime (fallback)
        if let shaderSource = loadShaderSource() {
            do {
                let compileOptions = MTLCompileOptions()
                compileOptions.fastMathEnabled = true
                self.library = try device.makeLibrary(source: shaderSource, options: compileOptions)
                print("[SVGARenderPipeline] Compiled shader library from source")
                return
            } catch {
                print("[SVGARenderPipeline] Shader compilation error: \(error)")
            }
        }
        
        throw NSError(domain: "SVGAEngine", code: 4004, userInfo: [NSLocalizedDescriptionKey: "Could not load Metal shader library"])
    }
    
    /// Load shader source from bundle
    private func loadShaderSource() -> String? {
        // Try TUILiveKitBundle first
        if let bundlePath = Bundle(for: type(of: self)).path(forResource: "TUILiveKitBundle", ofType: "bundle"),
           let resourceBundle = Bundle(path: bundlePath),
           let shaderURL = resourceBundle.url(forResource: "Shaders", withExtension: "metal") {
            return try? String(contentsOf: shaderURL, encoding: .utf8)
        }
        
        // Try current bundle
        if let shaderURL = Bundle(for: type(of: self)).url(forResource: "Shaders", withExtension: "metal") {
            return try? String(contentsOf: shaderURL, encoding: .utf8)
        }
        
        // Try main bundle
        if let shaderURL = Bundle.main.url(forResource: "Shaders", withExtension: "metal") {
            return try? String(contentsOf: shaderURL, encoding: .utf8)
        }
        
        return nil
    }
    
    // MARK: - Sprite Pipeline
    
    private func createSpritePipeline(pixelFormat: MTLPixelFormat) throws {
        guard let library = library else {
            throw NSError(domain: "SVGAEngine", code: 4004, userInfo: [NSLocalizedDescriptionKey: "Shader library not loaded"])
        }
        
        guard let vertexFunction = library.makeFunction(name: "svga_vertex"),
              let fragmentFunction = library.makeFunction(name: "svga_fragment") else {
            throw NSError(domain: "SVGAEngine", code: 4004, userInfo: [NSLocalizedDescriptionKey: "Could not find sprite shader functions"])
        }
        
        let descriptor = MTLRenderPipelineDescriptor()
        descriptor.label = "SVGA Sprite Pipeline"
        descriptor.vertexFunction = vertexFunction
        descriptor.fragmentFunction = fragmentFunction
        descriptor.vertexDescriptor = SVGAVertexDescriptor.create()
        
        // Color attachment with alpha blending
        let colorAttachment = descriptor.colorAttachments[0]!
        colorAttachment.pixelFormat = pixelFormat
        colorAttachment.isBlendingEnabled = true
        
        // Premultiplied alpha blending
        colorAttachment.sourceRGBBlendFactor = .one
        colorAttachment.destinationRGBBlendFactor = .oneMinusSourceAlpha
        colorAttachment.rgbBlendOperation = .add
        
        colorAttachment.sourceAlphaBlendFactor = .one
        colorAttachment.destinationAlphaBlendFactor = .oneMinusSourceAlpha
        colorAttachment.alphaBlendOperation = .add
        
        // Stencil for masking support
        descriptor.stencilAttachmentPixelFormat = .stencil8
        
        do {
            spritePipeline = try device.makeRenderPipelineState(descriptor: descriptor)
        } catch {
            throw NSError(domain: "SVGAEngine", code: 4003, userInfo: [NSLocalizedDescriptionKey: "Sprite pipeline: \(error.localizedDescription)"])
        }
    }
    
    // MARK: - Mask Pipeline
    
    private func createMaskPipeline(pixelFormat: MTLPixelFormat) throws {
        guard let library = library else {
            throw NSError(domain: "SVGAEngine", code: 4004, userInfo: [NSLocalizedDescriptionKey: "Shader library not loaded"])
        }
        
        guard let vertexFunction = library.makeFunction(name: "svga_mask_vertex"),
              let fragmentFunction = library.makeFunction(name: "svga_mask_fragment") else {
            throw NSError(domain: "SVGAEngine", code: 4004, userInfo: [NSLocalizedDescriptionKey: "Could not find mask shader functions"])
        }
        
        let descriptor = MTLRenderPipelineDescriptor()
        descriptor.label = "SVGA Mask Pipeline"
        descriptor.vertexFunction = vertexFunction
        descriptor.fragmentFunction = fragmentFunction
        descriptor.vertexDescriptor = SVGAVertexDescriptor.create()
        
        // No color write for mask pass
        let colorAttachment = descriptor.colorAttachments[0]!
        colorAttachment.pixelFormat = pixelFormat
        colorAttachment.writeMask = []  // Don't write color
        
        // Stencil write
        descriptor.stencilAttachmentPixelFormat = .stencil8
        
        do {
            maskPipeline = try device.makeRenderPipelineState(descriptor: descriptor)
        } catch {
            throw NSError(domain: "SVGAEngine", code: 4003, userInfo: [NSLocalizedDescriptionKey: "Mask pipeline: \(error.localizedDescription)"])
        }
    }
    
    // MARK: - Shape Pipeline
    
    private func createShapePipeline(pixelFormat: MTLPixelFormat) throws {
        guard let library = library else {
            throw NSError(domain: "SVGAEngine", code: 4004, userInfo: [NSLocalizedDescriptionKey: "Shader library not loaded"])
        }
        
        guard let vertexFunction = library.makeFunction(name: "svga_shape_vertex"),
              let fragmentFunction = library.makeFunction(name: "svga_shape_fragment") else {
            throw NSError(domain: "SVGAEngine", code: 4004, userInfo: [NSLocalizedDescriptionKey: "Could not find shape shader functions"])
        }
        
        let descriptor = MTLRenderPipelineDescriptor()
        descriptor.label = "SVGA Shape Pipeline"
        descriptor.vertexFunction = vertexFunction
        descriptor.fragmentFunction = fragmentFunction
        descriptor.vertexDescriptor = SVGAVertexDescriptor.create()
        
        // Color attachment with alpha blending
        let colorAttachment = descriptor.colorAttachments[0]!
        colorAttachment.pixelFormat = pixelFormat
        colorAttachment.isBlendingEnabled = true
        colorAttachment.sourceRGBBlendFactor = .one
        colorAttachment.destinationRGBBlendFactor = .oneMinusSourceAlpha
        colorAttachment.rgbBlendOperation = .add
        colorAttachment.sourceAlphaBlendFactor = .one
        colorAttachment.destinationAlphaBlendFactor = .oneMinusSourceAlpha
        colorAttachment.alphaBlendOperation = .add
        
        descriptor.stencilAttachmentPixelFormat = .stencil8
        
        do {
            shapePipeline = try device.makeRenderPipelineState(descriptor: descriptor)
        } catch {
            throw NSError(domain: "SVGAEngine", code: 4003, userInfo: [NSLocalizedDescriptionKey: "Shape pipeline: \(error.localizedDescription)"])
        }
    }
    
    // MARK: - Debug Pipeline
    
    private func createDebugPipeline(pixelFormat: MTLPixelFormat) throws {
        guard let library = library else {
            throw NSError(domain: "SVGAEngine", code: 4004, userInfo: [NSLocalizedDescriptionKey: "Shader library not loaded"])
        }
        
        guard let vertexFunction = library.makeFunction(name: "svga_debug_vertex"),
              let fragmentFunction = library.makeFunction(name: "svga_debug_fragment") else {
            // Debug pipeline is optional
            return
        }
        
        let descriptor = MTLRenderPipelineDescriptor()
        descriptor.label = "SVGA Debug Pipeline"
        descriptor.vertexFunction = vertexFunction
        descriptor.fragmentFunction = fragmentFunction
        descriptor.vertexDescriptor = SVGAVertexDescriptor.create()
        descriptor.colorAttachments[0].pixelFormat = pixelFormat
        
        do {
            debugPipeline = try device.makeRenderPipelineState(descriptor: descriptor)
        } catch {
            // Debug pipeline failure is non-fatal
            print("[SVGARenderPipeline] Debug pipeline creation failed: \(error)")
        }
    }
    
    // MARK: - Depth Stencil States
    
    private func createDepthStencilStates() throws {
        // Mask write state (increment stencil where mask is visible)
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
        
        guard let maskWriteState = device.makeDepthStencilState(descriptor: maskWriteDescriptor) else {
            throw NSError(domain: "SVGAEngine", code: 4003, userInfo: [NSLocalizedDescriptionKey: "Could not create mask write depth stencil state"])
        }
        self.maskWriteDepthStencilState = maskWriteState
        
        // Masked render state (only draw where stencil matches)
        let maskedDescriptor = MTLDepthStencilDescriptor()
        maskedDescriptor.label = "SVGA Masked Render"
        maskedDescriptor.isDepthWriteEnabled = false
        
        let maskedStencil = MTLStencilDescriptor()
        maskedStencil.stencilCompareFunction = .equal
        maskedStencil.stencilFailureOperation = .keep
        maskedStencil.depthFailureOperation = .keep
        maskedStencil.depthStencilPassOperation = .keep
        maskedStencil.readMask = 0xFF
        maskedStencil.writeMask = 0x00
        
        maskedDescriptor.frontFaceStencil = maskedStencil
        maskedDescriptor.backFaceStencil = maskedStencil
        
        guard let maskedState = device.makeDepthStencilState(descriptor: maskedDescriptor) else {
            throw NSError(domain: "SVGAEngine", code: 4003, userInfo: [NSLocalizedDescriptionKey: "Could not create masked depth stencil state"])
        }
        self.maskedDepthStencilState = maskedState
        
        // Default state (no depth/stencil test - for unmasked rendering)
        let defaultDescriptor = MTLDepthStencilDescriptor()
        defaultDescriptor.label = "SVGA Default (No Test)"
        defaultDescriptor.isDepthWriteEnabled = false
        // No stencil operations - leave everything at defaults (disabled)
        
        guard let defaultState = device.makeDepthStencilState(descriptor: defaultDescriptor) else {
            throw NSError(domain: "SVGAEngine", code: 4003, userInfo: [NSLocalizedDescriptionKey: "Could not create default depth stencil state"])
        }
        self.defaultDepthStencilState = defaultState
    }
    
    // MARK: - Sampler
    
    private func createDefaultSampler() throws {
        let descriptor = MTLSamplerDescriptor()
        descriptor.label = "SVGA Default Sampler"
        descriptor.minFilter = .linear
        descriptor.magFilter = .linear
        descriptor.mipFilter = .notMipmapped
        descriptor.sAddressMode = .clampToEdge
        descriptor.tAddressMode = .clampToEdge
        descriptor.rAddressMode = .clampToEdge
        descriptor.normalizedCoordinates = true
        
        guard let sampler = device.makeSamplerState(descriptor: descriptor) else {
            throw NSError(domain: "SVGAEngine", code: 4003, userInfo: [NSLocalizedDescriptionKey: "Could not create sampler state"])
        }
        self.defaultSampler = sampler
    }
    
    // MARK: - Cleanup
    
    /// Release all pipeline resources
    public func release() {
        spritePipeline = nil
        maskPipeline = nil
        shapePipeline = nil
        debugPipeline = nil
        maskedDepthStencilState = nil
        maskWriteDepthStencilState = nil
        defaultDepthStencilState = nil
        defaultSampler = nil
        library = nil
    }
}

// MARK: - Pipeline Configuration

/// Configuration for render pipeline creation
public struct SVGARenderPipelineConfig {
    
    /// Target pixel format
    public var pixelFormat: MTLPixelFormat = .bgra8Unorm
    
    /// Enable MSAA (sample count)
    public var sampleCount: Int = 1
    
    /// Enable stencil buffer
    public var enableStencil: Bool = true
    
    public init() {}
}
