import AtomicXCore
import Combine
import Foundation
import UIKit

/// Aggregates gift statistics and settles local gift comments. Gift presentation
/// is handled inside `GiftPlayView`, which subscribes to `GiftStore` itself.
@MainActor
final class PusherGiftStore {
    private static let giftCommentComboInterval: TimeInterval = 2

    struct Statistics: Equatable {
        var giftCount = 0
        var senderCount = 0
        var score: UInt64 = 0
    }

    struct State: Equatable {
        var statistics = Statistics()
    }

    var onStateChanged: ((State) -> Void)? {
        didSet { onStateChanged?(state) }
    }
    var onGiftCommentSettled: ((LiveGiftComment) -> Void)?

    private(set) var state = State()

    private struct GiftCommentComboKey: Hashable {
        let senderID: String
        let giftID: String
    }

    private struct PendingGiftComment {
        let giftID: String
        let giftName: String
        let giftIconURL: String
        let senderID: String
        let senderName: String
        let senderLevel: Int
        var count: UInt
        var timerID: UUID
        var timer: DispatchWorkItem?
    }

    private let liveID: String
    private var giftStore: GiftStore?
    private var senderIDs = Set<String>()
    private var cancellables = Set<AnyCancellable>()
    private var pendingGiftComments: [GiftCommentComboKey: PendingGiftComment] = [:]
    private var activationID = UUID()
    private var isGiftCommentCollectionEnabled = false
    private var isApplicationActive = false

    init(liveID: String) {
        self.liveID = liveID
    }

    func activate() {
        guard !liveID.isEmpty else { return }
        deactivate(resetStatistics: true)

        let activationID = UUID()
        self.activationID = activationID
        isGiftCommentCollectionEnabled = true
        isApplicationActive = UIApplication.shared.applicationState != .background
        let giftStore = GiftStore.create(liveID: liveID)
        self.giftStore = giftStore
        giftStore.setLanguage(LiveGiftLanguage.currentCode)

        giftStore.giftEventPublisher
            .receive(on: DispatchQueue.main)
            .sink { [weak self] event in
                guard let self, self.activationID == activationID else { return }
                self.receive(event)
            }
            .store(in: &cancellables)

        NotificationCenter.default.publisher(for: UIApplication.didEnterBackgroundNotification)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                guard let self, self.activationID == activationID else { return }
                self.isApplicationActive = false
                self.cancelPendingGiftComments()
            }
            .store(in: &cancellables)

        NotificationCenter.default.publisher(for: UIApplication.didBecomeActiveNotification)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                guard let self, self.activationID == activationID else { return }
                self.isApplicationActive = true
            }
            .store(in: &cancellables)
    }

    func deactivate(resetStatistics: Bool) {
        activationID = UUID()
        cancelPendingGiftComments()
        cancellables.removeAll()
        giftStore = nil
        isGiftCommentCollectionEnabled = false
        isApplicationActive = false
        guard resetStatistics else { return }
        senderIDs.removeAll()
        state = State()
        notify()
    }

    func setGiftCommentCollectionEnabled(_ enabled: Bool) {
        guard isGiftCommentCollectionEnabled != enabled else { return }
        isGiftCommentCollectionEnabled = enabled
        if !enabled {
            cancelPendingGiftComments()
        }
    }

    private func receive(_ event: GiftEvent) {
        guard case let .onReceiveGift(eventLiveID, gift, count, sender) = event,
              eventLiveID == liveID,
              count > 0
        else { return }

        state.statistics.giftCount = Self.saturatingAdd(
            state.statistics.giftCount,
            Int(min(count, UInt(Int.max)))
        )
        if senderIDs.insert(sender.userID).inserted {
            state.statistics.senderCount = senderIDs.count
        }
        let value = UInt64(gift.coins).multipliedReportingOverflow(by: UInt64(count))
        state.statistics.score = value.overflow
            ? UInt64.max
            : Self.saturatingAdd(state.statistics.score, value.partialValue)
        notify()

        guard isGiftCommentCollectionEnabled, isApplicationActive else { return }
        accumulateGiftComment(gift: gift, count: count, sender: sender)
    }

    private func accumulateGiftComment(gift: Gift, count: UInt, sender: LiveUserInfo) {
        let key = GiftCommentComboKey(senderID: sender.userID, giftID: gift.giftID)
        var pending = pendingGiftComments[key] ?? PendingGiftComment(
            giftID: gift.giftID,
            giftName: gift.name,
            giftIconURL: gift.iconURL,
            senderID: sender.userID,
            senderName: sender.userName,
            senderLevel: sender.level,
            count: 0,
            timerID: UUID(),
            timer: nil
        )
        pending.count = Self.saturatingAdd(pending.count, count)
        pending.timer?.cancel()

        let timerID = UUID()
        let timer = DispatchWorkItem { [weak self] in
            self?.flushGiftComment(for: key, timerID: timerID)
        }
        pending.timerID = timerID
        pending.timer = timer
        pendingGiftComments[key] = pending
        DispatchQueue.main.asyncAfter(
            deadline: .now() + Self.giftCommentComboInterval,
            execute: timer
        )
    }

    private func flushGiftComment(for key: GiftCommentComboKey, timerID: UUID) {
        guard isGiftCommentCollectionEnabled,
              isApplicationActive,
              pendingGiftComments[key]?.timerID == timerID,
              let pending = pendingGiftComments.removeValue(forKey: key)
        else { return }

        onGiftCommentSettled?(LiveGiftComment(
            giftID: pending.giftID,
            giftName: pending.giftName,
            giftIconURL: pending.giftIconURL,
            count: pending.count,
            senderID: pending.senderID,
            senderName: pending.senderName,
            senderLevel: pending.senderLevel
        ))
    }

    private func cancelPendingGiftComments() {
        pendingGiftComments.values.forEach { $0.timer?.cancel() }
        pendingGiftComments.removeAll()
    }

    private func notify() {
        onStateChanged?(state)
    }

    private static func saturatingAdd(_ lhs: Int, _ rhs: Int) -> Int {
        let result = lhs.addingReportingOverflow(rhs)
        return result.overflow ? Int.max : result.partialValue
    }

    private static func saturatingAdd(_ lhs: UInt64, _ rhs: UInt64) -> UInt64 {
        let result = lhs.addingReportingOverflow(rhs)
        return result.overflow ? UInt64.max : result.partialValue
    }

    private static func saturatingAdd(_ lhs: UInt, _ rhs: UInt) -> UInt {
        let result = lhs.addingReportingOverflow(rhs)
        return result.overflow ? UInt.max : result.partialValue
    }
}
