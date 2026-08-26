import Foundation
import Combine

final class ChatAudioPlaybackCoordinator {
    static let shared = ChatAudioPlaybackCoordinator()

    var playingPublisher: AnyPublisher<String?, Never> {
        playingSubject.eraseToAnyPublisher()
    }

    private let player = AudioPlayer.create()

    private let playingSubject = CurrentValueSubject<String?, Never>(nil)

    private var isPlayingCancellable: AnyCancellable?

    func isPlaying(msgID: String) -> Bool {
        return playingSubject.value == msgID && player.isPlaying
    }

    func toggle(msgID: String, url: URL) {
        if isPlaying(msgID: msgID) {
            player.pause()
            playingSubject.send(nil)
        } else {
            playingSubject.send(msgID)
            player.play(url)
        }
    }

    func stop() {
        player.stop()
        playingSubject.send(nil)
    }

    private init() {
        isPlayingCancellable = player.$isPlaying.sink { [weak self] isPlaying in
            guard !isPlaying else { return }
            self?.playingSubject.send(nil)
        }
    }
}
