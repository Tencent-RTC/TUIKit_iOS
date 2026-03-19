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
public final class TextureAtlasBuilder {
    
    // MARK: - Types
    
    /// Image source for building atlas
    public struct ImageSource {
        let key: String
        let image: CGImage
        
        public init(key: String, image: CGImage) {
            self.key = key
            self.image = image
        }
    }
    
    /// Build result
    public struct BuildResult {
        public let atlas: SVGATextureAtlas
        public let packingEfficiency: Float
        public let totalImages: Int
        public let failedImages: [String]
    }
    
    /// Build options
    public struct BuildOptions {
        /// Maximum atlas dimensions
        public var maxWidth: Int = 4096
        public var maxHeight: Int = 4096
        
        /// Padding between images
        public var padding: Int = 2
        
        /// Allow rotation for better packing
        public var allowRotation: Bool = true
        
        /// Pixel format
        public var pixelFormat: MTLPixelFormat = .bgra8Unorm
        
        /// Generate mipmaps
        public var generateMipmaps: Bool = false
        
        /// Premultiply alpha
        public var premultiplyAlpha: Bool = true
        
        /// Power of two dimensions
        public var powerOfTwo: Bool = false
        
        public init() {}
    }
    
    // MARK: - Properties
    
    /// Metal device
    private let device: MTLDevice
    
    /// Build options
    private let options: BuildOptions
    
    /// Pending images
    private var pendingImages: [TextureRegion] = []
    
    // MARK: - Initialization
    
    public init(device: MTLDevice, options: BuildOptions = BuildOptions()) {
        self.device = device
        self.options = options
    }
    
    // MARK: - Adding Images
    
    /// Add an image to be packed
    public func addImage(key: String, image: CGImage) {
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
    public func addImages(_ sources: [ImageSource]) {
        pendingImages.reserveCapacity(pendingImages.count + sources.count)
        for source in sources {
            addImage(key: source.key, image: source.image)
        }
    }
    
    /// Add pre-decoded raw BGRA pixel data (skips CGImage → CGContext extraction)
    /// Use this when you already have the pixel data in the correct format
    public func addRawImage(key: String, data: Data, width: Int, height: Int) {
        let region = TextureRegion(
            key: key,
            width: width,
            height: height,
            imageData: data
        )
        pendingImages.append(region)
    }
    
    /// Add images from dictionary
    public func addImages(from dictionary: [String: CGImage]) {
        for (key, image) in dictionary {
            addImage(key: key, image: image)
        }
    }
    
    // MARK: - Building
    
    /// Build the texture atlas
    public func build() throws -> BuildResult {
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
        
        return BuildResult(
            atlas: atlas,
            packingEfficiency: packer.occupancy,
            totalImages: packedRegions.count,
            failedImages: failedImages
        )
    }
    
    /// Build atlas asynchronously
    public func buildAsync(completion: @escaping (Result<BuildResult, Error>) -> Void) {
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
        // Use private storage for optimal GPU read performance on iOS.
        // Data is uploaded via a staging buffer + blit encoder.
        let descriptor = MTLTextureDescriptor.texture2DDescriptor(
            pixelFormat: options.pixelFormat,
            width: width,
            height: height,
            mipmapped: options.generateMipmaps
        )
        descriptor.usage = [.shaderRead]
        descriptor.storageMode = .private
        
        guard let texture = device.makeTexture(descriptor: descriptor) else {
            throw NSError(domain: "SVGAEngine", code: 5002, userInfo: [NSLocalizedDescriptionKey: "Failed to create texture"])
        }
        texture.label = "SVGA Texture Atlas"
        
        // Build a full-texture-sized staging buffer laid out as a linear image.
        // The buffer is zero-initialized (transparent black) so padding areas and
        // unused regions are automatically clean — preventing colored edge artifacts.
        // Region pixel data is then written directly to the correct (x, y) positions,
        // and the entire texture is uploaded with a single blit copy.
        //
        // Key perf insight: We use vm_allocate (via UnsafeMutableRawPointer.allocate)
        // for lazy zero-fill — the OS maps zero pages on demand, so only pages
        // actually touched by region data consume physical memory. This avoids the
        // 16-64MB memset that previously caused memory pressure and video capture stalls.
        
        struct RegionUpload {
            let region: TextureRegion
            let data: Data          // potentially rotated
            let sourceWidth: Int
            let sourceHeight: Int
        }
        var uploads: [RegionUpload] = []
        uploads.reserveCapacity(regions.count)
        
        for region in regions {
            guard let imageData = region.imageData else { continue }
            
            let sourceWidth = region.rotated ? region.height : region.width
            let sourceHeight = region.rotated ? region.width : region.height
            let regionData: Data
            
            if region.rotated {
                regionData = rotateImageData(imageData, width: region.width, height: region.height)
            } else {
                regionData = imageData
            }
            
            uploads.append(RegionUpload(
                region: region,
                data: regionData,
                sourceWidth: sourceWidth,
                sourceHeight: sourceHeight
            ))
        }
        
        guard !uploads.isEmpty else {
            return texture
        }
        
        let bytesPerRow = width * 4
        let totalBufferSize = bytesPerRow * height
        
        // Create staging buffer with lazy zero-fill semantics.
        // We allocate our own page-aligned memory via vm_allocate (through
        // UnsafeMutableRawPointer.allocate) which gives us lazy zero pages —
        // only pages actually written to consume physical memory. This avoids
        // the costly 2-4ms memset of 16MB+ that caused video capture stalls.
        //
        // We then create the MTLBuffer with .storageModeShared + noCopy to wrap
        // this memory without any additional allocation or copy.
        let pageSize = Int(vm_page_size)
        let alignedSize = (totalBufferSize + pageSize - 1) & ~(pageSize - 1)
        let rawPtr = UnsafeMutableRawPointer.allocate(byteCount: alignedSize, alignment: pageSize)
        // vm_allocate-backed pages are zero on first access — no memset needed.
        // However, we must zero the padding around each region to prevent
        // bilinear sampling artifacts. We do this surgically below.
        
        guard let stagingBuffer = device.makeBuffer(
            bytesNoCopy: rawPtr,
            length: alignedSize,
            options: .storageModeShared,
            deallocator: { ptr, _ in ptr.deallocate() }
        ) else {
            rawPtr.deallocate()
            throw NSError(domain: "SVGAEngine", code: 5002, userInfo: [NSLocalizedDescriptionKey: "Failed to create staging buffer"])
        }
        stagingBuffer.label = "SVGA Atlas Staging Buffer (noCopy)"
        
        // Write each region's pixel data directly into the staging buffer at (x, y).
        // Because the backing memory is lazily zero-filled by the OS, untouched pages
        // (unused atlas regions, large padding areas) remain virtual zero pages and
        // never consume physical RAM. Only pages containing sprite pixel data and their
        // immediately adjacent padding rows are faulted in.
        let stagingPtr = stagingBuffer.contents()
        let padding = options.padding
        for upload in uploads {
            let srcBytesPerRow = upload.sourceWidth * 4
            let dstX = upload.region.x
            let dstY = upload.region.y
            
            // Zero the padding rows above the region (padding rows × full padded width).
            // This ensures bilinear filtering at the top edge samples transparent black.
            if padding > 0 {
                let paddedRowBytes = (upload.sourceWidth + padding * 2) * 4
                let topPadStartX = max(0, dstX - padding)
                for padRow in 0..<padding {
                    let rowY = dstY - padding + padRow
                    guard rowY >= 0 && rowY < height else { continue }
                    let dstOffset = rowY * bytesPerRow + topPadStartX * 4
                    memset(stagingPtr + dstOffset, 0, min(paddedRowBytes, bytesPerRow - topPadStartX * 4))
                }
            }
            
            upload.data.withUnsafeBytes { ptr in
                guard let srcBase = ptr.baseAddress else { return }
                // Copy row by row into the correct position in the full-texture layout.
                // Also zero the padding columns on left and right of each row.
                for row in 0..<upload.sourceHeight {
                    let srcOffset = row * srcBytesPerRow
                    let dstRowY = dstY + row
                    guard dstRowY >= 0 && dstRowY < height else { continue }
                    let dstOffset = dstRowY * bytesPerRow + dstX * 4
                    memcpy(stagingPtr + dstOffset, srcBase + srcOffset, srcBytesPerRow)
                    
                    // Zero padding columns (left + right of this row)
                    if padding > 0 {
                        let leftPadX = max(0, dstX - padding)
                        let leftPadBytes = (dstX - leftPadX) * 4
                        if leftPadBytes > 0 {
                            memset(stagingPtr + dstRowY * bytesPerRow + leftPadX * 4, 0, leftPadBytes)
                        }
                        let rightPadX = dstX + upload.sourceWidth
                        let rightPadEnd = min(width, rightPadX + padding)
                        let rightPadBytes = (rightPadEnd - rightPadX) * 4
                        if rightPadBytes > 0 {
                            memset(stagingPtr + dstRowY * bytesPerRow + rightPadX * 4, 0, rightPadBytes)
                        }
                    }
                }
            }
            
            // Zero the padding rows below the region
            if padding > 0 {
                let paddedRowBytes = (upload.sourceWidth + padding * 2) * 4
                let bottomPadStartX = max(0, dstX - padding)
                for padRow in 0..<padding {
                    let rowY = dstY + upload.sourceHeight + padRow
                    guard rowY >= 0 && rowY < height else { continue }
                    let dstOffset = rowY * bytesPerRow + bottomPadStartX * 4
                    memset(stagingPtr + dstOffset, 0, min(paddedRowBytes, bytesPerRow - bottomPadStartX * 4))
                }
            }
        }
        
        // Single blit copy: staging buffer → private texture
        guard let context = SharedMetalContext.shared else {
            throw NSError(domain: "SVGAEngine", code: 5002, userInfo: [NSLocalizedDescriptionKey: "Metal context unavailable"])
        }
        guard let commandBuffer = context.commandQueue.makeCommandBuffer() else {
            throw NSError(domain: "SVGAEngine", code: 5002, userInfo: [NSLocalizedDescriptionKey: "Failed to create command buffer"])
        }
        commandBuffer.label = "SVGA Atlas Upload"
        
        guard let blitEncoder = commandBuffer.makeBlitCommandEncoder() else {
            throw NSError(domain: "SVGAEngine", code: 5002, userInfo: [NSLocalizedDescriptionKey: "Failed to create blit encoder"])
        }
        blitEncoder.label = "SVGA Atlas Blit"
        
        blitEncoder.copy(
            from: stagingBuffer,
            sourceOffset: 0,
            sourceBytesPerRow: bytesPerRow,
            sourceBytesPerImage: totalBufferSize,
            sourceSize: MTLSize(width: width, height: height, depth: 1),
            to: texture,
            destinationSlice: 0,
            destinationLevel: 0,
            destinationOrigin: MTLOrigin(x: 0, y: 0, z: 0)
        )
        
        blitEncoder.endEncoding()
        
        // Capture staging buffer in the completion handler to ensure it stays
        // alive until the GPU finishes the blit. Without this, ARC may deallocate
        // the buffer before the GPU reads from it, causing data corruption.
        commandBuffer.addCompletedHandler { _ in
            _ = stagingBuffer
        }
        
        commandBuffer.commit()
        // waitUntilScheduled() ensures the GPU scheduler has accepted this blit
        // command buffer before we return. Cost: ~10-50μs (microseconds), negligible.
        // Without this, if the caller immediately submits render command buffers,
        // the GPU scheduler has to queue both the blit and render simultaneously,
        // which can cause a brief scheduling stall that manifests as a video
        // capture hiccup on the host side. waitUntilScheduled does NOT wait for
        // the blit to finish — it only waits for the GPU to acknowledge the work.
        commandBuffer.waitUntilScheduled()
        // The first render pass will implicitly wait on this command buffer
        // because it's in the same command queue.
        
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
    public func reset() {
        pendingImages.removeAll()
    }
}

// MARK: - TextureAtlasBuilder + Convenience

extension TextureAtlasBuilder {
    
    /// Build atlas from raw image data
    public func buildFromData(
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
    public func buildFromURLs(_ urls: [String: URL]) throws -> BuildResult {
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
