import Foundation

enum AICallState {
    case idle
    case listening
    case thinking
    case speaking
}

enum AICallError {
    case audioUnavailable
    case playbackUnavailable
    case asrStartFailed
    case sendFailed
    case replyTimeout
}

struct AICallTranscriptEntry {
    let isUser: Bool
    let text: String
    var isFailed: Bool = false
    var msgID: String? = nil
    var isStreaming: Bool = false
    var speechProgress: AICallSpeechProgress? = nil
}

final class AICallSpeechProgress: StreamRevealLimiter {
    private static let estimatedCharactersPerSecond = 8.0
    private let playedMillisecondsProvider: () -> Int
    private let speed: Double
    private var synthesizedMilliseconds: Int?
    private var frozenPlayedMilliseconds: Int?
    private var isUnlimited = false
    private var lastRevealLimit = 0

    init(speed: Float, playedMillisecondsProvider: @escaping () -> Int) {
        self.speed = Double(speed)
        self.playedMillisecondsProvider = playedMillisecondsProvider
    }

    var isSettled: Bool {
        isUnlimited || frozenPlayedMilliseconds != nil
    }

    func revealLimit(forTotalLength totalLength: Int) -> Int {
        guard !isUnlimited else { return totalLength }
        let playedMilliseconds = frozenPlayedMilliseconds ?? playedMillisecondsProvider()
        let limit: Int
        if let synthesizedMilliseconds, synthesizedMilliseconds > 0 {
            let fraction = min(1, max(0, Double(playedMilliseconds) / Double(synthesizedMilliseconds)))
            limit = Int(Double(totalLength) * fraction)
        } else {
            limit = Int(Double(max(0, playedMilliseconds)) / 1000 * Self.estimatedCharactersPerSecond * speed)
        }
        lastRevealLimit = min(totalLength, max(lastRevealLimit, limit))
        return lastRevealLimit
    }

    func markSynthesisFinished(totalMilliseconds: Int) {
        synthesizedMilliseconds = totalMilliseconds
    }

    func settleAtCurrentPosition() {
        guard !isSettled else { return }
        let playedMilliseconds = playedMillisecondsProvider()
        if playedMilliseconds > 0 {
            frozenPlayedMilliseconds = playedMilliseconds
        } else {
            removeLimit()
        }
    }

    func removeLimit() {
        isUnlimited = true
    }
}
