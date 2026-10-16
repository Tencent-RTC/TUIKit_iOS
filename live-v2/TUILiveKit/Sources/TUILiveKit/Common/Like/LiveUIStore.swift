import AtomicXCore
import Combine
import Foundation

@MainActor
final class LiveUIStore {
    struct State: Equatable {
        var liveID = ""
        var likeCount: UInt = 0
    }

    var onStateChanged: ((State) -> Void)? {
        didSet { onStateChanged?(state) }
    }

    private(set) var state = State()
    private var likeStore: LikeStore?
    private var cancellables = Set<AnyCancellable>()

    // SDK sendLike 限频 5s，UI 侧节流窗口取 6s：首次立即发送，窗口内累加，窗口边界统一 flush。
    private static let sendIntervalMs: Int64 = 6_000
    private var pendingCount: Int = 0
    private var lastSendAt: Int64 = 0
    private var flushWorkItem: DispatchWorkItem?

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
        likeStore.state.subscribe()
            .receive(on: DispatchQueue.main)
            .sink { [weak self] likeState in
                guard let self, self.state.liveID == liveID else { return }
                self.state.likeCount = likeState.totalLikeCount
                self.notify()
            }
            .store(in: &cancellables)
    }

    func deactivate() {
        cancelScheduledFlush()
        flushPending()
        cancellables.removeAll()
        likeStore = nil
        state = State()
        pendingCount = 0
        lastSendAt = 0
        notify()
    }

    func sendLike() {
        pendingCount += 1
        let now = nowMs()
        let elapsed = now - lastSendAt
        cancelScheduledFlush()
        if lastSendAt == 0 || elapsed > Self.sendIntervalMs {
            flushPending()
        } else {
            scheduleFlush(afterMs: Self.sendIntervalMs - elapsed + 1)
        }
    }

    private func flushPending() {
        let count = pendingCount
        guard count > 0, let store = likeStore else { return }
        pendingCount = 0
        lastSendAt = nowMs()
        store.sendLike(count: UInt(count), completion: nil)
    }

    private func scheduleFlush(afterMs: Int64) {
        let workItem = DispatchWorkItem { [weak self] in
            self?.flushPending()
        }
        flushWorkItem = workItem
        DispatchQueue.main.asyncAfter(deadline: .now() + .milliseconds(Int(max(0, afterMs))), execute: workItem)
    }

    private func cancelScheduledFlush() {
        flushWorkItem?.cancel()
        flushWorkItem = nil
    }

    private func nowMs() -> Int64 {
        Int64(Date().timeIntervalSince1970 * 1000)
    }

    private func notify() {
        onStateChanged?(state)
    }
}
