import TCGiftPlayerKit
import UIKit

/// Owns gift order and the current/next preparation policy; media details belong to the Kit.
final class GiftAnimationView: UIView {
    private final class Effect {
        let resourceURL: String
        var task: TCGiftPreparationTask?
        var result: Result<TCGiftPreparedResource, Error>?

        init(resourceURL: String) { self.resourceURL = resourceURL }
        deinit { task?.cancel() }
    }

    private let giftPlayer = TCGiftPlayer()
    private var queue: [Effect] = []
    private var currentEffect: Effect?
    private var hasStartedPlayback = false
    private var timeoutWorkItem: DispatchWorkItem?

    override init(frame: CGRect) {
        super.init(frame: frame)
        isHidden = true
        isUserInteractionEnabled = false
        backgroundColor = .clear
        let canvas = giftPlayer.view
        canvas.translatesAutoresizingMaskIntoConstraints = false
        addSubview(canvas)
        NSLayoutConstraint.activate([
            canvas.leadingAnchor.constraint(equalTo: leadingAnchor),
            canvas.trailingAnchor.constraint(equalTo: trailingAnchor),
            canvas.topAnchor.constraint(equalTo: topAnchor),
            canvas.bottomAnchor.constraint(equalTo: bottomAnchor),
        ])
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func enqueue(resourceURL: String) {
        queue.append(Effect(resourceURL: resourceURL))
        playNextIfNeeded()
        prepareNextIfNeeded()
    }

    func reset() {
        // Invalidate the queue before cancellation can deliver any late result.
        queue.removeAll()
        clearCurrentEffect()
    }

    private func playNextIfNeeded() {
        guard currentEffect == nil, !queue.isEmpty else { return }
        let effect = queue.removeFirst()
        currentEffect = effect
        isHidden = false
        scheduleTimeout(for: effect)
        if effect.result != nil {
            consumePreparation(effect)
        } else {
            prepare(effect)
        }
    }

    private func prepareNextIfNeeded() {
        guard hasStartedPlayback, let next = queue.first else { return }
        prepare(next)
    }

    private func prepare(_ effect: Effect) {
        guard effect.task == nil, effect.result == nil else { return }
        effect.task = giftPlayer.prepare(resourceURL: effect.resourceURL) { [weak self, weak effect] result in
            guard let self, let effect else { return }
            effect.task = nil
            effect.result = result
            self.consumePreparation(effect)
        }
    }

    private func consumePreparation(_ effect: Effect) {
        guard currentEffect === effect, let result = effect.result else { return }
        switch result {
        case .success(let resource):
            giftPlayer.play(resource: resource) { [weak self, weak effect] event in
                guard let self, let effect, self.currentEffect === effect else { return }
                switch event {
                case .started:
                    self.hasStartedPlayback = true
                    self.scheduleTimeout(for: effect)
                    self.prepareNextIfNeeded()
                case .finished:
                    self.finishCurrentEffect()
                case .failed(let error):
                    LiveKitLog.error("Gift playback failed: \(error.localizedDescription)")
                    self.finishCurrentEffect()
                }
            }
        case .failure(let error):
            LiveKitLog.error("Gift preparation failed: \(error.localizedDescription)")
            finishCurrentEffect()
        }
    }

    private func scheduleTimeout(for effect: Effect) {
        timeoutWorkItem?.cancel()
        let work = DispatchWorkItem { [weak self, weak effect] in
            guard let self, let effect, self.currentEffect === effect else { return }
            LiveKitLog.error("Gift effect timed out")
            self.finishCurrentEffect()
        }
        timeoutWorkItem = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 30, execute: work)
    }

    private func finishCurrentEffect() {
        clearCurrentEffect()
        playNextIfNeeded()
    }

    private func clearCurrentEffect() {
        let previous = currentEffect
        currentEffect = nil
        previous?.task?.cancel()
        timeoutWorkItem?.cancel()
        timeoutWorkItem = nil
        hasStartedPlayback = false
        giftPlayer.stop()
        isHidden = true
    }
}
