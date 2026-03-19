//
//  SVGAParser.swift
//  TUILiveKit
//
//  Created on 2026/2/5.
//  High-Performance SVGA Player Core
//
//  Main parser entry point with cache integration
//

import Foundation

// MARK: - SVGAParser

/// High-performance SVGA parser with automatic caching
public final class SVGAParser {
    public func cancelAll() {
        
    }


    
    // MARK: - Configuration
    
    /// Parser configuration
    public struct Configuration {
        /// Enable binary cache
        public var enableCache: Bool = true
        
        /// Cache directory (nil = use default)
        public var cacheDirectory: URL?
        
        /// Maximum memory for decompression buffer
        public var maxDecompressionBuffer: Int = 32 * 1024 * 1024  // 32MB
        
        /// Enable lazy parsing (only parse on demand)
        public var enableLazyParsing: Bool = false
        
        /// Timeout for async operations
        public var timeout: TimeInterval = 30.0
        
        public init() {}
        
        public static let `default` = Configuration()
    }
    
    // MARK: - Properties
    
    /// Parser configuration
    public let configuration: Configuration
    
    /// Proto parser
    private let protoParser: SVGAProtoParser
    
    /// Cache manager
    private let cacheManager: SVGACacheManager
    
    /// Statistics
    public private(set) var lastParseStatistics: SVGAProtoParser.ParseStatistics?
    
    /// Active parse tasks (for cancellation)
    private var activeTasks: [String: DispatchWorkItem] = [:]
    private let taskLock = NSLock()
    
    // MARK: - Initialization
    
    public init(configuration: Configuration = .default) {
        self.configuration = configuration
        self.protoParser = SVGAProtoParser()
        self.cacheManager = SVGACacheManager.shared
    }
    
    // MARK: - Parse API
    
    /// Parse SVGA from local file path
    public func parse(
        from path: String,
        completion: @escaping (Result<SVGAAnimation, Error>) -> Void
    ) {
        let url = URL(fileURLWithPath: path)
        let identifier = url.deletingPathExtension().lastPathComponent
        
        parseAsync(identifier: identifier) {
            let data = try Data(contentsOf: url, options: [.mappedIfSafe])
            return data
        } completion: { result in
            switch result {
            case .success(let animation):
                completion(.success(animation))
            case .failure(let error):
                completion(.failure(error))
            }
        }
    }
    
    /// Parse SVGA from Data
    public func parse(
        from data: Data,
        cacheKey: String,
        completion: @escaping (Result<SVGAAnimation, Error>) -> Void
    ) {
        parseAsync(identifier: cacheKey) {
            data
        } completion: { result in
            switch result {
            case .success(let animation):
                completion(.success(animation))
            case .failure(let error):
                completion(.failure(error))
            }
        }
    }
    
    /// Parse SVGA from local file path (legacy API)
    public func parse(
        filePath: String,
        completion: @escaping (Result<SVGAAnimation, Error>) -> Void
    ) {
        parse(from: filePath) { result in
            switch result {
            case .success(let animation):
                completion(.success(animation))
            case .failure(let error):
                completion(.failure(error))
            }
        }
    }
    
    /// Parse SVGA from Data (legacy API)
    public func parse(
        data: Data,
        cacheKey: String,
        completion: @escaping (Result<SVGAAnimation, Error>) -> Void
    ) {
        parse(from: data, cacheKey: cacheKey) { result in
            switch result {
            case .success(let animation):
                completion(.success(animation))
            case .failure(let error):
                completion(.failure(error))
            }
        }
    }
    
    /// Clear parser cache
    public func clearCache() {
        try? cacheManager.clearAll()
    }
    
    /// Cancel ongoing parse operation
    public func cancelParse(identifier: String) {
        taskLock.lock()
        activeTasks[identifier]?.cancel()
        activeTasks.removeValue(forKey: identifier)
        taskLock.unlock()
    }
    
    // MARK: - Synchronous API
    
    /// Parse SVGA data synchronously
    /// - Parameters:
    ///   - data: SVGA file data
    ///   - identifier: Cache key
    /// - Returns: Parsed animation (with externalImageData attached)
    public func parseSync(data: Data, identifier: String) throws -> SVGAAnimation {
        // Always do full parse — the binary cache only stores sprite/frame transforms,
        // but we need the image data for texture atlas building.
        // The proto parser is already fast (~50ms for decompression + parse);
        // the real bottleneck is CGImage decode + texture upload which happens later.
        let animation = try protoParser.parse(data: data, identifier: identifier)
        lastParseStatistics = protoParser.statistics
        return animation
    }
    
    /// Parse from file synchronously
    public func parseSync(filePath: String) throws -> SVGAAnimation {
        let url = URL(fileURLWithPath: filePath)
        let identifier = url.deletingPathExtension().lastPathComponent
        let data = try Data(contentsOf: url, options: [.mappedIfSafe])
        return try parseSync(data: data, identifier: identifier)
    }
    
    // MARK: - Private Methods
    
    private func parseAsync(
        identifier: String,
        dataProvider: @escaping () throws -> Data,
        completion: @escaping (Result<SVGAAnimation, Error>) -> Void
    ) {
        let workItem = DispatchWorkItem { [weak self] in
            guard let self = self else {
                completion(.failure(NSError(domain: "SVGAEngine", code: 9002, userInfo: [NSLocalizedDescriptionKey: "Parser deallocated"])))
                return
            }
            
            do {
                let data = try dataProvider()
                let animation = try self.parseSync(data: data, identifier: identifier)
                
                DispatchQueue.main.async {
                    completion(.success(animation))
                }
            } catch {
                DispatchQueue.main.async {
                    completion(.failure(error))
                }
            }
            
            // Remove from active tasks
            self.taskLock.lock()
            self.activeTasks.removeValue(forKey: identifier)
            self.taskLock.unlock()
        }
        
        // Register task
        taskLock.lock()
        activeTasks[identifier] = workItem
        taskLock.unlock()
        
        // Execute on background queue
        DispatchQueue.global(qos: .userInitiated).async(execute: workItem)
    }
}

// MARK: - SVGAParser + Preloading

extension SVGAParser {
    
    /// Preload SVGA files into cache
    /// - Parameters:
    ///   - filePaths: Array of file paths to preload
    ///   - progress: Progress callback (0.0 - 1.0)
    ///   - completion: Completion callback with success count
    public func preload(
        filePaths: [String],
        progress: ((Float) -> Void)? = nil,
        completion: @escaping (Int) -> Void
    ) {
        DispatchQueue.global(qos: .utility).async { [weak self] in
            guard let self = self else {
                completion(0)
                return
            }
            
            var successCount = 0
            let total = filePaths.count
            
            for (index, path) in filePaths.enumerated() {
                autoreleasepool {
                    do {
                        let url = URL(fileURLWithPath: path)
                        let identifier = url.deletingPathExtension().lastPathComponent
                        let data = try Data(contentsOf: url, options: [.mappedIfSafe])
                        
                        _ = try self.cacheManager.getOrCreate(data: data, identifier: identifier)
                        successCount += 1
                    } catch {
                        // Log error but continue
                        print("[SVGAParser] Preload failed for \(path): \(error)")
                    }
                    
                    progress?(Float(index + 1) / Float(total))
                }
            }
            
            DispatchQueue.main.async {
                completion(successCount)
            }
        }
    }
    
    /// Check if animation is cached
    public func isCached(identifier: String) -> Bool {
        let cache = SVGABinaryCache(cacheDirectory: cacheManager.cacheDirectory, identifier: identifier)
        return FileManager.default.fileExists(atPath: cache.cacheURL.path)
    }
}

// MARK: - SVGAParser + Streaming

extension SVGAParser {
    
    /// Parse SVGA with streaming progress
    /// Useful for very large files
    public func parseStreaming(
        filePath: String,
        onProgress: @escaping (SVGAParseProgress) -> Void,
        completion: @escaping (Result<SVGAAnimation, Error>) -> Void
    ) {
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self = self else {
                completion(.failure(NSError(domain: "SVGAEngine", code: 9002, userInfo: [NSLocalizedDescriptionKey: "Parser deallocated"])))
                return
            }
            
            do {
                let url = URL(fileURLWithPath: filePath)
                let identifier = url.deletingPathExtension().lastPathComponent
                
                // Report loading start
                DispatchQueue.main.async {
                    onProgress(SVGAParseProgress(stage: .loading, progress: 0))
                }
                
                // Load file
                let data = try Data(contentsOf: url, options: [.mappedIfSafe])
                
                DispatchQueue.main.async {
                    onProgress(SVGAParseProgress(stage: .loading, progress: 1.0))
                    onProgress(SVGAParseProgress(stage: .decompressing, progress: 0))
                }
                
                // Parse with cache
                let animation = try self.parseSync(data: data, identifier: identifier)
                
                DispatchQueue.main.async {
                    onProgress(SVGAParseProgress(stage: .parsing, progress: 1.0))
                    onProgress(SVGAParseProgress(stage: .complete, progress: 1.0))
                    completion(.success(animation))
                }
            } catch {
                DispatchQueue.main.async {
                    completion(.failure(error))
                }
            }
        }
    }
}

// MARK: - SVGAParseProgress

/// Progress information during SVGA parsing
public struct SVGAParseProgress {
    
    /// Parse stage
    public enum Stage {
        case loading
        case decompressing
        case parsing
        case building
        case complete
        
        public var displayName: String {
            switch self {
            case .loading: return "Loading"
            case .decompressing: return "Decompressing"
            case .parsing: return "Parsing"
            case .building: return "Building"
            case .complete: return "Complete"
            }
        }
    }
    
    public let stage: Stage
    public let progress: Float  // 0.0 - 1.0
    
    public var overallProgress: Float {
        switch stage {
        case .loading: return progress * 0.1
        case .decompressing: return 0.1 + progress * 0.3
        case .parsing: return 0.4 + progress * 0.4
        case .building: return 0.8 + progress * 0.2
        case .complete: return 1.0
        }
    }
}

// MARK: - SVGAParser + Validation

extension SVGAParser {
    
    /// Validate SVGA file without full parsing
    /// - Parameter filePath: Path to SVGA file
    /// - Returns: Validation result with basic info
    public func validate(filePath: String) -> SVGAValidationResult {
        do {
            let url = URL(fileURLWithPath: filePath)
            let data = try Data(contentsOf: url, options: [.mappedIfSafe])
            return validate(data: data)
        } catch {
            return SVGAValidationResult(isValid: false, error: error)
        }
    }
    
    /// Validate SVGA data
    public func validate(data: Data) -> SVGAValidationResult {
        // Check minimum size
        guard data.count > 10 else {
            return SVGAValidationResult(
                isValid: false,
                error: NSError(domain: "SVGAEngine", code: 1003, userInfo: [NSLocalizedDescriptionKey: "File too small"])
            )
        }
        
        // Check for zlib header (0x78)
        let isCompressed = data.withUnsafeBytes { ptr -> Bool in
            let firstByte = ptr.load(as: UInt8.self)
            return firstByte == 0x78
        }
        
        return SVGAValidationResult(
            isValid: true,
            isCompressed: isCompressed,
            fileSize: data.count
        )
    }
}

/// Validation result
public struct SVGAValidationResult {
    public let isValid: Bool
    public var isCompressed: Bool = false
    public var fileSize: Int = 0
    public var error: Error?
    public var videoSize: CGSize?
    public var frameCount: Int?
    public var spriteCount: Int?
}
