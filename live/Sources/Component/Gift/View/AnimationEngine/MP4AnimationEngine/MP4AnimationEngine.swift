//
//  MP4AnimationEngine.swift
//  TUILiveKit
//
//  Concrete GiftAnimationEngine implementation for MP4 format.
//  Wraps the existing TCEffectAnimationView (TUIEffectPlayerService).
//

import UIKit

final class MP4AnimationEngine: GiftAnimationEngine {

    // MARK: - Properties

    weak var delegate: GiftAnimationEngineDelegate?

    var contentView: UIView { effectView }

    private let effectView: TCEffectAnimationView = TCEffectAnimationView()
    private var repeatCount: Int = 1
    private var loadedFilePath: String?

    // MARK: - GiftAnimationEngine

    func load(filePath: String, completion: @escaping (Result<Void, Error>) -> Void) {
        guard filePath.lowercased().hasSuffix(".mp4") else {
            completion(.failure(NSError(domain: "GiftAnimationEngine", code: -1, userInfo: [NSLocalizedDescriptionKey: "Expected .mp4 file, got: \(filePath)"])))
            return
        }
        guard effectView.usable else {
            completion(.failure(NSError(domain: "GiftAnimationEngine", code: -2, userInfo: [NSLocalizedDescriptionKey: "TUIEffectPlayerService is not available"])))
            return
        }
        loadedFilePath = filePath
        completion(.success(()))
    }

    func play() {
        guard let filePath = loadedFilePath else { return }
        delegate?.animationDidStart(self)
        effectView.playAnimation(playUrl: filePath) { [weak self] code in
            guard let self = self else { return }
            if code == 0 {
                self.delegate?.animationDidFinish(self)
            } else {
                let error = NSError(domain: "GiftAnimationEngine", code: code, userInfo: [NSLocalizedDescriptionKey: "MP4 playback failed with code \(code)"])
                self.delegate?.animationDidFail(self, error: error)
            }
        }
    }

    func pause() {
        // MP4 pause not exposed by TCEffectAnimationView currently.
    }

    func stop() {
        loadedFilePath = nil
    }

    func setRepeatCount(_ count: Int) {
        repeatCount = count
    }

    func seek(to frame: Int) {
        // Seek not supported for MP4 effect player.
    }
}
