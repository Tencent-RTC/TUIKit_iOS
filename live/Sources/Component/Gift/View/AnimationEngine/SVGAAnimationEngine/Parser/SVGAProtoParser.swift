//
//  SVGAProtoParser.swift
//  TUILiveKit
//
//  Created on 2026/2/5.
//  High-Performance SVGA Player Core
//
//  Zero-copy Protobuf parser with FlatBuffers-inspired lazy access
//

import Foundation
import simd
import CoreGraphics
import Compression

// MARK: - SVGAProtoParser

/// High-performance zero-copy SVGA protobuf parser
/// Parses directly from memory-mapped buffer without intermediate allocations
public final class SVGAProtoParser {
    
    // MARK: - Field Numbers (from svga.proto)
    
    private enum MovieEntityField: Int {
        case version = 1
        case params = 2
        case images = 3
        case sprites = 4
        case audios = 5
    }
    
    private enum MovieParamsField: Int {
        case viewBoxWidth = 1
        case viewBoxHeight = 2
        case fps = 3
        case frames = 4
    }
    
    private enum SpriteEntityField: Int {
        case imageKey = 1
        case frames = 2
        case matteKey = 3
    }
    
    private enum FrameEntityField: Int {
        case alpha = 1
        case layout = 2
        case transform = 3
        case clipPath = 4
        case shapes = 5
    }
    
    private enum TransformField: Int {
        case a = 1, b = 2, c = 3, d = 4, tx = 5, ty = 6
    }
    
    private enum LayoutField: Int {
        case x = 1, y = 2, width = 3, height = 4
    }
    
    // MARK: - Properties
    
    /// Decompressor for SVGA files
    private let decompressor: SVGAStreamDecompressor
    
    /// Parse statistics
    public private(set) var statistics = ParseStatistics()
    
    // MARK: - Initialization
    
    public init() {
        self.decompressor = SVGAStreamDecompressor()
    }
    
    // MARK: - Public API
    
    /// Parse SVGA file from Data (zero-copy when possible)
    /// - Parameters:
    ///   - data: SVGA file data (may be ZIP, zlib compressed, or raw protobuf)
    ///   - identifier: Unique identifier for the animation
    /// - Returns: Parsed animation with lazy-loaded sprites
    public func parse(data: Data, identifier: String) throws -> SVGAAnimation {
        let startTime = CFAbsoluteTimeGetCurrent()
        
        // Detect file format
        let format = detectFormat(data: data)
        
        var protobufData: Data
        var imageDataMap: [String: Data] = [:]
        
        switch format {
        case .zip:
            let extracted = try extractZipArchive(data: data)
            protobufData = extracted.protobuf
            imageDataMap = extracted.images
            
        case .zlibCompressed:
            let decompressResult = try data.withUnsafeBytes { ptr -> SVGAStreamDecompressor.DecompressResult in
                try decompressor.decompress(data: ptr)
            }
            statistics.decompressTimeMs = decompressResult.timeMs
            // Use RAII toData() — copies result and auto-releases the owned buffer
            protobufData = decompressResult.toData()
            
        case .rawProtobuf:
            protobufData = data
        }
        
        // Parse protobuf
        let animation = try protobufData.withUnsafeBytes { ptr in
            try parseMovieEntity(buffer: ptr, identifier: identifier, externalImages: imageDataMap)
        }
        
        statistics.totalTimeMs = (CFAbsoluteTimeGetCurrent() - startTime) * 1000
        
        return animation
    }
    
    // MARK: - Format Detection
    
    private enum SVGAFormat {
        case zip
        case zlibCompressed
        case rawProtobuf
    }
    
    private func detectFormat(data: Data) -> SVGAFormat {
        guard data.count > 4 else {
            return .rawProtobuf
        }
        
        return data.withUnsafeBytes { ptr -> SVGAFormat in
            let byte0 = ptr.load(as: UInt8.self)
            let byte1 = ptr.load(fromByteOffset: 1, as: UInt8.self)
            let byte2 = ptr.load(fromByteOffset: 2, as: UInt8.self)
            let byte3 = ptr.load(fromByteOffset: 3, as: UInt8.self)
            
            // Check for ZIP signature: PK\x03\x04
            if byte0 == 0x50 && byte1 == 0x4B && byte2 == 0x03 && byte3 == 0x04 {
                return .zip
            }
            
            // Check for zlib header: 0x78 followed by 0x9C, 0x01, 0xDA, or 0x5E
            if byte0 == 0x78 && (byte1 == 0x9C || byte1 == 0x01 || byte1 == 0xDA || byte1 == 0x5E) {
                return .zlibCompressed
            }
            
            return .rawProtobuf
        }
    }
    
    // MARK: - ZIP Extraction
    
    private struct ZipExtractResult {
        let protobuf: Data
        let images: [String: Data]
    }
    
    private func extractZipArchive(data: Data) throws -> ZipExtractResult {
        var protobufData: Data?
        var images: [String: Data] = [:]
        
        // ZIP parser using Data slicing — avoids full [UInt8] copy of the entire archive.
        // Data.withUnsafeBytes is used only for header reads; file content uses Data subranges.
        
        let totalCount = data.count
        var offset = 0
        
        while offset + 30 < totalCount {
            // Read local file header signature from Data directly
            let sig = data.withUnsafeBytes { ptr -> UInt32 in
                guard offset + 4 <= totalCount else { return 0 }
                return ptr.load(fromByteOffset: offset, as: UInt32.self)
            }
            
            // Check for local file header signature: PK\x03\x04 = 0x04034b50 (little-endian)
            guard sig == 0x04034b50 else {
                // Check for central directory signature: PK\x01\x02 = 0x02014b50
                if sig == 0x02014b50 {
                    break
                }
                offset += 1
                continue
            }
            
            // Parse header fields using Data.withUnsafeBytes (single access)
            let (compressionMethod, compressedSize, uncompressedSize, fileNameLength, extraFieldLength) = data.withUnsafeBytes { ptr -> (UInt16, UInt32, UInt32, UInt16, UInt16) in
                let cm = ptr.load(fromByteOffset: offset + 8, as: UInt16.self)
                let cs = ptr.load(fromByteOffset: offset + 18, as: UInt32.self)
                let us = ptr.load(fromByteOffset: offset + 22, as: UInt32.self)
                let fnl = ptr.load(fromByteOffset: offset + 26, as: UInt16.self)
                let efl = ptr.load(fromByteOffset: offset + 28, as: UInt16.self)
                return (cm, cs, us, fnl, efl)
            }
            
            let headerSize = 30
            let fileNameStart = offset + headerSize
            let fileNameEnd = fileNameStart + Int(fileNameLength)
            
            guard fileNameEnd <= totalCount else { break }
            
            // Use Data subrange for filename — avoids [UInt8] copy
            let fileNameData = data[fileNameStart..<fileNameEnd]
            let fileName = String(data: fileNameData, encoding: .utf8) ?? ""
            
            let dataStart = fileNameEnd + Int(extraFieldLength)
            let dataEnd = dataStart + Int(compressedSize)
            
            guard dataEnd <= totalCount else { break }
            
            // Use Data subrange — copy-on-write, no immediate allocation
            let fileData = data[dataStart..<dataEnd]
            
            // Decompress if needed
            let finalData: Data
            if compressionMethod == 8 {
                // Deflate compression
                do {
                    finalData = try decompressDeflate(data: fileData, expectedSize: Int(uncompressedSize))
                } catch {
                    offset = dataEnd
                    continue
                }
            } else if compressionMethod == 0 {
                // Stored (no compression) — Data(fileData) creates a contiguous copy only when needed
                finalData = Data(fileData)
            } else {
                offset = dataEnd
                continue
            }
            
            // Categorize file
            let lowerFileName = fileName.lowercased()
            if lowerFileName == "movie.binary" {
                protobufData = finalData
            } else if lowerFileName.hasSuffix(".png") || lowerFileName.hasSuffix(".jpg") || lowerFileName.hasSuffix(".jpeg") {
                let key = extractImageKey(from: fileName)
                images[key] = finalData
            } else if lowerFileName == "movie.spec" {
                // SVGA 1.x JSON format - not supported
            }
            
            offset = dataEnd
        }
        
        guard let protobuf = protobufData else {
            throw NSError(domain: "SVGAEngine", code: 2001, userInfo: [NSLocalizedDescriptionKey: "No movie.binary found in SVGA archive"])
        }
        
        return ZipExtractResult(protobuf: protobuf, images: images)
    }
    
    private func decompressDeflate<D: DataProtocol>(data: D, expectedSize: Int) throws -> Data {
        // Use Compression framework to decompress raw deflate data.
        // Accept any DataProtocol (Data, Data.SubSequence) to avoid unnecessary copies.
        let contiguousData = Data(data) // Ensure contiguous for withUnsafeBytes
        let bufferSize = max(expectedSize, contiguousData.count * 4)
        
        let outputBuffer = UnsafeMutablePointer<UInt8>.allocate(capacity: bufferSize)
        
        let decompressedSize = contiguousData.withUnsafeBytes { srcPtr -> Int in
            return compression_decode_buffer(
                outputBuffer,
                bufferSize,
                srcPtr.bindMemory(to: UInt8.self).baseAddress!,
                contiguousData.count,
                nil,
                COMPRESSION_ZLIB
            )
        }
        
        if decompressedSize == 0 {
            outputBuffer.deallocate()
            throw NSError(domain: "SVGAEngine", code: 2004, userInfo: [NSLocalizedDescriptionKey: "Deflate decompression failed"])
        }
        
        let result = Data(bytesNoCopy: outputBuffer, count: decompressedSize, deallocator: .custom({ ptr, _ in
            ptr.deallocate()
        }))
        return result
    }
    
    private func extractImageKey(from path: String) -> String {
        // "images/0.png" -> "0"
        // "0.png" -> "0"
        let fileName = (path as NSString).lastPathComponent
        let name = (fileName as NSString).deletingPathExtension
        return name
    }
    
    /// Parse SVGA file from path
    public func parse(filePath: String) throws -> SVGAAnimation {
        let url = URL(fileURLWithPath: filePath)
        let identifier = url.deletingPathExtension().lastPathComponent
        
        // Memory-map file for zero-copy access
        let data = try Data(contentsOf: url, options: [.mappedIfSafe])
        return try parse(data: data, identifier: identifier)
    }
    
    /// Parse with progress callback (for large files)
    public func parseAsync(
        data: Data,
        identifier: String,
        progress: ((Float) -> Void)?,
        completion: @escaping (Result<SVGAAnimation, Error>) -> Void
    ) {
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self = self else {
                completion(.failure(NSError(domain: "SVGAEngine", code: 9002, userInfo: [NSLocalizedDescriptionKey: "Parser deallocated"])))
                return
            }
            
            do {
                let animation = try self.parse(data: data, identifier: identifier)
                DispatchQueue.main.async {
                    completion(.success(animation))
                }
            } catch {
                DispatchQueue.main.async {
                    completion(.failure(error))
                }
            }
        }
    }
    
    // MARK: - Core Parsing
    
    private func parseMovieEntity(
        buffer: UnsafeRawBufferPointer,
        identifier: String,
        externalImages: [String: Data] = [:]
    ) throws -> SVGAAnimation {
        var reader = SVGABinaryReader(buffer: buffer)
        
        var videoSize = CGSize(width: 200, height: 200)
        var frameRate: Int = 20
        var frameCount: Int = 0
        var sprites: [SpriteEntity] = []
        var inlineImages: [String: Data] = [:]
        
        let parseStart = CFAbsoluteTimeGetCurrent()
        
        while reader.hasMore {
            let (fieldNum, wireType) = reader.readTag()
            guard fieldNum > 0 else { break }
            
            switch MovieEntityField(rawValue: fieldNum) {
            case .version:
                _ = reader.readString()
                
            case .params:
                let (size, fps, frames) = try parseMovieParams(reader: &reader)
                videoSize = size
                frameRate = fps
                frameCount = frames
                
            case .images:
                let entry = try parseImageMapEntryCopy(reader: &reader)
                if let (key, data) = entry {
                    inlineImages[key] = data
                }
                
            case .sprites:
                let sprite = try parseSpriteEntity(reader: &reader, frameCount: frameCount)
                sprites.append(sprite)
                
            case .audios:
                reader.skipField(wireType: wireType)
                
            default:
                reader.skipField(wireType: wireType)
            }
        }
        
        statistics.parseTimeMs = (CFAbsoluteTimeGetCurrent() - parseStart) * 1000
        statistics.spriteCount = sprites.count
        statistics.imageCount = inlineImages.count + externalImages.count
        
        // Create animation
        let animation = SVGAAnimation(
            identifier: identifier,
            videoSize: videoSize,
            frameRate: frameRate,
            frameCount: frameCount,
            sprites: sprites
        )
        
        // Store image data - prefer external images (from ZIP), fallback to inline images
        if !externalImages.isEmpty {
            animation.setExternalImageData(externalImages)
        } else if !inlineImages.isEmpty {
            animation.setExternalImageData(inlineImages)
        }
        
        return animation
    }
    
    private func parseMovieParams(reader: inout SVGABinaryReader) throws -> (CGSize, Int, Int) {
        let length = Int(reader.readVarint32())
        let endPosition = reader.position + length
        
        var width: Float = 200
        var height: Float = 200
        var fps: Int = 20
        var frames: Int = 0
        
        while reader.position < endPosition {
            let (fieldNum, wireType) = reader.readTag()
            
            switch MovieParamsField(rawValue: fieldNum) {
            case .viewBoxWidth:
                if wireType == .fixed32 {
                    width = reader.readFloat32LE()
                } else {
                    width = Float(reader.readVarint32())
                }
            case .viewBoxHeight:
                if wireType == .fixed32 {
                    height = reader.readFloat32LE()
                } else {
                    height = Float(reader.readVarint32())
                }
            case .fps:
                fps = Int(reader.readVarint32())
            case .frames:
                frames = Int(reader.readVarint32())
            default:
                reader.skipField(wireType: wireType)
            }
        }
        
        return (CGSize(width: CGFloat(width), height: CGFloat(height)), fps, frames)
    }
    
    /// Parse image map entry and copy data (safe version - data survives after buffer is released)
    private func parseImageMapEntryCopy(
        reader: inout SVGABinaryReader
    ) throws -> (String, Data)? {
        let length = Int(reader.readVarint32())
        let endPosition = reader.position + length
        
        var key: String?
        var imageData: Data?
        
        while reader.position < endPosition {
            let (fieldNum, wireType) = reader.readTag()
            
            switch fieldNum {
            case 1: // key
                key = reader.readString()
            case 2: // value (image data) - copy to Data for safety
                let dataPointer = reader.readBytesPointer()
                if dataPointer.count > 0, let baseAddress = dataPointer.baseAddress {
                    imageData = Data(bytes: baseAddress, count: dataPointer.count)
                }
            default:
                reader.skipField(wireType: wireType)
            }
        }
        
        guard let k = key, let d = imageData else { return nil }
        return (k, d)
    }
    
    private func parseSpriteEntity(
        reader: inout SVGABinaryReader,
        frameCount: Int
    ) throws -> SpriteEntity {
        let length = Int(reader.readVarint32())
        let endPosition = reader.position + length
        
        var imageKey: String?
        var matteKey: String?
        var frames: [SpriteFrame] = []
        frames.reserveCapacity(frameCount)
        
        while reader.position < endPosition {
            let (fieldNum, wireType) = reader.readTag()
            
            switch SpriteEntityField(rawValue: fieldNum) {
            case .imageKey:
                imageKey = reader.readString()
            case .frames:
                let frame = try parseFrameEntity(reader: &reader)
                frames.append(frame)
            case .matteKey:
                matteKey = reader.readString()
            default:
                reader.skipField(wireType: wireType)
            }
        }
        
        return SpriteEntity(
            identifier: imageKey ?? UUID().uuidString,
            imageKey: imageKey,
            matteKey: matteKey,
            frames: frames
        )
    }
    
    private func parseFrameEntity(reader: inout SVGABinaryReader) throws -> SpriteFrame {
        let length = Int(reader.readVarint32())
        let endPosition = reader.position + length
        
        // Empty frame means sprite is HIDDEN
        if length == 0 {
            return SpriteFrame(
                transform: simd_float3x3(1),
                alpha: 0.0,
                clipPath: nil
            )
        }
        
        var alpha: Float = 0.0
        var transform = simd_float3x3(1)
        var layout: CGRect?
        
        var hasTransform = false
        var hasLayout = false
        
        while reader.position < endPosition {
            let (fieldNum, wireType) = reader.readTag()
            
            switch FrameEntityField(rawValue: fieldNum) {
            case .alpha:
                if wireType == .fixed32 {
                    alpha = reader.readFloat32LE()
                } else if wireType == .fixed64 {
                    alpha = Float(reader.readFloat64LE())
                } else {
                    reader.skipField(wireType: wireType)
                }
                
            case .layout:
                layout = try parseLayout(reader: &reader)
                hasLayout = true
                
            case .transform:
                transform = try parseTransform(reader: &reader)
                hasTransform = true
                
            case .clipPath:
                _ = reader.readString()
                
            case .shapes:
                reader.skipField(wireType: wireType)
                
            default:
                reader.skipField(wireType: wireType)
            }
        }
        
        // Combine layout and transform into final 3x3 matrix
        // Maps unit quad (0,0)→(1,1) to final position in parent coordinates
        let finalTransform: simd_float3x3
        
        if hasLayout, let layoutRect = layout {
            let lx = Float(layoutRect.origin.x)
            let ly = Float(layoutRect.origin.y)
            let lw = Float(layoutRect.width)
            let lh = Float(layoutRect.height)
            
            if hasTransform {
                let a = transform[0][0], b = transform[0][1]
                let c = transform[1][0], d = transform[1][1]
                let tx = transform[2][0], ty = transform[2][1]
                
                let originX = a * lx + c * ly + tx
                let originY = b * lx + d * ly + ty
                
                finalTransform = simd_float3x3(
                    SIMD3<Float>(a * lw, b * lw, 0),
                    SIMD3<Float>(c * lh, d * lh, 0),
                    SIMD3<Float>(originX, originY, 1)
                )
            } else {
                finalTransform = simd_float3x3(
                    SIMD3<Float>(lw, 0, 0),
                    SIMD3<Float>(0, lh, 0),
                    SIMD3<Float>(lx, ly, 1)
                )
            }
        } else if hasTransform {
            finalTransform = transform
        } else {
            finalTransform = simd_float3x3(1)
        }
        
        return SpriteFrame(
            transform: finalTransform,
            alpha: alpha,
            clipPath: nil
        )
    }
    
    private func parseTransform(reader: inout SVGABinaryReader) throws -> simd_float3x3 {
        let length = Int(reader.readVarint32())
        let endPosition = reader.position + length
        
        var a: Float = 1, b: Float = 0, c: Float = 0, d: Float = 1
        var tx: Float = 0, ty: Float = 0
        
        while reader.position < endPosition {
            let (fieldNum, wireType) = reader.readTag()
            
            switch TransformField(rawValue: fieldNum) {
            case .a:
                if wireType == .fixed64 { a = Float(reader.readFloat64LE()) }
                else if wireType == .fixed32 { a = reader.readFloat32LE() }
                else { reader.skipField(wireType: wireType) }
            case .b:
                if wireType == .fixed64 { b = Float(reader.readFloat64LE()) }
                else if wireType == .fixed32 { b = reader.readFloat32LE() }
                else { reader.skipField(wireType: wireType) }
            case .c:
                if wireType == .fixed64 { c = Float(reader.readFloat64LE()) }
                else if wireType == .fixed32 { c = reader.readFloat32LE() }
                else { reader.skipField(wireType: wireType) }
            case .d:
                if wireType == .fixed64 { d = Float(reader.readFloat64LE()) }
                else if wireType == .fixed32 { d = reader.readFloat32LE() }
                else { reader.skipField(wireType: wireType) }
            case .tx:
                if wireType == .fixed64 { tx = Float(reader.readFloat64LE()) }
                else if wireType == .fixed32 { tx = reader.readFloat32LE() }
                else { reader.skipField(wireType: wireType) }
            case .ty:
                if wireType == .fixed64 { ty = Float(reader.readFloat64LE()) }
                else if wireType == .fixed32 { ty = reader.readFloat32LE() }
                else { reader.skipField(wireType: wireType) }
            default:
                reader.skipField(wireType: wireType)
            }
        }
        
        return simd_float3x3(
            SIMD3<Float>(a, b, 0),
            SIMD3<Float>(c, d, 0),
            SIMD3<Float>(tx, ty, 1)
        )
    }
    
    private func parseLayout(reader: inout SVGABinaryReader) throws -> CGRect {
        let length = Int(reader.readVarint32())
        let endPosition = reader.position + length
        
        var x: Float = 0, y: Float = 0
        var width: Float = 0, height: Float = 0
        
        while reader.position < endPosition {
            let (fieldNum, wireType) = reader.readTag()
            
            switch LayoutField(rawValue: fieldNum) {
            case .x:
                // Layout fields are float (fixed32) in SVGA proto, but some encoders use double (fixed64)
                if wireType == .fixed32 {
                    x = reader.readFloat32LE()
                } else if wireType == .fixed64 {
                    x = Float(reader.readFloat64LE())
                } else {
                    reader.skipField(wireType: wireType)
                }
            case .y:
                if wireType == .fixed32 {
                    y = reader.readFloat32LE()
                } else if wireType == .fixed64 {
                    y = Float(reader.readFloat64LE())
                } else {
                    reader.skipField(wireType: wireType)
                }
            case .width:
                if wireType == .fixed32 {
                    width = reader.readFloat32LE()
                } else if wireType == .fixed64 {
                    width = Float(reader.readFloat64LE())
                } else {
                    reader.skipField(wireType: wireType)
                }
            case .height:
                if wireType == .fixed32 {
                    height = reader.readFloat32LE()
                } else if wireType == .fixed64 {
                    height = Float(reader.readFloat64LE())
                } else {
                    reader.skipField(wireType: wireType)
                }
            default:
                reader.skipField(wireType: wireType)
            }
        }
        
        return CGRect(x: CGFloat(x), y: CGFloat(y), width: CGFloat(width), height: CGFloat(height))
    }
    
    // MARK: - Statistics
    
    public struct ParseStatistics {
        public var decompressTimeMs: Double = 0
        public var parseTimeMs: Double = 0
        public var totalTimeMs: Double = 0
        public var spriteCount: Int = 0
        public var imageCount: Int = 0
        public var totalFrameCount: Int = 0
        
        public var description: String {
            """
            SVGA Parse Statistics:
            - Decompress: \(String(format: "%.2f", decompressTimeMs))ms
            - Parse: \(String(format: "%.2f", parseTimeMs))ms
            - Total: \(String(format: "%.2f", totalTimeMs))ms
            - Sprites: \(spriteCount)
            - Images: \(imageCount)
            """
        }
    }
}

// MARK: - SVGAAnimation Extension for Image Data

extension SVGAAnimation {
    
    /// Internal storage for external image data (from ZIP)
    private static var externalImageDataKey: UInt8 = 0
    
    /// Set external image data (from ZIP archive or inline protobuf images)
    func setExternalImageData(_ images: [String: Data]) {
        objc_setAssociatedObject(
            self,
            &SVGAAnimation.externalImageDataKey,
            images,
            .OBJC_ASSOCIATION_RETAIN_NONATOMIC
        )
    }
    
    /// Get external image data (from ZIP archive)
    public var externalImageData: [String: Data]? {
        objc_getAssociatedObject(self, &SVGAAnimation.externalImageDataKey) as? [String: Data]
    }
}

// MARK: - SVGALazyMovieEntity

/// Lazy-loading movie entity that only parses fields on demand
/// Inspired by FlatBuffers accessor pattern
public final class SVGALazyMovieEntity {
    
    // MARK: - Properties
    
    private let buffer: Data
    private let accessor: SVGAProtoFieldAccessor
    
    // Cached values
    private var _params: SVGALazyMovieParams?
    private var _sprites: [SVGALazySpriteEntity]?
    
    // MARK: - Initialization
    
    public init(buffer: Data) {
        self.buffer = buffer
        self.accessor = buffer.withUnsafeBytes { ptr in
            SVGAProtoFieldAccessor(buffer: ptr)
        }
    }
    
    // MARK: - Lazy Accessors
    
    public var version: Int {
        Int(accessor.readVarint(1) ?? 1)
    }
    
    public var params: SVGALazyMovieParams? {
        if let cached = _params { return cached }
        
        guard let ptr = accessor.readBytesPointer(2) else { return nil }
        let params = SVGALazyMovieParams(buffer: ptr)
        _params = params
        return params
    }
    
    public var spriteCount: Int {
        // Count sprite fields (field number 4)
        var count = 0
        buffer.withUnsafeBytes { ptr in
            var reader = SVGABinaryReader(buffer: ptr)
            while reader.hasMore {
                let (fieldNum, wireType) = reader.readTag()
                if fieldNum == 4 {
                    count += 1
                }
                reader.skipField(wireType: wireType)
            }
        }
        return count
    }
}

// MARK: - SVGALazyMovieParams

public struct SVGALazyMovieParams {
    private let accessor: SVGAProtoFieldAccessor
    
    init(buffer: UnsafeRawBufferPointer) {
        self.accessor = SVGAProtoFieldAccessor(buffer: buffer)
    }
    
    public var viewBoxWidth: Float {
        Float(accessor.readVarint(1) ?? 200)
    }
    
    public var viewBoxHeight: Float {
        Float(accessor.readVarint(2) ?? 200)
    }
    
    public var fps: Int {
        Int(accessor.readVarint(3) ?? 20)
    }
    
    public var frames: Int {
        Int(accessor.readVarint(4) ?? 0)
    }
}

// MARK: - SVGALazySpriteEntity

public struct SVGALazySpriteEntity {
    private let accessor: SVGAProtoFieldAccessor
    
    init(buffer: UnsafeRawBufferPointer) {
        self.accessor = SVGAProtoFieldAccessor(buffer: buffer)
    }
    
    public var imageKey: String? {
        accessor.readString(1)
    }
    
    public var matteKey: String? {
        accessor.readString(3)
    }
    
    public var frameCount: Int {
        // Count frame fields
        var count = 0
        // Implementation would iterate through fields
        return count
    }
}
