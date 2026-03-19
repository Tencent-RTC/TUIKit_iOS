//
//  VertexDescriptor.swift
//  TUILiveKit
//
//  Created on 2026/2/5.
//  High-Performance SVGA Player Core
//

import Foundation
import Metal
import simd

// MARK: - Vertex Structures

/// Per-vertex data (quad corners)
public struct SVGAVertex {
    /// Position in local space (0-1 normalized quad)
    public var position: SIMD2<Float>
    
    /// Texture coordinate (0-1 normalized)
    public var texCoord: SIMD2<Float>
    
    public init(position: SIMD2<Float>, texCoord: SIMD2<Float>) {
        self.position = position
        self.texCoord = texCoord
    }
}

/// Packed float3 (12 bytes, NO padding)
/// Swift 的 SIMD3<Float> 实际 size=16, stride=16, alignment=16
/// 但 Metal vertex attribute 的 float3 只有 12 bytes。
/// 必须用 3 个独立 Float 手动 pack，才能与 Metal 对齐。
public struct PackedFloat3 {
    public var x: Float
    public var y: Float
    public var z: Float
    
    @inline(__always)
    public init(_ x: Float, _ y: Float, _ z: Float) {
        self.x = x; self.y = y; self.z = z
    }
    
    @inline(__always)
    public init(_ v: SIMD3<Float>) {
        self.x = v.x; self.y = v.y; self.z = v.z
    }
    
    @inline(__always)
    public var simd: SIMD3<Float> {
        SIMD3<Float>(x, y, z)
    }
}

/// Per-instance data (one per sprite)
/// Must match InstanceIn in Shaders.metal EXACTLY
///
/// 【关键修复 v5】使用 PackedFloat3 而非 SIMD3<Float>！
/// Swift 的 SIMD3<Float> 有 16-byte alignment，会插入 4 字节 padding，
/// 导致整个 struct stride = 64 字节，但 Metal 期望 48 字节。
/// 之前 GPU 读取的每个 instance 数据全部错位 → 闪烁/画面异常。
///
/// 正确的内存布局（48 bytes）：
///   offset 0:  transformCol0 (3 * Float = 12 bytes)
///   offset 12: transformCol1 (3 * Float = 12 bytes)
///   offset 24: transformCol2 (3 * Float = 12 bytes)
///   offset 36: alpha (Float = 4 bytes)
///   offset 40: textureIndex (UInt16 = 2 bytes)
///   offset 42: maskIndex (UInt16 = 2 bytes)
///   offset 44: _padding (UInt32 = 4 bytes)
///   Total: 48 bytes
public struct SVGAInstance {
    public var transformCol0: PackedFloat3  // 12 bytes at offset 0
    public var transformCol1: PackedFloat3  // 12 bytes at offset 12
    public var transformCol2: PackedFloat3  // 12 bytes at offset 24
    
    /// Opacity [0, 1]
    public var alpha: Float                 // 4 bytes at offset 36
    
    /// Texture region index in atlas
    public var textureIndex: UInt16         // 2 bytes at offset 40
    
    /// Mask sprite index (0 = no mask)
    public var maskIndex: UInt16            // 2 bytes at offset 42
    
    /// Padding to 48 bytes
    private var _padding: UInt32 = 0        // 4 bytes at offset 44
    
    public init(
        transform: simd_float3x3 = matrix_identity_float3x3,
        alpha: Float = 1.0,
        textureIndex: UInt16 = 0,
        maskIndex: UInt16 = 0
    ) {
        self.transformCol0 = PackedFloat3(transform.columns.0)
        self.transformCol1 = PackedFloat3(transform.columns.1)
        self.transformCol2 = PackedFloat3(transform.columns.2)
        self.alpha = alpha
        self.textureIndex = textureIndex
        self.maskIndex = maskIndex
    }
    
    /// Get transform as simd_float3x3
    public var transform: simd_float3x3 {
        get {
            simd_float3x3(transformCol0.simd, transformCol1.simd, transformCol2.simd)
        }
        set {
            transformCol0 = PackedFloat3(newValue.columns.0)
            transformCol1 = PackedFloat3(newValue.columns.1)
            transformCol2 = PackedFloat3(newValue.columns.2)
        }
    }
}

// Verify sizes at compile time
#if DEBUG
private let _vertexSizeCheck: Void = {
    assert(MemoryLayout<SVGAVertex>.stride == 16, "SVGAVertex must be 16 bytes")
}()

private let _packedFloat3SizeCheck: Void = {
    assert(MemoryLayout<PackedFloat3>.size == 12, "PackedFloat3 must be 12 bytes, got \(MemoryLayout<PackedFloat3>.size)")
    assert(MemoryLayout<PackedFloat3>.stride == 12, "PackedFloat3 stride must be 12 bytes, got \(MemoryLayout<PackedFloat3>.stride)")
}()

private let _instanceSizeCheck: Void = {
    assert(MemoryLayout<SVGAInstance>.size == 48, "SVGAInstance must be 48 bytes, got \(MemoryLayout<SVGAInstance>.size)")
    assert(MemoryLayout<SVGAInstance>.stride == 48, "SVGAInstance stride must be 48 bytes, got \(MemoryLayout<SVGAInstance>.stride)")
}()
#endif

// MARK: - Uniform Structures

/// Per-frame uniforms
/// Must match Uniforms in Shaders.metal
public struct SVGAUniforms {
    /// Orthographic projection matrix
    public var projectionMatrix: simd_float4x4
    
    /// View transform matrix
    public var viewMatrix: simd_float4x4
    
    /// Viewport size in points
    public var viewportSize: SIMD2<Float>
    
    /// Animation time (for effects)
    public var time: Float
    
    /// Number of sprites to render
    public var spriteCount: UInt32
    
    public init(
        projectionMatrix: simd_float4x4 = matrix_identity_float4x4,
        viewMatrix: simd_float4x4 = matrix_identity_float4x4,
        viewportSize: SIMD2<Float> = .zero,
        time: Float = 0,
        spriteCount: UInt32 = 0
    ) {
        self.projectionMatrix = projectionMatrix
        self.viewMatrix = viewMatrix
        self.viewportSize = viewportSize
        self.time = time
        self.spriteCount = spriteCount
    }
    
    /// Create orthographic projection for 2D rendering
    public static func orthographic(
        width: Float,
        height: Float,
        near: Float = -1,
        far: Float = 1
    ) -> simd_float4x4 {
        let left: Float = 0
        let right = width
        let bottom = height
        let top: Float = 0
        
        let sx = 2 / (right - left)
        let sy = 2 / (top - bottom)
        let sz = 1 / (far - near)
        let tx = -(right + left) / (right - left)
        let ty = -(top + bottom) / (top - bottom)
        let tz = -near / (far - near)
        
        return simd_float4x4(
            SIMD4<Float>(sx, 0, 0, 0),
            SIMD4<Float>(0, sy, 0, 0),
            SIMD4<Float>(0, 0, sz, 0),
            SIMD4<Float>(tx, ty, tz, 1)
        )
    }
}

/// UV region for texture atlas lookup
/// Must match UVRegion in Shaders.metal EXACTLY (32 bytes)
///
/// Metal shader 定义：
///   struct UVRegion {
///       float2 offset;     // 8 bytes
///       float2 size;       // 8 bytes
///       uint rotated;      // 4 bytes
///       uint _padding[3];  // 12 bytes
///   };  // Total: 32 bytes
///
/// 【关键修复 v5】之前 padding 用的 SIMD3<UInt32>（alignment=16，导致 stride=48），
/// 与 Metal 的 32 字节不匹配，UV region 查找全部错位。
/// 现在改用 3 个独立 UInt32 保持 4-byte alignment。
public struct SVGAUVRegion {
    /// UV offset (top-left corner)
    public var offset: SIMD2<Float>     // 8 bytes at offset 0
    
    /// UV size (width, height)
    public var size: SIMD2<Float>       // 8 bytes at offset 8
    
    /// 1 if rotated 90°, 0 otherwise
    public var rotated: UInt32          // 4 bytes at offset 16
    
    /// Padding for 32-byte alignment (use individual UInt32, NOT SIMD3!)
    private var _pad0: UInt32 = 0       // 4 bytes at offset 20
    private var _pad1: UInt32 = 0       // 4 bytes at offset 24
    private var _pad2: UInt32 = 0       // 4 bytes at offset 28
    // Total: 32 bytes ✅
    
    public init(
        offset: SIMD2<Float> = .zero,
        size: SIMD2<Float> = SIMD2<Float>(1, 1),
        rotated: Bool = false
    ) {
        self.offset = offset
        self.size = size
        self.rotated = rotated ? 1 : 0
    }
    
    /// Create from UVRegion model
    public init(from region: UVRegion) {
        self.offset = SIMD2<Float>(region.u, region.v)
        self.size = SIMD2<Float>(region.width, region.height)
        self.rotated = region.rotated ? 1 : 0
    }
}

#if DEBUG
private let _uvRegionSizeCheck: Void = {
    assert(MemoryLayout<SVGAUVRegion>.size == 32, "SVGAUVRegion must be 32 bytes, got \(MemoryLayout<SVGAUVRegion>.size)")
    assert(MemoryLayout<SVGAUVRegion>.stride == 32, "SVGAUVRegion stride must be 32 bytes, got \(MemoryLayout<SVGAUVRegion>.stride)")
}()
#endif

// MARK: - Vertex Descriptor

/// Creates Metal vertex descriptor for SVGA rendering
public struct SVGAVertexDescriptor {
    
    /// Vertex buffer index (for position/texCoord via [[stage_in]])
    public static let vertexBufferIndex = 0
    
    /// Instance buffer index (for per-instance data via [[stage_in]])
    public static let instanceBufferIndex = 1
    
    /// UV regions buffer index (accessed via [[buffer(2)]] in shader)
    public static let uvRegionsBufferIndex = 2
    
    /// Uniform buffer index (accessed via [[buffer(3)]] in shader)
    public static let uniformBufferIndex = 3
    
    /// Create vertex descriptor for main shader
    public static func create() -> MTLVertexDescriptor {
        let descriptor = MTLVertexDescriptor()
        
        // MARK: Per-Vertex Attributes
        
        // Position (float2 at offset 0)
        descriptor.attributes[0].format = .float2
        descriptor.attributes[0].offset = 0
        descriptor.attributes[0].bufferIndex = vertexBufferIndex
        
        // TexCoord (float2 at offset 8)
        descriptor.attributes[1].format = .float2
        descriptor.attributes[1].offset = MemoryLayout<SIMD2<Float>>.stride
        descriptor.attributes[1].bufferIndex = vertexBufferIndex
        
        // Vertex buffer layout
        descriptor.layouts[vertexBufferIndex].stride = MemoryLayout<SVGAVertex>.stride
        descriptor.layouts[vertexBufferIndex].stepFunction = .perVertex
        descriptor.layouts[vertexBufferIndex].stepRate = 1
        
        // MARK: Per-Instance Attributes
        
        // Transform column 0 (float3 at offset 0)
        descriptor.attributes[2].format = .float3
        descriptor.attributes[2].offset = 0
        descriptor.attributes[2].bufferIndex = instanceBufferIndex
        
        // Transform column 1 (float3 at offset 12)
        descriptor.attributes[3].format = .float3
        descriptor.attributes[3].offset = 12
        descriptor.attributes[3].bufferIndex = instanceBufferIndex
        
        // Transform column 2 (float3 at offset 24)
        descriptor.attributes[4].format = .float3
        descriptor.attributes[4].offset = 24
        descriptor.attributes[4].bufferIndex = instanceBufferIndex
        
        // Alpha (float at offset 36)
        descriptor.attributes[5].format = .float
        descriptor.attributes[5].offset = 36
        descriptor.attributes[5].bufferIndex = instanceBufferIndex
        
        // TextureIndex (ushort at offset 40)
        descriptor.attributes[6].format = .ushort
        descriptor.attributes[6].offset = 40
        descriptor.attributes[6].bufferIndex = instanceBufferIndex
        
        // MaskIndex (ushort at offset 42)
        descriptor.attributes[7].format = .ushort
        descriptor.attributes[7].offset = 42
        descriptor.attributes[7].bufferIndex = instanceBufferIndex
        
        // Instance buffer layout
        descriptor.layouts[instanceBufferIndex].stride = MemoryLayout<SVGAInstance>.stride
        descriptor.layouts[instanceBufferIndex].stepFunction = .perInstance
        descriptor.layouts[instanceBufferIndex].stepRate = 1
        
        return descriptor
    }
}

// MARK: - Quad Mesh

/// Pre-defined quad vertices for sprite rendering
public struct SVGAQuadMesh {
    
    /// Vertices for a unit quad (0,0) to (1,1)
    /// Counter-clockwise winding
    public static let vertices: [SVGAVertex] = [
        // Top-left
        SVGAVertex(position: SIMD2<Float>(0, 0), texCoord: SIMD2<Float>(0, 0)),
        // Bottom-left
        SVGAVertex(position: SIMD2<Float>(0, 1), texCoord: SIMD2<Float>(0, 1)),
        // Bottom-right
        SVGAVertex(position: SIMD2<Float>(1, 1), texCoord: SIMD2<Float>(1, 1)),
        // Top-right
        SVGAVertex(position: SIMD2<Float>(1, 0), texCoord: SIMD2<Float>(1, 0))
    ]
    
    /// Indices for two triangles forming a quad
    public static let indices: [UInt16] = [
        0, 1, 2,  // First triangle (TL, BL, BR)
        0, 2, 3   // Second triangle (TL, BR, TR)
    ]
    
    /// Number of vertices
    public static let vertexCount = 4
    
    /// Number of indices
    public static let indexCount = 6
    
    /// Vertex buffer size in bytes
    public static var vertexBufferSize: Int {
        MemoryLayout<SVGAVertex>.stride * vertexCount
    }
    
    /// Index buffer size in bytes
    public static var indexBufferSize: Int {
        MemoryLayout<UInt16>.stride * indexCount
    }
}

// MARK: - Buffer Helpers

extension SVGAVertexDescriptor {
    
    /// Create vertex buffer from quad mesh
    public static func createVertexBuffer(device: MTLDevice) -> MTLBuffer? {
        device.makeBuffer(
            bytes: SVGAQuadMesh.vertices,
            length: SVGAQuadMesh.vertexBufferSize,
            options: .storageModeShared
        )
    }
    
    /// Create index buffer from quad mesh
    public static func createIndexBuffer(device: MTLDevice) -> MTLBuffer? {
        device.makeBuffer(
            bytes: SVGAQuadMesh.indices,
            length: SVGAQuadMesh.indexBufferSize,
            options: .storageModeShared
        )
    }
    
    /// Create instance buffer for given capacity
    public static func createInstanceBuffer(
        device: MTLDevice,
        capacity: Int
    ) -> MTLBuffer? {
        let size = MemoryLayout<SVGAInstance>.stride * capacity
        return device.makeBuffer(length: size, options: .storageModeShared)
    }
    
    /// Create uniform buffer
    public static func createUniformBuffer(device: MTLDevice) -> MTLBuffer? {
        let size = MemoryLayout<SVGAUniforms>.stride
        return device.makeBuffer(length: size, options: .storageModeShared)
    }
    
    /// Create UV regions buffer for given capacity
    public static func createUVRegionsBuffer(
        device: MTLDevice,
        capacity: Int
    ) -> MTLBuffer? {
        let size = MemoryLayout<SVGAUVRegion>.stride * capacity
        return device.makeBuffer(length: size, options: .storageModeShared)
    }
}
