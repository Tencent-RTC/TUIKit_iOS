import AtomicXCore
import Combine
import Foundation

@MainActor final class LiveUIStore {
    struct State: Equatable {
        var liveID = ""
        var likeCount: UInt = 0
    }

    var onStateChanged: ((State) -> Void)? { didSet { onStateChanged?(state) } }

    private(set) var state = State()
    private var likeStore: LikeStore?
    private var cancellables = Set<AnyCancellable>()

    private let likeSender = LikeSender()

    func activate(liveID: String) {
        guard !liveID.isEmpty else {
            deactivate()
            return
        }
        if state.liveID == liveID, likeStore != nil { return }

        deactivate()
        state.liveID = liveID

        let likeStore = LikeStore.create(liveID: liveID)
        self.likeStore = likeStore
        likeSender.activate { likeStore.sendLike(count: $0, completion: nil) }
        likeStore.state.subscribe().receive(on: DispatchQueue.main).sink { [weak self] likeState in
            guard let self, self.state.liveID == liveID else { return }
            self.state.likeCount = likeState.totalLikeCount
            self.notify()
        }.store(in: &cancellables)
    }

    func deactivate() {
        likeSender.deactivate()
        cancellables.removeAll()
        likeStore = nil
        state = State()
        notify()
    }

    func sendLike() { likeSender.sendLike() }

    private func notify() { onStateChanged?(state) }
}

/// One sender per entry activation. Only batches sends; the host owns SDK state and UI gates.
@MainActor final class LikeSender {
    private let now: () -> TimeInterval
    private var send: ((UInt) -> Void)?
    private var pendingCount: UInt = 0
    private var lastSendTime: TimeInterval?
    private var timer: Timer?
    private var generation = UUID()

    init(now: @escaping () -> TimeInterval = { ProcessInfo.processInfo.systemUptime }) { self.now = now }

    deinit { timer?.invalidate() }

    func activate(send: @escaping (UInt) -> Void) {
        deactivate()
        self.send = send
    }

    func sendLike() {
        guard send != nil else { return }
        pendingCount += 1
        let elapsed = lastSendTime.map { now() - $0 } ?? 6
        if elapsed >= 6 {
            flush()
        } else if timer == nil {
            let generation = generation
            let timer = Timer(timeInterval: 6 - elapsed, repeats: false) { [weak self] _ in
                Task { @MainActor in
                    guard let self, self.generation == generation else { return }
                    self.flush()
                }
            }
            self.timer = timer
            RunLoop.main.add(timer, forMode: .common)
        }
    }

    func deactivate(discardPending: Bool = false) {
        generation = UUID()
        timer?.invalidate()
        timer = nil
        let action = send
        let count = pendingCount
        send = nil
        pendingCount = 0
        lastSendTime = nil
        if !discardPending, count > 0 { action?(count) }
    }

    private func flush() {
        generation = UUID()
        timer?.invalidate()
        timer = nil
        guard pendingCount > 0 else { return }
        let count = pendingCount
        pendingCount = 0
        lastSendTime = now()
        send?(count)
    }
}
