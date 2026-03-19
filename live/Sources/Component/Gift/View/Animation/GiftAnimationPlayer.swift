//
//  GiftAnimationPlayer.swift
//  TUILiveKit
//
//  Created by krabyu on 2024/7/22.
//
//  Unified animation player using strategy + factory pattern.
//  Routes playback to the correct engine based on file type (SVGA / MP4 / PAG).
//

import AtomicX
import Metal

typealias AnimationViewWrapper = GiftAnimationPlayer

class GiftAnimationPlayer: UIView {

    // MARK: - Properties

    /// Current active engine
    private var currentEngine: GiftAnimationEngine?

    /// Cached engines keyed by file type for reuse
    private var engineCache: [GiftAnimationFileType: GiftAnimationEngine] = [:]

    /// The file type of the last played animation (exposed for DataReport)
    private(set) var lastPlayedFileType: GiftAnimationFileType = .unknown

    // MARK: - Init

    init() {
        super.init(frame: .zero)
        backgroundColor = .clear
        isUserInteractionEnabled = false
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private var isViewReady = false
    override func didMoveToWindow() {
        super.didMoveToWindow()
        guard !isViewReady else { return }
        isViewReady = true
    }

    // MARK: - Engine-based Playback

    /// Play animation using strategy + factory pattern.
    /// Automatically selects the correct engine (SVGA / MP4 / PAG) based on file extension.
    func playAnimation(playUrl: String, onFinished: @escaping ((Int) -> Void)) {
        LiveKitLog.info("\(#file)", "\(#line)", "playAnimation:[playUrl:\(playUrl)]")

        let fileType = GiftAnimationFileType(url: playUrl)
        lastPlayedFileType = fileType

        guard fileType != .unknown else {
            LiveKitLog.error("\(#file)", "\(#line)", "Unsupported animation format: \(playUrl)")
            onFinished(-1)
            return
        }

        // Obtain or create engine via factory
        let engine: GiftAnimationEngine
        if let cached = engineCache[fileType] {
            engine = cached
        } else {
            guard let created = GiftAnimationEngineFactory.createEngine(for: playUrl) else {
                LiveKitLog.error("\(#file)", "\(#line)", "Failed to create engine for: \(playUrl)")
                onFinished(-1)
                return
            }
            engineCache[fileType] = created
            engine = created
        }

        // Switch displayed view if engine changed
        switchEngineViewIfNeeded(engine)
        currentEngine = engine

        // Bridge delegate to closure
        let callbackAdapter = EngineCallbackAdapter(onFinished: onFinished)
        engine.delegate = callbackAdapter
        objc_setAssociatedObject(engine, &AssociatedKeys.delegateKey, callbackAdapter, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)

        // Load → Play
        engine.load(filePath: playUrl) { [weak engine] result in
            switch result {
            case .success:
                engine?.play()
            case .failure(let error):
                LiveKitLog.error("\(#file)", "\(#line)", "Engine load failed: \(error.localizedDescription)")
                onFinished(-1)
            }
        }
    }

    /// Stop the current engine
    func stopCurrentAnimation() {
        currentEngine?.stop()
    }

    // MARK: - Private

    private func switchEngineViewIfNeeded(_ engine: GiftAnimationEngine) {
        let newView = engine.contentView
        if let current = currentEngine, current.contentView === newView {
            return
        }
        currentEngine?.stop()
        currentEngine?.contentView.safeRemoveFromSuperview()

        addSubview(newView)
        newView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }
    }
}

// MARK: - AnimationView (backward compatibility)

extension GiftAnimationPlayer: AnimationView {}

// MARK: - EngineCallbackAdapter

/// Bridges GiftAnimationEngineDelegate to a simple closure callback.
private final class EngineCallbackAdapter: GiftAnimationEngineDelegate {
    private let onFinished: (Int) -> Void
    private var hasFired = false

    init(onFinished: @escaping (Int) -> Void) {
        self.onFinished = onFinished
    }

    func animationDidStart(_ engine: GiftAnimationEngine) {}

    func animationDidFinish(_ engine: GiftAnimationEngine) {
        guard !hasFired else { return }
        hasFired = true
        onFinished(0)
    }

    func animationDidFail(_ engine: GiftAnimationEngine, error: Error) {
        guard !hasFired else { return }
        hasFired = true
        onFinished(-1)
    }
}

// MARK: - Associated Keys

private struct AssociatedKeys {
    static var delegateKey: UInt8 = 0
}
