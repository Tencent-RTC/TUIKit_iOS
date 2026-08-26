import AVFoundation
import AVKit
import Combine
import UIKit

class AudioPlayer: NSObject, ObservableObject {
    @Published public var isPlaying: Bool = false

    @Published public var isPaused: Bool = false

    @Published public var currentPlayingURL: URL? = nil

    private var player: AVPlayer?

    private var playerItem: AVPlayerItem?

    private var endObserver: NSObjectProtocol?

    private var failedObserver: NSObjectProtocol?

    private var itemStatusObservation: NSKeyValueObservation?

    public static func create() -> AudioPlayer {
        return AudioPlayer()
    }

    func play(_ url: URL) {
        if isPlaying, currentPlayingURL == url {
            teardownPlayer()
            return
        }
        if player != nil {
            teardownPlayer()
        }
        playInternal(url)
    }

    func pause() {
        guard let player = player, isPlaying else { return }
        player.pause()
        isPlaying = false
        isPaused = true
    }

    func resume() {
        guard let player = player, isPaused else { return }
        player.play()
        isPlaying = true
        isPaused = false
    }

    public func stop() {
        guard player != nil else { return }
        teardownPlayer()
    }

    deinit {
        teardownPlayer()
    }

    private func playInternal(_ url: URL) {
        #if os(iOS)
        do {
            try AVAudioSession.sharedInstance().setCategory(.playback, mode: .default)
            try AVAudioSession.sharedInstance().setActive(true)
        } catch {
            print("AudioPlayer: AVAudioSession setup failed: \(error.localizedDescription)")
            teardownPlayer()
            return
        }
        #endif

        let item = AVPlayerItem(url: url)
        let avPlayer = AVPlayer(playerItem: item)
        avPlayer.actionAtItemEnd = .pause

        endObserver = NotificationCenter.default.addObserver(
            forName: .AVPlayerItemDidPlayToEndTime,
            object: item,
            queue: .main
        ) { [weak self] _ in
            print("AudioPlayer: Playback finished")
            self?.teardownPlayer()
        }

        failedObserver = NotificationCenter.default.addObserver(
            forName: .AVPlayerItemFailedToPlayToEndTime,
            object: item,
            queue: .main
        ) { [weak self] notification in
            let error = notification.userInfo?[AVPlayerItemFailedToPlayToEndTimeErrorKey] as? Error
            print("AudioPlayer: Item failed to play to end: \(error?.localizedDescription ?? "unknown")")
            self?.teardownPlayer()
        }

        itemStatusObservation = item.observe(\.status, options: [.new]) { [weak self] observedItem, _ in
            guard let self = self else { return }
            switch observedItem.status {
            case .failed:
                print("AudioPlayer: Item status failed: \(observedItem.error?.localizedDescription ?? "unknown")")
                DispatchQueue.main.async { self.teardownPlayer() }
            case .readyToPlay, .unknown:
                break
            @unknown default:
                break
            }
        }

        playerItem = item
        player = avPlayer
        currentPlayingURL = url
        isPlaying = true
        isPaused = false

        avPlayer.play()
    }

    private func teardownPlayer() {
        if let observer = endObserver {
            NotificationCenter.default.removeObserver(observer)
            endObserver = nil
        }
        if let observer = failedObserver {
            NotificationCenter.default.removeObserver(observer)
            failedObserver = nil
        }
        itemStatusObservation?.invalidate()
        itemStatusObservation = nil

        player?.pause()
        player = nil
        playerItem = nil

        isPlaying = false
        isPaused = false
        currentPlayingURL = nil
    }
}
