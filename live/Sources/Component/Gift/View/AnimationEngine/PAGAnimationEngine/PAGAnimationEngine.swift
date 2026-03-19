//
//  PAGAnimationEngine.swift
//  TUILiveKit
//
//  Concrete GiftAnimationEngine implementation for PAG format.
//  Uses PAG SDK (libpag) via TEBeautyKit → TencentEffect_S1-07 → libpag.xcframework.
//

import UIKit

#if canImport(libpag)
import libpag
#endif
// MARK: - PAGAnimationEngine

final class PAGAnimationEngine: NSObject, GiftAnimationEngine {

    // MARK: - Properties

    weak var delegate: GiftAnimationEngineDelegate?

    var contentView: UIView {
        #if canImport(libpag)
        return pagView
        #else
        return fallbackView
        #endif
    }

    #if canImport(libpag)
    private let pagView: PAGView = {
        let view = PAGView()
        view.setRepeatCount(1)
        view.setScaleMode(PAGScaleModeLetterBox)
        return view
    }()

    private var pagFile: PAGFile?
    #else
    private let fallbackView: UIView = {
        let view = UIView()
        view.backgroundColor = .clear
        return view
    }()
    #endif

    private var repeatCount: Int = 1
    private var loadedFilePath: String?
    private var isPlaying: Bool = false

    // MARK: - Init

    override init() {
        super.init()
        #if canImport(libpag)
        pagView.add(self)
        #endif
    }

    deinit {
        #if canImport(libpag)
        pagView.remove(self)
        pagView.stop()
        #endif
    }

    // MARK: - GiftAnimationEngine

    func load(filePath: String, completion: @escaping (Result<Void, Error>) -> Void) {
        #if canImport(libpag)
        guard filePath.lowercased().hasSuffix(".pag") else {
            completion(.failure(NSError(domain: "PAGAnimationEngine", code: -1,
                                        userInfo: [NSLocalizedDescriptionKey: "Invalid file extension: \(filePath)"])))
            return
        }

        pagView.stop()
        pagFile = nil
        loadedFilePath = nil
        isPlaying = false

        pagView.setPathAsync(filePath) { [weak self] file in
            guard let self = self else { return }
            guard let file = file else {
                completion(.failure(NSError(domain: "PAGAnimationEngine", code: -2,
                                            userInfo: [NSLocalizedDescriptionKey: "Failed to load PAG file: \(filePath)"])))
                return
            }
            self.pagFile = file
            self.loadedFilePath = filePath
            self.pagView.setRepeatCount(Int32(self.repeatCount))
            completion(.success(()))
        }
        #else
        completion(.failure(NSError(domain: "PAGAnimationEngine", code: -3,
                                    userInfo: [NSLocalizedDescriptionKey: "PAG SDK is not available"])))
        #endif
    }

    func play() {
        #if canImport(libpag)
        guard loadedFilePath != nil, pagFile != nil else { return }
        isPlaying = true
        pagView.play()
        #endif
    }

    func pause() {
        #if canImport(libpag)
        guard isPlaying else { return }
        pagView.pause()
        isPlaying = false
        #endif
    }

    func stop() {
        #if canImport(libpag)
        pagView.stop()
        isPlaying = false
        #endif
    }

    func setRepeatCount(_ count: Int) {
        repeatCount = count
        #if canImport(libpag)
        // PAG: 0 means infinite loop, so map -1 → 0
        let pagRepeat: Int32 = (count == -1) ? 0 : Int32(count)
        pagView.setRepeatCount(pagRepeat)
        #endif
    }

    func seek(to frame: Int) {
        #if canImport(libpag)
        guard let file = pagFile else { return }
        let frameRate = file.frameRate()
        guard frameRate > 0 else { return }
        let totalFrames = Double(file.duration()) / 1_000_000.0 * Double(frameRate)
        guard totalFrames > 0 else { return }
        let progress = Double(frame) / totalFrames
        pagView.setProgress(min(max(progress, 0.0), 1.0))
        pagView.flush()
        #endif
    }
}

// MARK: - PAGViewListener

#if canImport(libpag)
extension PAGAnimationEngine: PAGViewListener {

    func onAnimationStart(_ pagView: PAGView) {
        delegate?.animationDidStart(self)
    }

    func onAnimationEnd(_ pagView: PAGView) {
        isPlaying = false
        delegate?.animationDidFinish(self)
    }

    func onAnimationCancel(_ pagView: PAGView) {
        isPlaying = false
        delegate?.animationDidFinish(self)
    }
}
#endif
