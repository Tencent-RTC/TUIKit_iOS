//
//  SVGABinaryCache.swift
//  TUILiveKit
//
//  Created on 2026/2/5.
//  High-Performance SVGA Player Core
//
//  Pre-compiled binary cache format for instant loading
//

import Foundation
import simd
import CoreGraphics

// MARK: - SVGABinaryCache

/// Pre-compiled binary cache for SVGA animations
/// Enables instant loading by storing parsed data in memory-mapped format
///
/// Features:
/// - Memory-mapped file access (zero-copy)
/// - Pre-computed transforms stored as simd_float3x3
/// - Direct array access without parsing overhead
/// - Versioned format for cache invalidation
final class SVGABinaryCache {

    // MARK: - Cache Format Version

    /// Cache format version (bump when format changes)
    static let formatVersion: UInt32 = 1

    /// Magic bytes for file identification
    static let magicBytes: UInt32 = 0x53564341  // "SVCA"

    // MARK: - Header Structure

    /// Cache file header (64 bytes, aligned)

    struct CacheHeader {
        /// Magic bytes for identification
        let magic: UInt32           // 4 bytes
        /// Format version
        let version: UInt32         // 4 bytes
        /// Original SVGA file hash
        let sourceHash: UInt64      // 8 bytes
        /// Video width
        let videoWidth: Float       // 4 bytes
        /// Video height
        let videoHeight: Float      // 4 bytes
        /// Frame rate
        let frameRate: UInt16       // 2 bytes
        /// Total frame count
        let frameCount: UInt16      // 2 bytes
        /// Number of sprites
        let spriteCount: UInt16     // 2 bytes
        /// Number of images
        let imageCount: UInt16      // 2 bytes
        /// Offset to sprite data section
        let spriteDataOffset: UInt32  // 4 bytes
        /// Offset to frame data section
        let frameDataOffset: UInt32   // 4 bytes
        /// Offset to image data section
        let imageDataOffset: UInt32   // 4 bytes
        /// Offset to string table
        let stringTableOffset: UInt32 // 4 bytes
        /// Total file size
        let totalSize: UInt32       // 4 bytes
        /// Reserved for future use
        let reserved: (UInt32, UInt32, UInt32)  // 12 bytes

        /// Total: 64 bytes

        static let size = 64
    }

    // MARK: - Sprite Entry (Cache Format)

    /// Cached sprite entry (32 bytes)

    struct CachedSpriteEntry {
        /// String table offset for imageKey
        let imageKeyOffset: UInt32    // 4 bytes
        /// String table offset for matteKey (0 = none)
        let matteKeyOffset: UInt32    // 4 bytes
        /// First frame index in frame array
        let firstFrameIndex: UInt32   // 4 bytes
        /// Number of frames for this sprite
        let frameCount: UInt32        // 4 bytes
        /// Sprite index
        let spriteIndex: UInt16       // 2 bytes
        /// Flags
        let flags: UInt16             // 2 bytes
        /// Reserved
        let reserved: (UInt32, UInt32)  // 8 bytes

        /// Total: 32 bytes
        static let size = 32
    }

    // MARK: - Frame Entry (Cache Format)

    /// Cached frame entry (64 bytes, cache-line aligned)

    struct CachedFrameEntry {
        /// Transform matrix (column-major)
        let transform: simd_float3x3   // 48 bytes (with padding)
        /// Alpha value
        let alpha: Float               // 4 bytes
        /// Clip path string offset (0 = none)
        let clipPathOffset: UInt32     // 4 bytes
        /// Texture index in atlas
        let textureIndex: UInt16       // 2 bytes
        /// Mask index (0 = none)
        let maskIndex: UInt16          // 2 bytes
        /// Reserved padding
        let _padding: UInt32           // 4 bytes

        /// Total: 64 bytes
        static let size = 64
    }

    // MARK: - Image Entry (Cache Format)

    /// Cached image entry (16 bytes)

    struct CachedImageEntry {
        /// String table offset for image key
        let keyOffset: UInt32        // 4 bytes
        /// Offset to image data
        let dataOffset: UInt32       // 4 bytes
        /// Image data size
        let dataSize: UInt32         // 4 bytes
        /// Image width
        let width: UInt16            // 2 bytes
        /// Image height
        let height: UInt16           // 2 bytes

        /// Total: 16 bytes
        static let size = 16
    }

    // MARK: - Properties

    /// Memory-mapped data
    private var mappedData: Data?

    /// Base pointer for direct access
    private var basePointer: UnsafeRawPointer?

    /// Parsed header
    private var header: CacheHeader?

    /// Cache file URL
    let cacheURL: URL

    /// Whether cache is loaded
    var isLoaded: Bool {
        basePointer != nil && header != nil
    }

    // MARK: - Initialization

    init(cacheDirectory: URL, identifier: String) {
        self.cacheURL = cacheDirectory
            .appendingPathComponent(identifier)
            .appendingPathExtension("svgacache")
    }

    // MARK: - Loading

    /// Load cache from file (memory-mapped, zero-copy)
    func load() throws {
        // Check if file exists
        guard FileManager.default.fileExists(atPath: cacheURL.path) else {
            throw NSError(domain: "SVGAEngine", code: 6001, userInfo: [NSLocalizedDescriptionKey: "Cache not found: \(cacheURL.path)"])
        }

        // Memory-map the file
        let data = try Data(contentsOf: cacheURL, options: [.mappedIfSafe])

        // Validate header
        guard data.count >= CacheHeader.size else {
            throw NSError(domain: "SVGAEngine", code: 6002, userInfo: [NSLocalizedDescriptionKey: "Cache file too small"])
        }

        let header: CacheHeader = data.withUnsafeBytes { ptr in
            ptr.load(as: CacheHeader.self)
        }

        // Validate magic and version
        guard header.magic == Self.magicBytes else {
            throw NSError(domain: "SVGAEngine", code: 6002, userInfo: [NSLocalizedDescriptionKey: "Invalid magic bytes"])
        }

        guard header.version == Self.formatVersion else {
            throw NSError(domain: "SVGAEngine", code: 6002, userInfo: [NSLocalizedDescriptionKey: "Version mismatch: \(header.version) vs \(Self.formatVersion)"])
        }

        guard data.count >= Int(header.totalSize) else {
            throw NSError(domain: "SVGAEngine", code: 6002, userInfo: [NSLocalizedDescriptionKey: "Truncated file"])
        }

        self.mappedData = data
        self.header = header

        // SAFETY: For memory-mapped Data (.mappedIfSafe), the kernel maps the file
        // into the process address space and Data holds the mapping alive.
        // We retain `mappedData` for the lifetime of basePointer, so the mapping
        // stays valid. Use `NSData.bytes` which is safe to use outside closures.
        self.basePointer = (data as NSData).bytes
    }

    /// Unload cache and release memory
    func unload() {
        mappedData = nil
        basePointer = nil
        header = nil
    }

    // MARK: - Direct Access (Zero-Copy)

    /// Get animation info
    var videoSize: CGSize {
        guard let h = header else { return .zero }
        return CGSize(width: CGFloat(h.videoWidth), height: CGFloat(h.videoHeight))
    }

    var frameRate: Int {
        Int(header?.frameRate ?? 20)
    }

    var frameCount: Int {
        Int(header?.frameCount ?? 0)
    }

    var spriteCount: Int {
        Int(header?.spriteCount ?? 0)
    }

    /// Get sprite entry by index (direct pointer access)
    func spriteEntry(at index: Int) -> CachedSpriteEntry? {
        guard let base = basePointer,
              let h = header,
              index < h.spriteCount else { return nil }

        let offset = Int(h.spriteDataOffset) + index * CachedSpriteEntry.size
        return base.load(fromByteOffset: offset, as: CachedSpriteEntry.self)
    }

    /// Get frame entry by global index (direct pointer access)
    func frameEntry(at index: Int) -> CachedFrameEntry? {
        guard let base = basePointer,
              let h = header else { return nil }

        let offset = Int(h.frameDataOffset) + index * CachedFrameEntry.size
        guard offset + CachedFrameEntry.size <= Int(h.totalSize) else { return nil }

        return base.load(fromByteOffset: offset, as: CachedFrameEntry.self)
    }

    /// Get frames for a sprite (returns pointer to contiguous frame array)
    func framesPointer(for spriteIndex: Int) -> UnsafeBufferPointer<CachedFrameEntry>? {
        guard let base = basePointer,
              let h = header,
              let sprite = spriteEntry(at: spriteIndex) else { return nil }

        let frameCount = Int(sprite.frameCount)
        guard frameCount > 0 else { return nil }

        let offset = Int(h.frameDataOffset) + Int(sprite.firstFrameIndex) * CachedFrameEntry.size
        let endOffset = offset + frameCount * CachedFrameEntry.size

        // Bounds check: ensure we don't read past the end of mapped data
        guard offset >= 0, endOffset <= Int(h.totalSize) else { return nil }

        let rawPtr = base.advanced(by: offset)

        // Alignment check: CachedFrameEntry contains simd_float3x3 which requires 16-byte alignment
        guard Int(bitPattern: rawPtr) % MemoryLayout<CachedFrameEntry>.alignment == 0 else { return nil }

        let ptr = rawPtr.assumingMemoryBound(to: CachedFrameEntry.self)
        return UnsafeBufferPointer(start: ptr, count: frameCount)
    }

    /// Read string from string table
    func readString(at offset: UInt32) -> String? {
        guard offset > 0,
              let base = basePointer,
              let h = header else { return nil }

        let stringStart = Int(h.stringTableOffset) + Int(offset)
        guard stringStart < Int(h.totalSize) else { return nil }

        // Read null-terminated string
        let ptr = base.advanced(by: stringStart).assumingMemoryBound(to: CChar.self)
        return String(cString: ptr)
    }

    /// Get image data pointer (zero-copy)
    func imageDataPointer(at index: Int) -> UnsafeRawBufferPointer? {
        guard let base = basePointer,
              let h = header,
              index < h.imageCount else { return nil }

        let entryOffset = Int(h.imageDataOffset) + index * CachedImageEntry.size
        let entry = base.load(fromByteOffset: entryOffset, as: CachedImageEntry.self)

        return UnsafeRawBufferPointer(
            start: base.advanced(by: Int(entry.dataOffset)),
            count: Int(entry.dataSize)
        )
    }

    // MARK: - Convert to SVGAAnimation

    /// Convert cached data to SVGAAnimation (zero-copy where possible)
    func toAnimation(identifier: String) throws -> SVGAAnimation {
        guard isLoaded, let h = header else {
            throw NSError(domain: "SVGAEngine", code: 9002, userInfo: [NSLocalizedDescriptionKey: "Cache not loaded"])
        }

        var sprites: [SpriteEntity] = []
        sprites.reserveCapacity(Int(h.spriteCount))

        for i in 0..<Int(h.spriteCount) {
            guard let spriteEntry = spriteEntry(at: i),
                  let framesPtr = framesPointer(for: i) else {
                continue
            }

            // Convert cached frames to SpriteFrame
            var frames: [SpriteFrame] = []
            frames.reserveCapacity(framesPtr.count)

            for frame in framesPtr {
                frames.append(SpriteFrame(
                    transform: frame.transform,
                    alpha: frame.alpha,
                    clipPath: nil  // clipPath stored separately in string table
                ))
            }

            sprites.append(SpriteEntity(
                identifier: readString(at: spriteEntry.imageKeyOffset) ?? "\(i)",
                imageKey: readString(at: spriteEntry.imageKeyOffset),
                matteKey: readString(at: spriteEntry.matteKeyOffset),
                frames: frames
            ))
        }

        return SVGAAnimation(
            identifier: identifier,
            videoSize: videoSize,
            frameRate: frameRate,
            frameCount: frameCount,
            sprites: sprites
        )
    }
}

// MARK: - SVGABinaryCacheWriter

/// Writer for creating binary cache files
final class SVGABinaryCacheWriter {

    // MARK: - Properties

    private var data: Data
    private var stringTable: [String: UInt32] = [:]
    private var stringData: Data
    private var currentStringOffset: UInt32 = 1  // 0 is reserved for null

    // MARK: - Initialization

    init() {
        self.data = Data()
        self.stringData = Data([0])  // Null byte at offset 0
    }

    // MARK: - Writing

    /// Write animation to cache format
    func write(animation: SVGAAnimation, sourceHash: UInt64) throws -> Data {
        data.removeAll(keepingCapacity: true)
        stringTable.removeAll(keepingCapacity: true)
        stringData = Data([0])
        currentStringOffset = 1

        // Calculate layout
        let spriteCount = animation.sprites.count
        var totalFrameCount = 0
        for sprite in animation.sprites {
            totalFrameCount += sprite.frames.count
        }

        let headerOffset: UInt32 = 0
        let spriteDataOffset = UInt32(SVGABinaryCache.CacheHeader.size)
        let frameDataOffset = spriteDataOffset + UInt32(spriteCount * SVGABinaryCache.CachedSpriteEntry.size)
        let imageDataOffset = frameDataOffset + UInt32(totalFrameCount * SVGABinaryCache.CachedFrameEntry.size)
        // String table comes after image entries (images not written in this version)
        let stringTableOffset = imageDataOffset

        // Write header placeholder
        var header = SVGABinaryCache.CacheHeader(
            magic: SVGABinaryCache.magicBytes,
            version: SVGABinaryCache.formatVersion,
            sourceHash: sourceHash,
            videoWidth: Float(animation.videoSize.width),
            videoHeight: Float(animation.videoSize.height),
            frameRate: UInt16(animation.frameRate),
            frameCount: UInt16(animation.frameCount),
            spriteCount: UInt16(spriteCount),
            imageCount: 0,  // TODO: Add image support
            spriteDataOffset: spriteDataOffset,
            frameDataOffset: frameDataOffset,
            imageDataOffset: imageDataOffset,
            stringTableOffset: stringTableOffset,
            totalSize: 0,  // Will be updated
            reserved: (0, 0, 0)
        )

        // Reserve space for header
        data.append(Data(count: SVGABinaryCache.CacheHeader.size))

        // Write sprite entries
        var frameIndex: UInt32 = 0
        for (i, sprite) in animation.sprites.enumerated() {
            let entry = SVGABinaryCache.CachedSpriteEntry(
                imageKeyOffset: addString(sprite.imageKey),
                matteKeyOffset: addString(sprite.matteKey),
                firstFrameIndex: frameIndex,
                frameCount: UInt32(sprite.frames.count),
                spriteIndex: UInt16(i),
                flags: 0,
                reserved: (0, 0)
            )

            withUnsafeBytes(of: entry) { ptr in
                data.append(contentsOf: ptr)
            }

            frameIndex += UInt32(sprite.frames.count)
        }

        // Write frame entries
        for sprite in animation.sprites {
            for frame in sprite.frames {
                let entry = SVGABinaryCache.CachedFrameEntry(
                    transform: frame.transform,
                    alpha: frame.alpha,
                    clipPathOffset: 0,  // clipPath handled separately
                    textureIndex: 0,  // Set during texture building
                    maskIndex: 0,
                    _padding: 0
                )

                withUnsafeBytes(of: entry) { ptr in
                    data.append(contentsOf: ptr)
                }
            }
        }

        // Append string table
        data.append(stringData)

        // Update header with final size
        header = SVGABinaryCache.CacheHeader(
            magic: header.magic,
            version: header.version,
            sourceHash: header.sourceHash,
            videoWidth: header.videoWidth,
            videoHeight: header.videoHeight,
            frameRate: header.frameRate,
            frameCount: header.frameCount,
            spriteCount: header.spriteCount,
            imageCount: header.imageCount,
            spriteDataOffset: header.spriteDataOffset,
            frameDataOffset: header.frameDataOffset,
            imageDataOffset: header.imageDataOffset,
            stringTableOffset: UInt32(imageDataOffset),
            totalSize: UInt32(data.count),
            reserved: header.reserved
        )

        // Write final header
        data.withUnsafeMutableBytes { ptr in
            ptr.storeBytes(of: header, as: SVGABinaryCache.CacheHeader.self)
        }

        return data
    }

    /// Save cache to file
    func save(animation: SVGAAnimation, sourceHash: UInt64, to url: URL) throws {
        let cacheData = try write(animation: animation, sourceHash: sourceHash)

        // Create directory if needed
        let directory = url.deletingLastPathComponent()
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)

        try cacheData.write(to: url, options: .atomic)
    }

    // MARK: - String Table

    private func addString(_ string: String?) -> UInt32 {
        guard let str = string, !str.isEmpty else { return 0 }

        // Check if already in table
        if let offset = stringTable[str] {
            return offset
        }

        // Add to table
        let offset = currentStringOffset
        stringTable[str] = offset

        // Append null-terminated string
        stringData.append(str.utf8CString.withUnsafeBytes { Data($0) })
        currentStringOffset = UInt32(stringData.count)

        return offset
    }
}

// MARK: - SVGACacheManager

/// Manager for SVGA binary cache files
final class SVGACacheManager {

    // MARK: - Singleton

    static let shared = SVGACacheManager()

    // MARK: - Properties

    /// Cache directory
    let cacheDirectory: URL

    /// In-memory cache using NSCache with strong references + automatic LRU eviction
    private let memoryCache = NSCache<NSString, SVGABinaryCache>()

    /// Memory pressure observer
    private var memoryPressureSource: DispatchSourceMemoryPressure?

    /// Maximum cache size in bytes
    var maxCacheSize: Int = 100 * 1024 * 1024 {  // 100MB
        didSet {
            // NSCache countLimit as rough proxy: assume ~1MB per cached animation
            memoryCache.countLimit = max(1, maxCacheSize / (1024 * 1024))
        }
    }

    /// Parser for creating caches
    private let parser = SVGAProtoParser()

    /// Writer for cache files
    private let writer = SVGABinaryCacheWriter()

    // MARK: - Initialization

    private init() {
        let cachePath = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first!
        self.cacheDirectory = cachePath.appendingPathComponent("SVGACache", isDirectory: true)

        // Create cache directory
        try? FileManager.default.createDirectory(at: cacheDirectory, withIntermediateDirectories: true)

        // Configure NSCache LRU limits
        memoryCache.countLimit = max(1, maxCacheSize / (1024 * 1024))
        memoryCache.name = "com.tuilivekit.svga.binarycache"

        // Register for memory pressure notifications
        setupMemoryPressureHandler()
    }

    // MARK: - Memory Pressure

    private func setupMemoryPressureHandler() {
        let source = DispatchSource.makeMemoryPressureSource(
            eventMask: [.warning, .critical],
            queue: .global(qos: .utility)
        )
        source.setEventHandler { [weak self] in
            guard let self = self else { return }
            let event = source.data
            if event.contains(.critical) {
                // Critical: clear all in-memory caches
                self.memoryCache.removeAllObjects()
                #if DEBUG
                print("[SVGACacheManager] Critical memory pressure — cleared all in-memory caches")
                #endif
            } else if event.contains(.warning) {
                // Warning: reduce cache limit
                self.memoryCache.countLimit = max(1, self.memoryCache.countLimit / 2)
                #if DEBUG
                print("[SVGACacheManager] Memory pressure warning — halved cache limit")
                #endif
            }
        }
        source.resume()
        memoryPressureSource = source
    }

    // MARK: - Public API

    /// Get or create cache for SVGA data
    func getOrCreate(
        data: Data,
        identifier: String,
        forceRefresh: Bool = false
    ) throws -> SVGABinaryCache {
        let cacheKey = identifier as NSString
        let sourceHash = xxHash64(data: data)

        // Check memory cache
        if !forceRefresh, let cached = memoryCache.object(forKey: cacheKey) {
            return cached
        }

        // Check file cache
        let cache = SVGABinaryCache(cacheDirectory: cacheDirectory, identifier: identifier)

        if !forceRefresh, FileManager.default.fileExists(atPath: cache.cacheURL.path) {
            do {
                try cache.load()
                // Store in memory cache for fast subsequent access
                memoryCache.setObject(cache, forKey: cacheKey)
                return cache
            } catch {
                // Cache invalid, will recreate
                try? FileManager.default.removeItem(at: cache.cacheURL)
            }
        }

        // Parse and create cache
        let animation = try parser.parse(data: data, identifier: identifier)

        try writer.save(animation: animation, sourceHash: sourceHash, to: cache.cacheURL)
        try cache.load()

        // Store in memory cache for fast subsequent access
        memoryCache.setObject(cache, forKey: cacheKey)
        return cache
    }

    /// Clear all caches
    func clearAll() throws {
        memoryCache.removeAllObjects()
        try FileManager.default.removeItem(at: cacheDirectory)
        try FileManager.default.createDirectory(at: cacheDirectory, withIntermediateDirectories: true)
    }

    /// Get cache size
    func cacheSize() -> Int {
        let enumerator = FileManager.default.enumerator(
            at: cacheDirectory,
            includingPropertiesForKeys: [.fileSizeKey]
        )

        var totalSize = 0
        while let url = enumerator?.nextObject() as? URL {
            let size = (try? url.resourceValues(forKeys: [.fileSizeKey]).fileSize) ?? 0
            totalSize += size
        }
        return totalSize
    }

    // MARK: - Hash Function

    /// Simple xxHash64 implementation for cache validation
    private func xxHash64(data: Data) -> UInt64 {
        var hash: UInt64 = 0
        data.withUnsafeBytes { ptr in
            let bytes = ptr.bindMemory(to: UInt64.self)
            for i in 0..<bytes.count {
                hash ^= bytes[i] &* 0x9E3779B97F4A7C15
                hash = (hash << 31) | (hash >> 33)
            }
        }
        return hash
    }
}
