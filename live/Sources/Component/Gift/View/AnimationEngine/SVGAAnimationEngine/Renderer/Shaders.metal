//
//  Shaders.metal
//  TUILiveKit
//
//  Created on 2026/2/5.
//  High-Performance SVGA Player Core
//
//  Metal shaders for SVGA animation rendering
//  Features:
//  - Instanced rendering for multiple sprites (batch rendering)
//  - Texture atlas sampling
//  - Alpha blending with multiple modes
//  - Stencil and shader-based masking
//  - Zero off-screen rendering
//

#include <metal_stdlib>
using namespace metal;

// MARK: - Constants

constant float ALPHA_THRESHOLD = 0.01;

// Blend mode constants
constant uint BLEND_MODE_NORMAL = 0;
constant uint BLEND_MODE_ADDITIVE = 1;
constant uint BLEND_MODE_MULTIPLY = 2;
constant uint BLEND_MODE_SCREEN = 3;

// MARK: - Vertex Structures

/// Per-vertex input data (shared quad mesh)
struct VertexIn {
    float2 position [[attribute(0)]];   // Quad corner position (0-1)
    float2 texCoord [[attribute(1)]];   // Base texture coordinate (0-1)
};

/// Per-instance input data (one per sprite in batch)
/// Note: float3x3 cannot be used directly as attribute, use separate float3 columns
/// MUST match SVGAInstance in Swift (48 bytes total)
///
/// 【关键修复 v6】使用 packed_float3 而非 float3！
/// Metal 中 float3 在 struct 里的 size=16, alignment=16（和 float4 一样），
/// 导致 InstanceIn 实际 size=64 字节。
/// 而 Swift 端 PackedFloat3（3个Float）stride=12，SVGAInstance stride=48。
/// 必须使用 packed_float3（size=12, alignment=4）才能与 Swift 对齐。
struct InstanceIn {
    packed_float3 transformCol0;    // Transform matrix column 0 (12 bytes, offset 0)
    packed_float3 transformCol1;    // Transform matrix column 1 (12 bytes, offset 12)
    packed_float3 transformCol2;    // Transform matrix column 2 (12 bytes, offset 24)
    float alpha;                    // Opacity [0-1] (4 bytes, offset 36)
    ushort textureIndex;            // Texture region index in atlas (2 bytes, offset 40)
    ushort maskIndex;               // Mask index (0 = no mask) (2 bytes, offset 42)
    uint _padding;                  // Padding to match Swift's 48-byte stride (4 bytes, offset 44)
    
    // Inline transform * localPos without constructing float3x3
    // (avoids 3 packed_float3 → float3 copies + matrix build)
    float3 transformPoint(float2 pos) const {
        float3 c0 = float3(transformCol0);
        float3 c1 = float3(transformCol1);
        float3 c2 = float3(transformCol2);
        return c0 * pos.x + c1 * pos.y + c2;
    }
};

/// Extended instance data for batched rendering
struct BatchInstanceIn {
    float3x3 transform;           // Transformation matrix
    float alpha;                  // Opacity
    ushort textureIndex;          // Texture region index
    ushort maskIndex;             // Mask index (0 = no mask)
    ushort blendMode;             // Blend mode
    ushort flags;                 // Bit flags (hasMask, invertMask, etc.)
    float4 color;                 // Tint color (for color modulation)
};

/// Vertex output / Fragment input
struct VertexOut {
    float4 position [[position]];      // Clip-space position
    float2 texCoord;                   // Texture coordinate in atlas
    float alpha;                       // Interpolated alpha
    uint textureIndex;                 // Texture region index
    uint maskIndex;                    // Mask index
};

/// Extended vertex output for masked rendering
struct MaskedVertexOut {
    float4 position [[position]];      // Clip-space position
    float2 texCoord;                   // Content texture coordinate
    float2 maskTexCoord;               // Mask texture coordinate
    float alpha;                       // Content alpha
    uint textureIndex;                 // Content texture index
    uint maskIndex;                    // Mask texture index
    uint blendMode;                    // Blend mode
};

// MARK: - Uniforms

/// Per-frame uniform data
/// NOTE: viewMatrix is always identity in SVGA playback.
/// Shader code uses projectionMatrix directly (skipping viewMatrix multiply).
/// viewMatrix field is kept for ABI compatibility but unused by GPU.
struct Uniforms {
    float4x4 projectionMatrix;         // Orthographic projection
    float4x4 viewMatrix;               // UNUSED by shaders (always identity, kept for layout compat)
    float2 viewportSize;               // Viewport dimensions in points
    float time;                        // Animation time (for effects)
    uint spriteCount;                  // Total sprites this frame
};

/// Batch render uniforms
struct BatchUniforms {
    float4x4 projectionMatrix;         // Projection matrix
    float4x4 viewMatrix;               // View matrix
    float2 viewportSize;               // Viewport size
    float time;                        // Time
    uint batchOffset;                  // Offset into instance buffer
    uint batchCount;                   // Number of instances in batch
    float alphaThreshold;              // Alpha test threshold
    uint flags;                        // Global render flags
};

/// Mask uniforms for shader-based masking
struct MaskUniforms {
    float2 maskUVOffset;               // Mask UV offset
    float2 maskUVScale;                // Mask UV scale
    float alphaThreshold;              // Alpha threshold for mask
    uint invertMask;                   // 1 = invert mask
    float2 _padding;                   // Alignment padding
};

/// UV region data for texture atlas
struct UVRegion {
    float2 offset;     // UV offset (top-left corner)
    float2 size;       // UV size (width, height) normalized
    uint rotated;      // 1 if rotated 90° CW for packing
    uint _padding[3];  // Padding for 32-byte alignment
};

// MARK: - Batch Vertex Shader

/// Main vertex shader for batched SVGA sprite rendering
/// Processes entire batches with single draw call
/// Buffer indices:
///   0 - Vertex buffer (position, texCoord) via [[stage_in]]
///   1 - Instance buffer (transform, alpha, textureIndex) - accessed directly
///   2 - UV regions buffer
///   3 - Uniforms buffer
vertex VertexOut svga_vertex(
    VertexIn vertexIn [[stage_in]],
    uint instanceID [[instance_id]],
    constant Uniforms& uniforms [[buffer(3)]],
    device const InstanceIn* instances [[buffer(1)]],
    device const UVRegion* uvRegions [[buffer(2)]]
) {
    VertexOut out;
    
    // Get instance data for this sprite in batch
    InstanceIn instance = instances[instanceID];
    
    // Transform position using instance's 3x3 matrix (inline, no matrix construction)
    float3 transformedPos = instance.transformPoint(vertexIn.position);
    
    // Apply projection (viewMatrix omitted — always identity for SVGA)
    out.position = uniforms.projectionMatrix * float4(transformedPos.xy, 0.0, 1.0);
    
    // Calculate texture coordinates from atlas
    uint texIndex = instance.textureIndex;
    UVRegion region = uvRegions[texIndex];
    
    float2 texCoord = vertexIn.texCoord;
    
    // Handle rotated regions branchlessly using select()
    // Avoids GPU warp divergence when some sprites are rotated and others aren't
    float2 rotatedTC = float2(texCoord.y, 1.0 - texCoord.x);
    texCoord = select(texCoord, rotatedTC, bool2(region.rotated != 0));
    
    // Map to atlas region
    out.texCoord = region.offset + texCoord * region.size;
    
    // Pass through other data
    out.alpha = instance.alpha;
    out.textureIndex = texIndex;
    out.maskIndex = instance.maskIndex;
    
    return out;
}

/// Vertex shader with batch offset support
vertex VertexOut svga_batch_vertex(
    VertexIn vertexIn [[stage_in]],
    uint instanceID [[instance_id]],
    constant BatchUniforms& uniforms [[buffer(3)]],
    device const InstanceIn* instances [[buffer(1)]],
    device const UVRegion* uvRegions [[buffer(2)]]
) {
    VertexOut out;
    
    // Apply batch offset to instance ID
    uint globalInstanceID = uniforms.batchOffset + instanceID;
    InstanceIn instance = instances[globalInstanceID];
    
    // Transform (inline, no matrix construction)
    float3 transformedPos = instance.transformPoint(vertexIn.position);
    
    out.position = uniforms.projectionMatrix * float4(transformedPos.xy, 0.0, 1.0);
    
    // UV mapping (branchless rotation)
    uint texIndex = instance.textureIndex;
    UVRegion region = uvRegions[texIndex];
    float2 texCoord = vertexIn.texCoord;
    
    float2 rotatedTC = float2(texCoord.y, 1.0 - texCoord.x);
    texCoord = select(texCoord, rotatedTC, bool2(region.rotated != 0));
    
    out.texCoord = region.offset + texCoord * region.size;
    out.alpha = instance.alpha;
    out.textureIndex = texIndex;
    out.maskIndex = instance.maskIndex;
    
    return out;
}

// MARK: - Fragment Shaders

/// Main fragment shader for batched SVGA sprite rendering
/// Samples from texture atlas and applies premultiplied alpha
/// 【重要】纹理已经是 premultiplied alpha，不需要再次 premultiply
/// 【优化】移除 discard_fragment — premultiplied alpha blend (src=ONE, dst=1-srcA)
/// 对全透明像素自动产生 0 贡献，无需 discard 导致 GPU warp 分支
fragment float4 svga_fragment(
    VertexOut in [[stage_in]],
    texture2d<float> atlasTexture [[texture(0)]],
    sampler atlasSampler [[sampler(0)]]
) {
    // Sample texture atlas (已经是 premultiplied alpha)
    float4 color = atlasTexture.sample(atlasSampler, in.texCoord);
    
    // Apply instance alpha (premultiplied: 直接乘即可)
    color *= in.alpha;
    
    return color;
}

/// Fragment shader with alpha test (for masks and cutouts)
/// 【重要】纹理已经是 premultiplied alpha
/// 保留 discard 因为此 shader 用于需要精确 alpha 裁剪的场景
fragment float4 svga_fragment_alpha_test(
    VertexOut in [[stage_in]],
    texture2d<float> atlasTexture [[texture(0)]],
    sampler atlasSampler [[sampler(0)]],
    constant float& alphaThreshold [[buffer(0)]]
) {
    float4 color = atlasTexture.sample(atlasSampler, in.texCoord);
    
    if (color.a < alphaThreshold) {
        discard_fragment();
    }
    
    color *= in.alpha;
    
    return color;
}

// MARK: - Stencil Mask Shaders

/// Vertex shader for stencil mask writing (no color output)
vertex VertexOut svga_mask_vertex(
    VertexIn vertexIn [[stage_in]],
    uint instanceID [[instance_id]],
    constant Uniforms& uniforms [[buffer(3)]],
    device const InstanceIn* instances [[buffer(1)]],
    device const UVRegion* uvRegions [[buffer(2)]]
) {
    VertexOut out;
    
    InstanceIn instance = instances[instanceID];
    
    float3 transformedPos = instance.transformPoint(vertexIn.position);
    
    out.position = uniforms.projectionMatrix * float4(transformedPos.xy, 0.0, 1.0);
    
    // Get UV for mask texture (branchless rotation)
    uint texIndex = instance.textureIndex;
    UVRegion region = uvRegions[texIndex];
    float2 texCoord = vertexIn.texCoord;
    
    float2 rotatedTC = float2(texCoord.y, 1.0 - texCoord.x);
    texCoord = select(texCoord, rotatedTC, bool2(region.rotated != 0));
    
    out.texCoord = region.offset + texCoord * region.size;
    out.alpha = instance.alpha;
    out.textureIndex = texIndex;
    out.maskIndex = 0;
    
    return out;
}

/// Fragment shader for stencil mask - discards transparent pixels
/// Writes to stencil buffer only (color write disabled in pipeline)
fragment float4 svga_mask_fragment(
    VertexOut in [[stage_in]],
    texture2d<float> maskTexture [[texture(0)]],
    sampler maskSampler [[sampler(0)]]
) {
    // Sample mask texture alpha
    float4 mask = maskTexture.sample(maskSampler, in.texCoord);
    
    // Discard fully transparent pixels (don't write to stencil)
    if (mask.a < ALPHA_THRESHOLD) {
        discard_fragment();
    }
    
    // Return value doesn't matter - color write is disabled
    return float4(0.0);
}

/// Fragment shader for stencil mask with custom threshold
fragment float4 svga_mask_fragment_threshold(
    VertexOut in [[stage_in]],
    texture2d<float> maskTexture [[texture(0)]],
    sampler maskSampler [[sampler(0)]],
    constant MaskUniforms& maskUniforms [[buffer(0)]]
) {
    float4 mask = maskTexture.sample(maskSampler, in.texCoord);
    
    float alpha = mask.a;
    
    // Optional invert
    if (maskUniforms.invertMask != 0) {
        alpha = 1.0 - alpha;
    }
    
    if (alpha < maskUniforms.alphaThreshold) {
        discard_fragment();
    }
    
    return float4(0.0);
}

// MARK: - Shader-Based Masking (Alternative to Stencil)

/// Vertex shader for shader-based masked rendering
vertex MaskedVertexOut svga_shader_mask_vertex(
    VertexIn vertexIn [[stage_in]],
    uint instanceID [[instance_id]],
    constant Uniforms& uniforms [[buffer(3)]],
    device const InstanceIn* instances [[buffer(1)]],
    device const UVRegion* uvRegions [[buffer(2)]],
    constant MaskUniforms& maskUniforms [[buffer(4)]]
) {
    MaskedVertexOut out;
    
    InstanceIn instance = instances[instanceID];
    
    // Transform position (inline)
    float3 transformedPos = instance.transformPoint(vertexIn.position);
    
    out.position = uniforms.projectionMatrix * float4(transformedPos.xy, 0.0, 1.0);
    
    // Content UV (branchless rotation)
    uint texIndex = instance.textureIndex;
    UVRegion region = uvRegions[texIndex];
    float2 texCoord = vertexIn.texCoord;
    
    float2 rotatedTC = float2(texCoord.y, 1.0 - texCoord.x);
    texCoord = select(texCoord, rotatedTC, bool2(region.rotated != 0));
    
    out.texCoord = region.offset + texCoord * region.size;
    
    // Mask UV (can be different from content UV)
    out.maskTexCoord = maskUniforms.maskUVOffset + vertexIn.texCoord * maskUniforms.maskUVScale;
    
    out.alpha = instance.alpha;
    out.textureIndex = texIndex;
    out.maskIndex = instance.maskIndex;
    out.blendMode = BLEND_MODE_NORMAL;
    
    return out;
}

/// Fragment shader for shader-based masked rendering
/// Samples both content and mask textures
fragment float4 svga_shader_mask_fragment(
    MaskedVertexOut in [[stage_in]],
    texture2d<float> contentTexture [[texture(0)]],
    texture2d<float> maskTexture [[texture(1)]],
    sampler contentSampler [[sampler(0)]],
    sampler maskSampler [[sampler(1)]],
    constant MaskUniforms& maskUniforms [[buffer(0)]]
) {
    // Sample mask
    float4 mask = maskTexture.sample(maskSampler, in.maskTexCoord);
    float maskAlpha = mask.a;
    
    // Optional invert
    if (maskUniforms.invertMask != 0) {
        maskAlpha = 1.0 - maskAlpha;
    }
    
    // Early discard if mask is transparent
    if (maskAlpha < maskUniforms.alphaThreshold) {
        discard_fragment();
    }
    
    // Sample content
    float4 color = contentTexture.sample(contentSampler, in.texCoord);
    
    // Apply mask alpha
    color.a *= maskAlpha * in.alpha;
    
    // Premultiply
    color.rgb *= color.a;
    
    return color;
}

// MARK: - Blend Mode Shaders

/// Fragment shader with blend mode support
fragment float4 svga_blend_fragment(
    MaskedVertexOut in [[stage_in]],
    texture2d<float> atlasTexture [[texture(0)]],
    sampler atlasSampler [[sampler(0)]]
) {
    float4 srcColor = atlasTexture.sample(atlasSampler, in.texCoord);
    
    if (srcColor.a < ALPHA_THRESHOLD) {
        discard_fragment();
    }
    
    srcColor.a *= in.alpha;
    
    // Apply blend mode (requires framebuffer fetch or multi-pass)
    // For single-pass, we output the source color
    // Blend mode is handled by pipeline blend state
    srcColor.rgb *= srcColor.a;
    
    return srcColor;
}

// MARK: - Vector Shape Shaders

/// Vertex shader for vector shapes (solid color fills)
vertex VertexOut svga_shape_vertex(
    VertexIn vertexIn [[stage_in]],
    uint instanceID [[instance_id]],
    constant Uniforms& uniforms [[buffer(3)]],
    device const InstanceIn* instances [[buffer(1)]],
    device const UVRegion* uvRegions [[buffer(2)]]
) {
    VertexOut out;
    
    InstanceIn instance = instances[instanceID];
    
    float3 transformedPos = instance.transformPoint(vertexIn.position);
    
    out.position = uniforms.projectionMatrix * float4(transformedPos.xy, 0.0, 1.0);
    
    out.texCoord = vertexIn.texCoord;
    out.alpha = instance.alpha;
    out.textureIndex = instance.textureIndex;
    out.maskIndex = instance.maskIndex;
    
    return out;
}

/// Fragment shader for solid color shapes
fragment float4 svga_shape_fragment(
    VertexOut in [[stage_in]],
    constant float4* colors [[buffer(0)]]
) {
    // Get color from index
    float4 color = colors[in.textureIndex];
    
    // Apply alpha
    color.a *= in.alpha;
    color.rgb *= color.a;
    
    return color;
}

/// Fragment shader for gradient shapes
fragment float4 svga_gradient_fragment(
    VertexOut in [[stage_in]],
    constant float4* gradientStops [[buffer(0)]],
    constant uint& stopCount [[buffer(1)]]
) {
    // Linear gradient along Y axis (0 to 1)
    float t = in.texCoord.y;
    
    // Find gradient stops
    float4 color = gradientStops[0];
    
    for (uint i = 1; i < stopCount && i < 8; i++) {
        float stopPos = float(i) / float(stopCount - 1);
        if (t >= stopPos) {
            float localT = (t - (stopPos - 1.0 / float(stopCount - 1))) * float(stopCount - 1);
            color = mix(gradientStops[i - 1], gradientStops[i], saturate(localT));
        }
    }
    
    color.a *= in.alpha;
    color.rgb *= color.a;
    
    return color;
}

// MARK: - Debug Shaders

/// Debug vertex shader (passthrough)
vertex VertexOut svga_debug_vertex(
    VertexIn vertexIn [[stage_in]],
    constant Uniforms& uniforms [[buffer(3)]]
) {
    VertexOut out;
    
    float4 pos = float4(vertexIn.position, 0.0, 1.0);
    out.position = uniforms.projectionMatrix * pos;
    out.texCoord = vertexIn.texCoord;
    out.alpha = 1.0;
    out.textureIndex = 0;
    out.maskIndex = 0;
    
    return out;
}

/// Debug fragment shader (checkerboard pattern)
fragment float4 svga_debug_fragment(
    VertexOut in [[stage_in]]
) {
    // Checkerboard pattern for debugging
    float2 uv = in.texCoord * 10.0;
    float checker = fmod(floor(uv.x) + floor(uv.y), 2.0);
    
    float3 color = mix(float3(0.2, 0.2, 0.2), float3(0.8, 0.8, 0.8), checker);
    
    return float4(color, 1.0);
}

/// Debug fragment shader showing UV coordinates
fragment float4 svga_debug_uv_fragment(
    VertexOut in [[stage_in]]
) {
    return float4(in.texCoord.x, in.texCoord.y, 0.0, 1.0);
}

/// Debug fragment shader showing batch instance
fragment float4 svga_debug_batch_fragment(
    VertexOut in [[stage_in]]
) {
    // Color based on texture index
    float hue = fmod(float(in.textureIndex) * 0.1, 1.0);
    
    // HSV to RGB (simplified)
    float3 rgb = saturate(abs(fmod(hue * 6.0 + float3(0.0, 4.0, 2.0), 6.0) - 3.0) - 1.0);
    
    return float4(rgb, 1.0);
}

// MARK: - Utility Functions

/// Convert ARGB to float4 RGBA
inline float4 argbToFloat4(uint argb) {
    float a = float((argb >> 24) & 0xFF) / 255.0;
    float r = float((argb >> 16) & 0xFF) / 255.0;
    float g = float((argb >> 8) & 0xFF) / 255.0;
    float b = float(argb & 0xFF) / 255.0;
    return float4(r, g, b, a);
}

/// Linear interpolation
inline float4 lerp(float4 a, float4 b, float t) {
    return a + (b - a) * t;
}

/// Apply blend mode to colors
inline float4 applyBlendMode(float4 src, float4 dst, uint blendMode) {
    switch (blendMode) {
        case BLEND_MODE_ADDITIVE:
            // Additive: src + dst
            return float4(src.rgb + dst.rgb * dst.a, src.a + dst.a * (1.0 - src.a));
            
        case BLEND_MODE_MULTIPLY:
            // Multiply: src * dst
            return float4(src.rgb * dst.rgb, src.a * dst.a);
            
        case BLEND_MODE_SCREEN:
            // Screen: 1 - (1 - src) * (1 - dst)
            return float4(1.0 - (1.0 - src.rgb) * (1.0 - dst.rgb), src.a + dst.a * (1.0 - src.a));
            
        default:
            // Normal: standard alpha blend (handled by pipeline)
            return src;
    }
}

/// Premultiply alpha
inline float4 premultiply(float4 color) {
    return float4(color.rgb * color.a, color.a);
}

/// Unpremultiply alpha
inline float4 unpremultiply(float4 color) {
    if (color.a < 0.001) {
        return float4(0.0);
    }
    return float4(color.rgb / color.a, color.a);
}

// MARK: - Compute Kernels (for async texture processing)

/// Premultiply alpha kernel
kernel void svga_premultiply_alpha(
    texture2d<float, access::read> inTexture [[texture(0)]],
    texture2d<float, access::write> outTexture [[texture(1)]],
    uint2 gid [[thread_position_in_grid]]
) {
    if (gid.x >= outTexture.get_width() || gid.y >= outTexture.get_height()) {
        return;
    }
    
    float4 color = inTexture.read(gid);
    color.rgb *= color.a;
    outTexture.write(color, gid);
}

/// BGRA to RGBA conversion kernel
kernel void svga_bgra_to_rgba(
    texture2d<float, access::read> inTexture [[texture(0)]],
    texture2d<float, access::write> outTexture [[texture(1)]],
    uint2 gid [[thread_position_in_grid]]
) {
    if (gid.x >= outTexture.get_width() || gid.y >= outTexture.get_height()) {
        return;
    }
    
    float4 color = inTexture.read(gid);
    outTexture.write(float4(color.b, color.g, color.r, color.a), gid);
}

/// Flip texture vertically kernel
kernel void svga_flip_vertical(
    texture2d<float, access::read> inTexture [[texture(0)]],
    texture2d<float, access::write> outTexture [[texture(1)]],
    uint2 gid [[thread_position_in_grid]]
) {
    uint height = outTexture.get_height();
    if (gid.x >= outTexture.get_width() || gid.y >= height) {
        return;
    }
    
    float4 color = inTexture.read(uint2(gid.x, height - 1 - gid.y));
    outTexture.write(color, gid);
}
