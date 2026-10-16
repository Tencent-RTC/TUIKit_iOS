import AtomicXCore
import Combine
import Foundation
import UIKit

@MainActor
final class GiftUIStore {
    private static let giftCommentComboInterval: TimeInterval = 2

    struct GiftItem: Equatable {
        let id: String
        let name: String
        let coins: Int
        let iconURL: URL?
        let resourceURL: URL?
        let categoryID: String
        let categoryName: String
    }

    struct GiftCategoryGroup: Equatable {
        let id: String
        let name: String
        let gifts: [GiftItem]
    }

    struct State: Equatable {
        var liveID: String?
        var gifts: [GiftItem] = []
        var categories: [GiftCategoryGroup] = []
        var isLoading: Bool = false
    }

    var onStateChanged: ((State) -> Void)?
    var onGiftCommentSettled: ((LiveGiftComment) -> Void)?

    private var state = State() {
        didSet { if state != oldValue { onStateChanged?(state) } }
    }

    private var giftStore: GiftStore?
    private var cancellables = Set<AnyCancellable>()
    private var pendingGiftComments: [GiftCommentComboKey: PendingGiftComment] = [:]
    private var activationID = UUID()
    private var isGiftCommentCollectionEnabled = false
    private var isApplicationActive = false

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

    func activate(liveID: String) {
        guard state.liveID != liveID else { return }
        deactivate()
        let activationID = UUID()
        self.activationID = activationID
        state.liveID = liveID
        state.isLoading = true
        isGiftCommentCollectionEnabled = true
        isApplicationActive = UIApplication.shared.applicationState != .background

        let store = GiftStore.create(liveID: liveID)
        giftStore = store
        store.setLanguage(LiveGiftLanguage.currentCode)

        store.state.subscribe()
            .receive(on: DispatchQueue.main)
            .sink { [weak self] giftState in
                guard let self,
                      self.activationID == activationID,
                      self.state.liveID == liveID
                else { return }
                self.applyGiftState(giftState)
            }
            .store(in: &cancellables)

        store.giftEventPublisher
            .receive(on: DispatchQueue.main)
            .sink { [weak self] event in
                guard let self, self.activationID == activationID else { return }
                self.receive(event, liveID: liveID)
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

        store.refreshUsableGifts { [weak self] _ in
            DispatchQueue.main.async {
                guard let self,
                      self.activationID == activationID,
                      self.state.liveID == liveID
                else { return }
                self.state.isLoading = false
            }
        }
    }

    func deactivate() {
        activationID = UUID()
        cancelPendingGiftComments()
        cancellables.removeAll()
        giftStore = nil
        isGiftCommentCollectionEnabled = false
        isApplicationActive = false
        state = State()
    }

    func setGiftCommentCollectionEnabled(_ enabled: Bool) {
        let nextValue = enabled && giftStore != nil
        guard isGiftCommentCollectionEnabled != nextValue else { return }
        isGiftCommentCollectionEnabled = nextValue
        if !nextValue {
            cancelPendingGiftComments()
        }
    }

    func sendGift(
        id: String,
        count: Int = 1,
        completion: ((Bool) -> Void)? = nil
    ) {
        guard let store = giftStore else {
            completion?(false)
            return
        }
        store.sendGift(giftID: id, count: UInt(max(1, count))) { result in
            DispatchQueue.main.async {
                switch result {
                case .success:
                    completion?(true)
                case .failure(let error):
                    LiveKitLog.error("Gift send failed: gift=\(id), error=\(error)")
                    completion?(false)
                }
            }
        }
    }

    private func applyGiftState(_ giftState: GiftState) {
        var categories: [GiftCategoryGroup] = []
        var flatten: [GiftItem] = []
        for category in giftState.usableGifts {
            let items: [GiftItem] = category.giftList.map { gift in
                GiftItem(
                    id: gift.giftID,
                    name: gift.name,
                    coins: Int(gift.coins),
                    iconURL: URL(string: gift.iconURL),
                    resourceURL: URL(string: gift.resourceURL),
                    categoryID: category.categoryID,
                    categoryName: category.name
                )
            }
            categories.append(GiftCategoryGroup(id: category.categoryID, name: category.name, gifts: items))
            flatten.append(contentsOf: items)
        }
        state.categories = categories
        state.gifts = flatten
        if !giftState.usableGifts.isEmpty {
            state.isLoading = false
        }
    }

    private func receive(_ event: GiftEvent, liveID: String) {
        guard case let .onReceiveGift(eventLiveID, gift, count, sender) = event,
              eventLiveID == liveID,
              state.liveID == liveID,
              count > 0,
              isGiftCommentCollectionEnabled,
              isApplicationActive
        else { return }

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

    private static func saturatingAdd(_ lhs: UInt, _ rhs: UInt) -> UInt {
        let result = lhs.addingReportingOverflow(rhs)
        return result.overflow ? UInt.max : result.partialValue
    }
}
