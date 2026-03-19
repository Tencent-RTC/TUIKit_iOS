//
//  SVGAAnimationEngine.swift
//  TUILiveKit
//
//  Concrete GiftAnimationEngine implementation for SVGA format.
//  Wraps SVGAPlayerView (Metal-based) via the AnimationView protocol.
//

import UIKit

final class SVGAAnimationEngine: GiftAnimationEngine {

    // MARK: - Properties

    weak var delegate: GiftAnimationEngineDelegate?

    var contentView: UIView { animationView }

    private let animationView: AnimationView & UIView
    private var repeatCount: Int = 1
    private var loadedFilePath: String?

    // MARK: - Init

    init() {
        self.animationView = SVGAPlayerView()
    }

    // MARK: - GiftAnimationEngine

    func load(filePath: String, completion: @escaping (Result<Void, Error>) -> Void) {
        guard filePath.lowercased().hasSuffix(".svga") else {
            completion(.failure(NSError(domain: "GiftAnimationEngine", code: -1, userInfo: [NSLocalizedDescriptionKey: "Expected .svga file, got: \(filePath)"])))
            return
        }
        loadedFilePath = filePath
        completion(.success(()))
    }

    func play() {
        guard let filePath = loadedFilePath else { return }
        delegate?.animationDidStart(self)
        animationView.playAnimation(playUrl: filePath) { [weak self] code in
            guard let self = self else { return }
            if code == 0 {
                self.delegate?.animationDidFinish(self)
            } else {
                let error = NSError(domain: "GiftAnimationEngine", code: code, userInfo: [NSLocalizedDescriptionKey: "SVGA playback failed with code \(code)"])
                self.delegate?.animationDidFail(self, error: error)
            }
        }
    }

    func pause() {
        // Pause is not directly supported by existing AnimationView protocol.
    }

    func stop() {
        loadedFilePath = nil
    }

    func setRepeatCount(_ count: Int) {
        repeatCount = count
    }

    func seek(to frame: Int) {
        // Seek is not directly supported by existing AnimationView protocol.
    }
}
