//
//  LaunchAnimationPlayerView.swift
//  RTCube / TencentRTC / RTCubeLab
//
//  开屏动画播放视图：使用 AVPlayer 播放本地 mov 资源，播放结束（或失败 / 超时）后
//  通过回调通知调用方移除自身。单一职责：仅负责"播放 + 完成回调"。
//
//  布局：自身使用 SnapKit 约束铺满父视图。`AVPlayerLayer` 是 CALayer 不参与
//  Auto Layout，仅其 `frame` 在 `layoutSubviews` 中跟随 `bounds` 同步——这是
//  CALayer 与 Auto Layout 协同的业界标准做法。
//

import AVFoundation
import SnapKit
import UIKit

/// 开屏动画播放完成事件
enum LaunchAnimationFinishReason {
    /// 视频自然播放结束
    case finished
    /// 播放失败 / 资源不存在 / 解码错误
    case failed
    /// 超时兜底（防止视频异常卡死阻塞启动）
    case timedOut
}

final class LaunchAnimationPlayerView: UIView {
    // MARK: - Public

    /// 播放结束回调（仅触发一次）
    var onFinished: ((LaunchAnimationFinishReason) -> Void)?

    /// 兜底超时（秒）。视频异常未触发结束事件时主动结束，避免卡死启动流程。
    var timeoutSeconds: TimeInterval = 8.0

    // MARK: - Private

    private let videoURL: URL
    private var player: AVPlayer?
    private var playerLayer: AVPlayerLayer?
    private var timeoutWorkItem: DispatchWorkItem?
    private var hasFinished = false

    // MARK: - Init

    /// - Parameter videoURL: 视频文件路径（本地 file URL）
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

    /// `AVPlayerLayer` 不参与 Auto Layout，需在此同步其 frame。
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

    /// 启动播放（视图被加入到父视图后调用）
    func play() {
        // 超时兜底从 play() 开始计时，而非 init 时：
        // SceneDelegate 路径中 play() 在 dismiss completion 里调用，与 init 之间有 dismiss 动画间隔，
        // 从实际起播时刻计时可确保完整的超时窗口。
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
