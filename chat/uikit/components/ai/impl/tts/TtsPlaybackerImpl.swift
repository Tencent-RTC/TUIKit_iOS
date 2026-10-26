import AVFoundation
import Foundation
import ImSDK_Plus

final class TtsPlaybackerImpl {
    weak var owner: TtsPlaybacker?

    private let streaming = TtsStreamingPlayback()

    private var player: AVPlayer?

    private var playerItem: AVPlayerItem?

    private var endObserver: NSObjectProtocol?

    private var failedObserver: NSObjectProtocol?

    private var session = 0
    private var pendingOnComplete: (() -> Void)?

    init() {}

    static func hasSpeakableText(_ text: String) -> Bool {
        return !TtsTextProcessor.shared.sanitize(text: text).isEmpty
    }

    /// 合成并播放文本，重复调用会使旧请求回调失效。请在主线程调用。
    func playText(text: String,
                  voiceId: String = "",
                  language: String = "",
                  removeSymbols: Bool = false,
                  onStart: (() -> Void)? = nil,
                  onComplete: (() -> Void)? = nil,
                  onError: ((String) -> Void)? = nil) {
        streaming.stop(notifyCompletion: false)
        teardownPlayer()
        session += 1
        let currentSession = session
        pendingOnComplete = onComplete
        let speechText = removeSymbols ? TtsTextProcessor.shared.sanitize(text: text) : text
        if removeSymbols, speechText.isEmpty {
            DispatchQueue.main.async { [weak self] in
                guard let self, let owner = self.owner, self.session == currentSession else { return }
                let callback = self.pendingOnComplete
                self.pendingOnComplete = nil
                withExtendedLifetime(owner) { callback?() }
            }
            return
        }
        AiMediaProcessManager.convertTextToVoice(
            text: speechText,
            voiceId: voiceId,
            language: language,
            onSuccess: { [weak self] audioUrl in
                guard let self, let owner = self.owner, currentSession == self.session else { return }
                defer { withExtendedLifetime(owner) {} }
                guard let url = URL(string: audioUrl) else {
                    self.pendingOnComplete = nil
                    onError?("invalid tts audio url")
                    return
                }
                self.startPlayback(currentSession: currentSession, url: url, onStart: onStart, onComplete: onComplete, onError: onError)
            },
            onFailure: { [weak self] _, desc in
                guard let self, let owner = self.owner, currentSession == self.session else { return }
                defer { withExtendedLifetime(owner) {} }
                self.pendingOnComplete = nil
                onError?(desc)
            }
        )
    }

    func playStreamMessage(message: V2TIMMessage, voiceId: String, speed: Float,
                           onStart: (() -> Void)?, onProgress: ((TtsPlaybackProgress) -> Void)?,
                           onComplete: (() -> Void)?, onError: ((Int32, String) -> Void)?) {
        session += 1
        pendingOnComplete = nil
        teardownPlayer()
        streaming.playStreamMessage(message: message, voiceId: voiceId, speed: speed,
                                    onStart: onStart, onProgress: onProgress, onComplete: onComplete, onError: onError)
    }

    func stop(notifyCompletion: Bool = true) {
        session += 1
        let callback = notifyCompletion ? pendingOnComplete : nil
        pendingOnComplete = nil
        teardownPlayer()
        streaming.stop(notifyCompletion: notifyCompletion)
        callback?()
    }

    deinit {
        teardownPlayer()
        streaming.stop(notifyCompletion: false)
    }

    private func startPlayback(currentSession: Int,
                               url: URL,
                               onStart: (() -> Void)?,
                               onComplete: (() -> Void)?,
                               onError: ((String) -> Void)?) {
        teardownPlayer()
        do {
            try AVAudioSession.sharedInstance().setCategory(.playback, mode: .default)
            try AVAudioSession.sharedInstance().setActive(true)
        } catch {
            pendingOnComplete = nil
            onError?(error.localizedDescription)
            return
        }
        let item = AVPlayerItem(url: url)
        let avPlayer = AVPlayer(playerItem: item)
        avPlayer.actionAtItemEnd = .pause

        endObserver = NotificationCenter.default.addObserver(
            forName: .AVPlayerItemDidPlayToEndTime,
            object: item,
            queue: .main
        ) { [weak self] _ in
            guard let self, let owner = self.owner, currentSession == self.session else { return }
            defer { withExtendedLifetime(owner) {} }
            self.pendingOnComplete = nil
            self.teardownPlayer()
            onComplete?()
        }
        failedObserver = NotificationCenter.default.addObserver(
            forName: .AVPlayerItemFailedToPlayToEndTime,
            object: item,
            queue: .main
        ) { [weak self] notification in
            guard let self, let owner = self.owner, currentSession == self.session else { return }
            defer { withExtendedLifetime(owner) {} }
            self.pendingOnComplete = nil
            self.teardownPlayer()
            let error = notification.userInfo?[AVPlayerItemFailedToPlayToEndTimeErrorKey] as? Error
            onError?(error?.localizedDescription ?? "play failed")
        }

        playerItem = item
        player = avPlayer
        avPlayer.play()
        onStart?()
    }

    private func teardownPlayer() {
        if let endObserver {
            NotificationCenter.default.removeObserver(endObserver)
            self.endObserver = nil
        }
        if let failedObserver {
            NotificationCenter.default.removeObserver(failedObserver)
            self.failedObserver = nil
        }
        player?.pause()
        player = nil
        playerItem = nil
    }
}

extension TtsPlaybacker {
    static func hasSpeakableText(_ text: String) -> Bool {
        return TtsPlaybackerImpl.hasSpeakableText(text)
    }
}
