import AVFoundation
import Foundation

final class TtsPlaybackHelper {
    private(set) var isPlaying = false

    private var player: AVPlayer?

    private var playerItem: AVPlayerItem?

    private var endObserver: NSObjectProtocol?

    private var failedObserver: NSObjectProtocol?

    private var session = 0

    func speak(text: String,
               voiceId: String = "",
               language: String = "",
               onStart: (() -> Void)? = nil,
               onComplete: (() -> Void)? = nil,
               onError: ((String) -> Void)? = nil) {
        session += 1
        let currentSession = session
        AiMediaProcessManager.convertTextToVoice(
            text: text,
            voiceId: voiceId,
            onSuccess: { [weak self] audioUrl in
                guard let self, currentSession == self.session else { return }
                guard let url = URL(string: audioUrl) else {
                    onError?("invalid tts audio url")
                    return
                }
                self.startPlayback(currentSession: currentSession, url: url, onStart: onStart, onComplete: onComplete, onError: onError)
            },
            onFailure: { [weak self] _, desc in
                guard let self, currentSession == self.session else { return }
                self.isPlaying = false
                onError?(desc)
            }
        )
    }

    func stop() {
        session += 1
        isPlaying = false
        teardownPlayer()
    }

    deinit {
        teardownPlayer()
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
            guard let self, currentSession == self.session else { return }
            self.isPlaying = false
            self.teardownPlayer()
            onComplete?()
        }
        failedObserver = NotificationCenter.default.addObserver(
            forName: .AVPlayerItemFailedToPlayToEndTime,
            object: item,
            queue: .main
        ) { [weak self] notification in
            guard let self, currentSession == self.session else { return }
            self.isPlaying = false
            self.teardownPlayer()
            let error = notification.userInfo?[AVPlayerItemFailedToPlayToEndTimeErrorKey] as? Error
            onError?(error?.localizedDescription ?? "play failed")
        }

        playerItem = item
        player = avPlayer
        isPlaying = true
        onStart?()
        avPlayer.play()
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
