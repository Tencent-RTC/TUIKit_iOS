import SnapKit
import TCEffectPlayer
import UIKit

final class LiveGiftEffectView: UIView, TCEPAnimViewDelegate {
    private enum ResourceKind {
        case svga
        case mp4

        init?(resourceURL: String) {
            guard let url = URL(string: resourceURL) else { return nil }
            switch url.pathExtension.lowercased() {
            case "svga": self = .svga
            case "mp4": self = .mp4
            default: return nil
            }
        }
    }

    private struct PendingEffect {
        let id = UUID()
        let resourceURL: String
        let kind: ResourceKind
    }

    private final class Preparation {
        let effectID: UUID
        var task: URLSessionDownloadTask?
        var localURL: URL?
        var asset: AnyObject?
        var ready = false
        var failed = false

        init(effectID: UUID) { self.effectID = effectID }
        deinit { task?.cancel() }
    }

    private var currentPreparation: Preparation?
    private var nextPreparation: Preparation?

    private let loader = LiveGiftEffectLoader()
    private let animationCanvasView = UIView()
    private let svgaPlayer = SVGAPlayerView()
    private let effectPlayerView = TCEffectAnimView(frame: .zero)
    private var queue: [PendingEffect] = []
    private var currentEffect: PendingEffect?
    private var currentLocalURL: URL?
    private var timeoutWorkItem: DispatchWorkItem?
    private var licenseRetryWorkItem: DispatchWorkItem?
    private var isWaitingForLicense = false
    private var isSuspended = false
    private var hasStartedPlayback = false
    private var generation = UUID()

    override init(frame: CGRect) {
        super.init(frame: frame)
        configureUI()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func enqueue(resourceURL: String) {
        guard let kind = ResourceKind(resourceURL: resourceURL) else { return }
        let effect = PendingEffect(resourceURL: resourceURL, kind: kind)
        queue.append(effect)
        playNextIfNeeded()
        prepareNextIfNeeded()
    }

    func setSuspended(_ suspended: Bool) {
        guard isSuspended != suspended else { return }
        isSuspended = suspended
        if suspended {
            timeoutWorkItem?.cancel()
            timeoutWorkItem = nil
            licenseRetryWorkItem?.cancel()
            licenseRetryWorkItem = nil
            guard hasStartedPlayback else { return }
            switch currentEffect?.kind {
            case .svga:
                svgaPlayer.pause()
            case .mp4:
                effectPlayerView.pause()
            case nil:
                break
            }
        } else {
            resumeCurrentEffectIfNeeded()
        }
    }

    func reset() {
        generation = UUID()
        nextPreparation?.task?.cancel()
        nextPreparation = nil
        queue.removeAll()
        currentEffect = nil
        cleanupPlayback()
        isHidden = true
    }

    func tcePlayerEnd(_ player: ITCEffectPlayer) {
        guard !isWaitingForLicense, !isSuspended else { return }
        finishCurrentEffect()
    }

    func tcePlayerError(_ player: ITCEffectPlayer, error: Error) {
        if Self.isLicenseError(error), currentLocalURL != nil {
            isWaitingForLicense = true
            if !isSuspended {
                scheduleLicenseRetry()
            }
            return
        }
        LiveKitLog.error("Gift MP4 playback failed: \(error.localizedDescription)")
        finishCurrentEffect()
    }

    private func configureUI() {
        isHidden = true
        isUserInteractionEnabled = false
        backgroundColor = .clear

        animationCanvasView.backgroundColor = .clear
        animationCanvasView.isUserInteractionEnabled = false
        addSubview(animationCanvasView)

        svgaPlayer.svgaContentMode = .scaleAspectFit
        svgaPlayer.setLoops(1)
        animationCanvasView.addSubview(svgaPlayer)

        effectPlayerView.backgroundColor = .clear
        effectPlayerView.effectPlayerDelegate = self
        effectPlayerView.setLoop(false)
        effectPlayerView.setRenderMode(.aspectFill)
        let alphaRightMode = TCEPVAPVideoFrameTextureBlendMode(rawValue: 2)!
        effectPlayerView.setVideoMode(alphaRightMode)
        effectPlayerView.isUserInteractionEnabled = false
        animationCanvasView.addSubview(effectPlayerView)

        animationCanvasView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }
        svgaPlayer.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }
        effectPlayerView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }
    }

    private func playNextIfNeeded() {
        guard currentEffect == nil, !queue.isEmpty else { return }
        let effect = queue.removeFirst()
        currentEffect = effect
        let currentGeneration = generation
        isHidden = false
        if !isSuspended { scheduleTimeout(effectID: effect.id, generation: currentGeneration) }

        if let prepared = nextPreparation, prepared.effectID == effect.id {
            currentPreparation = prepared
            nextPreparation = nil
            consumePreparation(prepared)
        } else {
            let prepared = Preparation(effectID: effect.id)
            currentPreparation = prepared
            prepare(effect, into: prepared, generation: currentGeneration)
        }
    }

    private func prepareNextIfNeeded() {
        guard !isSuspended, hasStartedPlayback, nextPreparation == nil, let effect = queue.first else { return }
        let prepared = Preparation(effectID: effect.id)
        nextPreparation = prepared
        prepare(effect, into: prepared, generation: generation)
    }

    private func prepare(_ effect: PendingEffect, into prepared: Preparation, generation: UUID) {
        if effect.kind == .svga, currentEffect?.resourceURL == effect.resourceURL,
           let current = currentPreparation, current !== prepared,
           current.ready, let asset = current.asset, let localURL = current.localURL {
            prepared.asset = asset
            prepared.localURL = localURL
            prepared.ready = true
            consumePreparation(prepared)
            return
        }
        prepared.task = loader.load(resourceURL: effect.resourceURL) { [weak self, weak prepared] result in
            guard let self, let prepared, self.generation == generation else { return }
            prepared.task = nil
            switch result {
            case .success(let localURL):
                prepared.localURL = localURL
                if effect.kind == .svga {
                    SVGAPlayerView.preload(filePath: localURL.path) { [weak self, weak prepared] asset in
                        guard let self, let prepared, self.generation == generation else { return }
                        prepared.asset = asset
                        prepared.failed = asset == nil
                        prepared.ready = true
                        self.consumePreparation(prepared)
                    }
                } else {
                    prepared.ready = true
                    self.consumePreparation(prepared)
                }
            case .failure(let error):
                LiveKitLog.error("Gift effect download failed: \(error)")
                prepared.failed = true
                prepared.ready = true
                self.consumePreparation(prepared)
            }
        }
    }

    private func consumePreparation(_ prepared: Preparation) {
        guard currentPreparation === prepared, prepared.ready,
              let effect = currentEffect, effect.id == prepared.effectID else { return }
        if prepared.failed {
            finishCurrentEffect()
        } else if let localURL = prepared.localURL {
            play(effect, localURL: localURL, generation: generation)
        }
    }

    private func play(_ effect: PendingEffect, localURL: URL, generation: UUID) {
        currentLocalURL = localURL
        guard !isSuspended else { return }
        startCurrentEffect(effect: effect, localURL: localURL, generation: generation)
    }

    private func startCurrentEffect(effect: PendingEffect, localURL: URL, generation: UUID) {
        scheduleTimeout(effectID: effect.id, generation: generation)
        switch effect.kind {
        case .svga:
            playSVGA(localURL: localURL, effectID: effect.id, generation: generation)
        case .mp4:
            hasStartedPlayback = true
            playMP4(localURL: localURL)
        }
        prepareNextIfNeeded()
    }

    private func playSVGA(localURL: URL, effectID: UUID, generation: UUID) {
        effectPlayerView.isHidden = true
        svgaPlayer.isHidden = false
        hasStartedPlayback = true
        svgaPlayer.playAnimation(playUrl: localURL.path, prepared: currentPreparation?.asset) { [weak self] code in
            guard let self,
                  self.generation == generation,
                  self.currentEffect?.id == effectID else { return }
            if code != 0 { LiveKitLog.error("Gift SVGA playback failed: code=\(code)") }
            self.finishCurrentEffect()
        }
    }

    private func playMP4(localURL: URL) {
        svgaPlayer.isHidden = true
        effectPlayerView.isHidden = false
        effectPlayerView.startPlay(localURL.path)
    }

    private func resumeCurrentEffectIfNeeded() {
        guard let effect = currentEffect else { return }
        scheduleTimeout(effectID: effect.id, generation: generation)
        prepareNextIfNeeded()
        guard let localURL = currentLocalURL else { return }
        if isWaitingForLicense {
            scheduleLicenseRetry()
            return
        }
        switch effect.kind {
        case .svga:
            if hasStartedPlayback {
                svgaPlayer.resume()
            } else {
                startCurrentEffect(effect: effect, localURL: localURL, generation: generation)
            }
        case .mp4:
            if hasStartedPlayback {
                effectPlayerView.resume()
            } else {
                hasStartedPlayback = true
                playMP4(localURL: localURL)
            }
        }
    }

    private func scheduleLicenseRetry() {
        licenseRetryWorkItem?.cancel()
        let currentGeneration = generation
        let effectID = currentEffect?.id
        let work = DispatchWorkItem { [weak self] in
            guard let self,
                  self.generation == currentGeneration,
                  self.currentEffect?.id == effectID,
                  !self.isSuspended,
                  let localURL = self.currentLocalURL
            else { return }
            self.isWaitingForLicense = false
            self.playMP4(localURL: localURL)
        }
        licenseRetryWorkItem = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 1, execute: work)
    }

    private func scheduleTimeout(effectID: UUID, generation: UUID) {
        timeoutWorkItem?.cancel()
        let work = DispatchWorkItem { [weak self] in
            guard let self,
                  self.generation == generation,
                  self.currentEffect?.id == effectID
            else { return }
            if self.isWaitingForLicense {
                LiveKitLog.error("Gift MP4 playback timed out while waiting for license")
            }
            self.finishCurrentEffect()
        }
        timeoutWorkItem = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 30, execute: work)
    }

    private func finishCurrentEffect() {
        guard currentEffect != nil else { return }
        cleanupPlayback()
        currentEffect = nil
        isHidden = true
        playNextIfNeeded()
    }

    private func cleanupPlayback() {
        currentPreparation?.task?.cancel()
        currentPreparation = nil
        timeoutWorkItem?.cancel()
        timeoutWorkItem = nil
        licenseRetryWorkItem?.cancel()
        licenseRetryWorkItem = nil
        isWaitingForLicense = false
        hasStartedPlayback = false
        currentLocalURL = nil
        svgaPlayer.stop()
        effectPlayerView.stopPlay()
    }

    private static func isLicenseError(_ error: Error) -> Bool {
        let error = error as NSError
        return error.code == -10009 || error.localizedDescription.lowercased().contains("license")
    }
}
