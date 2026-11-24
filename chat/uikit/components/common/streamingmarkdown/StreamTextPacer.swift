import Foundation

protocol StreamTextPacerListener: AnyObject {
    func streamTextPacer(_ pacer: StreamTextPacer, didAdvance msgID: String, revealedLength: Int)
}

final class StreamTextPacer {
    static let shared = StreamTextPacer()

    private static let tickInterval: TimeInterval = 0.033
    private static let catchUpDuration: TimeInterval = 1

    private final class State {
        var text: NSString = ""
        var stableLength = 0
        var revealedLength = 0
        var speedBudget: Double = 0
        var maxCharactersPerSecond: Double = 0
        var isStreaming = true
        weak var limiter: StreamRevealLimiter?
        weak var listener: StreamTextPacerListener?
    }

    private struct StateKey: Hashable {
        let msgID: String
        let listenerID: ObjectIdentifier
    }

    private var states: [StateKey: State] = [:]
    private var timer: Timer?

    private init() {}

    func revealedLength(msgID: String,
                        rendered: NSAttributedString,
                        stableLength: Int,
                        isStreaming: Bool,
                        limiter: StreamRevealLimiter? = nil,
                        maxCharactersPerSecond: Double = 0,
                        listener: StreamTextPacerListener?) -> Int {
        guard !msgID.isEmpty, let listener else {
            return Self.limitedLength(rendered.length, limiter: limiter)
        }
        let key = StateKey(msgID: msgID, listenerID: ObjectIdentifier(listener))
        guard rendered.length > 0 else {
            states.removeValue(forKey: key)
            stopTimerIfIdle()
            return 0
        }
        let speed = maxCharactersPerSecond.isFinite && maxCharactersPerSecond > 0
            ? maxCharactersPerSecond : 0
        if let state = states[key], state.listener === listener {
            if state.maxCharactersPerSecond != speed {
                state.maxCharactersPerSecond = speed
                state.speedBudget = 0
            }
            state.text = rendered.string as NSString
            state.stableLength = stableLength
            state.revealedLength = min(state.revealedLength, rendered.length)
            state.isStreaming = isStreaming
            state.limiter = limiter
            state.listener = listener
            startTimerIfNeeded()
            return state.revealedLength
        }
        let needsPacing = isStreaming || (limiter.map { !$0.isSettled } ?? false)
        guard needsPacing else {
            return Self.limitedLength(rendered.length, limiter: limiter)
        }
        let state = State()
        state.maxCharactersPerSecond = speed
        state.text = rendered.string as NSString
        state.stableLength = stableLength
        state.isStreaming = isStreaming
        state.limiter = limiter
        state.listener = listener
        states[key] = state
        startTimerIfNeeded()
        return 0
    }

    func isRevealing(msgID: String) -> Bool {
        states.contains { key, state in
            key.msgID == msgID && state.listener != nil && !isFinished(state)
        }
    }

    func detach(msgID: String, listener: StreamTextPacerListener) {
        let key = StateKey(msgID: msgID, listenerID: ObjectIdentifier(listener))
        guard let state = states[key], state.listener === listener else { return }
        states.removeValue(forKey: key)
        stopTimerIfIdle()
    }

    func discard(msgID: String) {
        for key in Array(states.keys) where key.msgID == msgID {
            states.removeValue(forKey: key)
        }
        stopTimerIfIdle()
    }

    private func startTimerIfNeeded() {
        guard timer == nil else { return }
        let timer = Timer(timeInterval: Self.tickInterval, repeats: true) { [weak self] _ in
            self?.tick()
        }
        RunLoop.main.add(timer, forMode: .common)
        self.timer = timer
    }

    private func stopTimerIfIdle() {
        guard states.isEmpty else { return }
        timer?.invalidate()
        timer = nil
    }

    private func tick() {
        var finishedStates: [(StateKey, State)] = []
        for (key, state) in states {
            guard states[key] === state else { continue }
            if state.listener == nil {
                finishedStates.append((key, state))
                continue
            }
            if !isFinished(state) {
                advance(state, msgID: key.msgID)
            }
            if isFinished(state) {
                finishedStates.append((key, state))
            }
        }
        for (key, state) in finishedStates where states[key] === state {
            states.removeValue(forKey: key)
        }
        stopTimerIfIdle()
    }

    private func isFinished(_ state: State) -> Bool {
        guard !state.isStreaming else { return false }
        if state.revealedLength >= state.text.length {
            return true
        }
        guard let limiter = state.limiter, limiter.isSettled else { return false }
        return state.revealedLength >= revealLimit(of: state)
    }

    private func advance(_ state: State, msgID: String) {
        let limit = revealLimit(of: state)
        guard state.revealedLength < limit else { return }
        let backlog = Double(limit - state.revealedLength)
        let catchUpStep = max(1, Int(backlog * Self.tickInterval / Self.catchUpDuration))
        let step = speedLimitedStep(state, desired: catchUpStep)
        guard step > 0 else { return }
        let boundary = Self.composedBoundary(in: state.text, atLeast: state.revealedLength + step)
        let next = min(limit, boundary)
        guard next > state.revealedLength else { return }
        state.speedBudget -= Double(next - state.revealedLength)
        state.revealedLength = next
        state.listener?.streamTextPacer(self, didAdvance: msgID, revealedLength: next)
    }

    private func revealLimit(of state: State) -> Int {
        let total = state.text.length
        let parsedLimit = state.isStreaming ? min(state.stableLength, total) : total
        return min(parsedLimit, Self.limitedLength(total, limiter: state.limiter))
    }

    private static func limitedLength(_ total: Int, limiter: StreamRevealLimiter?) -> Int {
        guard let limiter else { return total }
        return min(total, max(0, limiter.revealLimit(forTotalLength: total)))
    }

    private func speedLimitedStep(_ state: State, desired: Int) -> Int {
        guard state.maxCharactersPerSecond > 0 else { return desired }
        let perTick = state.maxCharactersPerSecond * Self.tickInterval
        state.speedBudget = min(state.speedBudget + perTick, max(perTick, 1))
        return Int(min(Double(desired), max(0, state.speedBudget)))
    }

    private static func composedBoundary(in string: NSString, atLeast length: Int) -> Int {
        guard length < string.length else { return string.length }
        let range = string.rangeOfComposedCharacterSequence(at: length)
        return range.location == length ? length : NSMaxRange(range)
    }
}
