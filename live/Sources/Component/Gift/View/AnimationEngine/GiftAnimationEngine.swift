//
//  GiftAnimationEngine.swift
//  TUILiveKit
//
//  Gift animation engine abstraction layer.
//  Strategy Pattern: defines a unified interface for all animation engines.
//

import UIKit

// MARK: - GiftAnimationEngineDelegate

protocol GiftAnimationEngineDelegate: AnyObject {
    func animationDidStart(_ engine: GiftAnimationEngine)
    func animationDidFinish(_ engine: GiftAnimationEngine)
    func animationDidFail(_ engine: GiftAnimationEngine, error: Error)
}

// MARK: - GiftAnimationEngine

protocol GiftAnimationEngine: AnyObject {

    // MARK: Resource Loading

    /// Load animation resource from a local file path or remote URL.
    /// - Parameters:
    ///   - filePath: Local path **or** remote URL string (e.g. `https://…/gift.svga`, `/tmp/gift.mp4`).
    ///   - completion: Called on the main thread once loading finishes.
    func load(filePath: String, completion: @escaping (Result<Void, Error>) -> Void)

    // MARK: Playback Control

    func play()
    func pause()
    func stop()

    // MARK: Playback Configuration

    /// Set the number of times the animation should repeat.
    /// - Parameter count: `1` plays once (default), `-1` loops infinitely.
    func setRepeatCount(_ count: Int)

    /// Seek to a specific frame index.
    func seek(to frame: Int)

    // MARK: View

    /// The renderable view that hosts the animation content.
    /// Add this view to your view hierarchy before calling `play()`.
    var contentView: UIView { get }

    // MARK: Delegate

    var delegate: GiftAnimationEngineDelegate? { get set }
}


