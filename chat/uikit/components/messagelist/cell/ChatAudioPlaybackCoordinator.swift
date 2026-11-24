import Foundation
import Combine

final class ChatAudioPlaybackScope {
    private(set) var isVisible = false
    private(set) var generation = 0

    func setVisible(_ isVisible: Bool) {
        guard self.isVisible != isVisible else { return }
        self.isVisible = isVisible
        generation += 1
        if !isVisible { ChatAudioPlaybackCoordinator.shared.stop(scope: self) }
    }

    deinit {
        ChatAudioPlaybackCoordinator.shared.stop(scope: self)
    }
}

final class ChatAudioPlaybackCoordinator {
    static let shared = ChatAudioPlaybackCoordinator()

    struct PlaybackRequest {
        fileprivate let generation: Int
        fileprivate weak var scope: ChatAudioPlaybackScope?
        fileprivate let scopeID: ObjectIdentifier?
        fileprivate let scopeGeneration: Int?
    }

    private var requestGeneration = 0
    private var playingScopeID: ObjectIdentifier?

    var playingPublisher: AnyPublisher<String?, Never> {
        playingSubject.eraseToAnyPublisher()
    }

    private let player = AudioPlayer.create()

    private let playingSubject = CurrentValueSubject<String?, Never>(nil)

    private var isPlayingCancellable: AnyCancellable?

    func isPlaying(msgID: String, scope: ChatAudioPlaybackScope?) -> Bool {
        playingSubject.value == msgID && player.isPlaying && playingScopeID == scope.map(ObjectIdentifier.init)
    }

    func beginRequest(scope: ChatAudioPlaybackScope?) -> PlaybackRequest? {
        guard scope?.isVisible != false else { return nil }
        requestGeneration += 1
        return PlaybackRequest(generation: requestGeneration, scope: scope,
                               scopeID: scope.map(ObjectIdentifier.init), scopeGeneration: scope?.generation)
    }

    func isCurrent(_ request: PlaybackRequest) -> Bool {
        request.generation == requestGeneration
            && request.scopeID == request.scope.map(ObjectIdentifier.init)
            && request.scopeGeneration == request.scope?.generation
            && request.scope?.isVisible != false
    }

    func toggle(msgID: String, url: URL, scope: ChatAudioPlaybackScope?) {
        guard scope?.isVisible != false else { return }
        requestGeneration += 1
        if isPlaying(msgID: msgID, scope: scope) {
            player.pause()
            playingSubject.send(nil)
        } else {
            stop()
            playingScopeID = scope.map(ObjectIdentifier.init)
            player.play(url)
            playingSubject.send(player.isPlaying ? msgID : nil)
        }
    }

    func stop(scope: ChatAudioPlaybackScope) {
        guard playingScopeID == ObjectIdentifier(scope) else { return }
        stop()
    }

    func stop() {
        requestGeneration += 1
        player.stop()
        playingScopeID = nil
        playingSubject.send(nil)
    }

    private init() {
        isPlayingCancellable = player.$isPlaying.sink { [weak self] isPlaying in
            guard !isPlaying else { return }
            self?.playingSubject.send(nil)
        }
        NotificationCenter.default.addObserver(forName: .chatVideoPlaybackDidStart, object: nil, queue: .main) { [weak self] _ in
            self?.stop()
        }
    }
}
