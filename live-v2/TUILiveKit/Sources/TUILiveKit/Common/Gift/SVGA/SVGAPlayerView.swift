//
//  SVGAPlayerView.swift
//  TUILiveKit
//
//  Created on 2026/2/5.
//  High-Performance Metal-based SVGA Player
//
//  Drop-in replacement for SVGAAnimationView with:
//  - 60fps smooth playback
//  - Zero per-frame allocation
//  - Batch rendering (minimal DrawCalls)
//  - Stencil-based masking (no offscreen render)
//

import UIKit
import MetalKit
import Combine


// MARK: - Prepared Animation Cache (Two-Layer Architecture)

/// Lightweight metadata cached permanently (KB-level, no GPU resources).
/// Stores everything needed to rebuild a texture atlas without re-parsing.
private final class AnimationMetadata {
    let animation: SVGAAnimation
    let indices: [String: UInt16]
    let transparentKeys: Set<String>
    let spriteByKey: [String: SpriteEntity]

    init(animation: SVGAAnimation, indices: [String: UInt16],
         transparentKeys: Set<String>, spriteByKey: [String: SpriteEntity]) {
        self.animation = animation
        self.indices = indices
        self.transparentKeys = transparentKeys
        self.spriteByKey = spriteByKey
    }
}

/// Pins only the queued animation until it is handed to the player.
private final class PreparedGiftAnimation {
    let metadata: AnimationMetadata
    let atlas: SVGATextureAtlas

    init(metadata: AnimationMetadata, atlas: SVGATextureAtlas) {
        self.metadata = metadata
        self.atlas = atlas
    }
}

/// NSCache-compatible wrapper that holds the GPU texture atlas.
/// Uses `totalCostLimit` (bytes) for deterministic eviction instead of `countLimit`.
private final class TextureCacheEntry: NSObject {
    let atlas: SVGATextureAtlas
    let memoryCost: Int  // GPU texture bytes

    init(atlas: SVGATextureAtlas) {
        self.atlas = atlas
        self.memoryCost = atlas.estimatedMemorySize
        super.init()
    }
}

/// Two-layer cache for SVGA assets:
/// - **Metadata layer** (Dictionary): animation + indices + sprite maps. Permanent, KB-level.
///   Never evicted unless explicitly cleared — re-parsing is expensive (~50ms).
/// - **Texture layer** (NSCache with totalCostLimit): GPU MTLTexture atlas.
///   Automatically evicted by cost (bytes) or memory pressure. Can be rebuilt from metadata + SVGA file.
///
/// This design guarantees:
/// 1. Texture memory is deterministically bounded by `textureMemoryBudget`.
/// 2. NSCache eviction immediately frees GPU memory (sole owner).
/// 3. Cache hit with evicted texture triggers a fast rebuild (~10ms) without re-parsing.
/// 4. No dangling texture references — `SVGAPlayerView` holds its own strong ref during playback.
private final class PreparedAnimationCache {

    static let shared = PreparedAnimationCache()

    /// GPU texture memory budget in bytes (default 32MB — ~2 large atlas textures)
    static let textureMemoryBudget: Int = 32 * 1024 * 1024

    // Layer 1: Metadata (permanent, lightweight)
    private var metadataStore: [String: AnimationMetadata] = [:]
    private let metadataLock = NSLock()

    // Layer 2: Texture atlas (cost-based NSCache, auto-evicted)
    private let textureCache = NSCache<NSString, TextureCacheEntry>()

    /// Memory pressure observer
    private var memoryPressureSource: DispatchSourceMemoryPressure?

    private init() {
        textureCache.totalCostLimit = Self.textureMemoryBudget
        textureCache.name = "com.tuilivekit.svga.texture"

        setupMemoryPressureHandler()
    }

    // MARK: - Metadata API (permanent cache)

    func getMetadata(_ key: String) -> AnimationMetadata? {
        metadataLock.lock()
        defer { metadataLock.unlock() }
        return metadataStore[key]
    }

    func setMetadata(_ key: String, metadata: AnimationMetadata) {
        metadataLock.lock()
        defer { metadataLock.unlock() }
        metadataStore[key] = metadata
    }

    // MARK: - Texture API (cost-based eviction)

    func getTexture(_ key: String) -> SVGATextureAtlas? {
        textureCache.object(forKey: key as NSString)?.atlas
    }

    func setTexture(_ key: String, atlas: SVGATextureAtlas) {
        let entry = TextureCacheEntry(atlas: atlas)
        textureCache.setObject(entry, forKey: key as NSString, cost: entry.memoryCost)
    }

    /// Evict all textures (called on critical memory pressure)
    func evictAllTextures() {
        textureCache.removeAllObjects()
    }

    /// Evict all data (textures + metadata)
    func evictAll() {
        textureCache.removeAllObjects()
        metadataLock.lock()
        metadataStore.removeAll()
        metadataLock.unlock()
    }

    /// Current metadata count (for diagnostics)
    var metadataCount: Int {
        metadataLock.lock()
        defer { metadataLock.unlock() }
        return metadataStore.count
    }

    private func setupMemoryPressureHandler() {
        let source = DispatchSource.makeMemoryPressureSource(
            eventMask: [.warning, .critical],
            queue: .global(qos: .utility)
        )
        source.setEventHandler { [weak self] in
            guard let self = self else { return }
            let event = source.data
            if event.contains(.critical) {
                // Critical: evict ALL (including metadata) to free maximum memory
                self.evictAll()
                #if DEBUG
                print("[PreparedAnimationCache] Critical memory pressure — evicted all entries")
                #endif
            } else if event.contains(.warning) {
                // Warning: evict textures only (metadata is tiny, keep for fast rebuild)
                self.evictAllTextures()
                #if DEBUG
                print("[PreparedAnimationCache] Memory pressure warning — evicted all textures")
                #endif
            }
        }
        source.resume()
        memoryPressureSource = source
    }
}

// MARK: - SVGAPlayerView

/// High-performance Metal-based SVGA animation view
/// Internal Metal-backed gift animation view.
final class SVGAPlayerView: UIView {

    // MARK: - Properties

    /// Metal view for rendering
    private var metalView: MTKView!

    /// Renderer
    private var renderer: MetalRenderer?


    /// Texture atlas builder
    private var textureAtlasBuilder: TextureAtlasBuilder?

    /// Built texture atlas
    private var textureAtlas: SVGATextureAtlas?

    /// Sprite key to texture index mapping
    private var spriteTextureIndices: [String: UInt16] = [:]
    /// Fully transparent image keys (alpha all zero)
    private var transparentImageKeys: Set<String> = []

    /// Cache manager
    private let cacheManager = SVGACacheManager.shared

    /// Current animation
    private var playbackRequest = UUID()
    private var wantsPause = false
    private var animation: SVGAAnimation?

    /// Display link for vsync
    private var displayLink: CADisplayLink?

    /// Current frame index
    private var currentFrameIndex: Int = 0
    /// 最近一次实际渲染的帧索引
    private var lastRenderedFrameIndex: Int?
    /// sprite 映射（imageKey -> SpriteEntity），用于 matte 可见性判断
    private var spriteByKey: [String: SpriteEntity] = [:]

    /// Pre-computed per-sprite render info (avoids dictionary lookups in hot loop)
    private struct SpriteRenderInfo {
        let spriteIndex: Int          // Index into animation.sprites
        let textureIndex: UInt16      // Texture atlas index
        let hasMatte: Bool            // Whether sprite uses matte/mask
        let matteTextureIndex: UInt16 // Matte texture index (valid only if hasMatte)
        let matteSpriteIndex: Int     // Index into animation.sprites for matte sprite (-1 if none)
    }
    private var spriteRenderInfos: [SpriteRenderInfo] = []

    /// Whether the animation has any masked sprites (determined at load time)
    /// When false, we use the zero-copy direct-write fast path
    private var hasMaskedSprites: Bool = false

    // MARK: - Precomputed Frame Data (P0 optimization)

    /// Precomputed GPU instance data for ALL frames.
    /// Built once on load; runtime rendering is a single memcpy per frame.
    /// Layout: precomputedFrames[frameIndex] contains a flat array of SVGAInstance
    /// precomputedFrameCounts[frameIndex] stores the sprite count for that frame.
    private var precomputedFrames: UnsafeMutablePointer<UnsafeMutablePointer<SVGAInstance>>?
    private var precomputedFrameCounts: UnsafeMutablePointer<Int>?
    private var precomputedTotalFrames: Int = 0

    // MARK: - Render Thread (P0 optimization)

    /// Dedicated serial queue for rendering — keeps main thread free
    private let renderQueue = DispatchQueue(label: "com.tuilivekit.svga.render", qos: .userInteractive)

    /// Cached CAMetalLayer reference (avoids per-frame `as? CAMetalLayer` cast)
    private weak var cachedMetalLayer: CAMetalLayer?

    /// 缓存的 baseTransform 及其计算依赖的尺寸
    private var cachedBaseTransform: simd_float3x3 = matrix_identity_float3x3
    private var cachedViewWidth: Float = 0
    private var cachedViewHeight: Float = 0
    private var cachedVideoSize: CGSize = .zero

    /// Playback state
    private var isPlaying: Bool = false

    /// Loop count (0 = infinite, default 1)
    private var loopCount: Int = 1

    /// Current loop
    private var currentLoop: Int = 0

    /// Start time for frame timing
    private var playbackStartTime: CFTimeInterval = 0

    /// Last frame time
    private var lastFrameTime: CFTimeInterval = 0

    /// Cached animation params (avoid class pointer indirection in hot loop)
    private var cachedTotalFrames: Int = 0
    private var cachedFrameDuration: Double = 0
    /// Timeline frame index (raw frame counter)
    private var timelineFrameIndex: Int = 0

    /// Content mode for SVGA
    var svgaContentMode: SVGAContentMode = .scaleAspectFit

    /// Finish closure (AnimationViewCompatible)
    var finishClosure: ((Int) -> Void)?

    /// Configuration
    private let config: SVGAPlayerConfig

    /// Whether view is ready
    private var isViewReady = false

    /// Whether Metal is initialized
    private var isMetalInitialized = false

    // MARK: - Initialization

    override init(frame: CGRect) {
        self.config = .default
        super.init(frame: frame)
        commonInit()
    }

    init(frame: CGRect = .zero, config: SVGAPlayerConfig = .default) {
        self.config = config
        super.init(frame: frame)
        commonInit()
    }

    required init?(coder: NSCoder) {
        self.config = .default
        super.init(coder: coder)
        commonInit()
    }

    private func commonInit() {
        backgroundColor = .clear
        isUserInteractionEnabled = false
    }

    deinit {
        stopDisplayLink()
        deallocatePrecomputedFrames()
        // Detach atlas from animation; the cache's NSCache owns the texture lifecycle
        animation?.textureAtlas = nil
        renderer?.release()
    }

    // MARK: - UIView Lifecycle

    override func didMoveToWindow() {
        super.didMoveToWindow()
        guard window != nil else { stop(); return }
        guard !isViewReady else { return }

        constructViewHierarchy()
        activateConstraints()
        setupMetal()

        isViewReady = true
    }

    override func layoutSubviews() {
        super.layoutSubviews()

        guard bounds.width > 0, bounds.height > 0 else { return }

        // Update Metal drawable size
        metalView?.drawableSize = CGSize(
            width: bounds.width * UIScreen.main.scale,
            height: bounds.height * UIScreen.main.scale
        )
    }

    // MARK: - View Setup

    private func constructViewHierarchy() {
        metalView = MTKView(frame: bounds)
        metalView.device = SharedMetalContext.shared?.device
        metalView.delegate = self
        metalView?.isPaused = true
        metalView.enableSetNeedsDisplay = false
        metalView.framebufferOnly = true
        metalView.clearColor = MTLClearColor(red: 0, green: 0, blue: 0, alpha: 0)
        metalView.isOpaque = false
        metalView.backgroundColor = .clear

        if let metalLayer = metalView.layer as? CAMetalLayer {
            metalLayer.isOpaque = false
            metalLayer.maximumDrawableCount = 3
            metalLayer.allowsNextDrawableTimeout = true
            metalLayer.presentsWithTransaction = false
            cachedMetalLayer = metalLayer
        }

        addSubview(metalView)
    }

    private func activateConstraints() {
        metalView.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            metalView.topAnchor.constraint(equalTo: topAnchor),
            metalView.leadingAnchor.constraint(equalTo: leadingAnchor),
            metalView.trailingAnchor.constraint(equalTo: trailingAnchor),
            metalView.bottomAnchor.constraint(equalTo: bottomAnchor)
        ])
    }

    // MARK: - Metal Setup

    private func setupMetal() {
        guard let context = SharedMetalContext.shared else { return }

        // Start with a small initial capacity; prepare(for:) will resize dynamically
        let initialCapacity = 16
        guard let metalRenderer = MetalRenderer(maxSprites: initialCapacity) else { return }

        do {
            try metalRenderer.setup(pixelFormat: metalView.colorPixelFormat)
            self.renderer = metalRenderer
            isMetalInitialized = true
        } catch {
            // Metal setup failed
        }
    }

    // MARK: - AnimationView Protocol

    /// Play animation from file path (AnimationView protocol)
    func playAnimation(playUrl: String, prepared: AnyObject? = nil, onFinished: @escaping ((Int) -> Void)) {
        stop()
        let request = playbackRequest
        finishClosure = onFinished

        // Report analytics


        // Validate file
        guard isSVGAFile(url: playUrl) else {
            onFinished(-1)
            return
        }

        if !isViewReady {
            constructViewHierarchy()
            activateConstraints()
            isViewReady = true
        }

        // Ensure Metal is ready
        if !isMetalInitialized {
            setupMetal()
        }
        guard isMetalInitialized else {
            onFinished(-1)
            return
        }

        // Reset state (preserve loopCount set by setLoops())
        stopPlayback()
        currentFrameIndex = 0
        currentLoop = 0

        // Show loading state
        alpha = 1.0

        guard let context = SharedMetalContext.shared else {
            onFinished(-1)
            return
        }

        if let prepared = prepared as? PreparedGiftAnimation {
            applyMetadataAndAtlas(metadata: prepared.metadata, atlas: prepared.atlas)
            return
        }

        let cacheKey = playUrl
        let cache = PreparedAnimationCache.shared
        let device = context.device

        // Fast path: metadata + texture both cached → instant replay (~0ms)
        if let metadata = cache.getMetadata(cacheKey),
           let atlas = cache.getTexture(cacheKey) {
            applyMetadataAndAtlas(metadata: metadata, atlas: atlas)
            return
        }

        // Medium path: metadata cached but texture evicted → rebuild texture only (~10ms)
        if let metadata = cache.getMetadata(cacheKey) {
            DispatchQueue.global(qos: .userInitiated).async { [weak self] in
                guard let self = self else { return }
                do {
                    let atlas = try self.rebuildTextureAtlas(
                        for: metadata.animation, device: device, filePath: playUrl
                    )
                    cache.setTexture(cacheKey, atlas: atlas)
                    DispatchQueue.main.async { [weak self] in
                        guard let self = self, self.playbackRequest == request else { return }
                        self.applyMetadataAndAtlas(metadata: metadata, atlas: atlas)
                    }
                } catch {
                    LiveKitLog.error("SVGA texture rebuild failed: \(error)")
                    DispatchQueue.main.async { [weak self] in
                        guard let self = self, self.playbackRequest == request else { return }
                        self.handlePlaybackFinished(code: -1)
                    }
                }
            }
            return
        }

        // Slow path: full parse + build atlas
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self = self else { return }

            do {
                // Step 1: Parse SVGA
                let animation = try SVGAParser().parseSync(filePath: playUrl)

                // Step 2: Build texture atlas with fused decode
                let result = try self.buildTextureAtlasFused(for: animation, device: device)
                let builtAtlas: SVGATextureAtlas? = result.atlas
                let builtIndices = result.indices
                let builtTransparentKeys = result.transparentKeys

                // Step 3: Pre-build spriteByKey map
                var spriteMap: [String: SpriteEntity] = [:]
                spriteMap.reserveCapacity(animation.sprites.count * 2)
                for sprite in animation.sprites {
                    if !sprite.identifier.isEmpty {
                        spriteMap[sprite.identifier] = sprite
                    }
                    if let key = sprite.imageKey {
                        spriteMap[key] = sprite
                    }
                }

                // Release CPU-side image data (atlas is built)
                animation.setExternalImageData([:])

                // Store metadata permanently (lightweight, KB-level)
                let metadata = AnimationMetadata(
                    animation: animation,
                    indices: builtIndices,
                    transparentKeys: builtTransparentKeys,
                    spriteByKey: spriteMap
                )
                cache.setMetadata(cacheKey, metadata: metadata)

                // Store texture in cost-based cache (auto-evicts by GPU memory budget)
                if let atlas = builtAtlas {
                    cache.setTexture(cacheKey, atlas: atlas)
                }

                DispatchQueue.main.async { [weak self] in
                    guard let self = self, self.playbackRequest == request else { return }
                    self.applyMetadataAndAtlas(metadata: metadata, atlas: builtAtlas)
                }
            } catch {
                LiveKitLog.error("SVGA preparation failed: \(error)")
                DispatchQueue.main.async { [weak self] in
                    guard let self = self, self.playbackRequest == request else { return }
                    self.handlePlaybackFinished(code: -1)
                }
            }
        }
    }

    /// Apply metadata + texture atlas and start playback immediately.
    /// The SVGAPlayerView holds a strong reference to the atlas during playback,
    /// so even if NSCache evicts it, playback continues uninterrupted.
    ///
    /// Prepare only sprite lookup and GPU capacity here. Full-animation frame
    /// precomputation blocks first playback; direct-write rendering computes just
    /// the current frame on renderQueue instead.
    private func applyMetadataAndAtlas(metadata: AnimationMetadata, atlas: SVGATextureAtlas?) {
        metalView.isHidden = false
        self.animation = metadata.animation
        self.textureAtlas = atlas  // Strong local ref during playback
        self.spriteTextureIndices = metadata.indices
        self.transparentImageKeys = metadata.transparentKeys
        self.spriteByKey = metadata.spriteByKey
        metadata.animation.textureAtlas = atlas

        // Cache animation params for hot loop
        cachedTotalFrames = metadata.animation.frameCount
        cachedFrameDuration = 1.0 / Double(metadata.animation.frameRate)

        guard cachedTotalFrames > 0, metadata.animation.frameRate > 0 else {
            handlePlaybackFinished(code: -1)
            return
        }
        buildSpriteRenderInfos(animation: metadata.animation, indices: metadata.indices,
                               transparentKeys: metadata.transparentKeys, spriteMap: metadata.spriteByKey)
        do {
            try renderer?.prepare(for: metadata.animation)
        } catch {
            handlePlaybackFinished(code: -1)
            return
        }
        currentFrameIndex = 0
        isPlaying = !wantsPause
        startDisplayLink()
        displayLink?.isPaused = wantsPause
    }

    private func rebuildTextureAtlas(for animation: SVGAAnimation, device: MTLDevice, filePath: String) throws -> SVGATextureAtlas {
        let fresh = try SVGAParser().parseSync(filePath: filePath)
        return try Self.buildEncodedAtlas(animation: fresh, device: device).atlas
    }

    /// Build pre-computed sprite render info array (called once per animation load)
    private func buildSpriteRenderInfos(animation: SVGAAnimation, indices: [String: UInt16],
                                         transparentKeys: Set<String>, spriteMap: [String: SpriteEntity]) {
        var infos: [SpriteRenderInfo] = []
        infos.reserveCapacity(animation.sprites.count)

        // Build sprite index lookup for matte references
        var spriteIndexByKey: [String: Int] = [:]
        spriteIndexByKey.reserveCapacity(animation.sprites.count * 2)
        for (i, sprite) in animation.sprites.enumerated() {
            if !sprite.identifier.isEmpty { spriteIndexByKey[sprite.identifier] = i }
            if let key = sprite.imageKey { spriteIndexByKey[key] = i }
        }

        var anyMasked = false

        for (i, sprite) in animation.sprites.enumerated() {
            guard let imageKey = sprite.imageKey,
                  let textureIndex = indices[imageKey],
                  !transparentKeys.contains(imageKey) else {
                continue
            }

            var hasMatte = false
            var matteTextureIndex: UInt16 = 0
            var matteSpriteIndex: Int = -1

            if let matteKey = sprite.matteKey {
                if let matteSprite = spriteMap[matteKey] {
                    if let matteImageKey = matteSprite.imageKey, let idx = indices[matteImageKey] {
                        matteTextureIndex = idx
                    } else if let idx = indices[matteKey] {
                        matteTextureIndex = idx
                    }
                    matteSpriteIndex = spriteIndexByKey[matteKey] ?? -1
                    hasMatte = matteSpriteIndex >= 0
                    if hasMatte { anyMasked = true }
                }
            }

            infos.append(SpriteRenderInfo(
                spriteIndex: i,
                textureIndex: textureIndex,
                hasMatte: hasMatte,
                matteTextureIndex: matteTextureIndex,
                matteSpriteIndex: matteSpriteIndex
            ))
        }

        self.spriteRenderInfos = infos
        self.hasMaskedSprites = anyMasked
    }

    // MARK: - Precomputed Frames (P0 optimization)

    /// Build precomputed GPU instance data for ALL frames at once.
    /// Called on renderQueue during animation load.
    /// After this, each frame render is a single memcpy — zero per-frame computation.
    private func buildPrecomputedFrames(animation: SVGAAnimation, infos: [SpriteRenderInfo], hasMasks: Bool) {
        deallocatePrecomputedFrames()

        // For masked animations, we can't precompute (mask path uses SpriteBatcher)
        guard !hasMasks else { return }

        let totalFrames = animation.frameCount
        guard totalFrames > 0 else { return }

        let sprites = animation.sprites
        let stride = MemoryLayout<SVGAInstance>.stride

        // Allocate frame pointer array + count array
        let framePtrs = UnsafeMutablePointer<UnsafeMutablePointer<SVGAInstance>>.allocate(capacity: totalFrames)
        let frameCounts = UnsafeMutablePointer<Int>.allocate(capacity: totalFrames)

        // Parallel frame construction: each frame is independent.
        // Cap concurrency to half of available cores (min 2) to avoid starving
        // the video capture/encoding threads which share the same CPU.
        // concurrentPerform still uses GCD's cooperative thread pool, but limiting
        // the iteration batch size via stride achieves similar throttling.
        let maxConcurrency = max(2, ProcessInfo.processInfo.activeProcessorCount / 2)
        let batchSize = max(1, totalFrames / maxConcurrency)
        DispatchQueue.concurrentPerform(iterations: maxConcurrency) { batchIndex in
            let start = batchIndex * batchSize
            let end = (batchIndex == maxConcurrency - 1) ? totalFrames : min(start + batchSize, totalFrames)
            for f in start..<end {
                // Count visible sprites for this frame
                var count = 0
                for info in infos {
                    let frames = sprites[info.spriteIndex].frames
                    guard f < frames.count else { continue }
                    if frames[f].alpha > 0.001 { count += 1 }
                }

                // Allocate buffer for this frame's visible sprites
                let ptr = UnsafeMutablePointer<SVGAInstance>.allocate(capacity: max(count, 1))
                var writeIdx = 0

                for info in infos {
                    let frames = sprites[info.spriteIndex].frames
                    guard f < frames.count else { continue }
                    let frame = frames[f]
                    guard frame.alpha > 0.001 else { continue }

                    let ft = frame.transform
                    // Store raw transform (baseTransform applied at render time)
                    ptr[writeIdx].transformCol0 = PackedFloat3(ft[0][0], ft[0][1], ft[0][2])
                    ptr[writeIdx].transformCol1 = PackedFloat3(ft[1][0], ft[1][1], ft[1][2])
                    ptr[writeIdx].transformCol2 = PackedFloat3(ft[2][0], ft[2][1], ft[2][2])
                    ptr[writeIdx].alpha = frame.alpha
                    ptr[writeIdx].textureIndex = info.textureIndex
                    ptr[writeIdx].maskIndex = 0
                    writeIdx += 1
                }

                framePtrs[f] = ptr
                frameCounts[f] = writeIdx
            }
        }

        precomputedFrames = framePtrs
        precomputedFrameCounts = frameCounts
        precomputedTotalFrames = totalFrames
    }

    /// Free all precomputed frame data
    private func deallocatePrecomputedFrames() {
        if let ptrs = precomputedFrames, let counts = precomputedFrameCounts {
            for i in 0..<precomputedTotalFrames {
                ptrs[i].deallocate()
            }
            ptrs.deallocate()
            counts.deallocate()
        }
        precomputedFrames = nil
        precomputedFrameCounts = nil
        precomputedTotalFrames = 0
    }

    /// Build texture atlas with fused decode: CGImage → BGRA pixels in one parallel pass
    /// Eliminates the redundant CGImage → extractImageData conversion in TextureAtlasBuilder
    /// ~2x faster than the two-pass approach (createCGImage + extractImageData)
    private func buildTextureAtlasFused(for animation: SVGAAnimation, device: MTLDevice) throws -> (atlas: SVGATextureAtlas, indices: [String: UInt16], transparentKeys: Set<String>) {
        try Self.buildEncodedAtlas(animation: animation, device: device)
    }

    private static func buildEncodedAtlas(animation: SVGAAnimation, device: MTLDevice) throws -> (atlas: SVGATextureAtlas, indices: [String: UInt16], transparentKeys: Set<String>) {
        guard let images = animation.externalImageData, !images.isEmpty else {
            throw NSError(domain: "SVGAEngine", code: 5002, userInfo: [NSLocalizedDescriptionKey: "No image data available"])
        }
        var options = TextureAtlasBuilder.BuildOptions()
        options.maxWidth = device.supportsFamily(.apple3) ? 16384 : 8192
        options.maxHeight = options.maxWidth
        options.padding = 2
        let builder = TextureAtlasBuilder(device: device, options: options)
        let keys = images.keys.sorted()
        for key in keys {
            if let data = images[key] { builder.addEncodedImage(key: key, data: data) }
        }
        let result = try builder.build()
        var indices: [String: UInt16] = [:]
        for key in keys {
            if let index = result.atlas.regions.index(forKey: key) { indices[key] = UInt16(index) }
        }
        // Transparent pixels are rendered as transparent; no full-image scan or
        // retained decoded bitmap is needed to classify them before playback.
        return (result.atlas, indices, [])
    }

    private func stopPlayback() {
        isPlaying = false
        stopDisplayLink()

        renderQueue.sync {}

        // Free precomputed frame data
        deallocatePrecomputedFrames()

        // Detach atlas from animation (break reference cycle)
        animation?.textureAtlas = nil

        // Release local strong references.
        // The texture atlas is owned by PreparedAnimationCache's textureCache (NSCache).
        // When we nil our reference here, if the cache has already evicted it,
        // the MTLTexture will be deallocated immediately. If the cache still holds it,
        // it stays alive for future replay — no dangling reference possible.
        animation = nil
        textureAtlas = nil
        spriteTextureIndices.removeAll()
        spriteByKey.removeAll()
        transparentImageKeys.removeAll()
        spriteRenderInfos.removeAll()
        hasMaskedSprites = false

        // Invalidate cached transform so next playback recalculates
        cachedViewWidth = 0
        cachedViewHeight = 0
        cachedVideoSize = .zero
    }

    /// Pause playback
    func pause() {
        wantsPause = true
        guard isPlaying else { return }
        isPlaying = false
        displayLink?.isPaused = true
    }

    /// Resume playback
    func resume() {
        wantsPause = false
        guard !isPlaying, animation != nil else { return }
        isPlaying = true
        displayLink?.isPaused = false
        // 重新对齐时间基准，避免跳帧
        playbackStartTime = 0
        lastFrameTime = 0
        timelineFrameIndex = currentLoop * cachedTotalFrames + currentFrameIndex
    }

    /// Stop playback
    func stop() {
        playbackRequest = UUID()
        finishClosure = nil
        wantsPause = false
        stopPlayback()
        currentFrameIndex = 0
        currentLoop = 0
        spriteByKey.removeAll()
        transparentImageKeys.removeAll()

        // Hide the previous drawable until the next animation is prepared.
        metalView?.isHidden = true
        metalView?.isPaused = true
    }

    /// Set loops count
    func setLoops(_ count: Int) {
        loopCount = count
    }

    // MARK: - Display Link

    private func startDisplayLink() {
        stopDisplayLink()

        let targetFPS = animation?.frameRate ?? 30
        guard window != nil else { return }

        displayLink = CADisplayLink(target: self, selector: #selector(displayLinkFired(_:)))

        if #available(iOS 15.0, *) {
            let range = CAFrameRateRange(minimum: Float(targetFPS), maximum: Float(targetFPS), preferred: Float(targetFPS))
            displayLink?.preferredFrameRateRange = range
        } else {
            displayLink?.preferredFramesPerSecond = targetFPS
        }

        displayLink?.add(to: .main, forMode: .common)

        renderFrameCount = 0
        playbackStartTime = 0
        lastFrameTime = 0
        timelineFrameIndex = currentLoop * cachedTotalFrames + currentFrameIndex
        lastRenderedFrameIndex = nil
    }

    private func stopDisplayLink() {
        displayLink?.invalidate()
        displayLink = nil
    }

    @objc private func displayLinkFired(_ link: CADisplayLink) {
        guard isPlaying, animation != nil else { return }

        let totalFrames = cachedTotalFrames
        let frameDuration = cachedFrameDuration

        if playbackStartTime == 0 {
            playbackStartTime = link.timestamp
            lastFrameTime = link.timestamp
            timelineFrameIndex = currentLoop * cachedTotalFrames + currentFrameIndex
            dispatchRenderFrame(currentFrameIndex)
            return
        }

        // Use elapsed media time, not display callback count. Under load or
        // Low Power Mode, skip obsolete frames instead of slowing the animation.
        let advance = SVGAPlaybackTiming.advance(
            elapsed: link.timestamp - lastFrameTime, frameDuration: frameDuration
        )
        guard advance.frames > 0 else { return }
        lastFrameTime += advance.consumedTime
        timelineFrameIndex += advance.frames

        let rawFrame = timelineFrameIndex % totalFrames
        let completedLoops = timelineFrameIndex / totalFrames
        if loopCount > 0 && completedLoops >= loopCount {
            isPlaying = false
            stopDisplayLink()
            handlePlaybackFinished(code: 0)
            return
        }

        if completedLoops != currentLoop {
            lastRenderedFrameIndex = nil
        }
        currentLoop = completedLoops
        currentFrameIndex = rawFrame

        // Skip if same frame already rendered
        if lastRenderedFrameIndex == currentFrameIndex {
            return
        }

        dispatchRenderFrame(currentFrameIndex)
    }

    // MARK: - Rendering

    private let frameSemaphore = DispatchSemaphore(value: 3)
    private var currentBufferIndex: Int = 0
    /// Total number of frames actually rendered (for performance monitoring)
    private(set) var renderFrameCount: Int = 0

    /// P0: Dispatch rendering to the dedicated render queue.
    /// Main thread only does time advancement + frame index calculation.
    private func dispatchRenderFrame(_ frameIndex: Int) {
        // Capture everything we need for rendering on the render queue
        guard let animation = animation,
              let renderer = renderer,
              let context = SharedMetalContext.shared else { return }

        guard let metalLayer = cachedMetalLayer ?? (metalView.layer as? CAMetalLayer) else { return }

        let drawableSize = metalView.drawableSize
        guard drawableSize.width > 0 && drawableSize.height > 0 else { return }

        // Try to acquire semaphore (non-blocking) — if all 3 buffers in flight, skip
        if frameSemaphore.wait(timeout: .now()) != .success { return }

        let bufferIndex = currentBufferIndex
        currentBufferIndex = (currentBufferIndex + 1) % 3
        lastRenderedFrameIndex = frameIndex

        let hasMasks = hasMaskedSprites
        let precomputed = precomputedFrames
        let precomputedCounts = precomputedFrameCounts
        let precomputedTotal = precomputedTotalFrames
        let semaphore = frameSemaphore

        renderQueue.async { [weak self] in
            guard let self = self else {
                semaphore.signal()
                return
            }
            self.renderFrameOnRenderQueue(
                frameIndex: frameIndex,
                bufferIndex: bufferIndex,
                animation: animation,
                renderer: renderer,
                context: context,
                metalLayer: metalLayer,
                drawableSize: drawableSize,
                hasMasks: hasMasks,
                precomputed: precomputed,
                precomputedCounts: precomputedCounts,
                precomputedTotal: precomputedTotal
            )
        }
    }

    /// Render a single frame on the render queue. All heavy work happens here.
    private func renderFrameOnRenderQueue(
        frameIndex: Int,
        bufferIndex: Int,
        animation: SVGAAnimation,
        renderer: MetalRenderer,
        context: SharedMetalContext,
        metalLayer: CAMetalLayer,
        drawableSize: CGSize,
        hasMasks: Bool,
        precomputed: UnsafeMutablePointer<UnsafeMutablePointer<SVGAInstance>>?,
        precomputedCounts: UnsafeMutablePointer<Int>?,
        precomputedTotal: Int
    ) {
        // Acquire drawable FIRST — if the GPU is still presenting the previous frame,
        // nextDrawable() may block for up to a few ms. By calling it before sprite
        // data preparation, we overlap the GPU wait with any prior renderQueue work
        // and avoid extending the frame's critical path unnecessarily.
        // If no drawable is available, bail early and skip sprite computation entirely.
        guard let drawable = metalLayer.nextDrawable() else {
            frameSemaphore.signal()
            return
        }


        // Choose fast path or slow path for sprite data
        let spriteCount: Int
        if hasMasks {
            // Slow path: go through SpriteCommand batcher (supports stencil masking)
            feedSpritesToBatch(animation: animation, frameIndex: frameIndex, renderer: renderer, drawableSize: drawableSize)
            spriteCount = -1
        } else if let precomputed = precomputed, let counts = precomputedCounts,
                  frameIndex < precomputedTotal {
            // Ultra-fast path: use precomputed frame data
            spriteCount = feedSpritesPrecomputed(
                frameIndex: frameIndex,
                renderer: renderer,
                bufferIndex: bufferIndex,
                drawableSize: drawableSize,
                videoSize: animation.videoSize,
                precomputed: precomputed,
                precomputedCounts: counts
            )
        } else {
            // Fast path: direct-write (fallback for masked or un-precomputed)
            spriteCount = feedSpritesDirectWrite(animation: animation, frameIndex: frameIndex, renderer: renderer, bufferIndex: bufferIndex, drawableSize: drawableSize)
        }

        guard let commandBuffer = context.commandQueue.makeCommandBuffer() else {
            frameSemaphore.signal()
            return
        }

        let renderPass = MTLRenderPassDescriptor()
        renderPass.colorAttachments[0].texture = drawable.texture
        renderPass.colorAttachments[0].loadAction = .clear
        renderPass.colorAttachments[0].storeAction = .store
        renderPass.colorAttachments[0].clearColor = MTLClearColor(red: 0, green: 0, blue: 0, alpha: 0)

        if spriteCount >= 0 {
            renderer.renderDirectWrite(
                spriteCount: spriteCount,
                commandBuffer: commandBuffer,
                renderPassDescriptor: renderPass,
                viewportSize: drawableSize,
                bufferIndex: bufferIndex
            )
        } else {
            renderer.renderPreBatched(
                commandBuffer: commandBuffer,
                renderPassDescriptor: renderPass,
                viewportSize: drawableSize,
                bufferIndex: bufferIndex
            )
        }

        commandBuffer.addCompletedHandler { [weak renderer, weak self] cb in
            renderer?.updateGPUTiming(from: cb)
            self?.frameSemaphore.signal()
        }

        commandBuffer.present(drawable)
        commandBuffer.commit()

        renderFrameCount += 1
    }

    /// ULTRA-FAST PATH: Apply baseTransform to precomputed per-frame data and write to GPU buffer.
    /// Per-frame cost: iterate precomputed sprites, multiply by baseTransform, viewport cull, memcpy.
    /// No dictionary lookups, no sprite array traversal, no alpha checks on frame data.
    private func feedSpritesPrecomputed(
        frameIndex: Int,
        renderer: MetalRenderer,
        bufferIndex: Int,
        drawableSize: CGSize,
        videoSize: CGSize,
        precomputed: UnsafeMutablePointer<UnsafeMutablePointer<SVGAInstance>>,
        precomputedCounts: UnsafeMutablePointer<Int>
    ) -> Int {
        guard let dst = renderer.getInstanceBufferPointer(bufferIndex: bufferIndex) else { return 0 }

        let viewWidth = Float(drawableSize.width)
        let viewHeight = Float(drawableSize.height)

        if viewWidth != cachedViewWidth || viewHeight != cachedViewHeight || videoSize != cachedVideoSize {
            let scaleX = Float(drawableSize.width / videoSize.width)
            let scaleY = Float(drawableSize.height / videoSize.height)
            let scale = min(scaleX, scaleY)
            let offsetX = Float((drawableSize.width - videoSize.width * CGFloat(scale)) / 2)
            let offsetY = Float((drawableSize.height - videoSize.height * CGFloat(scale)) / 2)
            cachedBaseTransform = simd_float3x3(
                SIMD3<Float>(scale, 0, 0),
                SIMD3<Float>(0, scale, 0),
                SIMD3<Float>(offsetX, offsetY, 1)
            )
            cachedViewWidth = viewWidth
            cachedViewHeight = viewHeight
            cachedVideoSize = videoSize
        }

        let b00 = cachedBaseTransform[0][0], b01 = cachedBaseTransform[0][1]
        let b10 = cachedBaseTransform[1][0], b11 = cachedBaseTransform[1][1]
        let b20 = cachedBaseTransform[2][0], b21 = cachedBaseTransform[2][1]

        let src = precomputed[frameIndex]
        let srcCount = precomputedCounts[frameIndex]
        let maxCount = renderer.maxSpriteCapacity
        var writeIndex = 0

        for i in 0..<srcCount {
            guard writeIndex < maxCount else { break }
            let s = src[i]

            // Apply baseTransform to raw sprite transform
            let ft0x = s.transformCol0.x, ft0y = s.transformCol0.y
            let ft1x = s.transformCol1.x, ft1y = s.transformCol1.y
            let ft2x = s.transformCol2.x, ft2y = s.transformCol2.y

            let fc0x = b00 * ft0x + b10 * ft0y
            let fc0y = b01 * ft0x + b11 * ft0y
            let fc1x = b00 * ft1x + b10 * ft1y
            let fc1y = b01 * ft1x + b11 * ft1y
            let fc2x = b00 * ft2x + b10 * ft2y + b20
            let fc2y = b01 * ft2x + b11 * ft2y + b21

            // SIMD AABB viewport culling
            let px = SIMD4<Float>(fc2x, fc0x + fc2x, fc1x + fc2x, fc0x + fc1x + fc2x)
            let py = SIMD4<Float>(fc2y, fc0y + fc2y, fc1y + fc2y, fc0y + fc1y + fc2y)
            if px.max() < 0 || py.max() < 0 || px.min() > viewWidth || py.min() > viewHeight {
                continue
            }

            dst[writeIndex].transformCol0 = PackedFloat3(fc0x, fc0y, s.transformCol0.z)
            dst[writeIndex].transformCol1 = PackedFloat3(fc1x, fc1y, s.transformCol1.z)
            dst[writeIndex].transformCol2 = PackedFloat3(fc2x, fc2y, s.transformCol2.z)
            dst[writeIndex].alpha = s.alpha
            dst[writeIndex].textureIndex = s.textureIndex
            dst[writeIndex].maskIndex = 0
            writeIndex += 1
        }

        return writeIndex
    }

    /// FAST PATH: Write SVGAInstance data directly into the GPU buffer.
    /// Bypasses SpriteCommand, SpriteBatcher, endFrame, writeDirectlyToBuffer entirely.
    /// ~3x fewer memory writes per sprite compared to the batched path.
    /// Returns the number of sprites written.
    private func feedSpritesDirectWrite(animation: SVGAAnimation, frameIndex: Int, renderer: MetalRenderer, bufferIndex: Int, drawableSize: CGSize) -> Int {
        guard let dst = renderer.getInstanceBufferPointer(bufferIndex: bufferIndex) else { return 0 }

        let videoSize = animation.videoSize
        let viewWidth = Float(drawableSize.width)
        let viewHeight = Float(drawableSize.height)

        if viewWidth != cachedViewWidth || viewHeight != cachedViewHeight || videoSize != cachedVideoSize {
            let scaleX = Float(drawableSize.width / videoSize.width)
            let scaleY = Float(drawableSize.height / videoSize.height)
            let scale = min(scaleX, scaleY)
            let offsetX = Float((drawableSize.width - videoSize.width * CGFloat(scale)) / 2)
            let offsetY = Float((drawableSize.height - videoSize.height * CGFloat(scale)) / 2)
            cachedBaseTransform = simd_float3x3(
                SIMD3<Float>(scale, 0, 0),
                SIMD3<Float>(0, scale, 0),
                SIMD3<Float>(offsetX, offsetY, 1)
            )
            cachedViewWidth = viewWidth
            cachedViewHeight = viewHeight
            cachedVideoSize = videoSize
        }

        let b00 = cachedBaseTransform[0][0], b01 = cachedBaseTransform[0][1]
        let b10 = cachedBaseTransform[1][0], b11 = cachedBaseTransform[1][1]
        let b20 = cachedBaseTransform[2][0], b21 = cachedBaseTransform[2][1]

        let sprites = animation.sprites
        let maxCount = renderer.maxSpriteCapacity
        let infos = spriteRenderInfos
        var writeIndex = 0

        for i in 0..<infos.count {
            guard writeIndex < maxCount else { break }
            let info = infos[i]
            let frames = sprites[info.spriteIndex].frames
            guard frameIndex < frames.count else { continue }
            let frame = frames[frameIndex]

            guard frame.alpha > 0.001 else { continue }

            let ft = frame.transform
            let fc0x = b00 * ft[0][0] + b10 * ft[0][1]
            let fc0y = b01 * ft[0][0] + b11 * ft[0][1]
            let fc1x = b00 * ft[1][0] + b10 * ft[1][1]
            let fc1y = b01 * ft[1][0] + b11 * ft[1][1]
            let fc2x = b00 * ft[2][0] + b10 * ft[2][1] + b20
            let fc2y = b01 * ft[2][0] + b11 * ft[2][1] + b21

            // SIMD AABB viewport culling
            let px = SIMD4<Float>(fc2x, fc0x + fc2x, fc1x + fc2x, fc0x + fc1x + fc2x)
            let py = SIMD4<Float>(fc2y, fc0y + fc2y, fc1y + fc2y, fc0y + fc1y + fc2y)
            if px.max() < 0 || py.max() < 0 || px.min() > viewWidth || py.min() > viewHeight {
                continue
            }

            // Write PackedFloat3 directly to GPU buffer — no intermediate simd_float3x3
            dst[writeIndex].transformCol0 = PackedFloat3(fc0x, fc0y, ft[0][2])
            dst[writeIndex].transformCol1 = PackedFloat3(fc1x, fc1y, ft[1][2])
            dst[writeIndex].transformCol2 = PackedFloat3(fc2x, fc2y, ft[2][2])
            dst[writeIndex].alpha = frame.alpha
            dst[writeIndex].textureIndex = info.textureIndex
            dst[writeIndex].maskIndex = 0
            writeIndex += 1
        }

        return writeIndex
    }

    /// SLOW PATH: Feed sprites through SpriteCommand batcher (supports masked sprites).
    /// Only used when animation has matte/mask sprites.
    private func feedSpritesToBatch(animation: SVGAAnimation, frameIndex: Int, renderer: MetalRenderer, drawableSize: CGSize) {
        renderer.beginBatch()

        let videoSize = animation.videoSize
        let viewWidth = Float(drawableSize.width)
        let viewHeight = Float(drawableSize.height)

        if viewWidth != cachedViewWidth || viewHeight != cachedViewHeight || videoSize != cachedVideoSize {
            let scaleX = Float(drawableSize.width / videoSize.width)
            let scaleY = Float(drawableSize.height / videoSize.height)
            let scale = min(scaleX, scaleY)
            let offsetX = Float((drawableSize.width - videoSize.width * CGFloat(scale)) / 2)
            let offsetY = Float((drawableSize.height - videoSize.height * CGFloat(scale)) / 2)
            cachedBaseTransform = simd_float3x3(
                SIMD3<Float>(scale, 0, 0),
                SIMD3<Float>(0, scale, 0),
                SIMD3<Float>(offsetX, offsetY, 1)
            )
            cachedViewWidth = viewWidth
            cachedViewHeight = viewHeight
            cachedVideoSize = videoSize
        }

        let b00 = cachedBaseTransform[0][0], b01 = cachedBaseTransform[0][1]
        let b10 = cachedBaseTransform[1][0], b11 = cachedBaseTransform[1][1]
        let b20 = cachedBaseTransform[2][0], b21 = cachedBaseTransform[2][1]

        let sprites = animation.sprites

        for info in spriteRenderInfos {
            let sprite = sprites[info.spriteIndex]
            guard frameIndex < sprite.frames.count else { continue }
            let frame = sprite.frames[frameIndex]

            guard frame.alpha > 0.001 else { continue }

            let ft = frame.transform
            let fc0x = b00 * ft[0][0] + b10 * ft[0][1]
            let fc0y = b01 * ft[0][0] + b11 * ft[0][1]
            let fc1x = b00 * ft[1][0] + b10 * ft[1][1]
            let fc1y = b01 * ft[1][0] + b11 * ft[1][1]
            let fc2x = b00 * ft[2][0] + b10 * ft[2][1] + b20
            let fc2y = b01 * ft[2][0] + b11 * ft[2][1] + b21

            // SIMD AABB viewport culling
            let px = SIMD4<Float>(fc2x, fc0x + fc2x, fc1x + fc2x, fc0x + fc1x + fc2x)
            let py = SIMD4<Float>(fc2y, fc0y + fc2y, fc1y + fc2y, fc0y + fc1y + fc2y)
            if px.max() < 0 || py.max() < 0 || px.min() > viewWidth || py.min() > viewHeight {
                continue
            }

            let finalTransform = simd_float3x3(
                SIMD3<Float>(fc0x, fc0y, ft[0][2]),
                SIMD3<Float>(fc1x, fc1y, ft[1][2]),
                SIMD3<Float>(fc2x, fc2y, ft[2][2])
            )

            if info.hasMatte {
                let matteSprite = sprites[info.matteSpriteIndex]
                guard frameIndex < matteSprite.frames.count else { continue }
                let matteFrame = matteSprite.frames[frameIndex]
                guard matteFrame.alpha > 0.001 else { continue }

                let mt = matteFrame.transform
                let maskTransform = simd_float3x3(
                    SIMD3<Float>(b00 * mt[0][0] + b10 * mt[0][1], b01 * mt[0][0] + b11 * mt[0][1], mt[0][2]),
                    SIMD3<Float>(b00 * mt[1][0] + b10 * mt[1][1], b01 * mt[1][0] + b11 * mt[1][1], mt[1][2]),
                    SIMD3<Float>(b00 * mt[2][0] + b10 * mt[2][1] + b20, b01 * mt[2][0] + b11 * mt[2][1] + b21, mt[2][2])
                )

                renderer.addMaskedSpriteToBatch(
                    transform: finalTransform,
                    alpha: frame.alpha,
                    textureIndex: info.textureIndex,
                    maskTransform: maskTransform,
                    maskTextureIndex: info.matteTextureIndex
                )
            } else {
                renderer.addSpriteToBatch(
                    transform: finalTransform,
                    alpha: frame.alpha,
                    textureIndex: info.textureIndex
                )
            }
        }
    }

    // MARK: - Completion Handling

    private func handlePlaybackFinished(code: Int) {
        let completion = finishClosure
        stop()
        completion?(code)
    }

    // MARK: - Helpers

    private func isSVGAFile(url: String) -> Bool {
        let svgaExtension = "svga"
        let fileExtension = URL(fileURLWithPath: url).pathExtension
        return fileExtension.lowercased() == svgaExtension
    }

    // MARK: - Public API

    /// Get current performance metrics
    var performanceMetrics: SVGARendererStatistics? {
        renderer?.statistics
    }

    /// Get batch rendering statistics
    var batchStatistics: (drawCalls: Int, sprites: Int, efficiency: Float)? {
        renderer?.batchStatistics
    }

    /// Current GPU frame time in milliseconds (latest frame)
    var gpuFrameTimeMs: Double {
        renderer?.statistics.gpuFrameTimeMs ?? 0
    }

    /// Average GPU frame time in milliseconds (EMA smoothed)
    var gpuFrameTimeAvgMs: Double {
        renderer?.statistics.gpuFrameTimeAvgMs ?? 0
    }

    /// Peak GPU frame time in milliseconds
    var gpuFrameTimePeakMs: Double {
        renderer?.statistics.gpuFrameTimePeakMs ?? 0
    }

    /// Reset GPU timing statistics (call before starting a new performance test)
    func resetGPUTimingStats() {
        renderer?.resetGPUTimingStats()
    }

    // MARK: - Preload API

    /// Preload SVGA file into PreparedAnimationCache for instant first-frame playback.
    /// Call this when you know an animation will be played soon (e.g., when gift panel opens).
    /// Subsequent `playAnimation(playUrl:)` for the same path will have ~0ms first-frame time.
    /// - Parameters:
    ///   - filePath: Path to the SVGA file
    ///   - completion: Optional callback when preload is done (called on main thread)
    static func preload(filePath: String, completion: ((AnyObject?) -> Void)? = nil) {
        let cache = PreparedAnimationCache.shared

        // Already fully cached — nothing to do
        if let metadata = cache.getMetadata(filePath), let atlas = cache.getTexture(filePath) {
            completion?(PreparedGiftAnimation(metadata: metadata, atlas: atlas))
            return
        }

        guard let context = SharedMetalContext.shared else {
            completion?(nil)
            return
        }
        let device = context.device

        DispatchQueue.global(qos: .userInitiated).async {
            do {
                let parser = SVGAParser()
                let animation = try parser.parseSync(filePath: filePath)

                let result = try buildEncodedAtlas(animation: animation, device: device)
                let indices = result.indices
                let transparentKeys = result.transparentKeys

                var spriteMap: [String: SpriteEntity] = [:]
                spriteMap.reserveCapacity(animation.sprites.count * 2)
                for sprite in animation.sprites {
                    if !sprite.identifier.isEmpty { spriteMap[sprite.identifier] = sprite }
                    if let key = sprite.imageKey { spriteMap[key] = sprite }
                }

                animation.setExternalImageData([:])

                // Store metadata (permanent)
                let metadata = AnimationMetadata(
                    animation: animation,
                    indices: indices,
                    transparentKeys: transparentKeys,
                    spriteByKey: spriteMap
                )
                cache.setMetadata(filePath, metadata: metadata)

                // Store texture (cost-based eviction)
                cache.setTexture(filePath, atlas: result.atlas)

                DispatchQueue.main.async {
                    completion?(PreparedGiftAnimation(metadata: metadata, atlas: result.atlas))
                }
            } catch {
                LiveKitLog.error("SVGA preload failed: \(error)")
                DispatchQueue.main.async { completion?(nil) }
            }
        }
    }

    /// Check if an SVGA file is already preloaded and ready for instant playback
    static func isPreloaded(filePath: String) -> Bool {
        let cache = PreparedAnimationCache.shared
        return cache.getMetadata(filePath) != nil && cache.getTexture(filePath) != nil
    }
}

// MARK: - MTKViewDelegate

extension SVGAPlayerView: MTKViewDelegate {

    func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize) {
        // Handle size change if needed
    }

    func draw(in view: MTKView) {
        // Manual rendering via display link, not using this callback
    }
}

// MARK: - Debug

#if DEBUG
extension SVGAPlayerView {

    /// Print debug statistics
    func printStatistics() {
        guard let renderer = renderer else {
            print("[SVGAPlayerView] No renderer")
            return
        }

        let stats = renderer.statistics
        let batch = renderer.batchStatistics

        print("""
        [SVGAPlayerView Statistics]
        Frame: \(currentFrameIndex) / \(animation?.frameCount ?? 0)
        Loop: \(currentLoop + 1) / \(loopCount)
        FPS Target: \(animation?.frameRate ?? 0)
        Draw Calls: \(stats.drawCallCount)
        Vertices: \(stats.vertexCount)
        Batch Efficiency: \(String(format: "%.1f", batch.efficiency))
        Render Time: \(String(format: "%.2f", stats.frameRenderTimeMs))ms
        """)
    }
}
#endif

// Pure timing calculation shared by the display-link path and regression checks.
enum SVGAPlaybackTiming {
    static func advance(elapsed: TimeInterval, frameDuration: TimeInterval) -> (frames: Int, consumedTime: TimeInterval) {
        guard elapsed.isFinite, frameDuration.isFinite,
              elapsed > 0, frameDuration > 0 else { return (0, 0) }
        let count = floor(elapsed / frameDuration + 0.000001)
        guard count > 0, count < Double(Int.max) else { return (0, 0) }
        let frames = Int(count)
        return (frames, Double(frames) * frameDuration)
    }
}

enum SVGAPixelVisibility {
    static func isFullyTransparentBGRA(_ pixels: UnsafeRawBufferPointer) -> Bool {
        // byteOrder32Little + premultipliedFirst is B, G, R, A in memory.
        // Check every alpha: sampling can discard small visible details.
        for offset in stride(from: 3, to: pixels.count, by: 4) {
            if pixels[offset] != 0 { return false }
        }
        return true
    }
}
