//
//  TextureAtlas.swift
//  TUILiveKit
//
//  Created on 2026/2/5.
//  High-Performance SVGA Player Core
//
//  Merged from TextureAtlas.swift + UVRegion.swift
//

import Foundation
import Metal
import CoreGraphics
import simd

// MARK: - UVRegion

/// Represents UV coordinates for a texture region within a TextureAtlas
/// All coordinates are normalized [0, 1]
public struct UVRegion: Equatable {
    
    // MARK: - Properties
    
    public var u: Float
    public var v: Float
    public var width: Float
    public var height: Float
    public var rotated: Bool
    
    // MARK: - Initialization
    
    public init(
        u: Float = 0,
        v: Float = 0,
        width: Float = 1,
        height: Float = 1,
        rotated: Bool = false
    ) {
        self.u = u
        self.v = v
        self.width = width
        self.height = height
        self.rotated = rotated
    }
    
    // MARK: - Factory Methods
    
    public static var full: UVRegion {
        UVRegion(u: 0, v: 0, width: 1, height: 1, rotated: false)
    }
    
    public static func fromPixels(
        x: Int, y: Int, width: Int, height: Int,
        atlasWidth: Int, atlasHeight: Int, rotated: Bool = false
    ) -> UVRegion {
        UVRegion(
            u: Float(x) / Float(atlasWidth),
            v: Float(y) / Float(atlasHeight),
            width: Float(width) / Float(atlasWidth),
            height: Float(height) / Float(atlasHeight),
            rotated: rotated
        )
    }
    
    // MARK: - Computed Properties
    
    public var uMax: Float { u + width }
    public var vMax: Float { v + height }
    public var uCenter: Float { u + width * 0.5 }
    public var vCenter: Float { v + height * 0.5 }
    
    // MARK: - UV Corners
    
    /// Get UV coordinates for the four corners
    /// Returns: (topLeft, topRight, bottomRight, bottomLeft)
    public var corners: (SIMD2<Float>, SIMD2<Float>, SIMD2<Float>, SIMD2<Float>) {
        if rotated {
            return (
                SIMD2<Float>(u + width, v),
                SIMD2<Float>(u + width, v + height),
                SIMD2<Float>(u, v + height),
                SIMD2<Float>(u, v)
            )
        } else {
            return (
                SIMD2<Float>(u, v),
                SIMD2<Float>(u + width, v),
                SIMD2<Float>(u + width, v + height),
                SIMD2<Float>(u, v + height)
            )
        }
    }
    
    public var simd4: SIMD4<Float> {
        SIMD4<Float>(u, v, uMax, vMax)
    }
    
    // MARK: - Validation
    
    public var isValid: Bool {
        u >= 0 && u <= 1 &&
        v >= 0 && v <= 1 &&
        width > 0 && width <= 1 &&
        height > 0 && height <= 1 &&
        uMax <= 1.0001 &&
        vMax <= 1.0001
    }
    
    // MARK: - Transformations
    
    public func subRegion(u: Float, v: Float, width: Float, height: Float) -> UVRegion {
        UVRegion(
            u: self.u + u * self.width,
            v: self.v + v * self.height,
            width: width * self.width,
            height: height * self.height,
            rotated: self.rotated
        )
    }
    
    public var flippedHorizontally: UVRegion {
        var region = self
        region.u = uMax
        region.width = -width
        return region
    }
    
    public var flippedVertically: UVRegion {
        var region = self
        region.v = vMax
        region.height = -height
        return region
    }
}

// MARK: - UVRegion + Metal Integration

extension UVRegion {
    
    public func generateQuadUVs() -> [SIMD2<Float>] {
        let c = corners
        return [c.0, c.1, c.2, c.3]
    }
    
    public func generateTriangleStripUVs() -> [SIMD2<Float>] {
        let c = corners
        return [c.0, c.3, c.1, c.2]
    }
    
    public func generateTriangleUVs() -> [SIMD2<Float>] {
        let c = corners
        return [c.0, c.1, c.2, c.0, c.2, c.3]
    }
}

// MARK: - UVRegionMap

/// Dictionary-like container for UV regions with O(1) lookup
public struct UVRegionMap {
    
    private var regions: [String: UVRegion] = [:]
    private var indexedRegions: [UVRegion] = []
    private var keyToIndex: [String: Int] = [:]
    
    public init() {}
    
    public subscript(key: String) -> UVRegion? {
        get { regions[key] }
        set {
            if let value = newValue {
                if regions[key] == nil {
                    let index = indexedRegions.count
                    keyToIndex[key] = index
                    indexedRegions.append(value)
                } else if let index = keyToIndex[key] {
                    indexedRegions[index] = value
                }
                regions[key] = value
            } else {
                regions[key] = nil
            }
        }
    }
    
    public func region(at index: Int) -> UVRegion? {
        guard index >= 0 && index < indexedRegions.count else { return nil }
        return indexedRegions[index]
    }
    
    public func index(forKey key: String) -> Int? {
        keyToIndex[key]
    }
    
    public var count: Int { regions.count }
    public var keys: Dictionary<String, UVRegion>.Keys { regions.keys }
    public var isEmpty: Bool { regions.isEmpty }
    
    public mutating func addRegions(_ newRegions: [String: UVRegion]) {
        for (key, region) in newRegions {
            self[key] = region
        }
    }
    
    public var allRegions: [UVRegion] { indexedRegions }
    
    public mutating func removeAll() {
        regions.removeAll()
        indexedRegions.removeAll()
        keyToIndex.removeAll()
    }
}

// MARK: - SVGATextureAtlas

/// Packed texture atlas containing all sprite images
/// Optimized for GPU rendering with UV coordinate lookup
public final class SVGATextureAtlas: TextureAtlas {
    
    // MARK: - Properties
    
    public private(set) var texture: MTLTexture?
    public let size: CGSize
    public private(set) var regions: UVRegionMap
    public let pixelFormat: MTLPixelFormat
    
    public var isReady: Bool { texture != nil }
    
    // MARK: - Initialization
    
    public init(
        size: CGSize,
        pixelFormat: MTLPixelFormat = .bgra8Unorm
    ) {
        self.size = size
        self.pixelFormat = pixelFormat
        self.regions = UVRegionMap()
    }
    
    // MARK: - Region Management
    
    public func addRegion(key: String, region: UVRegion) {
        regions[key] = region
    }
    
    public func region(forKey key: String) -> UVRegion? {
        regions[key]
    }
    
    public func regionIndex(forKey key: String) -> Int? {
        regions.index(forKey: key)
    }
    
    public func region(at index: Int) -> UVRegion? {
        regions.region(at: index)
    }
    
    // MARK: - Texture Setup
    
    internal func setTexture(_ texture: MTLTexture) {
        self.texture = texture
    }
    
    // MARK: - Memory
    
    public override var estimatedMemorySize: Int {
        guard let tex = texture else { return 0 }
        let bytesPerPixel: Int
        switch pixelFormat {
        case .bgra8Unorm, .rgba8Unorm: bytesPerPixel = 4
        case .r8Unorm: bytesPerPixel = 1
        case .rg8Unorm: bytesPerPixel = 2
        default: bytesPerPixel = 4
        }
        return tex.width * tex.height * bytesPerPixel
    }
    
    // MARK: - Cleanup
    
    public func releaseTexture() {
        texture = nil
    }
}

// MARK: - TextureAtlasDescriptor

public struct TextureAtlasDescriptor {
    public var maxWidth: Int = 4096
    public var maxHeight: Int = 4096
    public var padding: Int = 2
    public var allowRotation: Bool = true
    public var pixelFormat: MTLPixelFormat = .bgra8Unorm
    public var generateMipmaps: Bool = false
    
    public init() {}
}

// MARK: - TextureRegion (for packing)

internal struct TextureRegion {
    let key: String
    var x: Int
    var y: Int
    let width: Int
    let height: Int
    var rotated: Bool
    var imageData: Data?
    
    init(key: String, width: Int, height: Int, imageData: Data? = nil) {
        self.key = key
        self.x = 0
        self.y = 0
        self.width = width
        self.height = height
        self.rotated = false
        self.imageData = imageData
    }
    
    var packedWidth: Int { rotated ? height : width }
    var packedHeight: Int { rotated ? width : height }
}

// MARK: - MaxRects Packing Algorithm

internal final class MaxRectsPacker {
    
    private var binWidth: Int
    private var binHeight: Int
    private var allowRotation: Bool
    private var freeRects: [CGRect] = []
    private var usedRects: [CGRect] = []
    
    init(width: Int, height: Int, allowRotation: Bool = true) {
        self.binWidth = width
        self.binHeight = height
        self.allowRotation = allowRotation
        self.freeRects = [CGRect(x: 0, y: 0, width: CGFloat(width), height: CGFloat(height))]
    }
    
    func insert(width: Int, height: Int) -> (rect: CGRect, rotated: Bool)? {
        var bestNode = CGRect.zero
        var bestShortSideFit = Int.max
        var bestLongSideFit = Int.max
        var bestRotated = false
        
        for freeRect in freeRects {
            if CGFloat(width) <= freeRect.width && CGFloat(height) <= freeRect.height {
                let leftoverHoriz = Int(freeRect.width) - width
                let leftoverVert = Int(freeRect.height) - height
                let shortSideFit = min(leftoverHoriz, leftoverVert)
                let longSideFit = max(leftoverHoriz, leftoverVert)
                
                if shortSideFit < bestShortSideFit ||
                   (shortSideFit == bestShortSideFit && longSideFit < bestLongSideFit) {
                    bestNode = CGRect(x: freeRect.minX, y: freeRect.minY,
                                     width: CGFloat(width), height: CGFloat(height))
                    bestShortSideFit = shortSideFit
                    bestLongSideFit = longSideFit
                    bestRotated = false
                }
            }
            
            if allowRotation && CGFloat(height) <= freeRect.width && CGFloat(width) <= freeRect.height {
                let leftoverHoriz = Int(freeRect.width) - height
                let leftoverVert = Int(freeRect.height) - width
                let shortSideFit = min(leftoverHoriz, leftoverVert)
                let longSideFit = max(leftoverHoriz, leftoverVert)
                
                if shortSideFit < bestShortSideFit ||
                   (shortSideFit == bestShortSideFit && longSideFit < bestLongSideFit) {
                    bestNode = CGRect(x: freeRect.minX, y: freeRect.minY,
                                     width: CGFloat(height), height: CGFloat(width))
                    bestShortSideFit = shortSideFit
                    bestLongSideFit = longSideFit
                    bestRotated = true
                }
            }
        }
        
        guard bestShortSideFit != Int.max else { return nil }
        
        placeRect(bestNode)
        return (bestNode, bestRotated)
    }
    
    private func placeRect(_ node: CGRect) {
        var i = 0
        while i < freeRects.count {
            if splitFreeNode(freeRects[i], used: node) {
                freeRects.remove(at: i)
            } else {
                i += 1
            }
        }
        pruneFreeList()
        usedRects.append(node)
    }
    
    private func splitFreeNode(_ freeNode: CGRect, used: CGRect) -> Bool {
        if used.minX >= freeNode.maxX || used.maxX <= freeNode.minX ||
           used.minY >= freeNode.maxY || used.maxY <= freeNode.minY {
            return false
        }
        
        if used.minX > freeNode.minX && used.minX < freeNode.maxX {
            freeRects.append(CGRect(x: freeNode.minX, y: freeNode.minY,
                                   width: used.minX - freeNode.minX, height: freeNode.height))
        }
        if used.maxX < freeNode.maxX {
            freeRects.append(CGRect(x: used.maxX, y: freeNode.minY,
                                   width: freeNode.maxX - used.maxX, height: freeNode.height))
        }
        if used.minY > freeNode.minY && used.minY < freeNode.maxY {
            freeRects.append(CGRect(x: freeNode.minX, y: freeNode.minY,
                                   width: freeNode.width, height: used.minY - freeNode.minY))
        }
        if used.maxY < freeNode.maxY {
            freeRects.append(CGRect(x: freeNode.minX, y: used.maxY,
                                   width: freeNode.width, height: freeNode.maxY - used.maxY))
        }
        return true
    }
    
    private func pruneFreeList() {
        var i = 0
        while i < freeRects.count {
            var j = i + 1
            while j < freeRects.count {
                if freeRects[j].contains(freeRects[i]) {
                    freeRects.remove(at: i)
                    i -= 1
                    break
                }
                if freeRects[i].contains(freeRects[j]) {
                    freeRects.remove(at: j)
                    j -= 1
                }
                j += 1
            }
            i += 1
        }
    }
    
    var occupancy: Float {
        var usedArea: CGFloat = 0
        for rect in usedRects {
            usedArea += rect.width * rect.height
        }
        return Float(usedArea) / Float(binWidth * binHeight)
    }
}

// MARK: - Type Alias for backward compatibility

public typealias TextureAtlasImpl = SVGATextureAtlas
