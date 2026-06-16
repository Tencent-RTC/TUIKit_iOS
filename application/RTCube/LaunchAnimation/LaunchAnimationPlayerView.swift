//
//  LaunchAnimationPlayerView.swift
//  RTCube / TencentRTC / RTCubeLab
//

import AVFoundation
import SnapKit
import UIKit

enum LaunchAnimationFinishReason {
    case finished
    case failed
    case timedOut
}

final class LaunchAnimationPlayerView: UIView {
    // MARK: - Public

    var onFinished: ((LaunchAnimationFinishReason) -> Void)?

    var timeoutSeconds: TimeInterval = 8.0

    // MARK: - Private

    private let videoURL: URL
    private var player: AVPlayer?
    private var playerLayer: AVPlayerLayer?
    private var timeoutWorkItem: DispatchWorkItem?
    private var hasFinished = false

    // MARK: - Init

    init(videoURL: URL) {
        self.videoURL = videoURL
        super.init(frame: .zero)
        backgroundColor = .white
        setupPlayer()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
        timeoutWorkItem?.cancel()
    }

    // MARK: - Layout

    override func layoutSubviews() {
        super.layoutSubviews()
        playerLayer?.frame = bounds
    }

    // MARK: - Setup

    private func setupPlayer() {
        let asset = AVURLAsset(url: videoURL)
        let item = AVPlayerItem(asset: asset)
        let player = AVPlayer(playerItem: item)
        player.actionAtItemEnd = .pause
        player.isMuted = false

        let playerLayer = AVPlayerLayer(player: player)
        playerLayer.videoGravity = .resizeAspectFill
        layer.addSublayer(playerLayer)

        self.player = player
        self.playerLayer = playerLayer

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(onItemDidPlayToEnd),
            name: .AVPlayerItemDidPlayToEndTime,
            object: item
        )
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(onItemFailedToPlayToEnd),
            name: .AVPlayerItemFailedToPlayToEndTime,
            object: item
        )
    }

    func play() {
        scheduleTimeoutFallback()
        player?.play()
    }

    private func scheduleTimeoutFallback() {
        let work = DispatchWorkItem { [weak self] in
            self?.finish(reason: .timedOut)
        }
        timeoutWorkItem = work
        DispatchQueue.main.asyncAfter(deadline: .now() + timeoutSeconds, execute: work)
    }

    // MARK: - Notifications

    @objc private func onItemDidPlayToEnd() {
        finish(reason: .finished)
    }

    @objc private func onItemFailedToPlayToEnd() {
        finish(reason: .failed)
    }

    // MARK: - Finish

    private func finish(reason: LaunchAnimationFinishReason) {
        guard !hasFinished else { return }
        hasFinished = true
        timeoutWorkItem?.cancel()
        timeoutWorkItem = nil
        player?.pause()
        let callback = onFinished
        onFinished = nil
        callback?(reason)
    }
}
