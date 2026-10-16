//
//  TextureAtlasBuilder.swift
//  TUILiveKit
//
//  Created on 2026/2/5.
//  High-Performance SVGA Player Core
//

import Foundation
import Metal
import CoreGraphics
import ImageIO
import Accelerate

// MARK: - TextureAtlasBuilder

/// Builder for creating packed texture atlases from images
/// Uses MaxRects bin packing algorithm for optimal texture utilization
final class TextureAtlasBuilder {

    // MARK: - Types

    /// Image source for building atlas
    struct ImageSource {
        let key: String
        let image: CGImage

        init(key: String, image: CGImage) {
            self.key = key
            self.image = image
        }
    }

    /// Build result
    struct BuildResult {
        let atlas: SVGATextureAtlas
        let packingEfficiency: Float
        let totalImages: Int
        let failedImages: [String]
    }

    /// Build options
    struct BuildOptions {
        /// Maximum atlas dimensions
        var maxWidth: Int = 4096
        var maxHeight: Int = 4096

        /// Padding between images
        var padding: Int = 2

        /// Allow rotation for better packing
        var allowRotation: Bool = true

        /// Pixel format
        var pixelFormat: MTLPixelFormat = .bgra8Unorm

        /// Generate mipmaps
        var generateMipmaps: Bool = false

        /// Premultiply alpha
        var premultiplyAlpha: Bool = true

        /// Power of two dimensions
        var powerOfTwo: Bool = false

        init() {}
    }

    // MARK: - Properties

    /// Metal device
    private let device: MTLDevice

    /// Build options
    private let options: BuildOptions

    /// Pending images
    private var pendingImages: [TextureRegion] = []
    private var encodedImages: [String: Data] = [:]

    // MARK: - Initialization

    init(device: MTLDevice, options: BuildOptions = BuildOptions()) {
        self.device = device
        self.options = options
    }

    // MARK: - Adding Images

    /// Read dimensions without decoding every image into a retained bitmap.
    func addEncodedImage(key: String, data: Data) {
        guard let source = CGImageSourceCreateWithData(data as CFData, [kCGImageSourceShouldCache: false] as CFDictionary),
              let properties = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any],
              let width = properties[kCGImagePropertyPixelWidth] as? Int,
              let height = properties[kCGImagePropertyPixelHeight] as? Int,
              width > 0, height > 0 else { return }
        encodedImages[key] = data
        pendingImages.append(TextureRegion(key: key, width: width, height: height, imageData: nil))
    }

    /// Add an image to be packed
    func addImage(key: String, image: CGImage) {
        let imageData = extractImageData(from: image)
        let region = TextureRegion(
            key: key,
            width: image.width,
            height: image.height,
            imageData: imageData
        )
        pendingImages.append(region)
        // CGImage is released here (no longer referenced after extractImageData)
    }

    /// Add multiple images (releases each CGImage after extraction)
    func addImages(_ sources: [ImageSource]) {
        pendingImages.reserveCapacity(pendingImages.count + sources.count)
        for source in sources {
            addImage(key: source.key, image: source.image)
        }
    }

    /// Add pre-decoded raw BGRA pixel data (skips CGImage → CGContext extraction)
    /// Use this when you already have the pixel data in the correct format
    func addRawImage(key: String, data: Data, width: Int, height: Int) {
        let region = TextureRegion(
            key: key,
            width: width,
            height: height,
            imageData: data
        )
        pendingImages.append(region)
    }

    /// Add images from dictionary
    func addImages(from dictionary: [String: CGImage]) {
        for (key, image) in dictionary {
            addImage(key: key, image: image)
        }
    }

    // MARK: - Building

    /// Build the texture atlas
    func build() throws -> BuildResult {
        guard !pendingImages.isEmpty else {
            throw NSError(domain: "SVGAEngine", code: 9001, userInfo: [NSLocalizedDescriptionKey: "No images to build atlas"])
        }

        // Sort images by area (largest first for better packing)
        var regions = pendingImages.sorted { ($0.width * $0.height) > ($1.width * $1.height) }

        // Calculate optimal atlas size
        let (atlasWidth, atlasHeight) = calculateAtlasSize(for: regions)

        // Create packer
        let packer = MaxRectsPacker(
            width: atlasWidth,
            height: atlasHeight,
            allowRotation: options.allowRotation
        )

        // Pack images
        var failedImages: [String] = []
        var packedRegions: [TextureRegion] = []

        for i in 0..<regions.count {
            let paddedWidth = regions[i].width + options.padding * 2
            let paddedHeight = regions[i].height + options.padding * 2

            if let (rect, rotated) = packer.insert(width: paddedWidth, height: paddedHeight) {
                regions[i].x = Int(rect.minX) + options.padding
                regions[i].y = Int(rect.minY) + options.padding
                regions[i].rotated = rotated
                packedRegions.append(regions[i])
            } else {
                failedImages.append(regions[i].key)
            }
        }

        guard failedImages.isEmpty else {
            throw NSError(domain: "SVGAEngine", code: 5002, userInfo: [NSLocalizedDescriptionKey: "Atlas cannot fit \(failedImages.count) images"])
        }
        // Create atlas
        let atlasSize = CGSize(width: atlasWidth, height: atlasHeight)
        let atlas = SVGATextureAtlas(size: atlasSize, pixelFormat: options.pixelFormat)

        // Create texture (uploads all imageData to GPU)
        let texture = try createTexture(
            width: atlasWidth,
            height: atlasHeight,
            regions: packedRegions
        )
        atlas.setTexture(texture)

        // Release CPU-side imageData immediately after GPU upload
        // This frees potentially several MB of peak memory
        for i in 0..<packedRegions.count {
            packedRegions[i].imageData = nil
        }

        // Add UV regions
        for region in packedRegions {
            let uvRegion = createUVRegion(
                from: region,
                atlasWidth: atlasWidth,
                atlasHeight: atlasHeight
            )
            atlas.addRegion(key: region.key, region: uvRegion)
        }

        // Clear pending (release all CPU-side image data)
        pendingImages.removeAll()
        encodedImages.removeAll()

        return BuildResult(
            atlas: atlas,
            packingEfficiency: packer.occupancy,
            totalImages: packedRegions.count,
            failedImages: failedImages
        )
    }

    /// Build atlas asynchronously
    func buildAsync(completion: @escaping (Result<BuildResult, Error>) -> Void) {
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self = self else {
                completion(.failure(NSError(domain: "SVGAEngine", code: 9002, userInfo: [NSLocalizedDescriptionKey: "Builder deallocated"])))
                return
            }

            do {
                let result = try self.build()
                DispatchQueue.main.async {
                    completion(.success(result))
                }
            } catch {
                DispatchQueue.main.async {
                    completion(.failure(error))
                }
            }
        }
    }

    // MARK: - Private Methods

    private func calculateAtlasSize(for regions: [TextureRegion]) -> (Int, Int) {
        // Calculate total area
        var totalArea = 0
        var maxWidth = 0
        var maxHeight = 0

        for region in regions {
            let paddedWidth = region.width + options.padding * 2
            let paddedHeight = region.height + options.padding * 2
            totalArea += paddedWidth * paddedHeight
            maxWidth = max(maxWidth, paddedWidth)
            maxHeight = max(maxHeight, paddedHeight)
        }

        // Add some slack for packing inefficiency (reduced from 1.3x to 1.15x
        // because MaxRects packer typically achieves >85% efficiency for SVGA)
        totalArea = Int(Float(totalArea) * 1.15)

        // Calculate initial dimensions — prefer squarish atlas for GPU efficiency
        var width = max(maxWidth, Int(sqrt(Float(totalArea))))
        var height = max(maxHeight, totalArea / max(1, width) + 1)

        // Clamp to max
        width = min(width, options.maxWidth)
        height = min(height, options.maxHeight)

        // Round up to multiple of 64 for GPU alignment
        // (reduces wasted memory vs power-of-two while keeping GPU-friendly alignment)
        width = (width + 63) & ~63
        height = (height + 63) & ~63

        // Power of two if required
        if options.powerOfTwo {
            width = nextPowerOfTwo(width)
            height = nextPowerOfTwo(height)
        }

        return (width, height)
    }

    private func nextPowerOfTwo(_ value: Int) -> Int {
        var v = value - 1
        v |= v >> 1
        v |= v >> 2
        v |= v >> 4
        v |= v >> 8
        v |= v >> 16
        return v + 1
    }

    private func extractImageData(from image: CGImage) -> Data? {
        let width = image.width
        let height = image.height
        let bytesPerPixel = 4
        let bytesPerRow = width * bytesPerPixel
        let totalBytes = bytesPerRow * height

        var data = Data(count: totalBytes)

        data.withUnsafeMutableBytes { ptr in
            guard let baseAddress = ptr.baseAddress else { return }

            let colorSpace = CGColorSpaceCreateDeviceRGB()
            var bitmapInfo = CGBitmapInfo.byteOrder32Little.rawValue
            if options.premultiplyAlpha {
                bitmapInfo |= CGImageAlphaInfo.premultipliedFirst.rawValue
            } else {
                bitmapInfo |= CGImageAlphaInfo.first.rawValue
            }

            guard let context = CGContext(
                data: baseAddress,
                width: width,
                height: height,
                bitsPerComponent: 8,
                bytesPerRow: bytesPerRow,
                space: colorSpace,
                bitmapInfo: bitmapInfo
            ) else { return }

            context.draw(image, in: CGRect(x: 0, y: 0, width: width, height: height))
        }

        return data
    }

    private func createTexture(width: Int, height: Int, regions: [TextureRegion]) throws -> MTLTexture {
        let descriptor = MTLTextureDescriptor.texture2DDescriptor(
            pixelFormat: options.pixelFormat, width: width, height: height, mipmapped: false
        )
        descriptor.usage = [.shaderRead]
        descriptor.storageMode = .shared
        guard let texture = device.makeTexture(descriptor: descriptor) else {
            throw NSError(domain: "SVGAEngine", code: 5002, userInfo: [NSLocalizedDescriptionKey: "Failed to allocate atlas texture"])
        }
        texture.label = "SVGA Streaming Upload Atlas"

        // The texture is not published to a renderer until all writes complete.
        // Clear padding in small strips, without a second atlas-sized buffer.
        let stripRows = min(16, height)
        let zeroes = Data(count: width * stripRows * 4)
        zeroes.withUnsafeBytes { bytes in
            for y in stride(from: 0, to: height, by: stripRows) {
                texture.replace(region: MTLRegionMake2D(0, y, width, min(stripRows, height - y)),
                                mipmapLevel: 0, withBytes: bytes.baseAddress!, bytesPerRow: width * 4)
            }
        }
        for region in regions {
            try autoreleasepool {
                let pixels: Data
                if let data = encodedImages[region.key] {
                    guard let source = CGImageSourceCreateWithData(data as CFData, [kCGImageSourceShouldCache: false] as CFDictionary),
                          let image = CGImageSourceCreateImageAtIndex(source, 0, nil),
                          let decoded = extractImageData(from: image) else {
                        throw NSError(domain: "SVGAEngine", code: 5002, userInfo: [NSLocalizedDescriptionKey: "Image decode failed: \(region.key)"])
                    }
                    pixels = decoded
                } else if let data = region.imageData {
                    pixels = data
                } else {
                    throw NSError(domain: "SVGAEngine", code: 5002, userInfo: [NSLocalizedDescriptionKey: "Missing image: \(region.key)"])
                }
                let upload = region.rotated ? rotateImageData(pixels, width: region.width, height: region.height) : pixels
                let uploadWidth = region.rotated ? region.height : region.width
                let uploadHeight = region.rotated ? region.width : region.height
                upload.withUnsafeBytes { bytes in
                    texture.replace(region: MTLRegionMake2D(region.x, region.y, uploadWidth, uploadHeight),
                                    mipmapLevel: 0, withBytes: bytes.baseAddress!, bytesPerRow: uploadWidth * 4)
                }
            }
        }
        return texture
    }

    private func rotateImageData(_ data: Data, width: Int, height: Int) -> Data {
        let bytesPerPixel = 4
        let srcBytesPerRow = width * bytesPerPixel
        let dstBytesPerRow = height * bytesPerPixel  // rotated: dst width = src height

        var rotated = Data(count: width * height * bytesPerPixel)

        // Use vImage for hardware-accelerated 90° CW rotation
        data.withUnsafeBytes { srcPtr in
            rotated.withUnsafeMutableBytes { dstPtr in
                guard let srcBase = srcPtr.baseAddress,
                      let dstBase = dstPtr.baseAddress else { return }

                var srcBuffer = vImage_Buffer(
                    data: UnsafeMutableRawPointer(mutating: srcBase),
                    height: vImagePixelCount(height),
                    width: vImagePixelCount(width),
                    rowBytes: srcBytesPerRow
                )
                var dstBuffer = vImage_Buffer(
                    data: dstBase,
                    height: vImagePixelCount(width),   // rotated height = original width
                    width: vImagePixelCount(height),    // rotated width = original height
                    rowBytes: dstBytesPerRow
                )

                // Rotate 90° CW = kRotate90DegreesClockwise
                let err = vImageRotate90_ARGB8888(&srcBuffer, &dstBuffer, UInt8(kRotate90DegreesClockwise), [0, 0, 0, 0], vImage_Flags(kvImageNoFlags))

                if err != kvImageNoError {
                    // Fallback to manual rotation
                    let src = srcBase.assumingMemoryBound(to: UInt32.self)
                    let dst = dstBase.assumingMemoryBound(to: UInt32.self)
                    for y in 0..<height {
                        for x in 0..<width {
                            let srcIndex = y * width + x
                            let dstIndex = x * height + (height - 1 - y)
                            dst[dstIndex] = src[srcIndex]
                        }
                    }
                }
            }
        }

        return rotated
    }

    private func createUVRegion(from region: TextureRegion, atlasWidth: Int, atlasHeight: Int) -> UVRegion {
        let invWidth = 1.0 / Float(atlasWidth)
        let invHeight = 1.0 / Float(atlasHeight)

        // Inset by half a pixel to prevent bilinear filtering from sampling
        // neighboring textures or uninitialized padding pixels in the atlas.
        // This eliminates colored edge artifacts (e.g. purple lines) at sprite boundaries.
        let halfPixelU = 0.5 * invWidth
        let halfPixelV = 0.5 * invHeight

        let u0 = Float(region.x) * invWidth + halfPixelU
        let v0 = Float(region.y) * invHeight + halfPixelV
        let uvWidth = Float(region.packedWidth) * invWidth - halfPixelU * 2
        let uvHeight = Float(region.packedHeight) * invHeight - halfPixelV * 2

        return UVRegion(
            u: u0,
            v: v0,
            width: uvWidth,
            height: uvHeight,
            rotated: region.rotated
        )
    }

    // MARK: - Reset

    /// Clear all pending images
    func reset() {
        pendingImages.removeAll()
    }
}

// MARK: - TextureAtlasBuilder + Convenience

extension TextureAtlasBuilder {

    /// Build atlas from raw image data
    func buildFromData(
        images: [(key: String, data: Data, width: Int, height: Int)]
    ) throws -> BuildResult {
        for (key, data, width, height) in images {
            let region = TextureRegion(
                key: key,
                width: width,
                height: height,
                imageData: data
            )
            pendingImages.append(region)
        }

        return try build()
    }

    /// Build atlas from file URLs
    func buildFromURLs(_ urls: [String: URL]) throws -> BuildResult {
        for (key, url) in urls {
            guard let imageSource = CGImageSourceCreateWithURL(url as CFURL, nil),
                  let image = CGImageSourceCreateImageAtIndex(imageSource, 0, nil) else {
                continue
            }
            addImage(key: key, image: image)
        }

        return try build()
    }
}
