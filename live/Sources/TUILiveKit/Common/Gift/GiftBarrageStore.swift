import AtomicXCore
import Combine
import Foundation
import UIKit

/// Settles received gift combos into local barrages for both live entries.
@MainActor
final class GiftBarrageStore {
    var onGiftBarrageSettled: ((LiveGiftBarrage) -> Void)?
    var hostUserID: String?

    private struct ComboKey: Hashable {
        let senderID: String
        let receiverID: String
        let giftID: String
    }

    private struct PendingBarrage {
        var barrage: LiveGiftBarrage
        let timerID: UUID
        let timer: DispatchWorkItem
    }

    private var liveID: String?
    private var giftStore: GiftStore?
    private var cancellables = Set<AnyCancellable>()
    private var giftSubscription: AnyCancellable?
    private var pendingBarrages: [ComboKey: PendingBarrage] = [:]
    private var activationID = UUID()
    private var collectionID = UUID()
    private var isCollectionEnabled = false
    private var isApplicationActive = false

    func activate(liveID: String) {
        guard self.liveID != liveID else { return }
        deactivate()
        guard !liveID.isEmpty else { return }
        self.liveID = liveID
        isCollectionEnabled = true
        isApplicationActive = UIApplication.shared.applicationState != .background
        giftStore = GiftStore.create(liveID: liveID)
        giftStore?.setLanguage(LiveKitResources.giftLanguageCode)
        updateCollection()

        let activationID = self.activationID
        NotificationCenter.default.publisher(for: UIApplication.didEnterBackgroundNotification)
            .map { _ in false }
            .merge(with: NotificationCenter.default.publisher(for: UIApplication.didBecomeActiveNotification)
                .map { _ in true })
            .receive(on: DispatchQueue.main)
            .sink { [weak self] isActive in
                guard let self, self.activationID == activationID,
                      self.isApplicationActive != isActive else { return }
                self.isApplicationActive = isActive
                self.updateCollection()
            }
            .store(in: &cancellables)
    }

    func deactivate() {
        activationID = UUID()
        cancellables.removeAll()
        giftStore = nil
        liveID = nil
        isCollectionEnabled = false
        isApplicationActive = false
        updateCollection()
    }

    func setCollectionEnabled(_ enabled: Bool) {
        guard isCollectionEnabled != enabled else { return }
        isCollectionEnabled = enabled
        updateCollection()
    }

    private func updateCollection() {
        collectionID = UUID()
        giftSubscription = nil
        pendingBarrages.values.forEach { $0.timer.cancel() }
        pendingBarrages.removeAll()
        guard isCollectionEnabled, isApplicationActive, let giftStore else { return }

        // Resubscribe after interruptions so queued events cannot settle on resume.
        let collectionID = self.collectionID
        giftSubscription = giftStore.giftEventPublisher
            .receive(on: DispatchQueue.main)
            .sink { [weak self] event in
                guard let self, self.collectionID == collectionID else { return }
                self.receive(event)
            }
    }

    private func receive(_ event: GiftEvent) {
        if hostUserID != nil {
            guard case let .onReceiveGiftWithReceiver(eventLiveID, gift, count, sender, receiver) = event,
                  eventLiveID == liveID, count > 0 else { return }
            mergeIntoCombo(gift: gift, count: count, sender: sender, receiver: receiverIfNotHost(receiver))
            return
        }
        guard case let .onReceiveGift(eventLiveID, gift, count, sender) = event,
              eventLiveID == liveID, count > 0 else { return }
        mergeIntoCombo(gift: gift, count: count, sender: sender, receiver: nil)
    }

    private func receiverIfNotHost(_ receiver: LiveUserInfo?) -> LiveUserInfo? {
        guard let hostUserID, !hostUserID.isEmpty, let receiver,
              !receiver.userID.isEmpty, receiver.userID != hostUserID else { return nil }
        return receiver
    }

    private func mergeIntoCombo(gift: Gift, count: UInt, sender: LiveUserInfo, receiver: LiveUserInfo?) {
        let key = ComboKey(senderID: sender.userID, receiverID: receiver?.userID ?? "", giftID: gift.giftID)
        var barrage = pendingBarrages[key]?.barrage ?? LiveGiftBarrage(
            giftID: gift.giftID,
            giftName: gift.name,
            giftIconURL: gift.iconURL,
            count: 0,
            senderID: sender.userID,
            senderName: sender.userName,
            senderLevel: sender.level,
            receiverID: receiver?.userID ?? "",
            receiverName: receiver.map { $0.userName.isEmpty ? $0.userID : $0.userName } ?? ""
        )
        let total = barrage.count.addingReportingOverflow(count)
        barrage.count = total.overflow ? UInt.max : total.partialValue
        pendingBarrages[key]?.timer.cancel()

        let timerID = UUID()
        let timer = DispatchWorkItem { [weak self] in
            self?.settleBarrage(for: key, timerID: timerID)
        }
        pendingBarrages[key] = PendingBarrage(barrage: barrage, timerID: timerID, timer: timer)
        DispatchQueue.main.asyncAfter(deadline: .now() + 2, execute: timer)
    }

    private func settleBarrage(for key: ComboKey, timerID: UUID) {
        guard pendingBarrages[key]?.timerID == timerID,
              let pending = pendingBarrages.removeValue(forKey: key) else { return }
        onGiftBarrageSettled?(pending.barrage)
    }
}

/// A client-local barrage derived from an AtomicXCore gift event.
///
/// This model is never encoded or sent. Each client independently settles the
/// same gift-event combo before inserting the barrage into its local timeline.
struct LiveGiftBarrage: Equatable {
    let id: String
    let giftID: String
    let giftName: String
    let giftIconURL: String
    var count: UInt
    let senderID: String
    let senderName: String
    let senderLevel: Int
    let receiverID: String
    let receiverName: String

    init(
        id: String = UUID().uuidString,
        giftID: String,
        giftName: String,
        giftIconURL: String,
        count: UInt,
        senderID: String,
        senderName: String,
        senderLevel: Int,
        receiverID: String = "",
        receiverName: String = ""
    ) {
        self.id = id
        self.giftID = giftID
        self.giftName = giftName
        self.giftIconURL = giftIconURL
        self.count = count
        self.senderID = senderID
        self.senderName = senderName
        self.senderLevel = senderLevel
        self.receiverID = receiverID
        self.receiverName = receiverName
    }
}
