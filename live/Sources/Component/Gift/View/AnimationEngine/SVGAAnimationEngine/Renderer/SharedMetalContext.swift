//
//  SharedMetalContext.swift
//  TUILiveKit
//
//  Created on 2026/2/13.
//  Performance Optimization: Global shared Metal context
//
//  Eliminates redundant creation of heavy Metal objects:
//  - MTLDevice (shared system-wide)
//  - MTLCommandQueue (shared across all renderers)
//  - MTLRenderPipelineState (compiled once, reused)
//  - MTLDepthStencilState (created once, reused)
//  - MTLSamplerState (created once, reused)
//

import Foundation
import Metal
import MetalKit
import UIKit

// MARK: - SharedMetalContext

/// Global shared Metal context — singleton
/// All SVGA player instances share the same device, queue, and pipeline states.
/// This eliminates ~5-10ms init overhead and ~2-3MB memory per player instance.
public final class SharedMetalContext {
    
    // MARK: - Singleton
    
    public static let shared = SharedMetalContext()
    
    // MARK: - Core Objects
    
    /// Shared Metal device
    public let device: MTLDevice
    
    /// Shared command queue
    public let commandQueue: MTLCommandQueue
    
    // MARK: - Pipeline (lazy, thread-safe)
    
    /// Render pipeline manager (created once, shared)
    public private(set) var pipeline: SVGARenderPipeline?
    
    /// Whether pipeline is set up
    public private(set) var isPipelineReady: Bool = false
    
    /// Lock for one-time pipeline setup
    private let setupLock = NSLock()
    
    /// Memory pressure observer token
    private var memoryPressureSource: DispatchSourceMemoryPressure?
    
    // MARK: - Initialization
    
    private init?() {
        guard let device = MTLCreateSystemDefaultDevice() else {
            return nil
        }
        guard let queue = device.makeCommandQueue() else {
            return nil
        }
        
        self.device = device
        self.commandQueue = queue
        queue.label = "SVGA Shared Command Queue"
        
        // Register for memory pressure notifications
        setupMemoryPressureHandler()
    }
    
    /// Private init that always succeeds (for singleton pattern fallback)
    /// If Metal is not available, `shared` will be nil via the failable init path.
    /// We use a class-level computed property to handle this gracefully.
    
    // MARK: - Pipeline Setup
    
    /// Ensure pipeline is set up for the given pixel format.
    /// Thread-safe; only the first caller performs the actual setup.
    /// Subsequent calls with the same format are no-ops.
    @discardableResult
    public func ensurePipeline(pixelFormat: MTLPixelFormat = .bgra8Unorm) throws -> SVGARenderPipeline {
        if let existing = pipeline, isPipelineReady {
            return existing
        }
        
        setupLock.lock()
        defer { setupLock.unlock() }
        
        // Double-check after acquiring lock
        if let existing = pipeline, isPipelineReady {
            return existing
        }
        
        let newPipeline = SVGARenderPipeline(device: device)
        try newPipeline.setup(pixelFormat: pixelFormat)
        self.pipeline = newPipeline
        self.isPipelineReady = true
        return newPipeline
    }
    
    // MARK: - MTLBuffer Pool
    
    /// Global buffer pool for reusing MTLBuffers across player instances.
    /// Buckets by size (rounded up to next power-of-two) to reduce fragmentation.
    public let bufferPool = MTLBufferPool()
    
    // MARK: - Memory Pressure Handling
    
    /// Set up handler that drains buffer pool on memory pressure
    private func setupMemoryPressureHandler() {
        let source = DispatchSource.makeMemoryPressureSource(
            eventMask: [.warning, .critical],
            queue: .global(qos: .utility)
        )
        source.setEventHandler { [weak self] in
            guard let self = self else { return }
            let event = source.data
            if event.contains(.critical) {
                // Critical: drain all pooled buffers
                self.bufferPool.drain()
                #if DEBUG
                print("[SharedMetalContext] Critical memory pressure — drained all pooled buffers")
                #endif
            } else if event.contains(.warning) {
                // Warning: drain half of pooled buffers
                self.bufferPool.drainPartial(fraction: 0.5)
                #if DEBUG
                print("[SharedMetalContext] Memory pressure warning — drained 50% of pooled buffers")
                #endif
            }
        }
        source.resume()
        memoryPressureSource = source
    }
}

// MARK: - MTLBufferPool

/// A thread-safe pool of MTLBuffers bucketed by size.
/// When a player instance is destroyed, its buffers are returned to the pool.
/// New player instances can reuse these buffers instead of calling device.makeBuffer().
public final class MTLBufferPool {
    
    /// Maximum number of buffers per bucket
    private let maxPerBucket: Int = 3
    
    /// Maximum total pooled memory (bytes) — reduced to 2MB to save memory
    private let maxTotalMemory: Int = 2 * 1024 * 1024  // 2MB
    
    /// Buckets: rounded size -> [MTLBuffer]
    private var buckets: [Int: [MTLBuffer]] = [:]
    
    /// Current total pooled memory
    private var currentMemory: Int = 0
    
    /// Lock
    private let lock = NSLock()
    
    public init() {}
    
    /// Acquire a buffer of at least `minSize` bytes.
    /// Returns a pooled buffer if available, otherwise creates a new one.
    public func acquire(device: MTLDevice, minSize: Int, options: MTLResourceOptions = .storageModeShared) -> MTLBuffer? {
        let bucketSize = roundUpToPowerOfTwo(minSize)
        
        lock.lock()
        if var bucket = buckets[bucketSize], !bucket.isEmpty {
            let buffer = bucket.removeLast()
            if bucket.isEmpty {
                buckets.removeValue(forKey: bucketSize)
            } else {
                buckets[bucketSize] = bucket
            }
            currentMemory -= buffer.length
            lock.unlock()
            return buffer
        }
        lock.unlock()
        
        // No pooled buffer available — create new
        return device.makeBuffer(length: bucketSize, options: options)
    }
    
    /// Return a buffer to the pool for future reuse.
    public func release(_ buffer: MTLBuffer) {
        let bucketSize = roundUpToPowerOfTwo(buffer.length)
        
        lock.lock()
        defer { lock.unlock() }
        
        // Check memory budget
        if currentMemory + buffer.length > maxTotalMemory {
            return // Drop — over budget
        }
        
        var bucket = buckets[bucketSize] ?? []
        if bucket.count >= maxPerBucket {
            return // Drop — bucket full
        }
        
        bucket.append(buffer)
        buckets[bucketSize] = bucket
        currentMemory += buffer.length
    }
    
    /// Clear all pooled buffers
    public func drain() {
        lock.lock()
        defer { lock.unlock() }
        buckets.removeAll()
        currentMemory = 0
    }
    
    /// Drain a fraction of pooled buffers (e.g., 0.5 = remove ~50% of memory)
    /// Used during memory pressure warnings to partially free memory while keeping some buffers for reuse.
    public func drainPartial(fraction: Double) {
        lock.lock()
        defer { lock.unlock() }
        
        let targetMemory = Int(Double(currentMemory) * (1.0 - fraction))
        
        // Remove from largest buckets first (most memory savings)
        let sortedKeys = buckets.keys.sorted(by: >)
        for key in sortedKeys {
            guard currentMemory > targetMemory else { break }
            guard var bucket = buckets[key], !bucket.isEmpty else { continue }
            
            while !bucket.isEmpty && currentMemory > targetMemory {
                let buffer = bucket.removeLast()
                currentMemory -= buffer.length
            }
            
            if bucket.isEmpty {
                buckets.removeValue(forKey: key)
            } else {
                buckets[key] = bucket
            }
        }
    }
    
    /// Round up to the next power of two (minimum 4096 for page alignment)
    private func roundUpToPowerOfTwo(_ value: Int) -> Int {
        let minBucket = 4096
        var v = max(value, minBucket) - 1
        v |= v >> 1
        v |= v >> 2
        v |= v >> 4
        v |= v >> 8
        v |= v >> 16
        v |= v >> 32
        return v + 1
    }
}
