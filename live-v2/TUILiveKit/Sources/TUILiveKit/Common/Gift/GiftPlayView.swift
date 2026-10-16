import AtomicXCore
import Combine
import UIKit
import SnapKit

/// Owns the "gift received -> gift rendered" loop by subscribing to
/// `GiftStore.giftEventPublisher` itself. Hosts may reserve local successful-send
/// previews, but never forward received gift events into the view.
final class GiftPlayView: UIView {
    private enum Constants {
        static let horizontalInset: CGFloat = 12
        static let channelHeight: CGFloat = 44
        static let channelSpacing: CGFloat = 4
        static let toolbarAndMessageOffset: CGFloat = 86
        static let welcomeReservedHeight: CGFloat = 32
    }

    private struct LocalGiftReservation {
        let id: UUID
        let comboKey: String
        let gift: LiveGiftEvent
        var remainingCount: UInt
        var isDisplayed: Bool
    }

    private let entryView = LiveGiftEntryView()
    private let effectView = LiveGiftEffectView()
    private var entryBottomConstraint: Constraint?
    private var messageContentHeight: CGFloat = 0
    private var toolbarAndMessageOffset = Constants.toolbarAndMessageOffset
    private var isAudienceWelcomeVisible = false
    private var giftStore: GiftStore?
    private var cancellables = Set<AnyCancellable>()
    private var liveID = ""
    private var activatedLiveID: String?
    private var activationID = UUID()
    private var isSuspended = false
    private var isActive = true
    private var giftPanelHeightAboveSafeArea: CGFloat?
    private var localGiftReservations: [LocalGiftReservation] = []

    init(liveID: String) {
        self.liveID = liveID
        super.init(frame: .zero)
        configureUI()
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleApplicationDidEnterBackground),
            name: UIApplication.didEnterBackgroundNotification,
            object: nil
        )
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }

    /// Window presence owns subscriptions; a retained, hidden stage can also
    /// deactivate its gift presentation without removing the view hierarchy.
    override func didMoveToWindow() {
        super.didMoveToWindow()
        if window == nil {
            deactivate()
        } else {
            activate()
        }
    }

    func setActive(_ active: Bool) {
        isActive = active
        if active, window != nil {
            activate()
        } else {
            deactivate()
        }
    }

    /// Suppresses rendering while the live is paused. Late events arriving in
    /// this window are dropped instead of being replayed afterwards.
    func setSuspended(_ isSuspended: Bool) {
        guard self.isSuspended != isSuspended else { return }
        self.isSuspended = isSuspended
        effectView.setSuspended(isSuspended)
    }

    func show(_ gift: LiveGiftEvent) {
        guard isActive, !isSuspended else { return }
        entryView.enqueue(gift)
        if gift.isAdvanced {
            effectView.enqueue(resourceURL: gift.resourceURL)
        }
    }

    @discardableResult
    func reserveLocalGift(_ gift: LiveGiftEvent) -> UUID? {
        guard isActive, !isSuspended, gift.count > 0 else {
            return nil
        }
        let id = UUID()
        localGiftReservations.append(
            LocalGiftReservation(
                id: id,
                comboKey: gift.comboKey,
                gift: gift,
                remainingCount: gift.count,
                isDisplayed: false
            )
        )
        return id
    }

    func confirmLocalGift(id: UUID) {
        guard let index = localGiftReservations.firstIndex(where: { $0.id == id }),
              !localGiftReservations[index].isDisplayed,
              localGiftReservations[index].remainingCount > 0
        else {
            return
        }
        localGiftReservations[index].isDisplayed = true
        show(Self.copy(localGiftReservations[index].gift, count: localGiftReservations[index].remainingCount))
    }

    func cancelLocalGift(id: UUID) {
        removeLocalGiftReservation(id: id)
    }

    func updateMessageContentHeight(_ height: CGFloat) {
        messageContentHeight = max(0, height)
        updateEntryBottomConstraint()
    }

    func updateToolbarAndMessageOffset(_ offset: CGFloat) {
        toolbarAndMessageOffset = max(0, offset)
        updateEntryBottomConstraint()
    }

    func updateAudienceWelcomeVisible(_ isVisible: Bool) {
        guard isAudienceWelcomeVisible != isVisible else { return }
        isAudienceWelcomeVisible = isVisible
        updateEntryBottomConstraint()
    }

    func updateGiftPanelHeightAboveSafeArea(_ height: CGFloat?) {
        giftPanelHeightAboveSafeArea = height.map { max(0, $0) }
        updateEntryBottomConstraint()
    }

    func resetEntries() {
        entryView.reset()
    }

    func resetPresentation() {
        resetEntries()
        effectView.reset()
    }

    private func resetSession() {
        localGiftReservations.removeAll()
        resetPresentation()
    }

    private func configureUI() {
        isUserInteractionEnabled = false
        clipsToBounds = false
        addSubview(entryView)
        addSubview(effectView)
        // Keep overlapping capsules below the effect, including newly animated entries.
        entryView.layer.zPosition = 0
        effectView.layer.zPosition = 1
        entryView.snp.makeConstraints { make in
            make.leading.trailing.equalToSuperview().inset(Constants.horizontalInset)
            make.height.equalTo(
                Constants.channelHeight * 2 + Constants.channelSpacing
            )
            entryBottomConstraint = make.bottom.equalTo(safeAreaLayoutGuide.snp.bottom)
                .offset(-Constants.toolbarAndMessageOffset).constraint
        }
        effectView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }
    }

    @objc private func handleApplicationDidEnterBackground() {
        resetPresentation()
    }

    private func activate() {
        guard isActive, !liveID.isEmpty, activatedLiveID != liveID else { return }
        deactivate()

        let activationID = UUID()
        self.activationID = activationID
        activatedLiveID = liveID
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
    }

    private func deactivate() {
        activationID = UUID()
        cancellables.removeAll()
        giftStore = nil
        activatedLiveID = nil
        resetSession()
    }

    private func receive(_ event: GiftEvent) {
        guard case let .onReceiveGift(eventLiveID, gift, count, sender) = event,
              eventLiveID == activatedLiveID,
              count > 0
        else { return }

        let receivedGift = LiveGiftEvent(
            giftID: gift.giftID,
            name: gift.name,
            iconURL: gift.iconURL,
            resourceURL: gift.resourceURL,
            coins: gift.coins,
            count: count,
            senderID: sender.userID,
            senderName: sender.userName,
            senderAvatarURL: sender.avatarURL
        )
        let visibleCounts = consumeLocalGiftReservations(
            comboKey: receivedGift.comboKey,
            count: receivedGift.count
        )
        for visibleCount in visibleCounts {
            show(Self.copy(receivedGift, count: visibleCount))
        }
    }

    private func updateEntryBottomConstraint() {
        if let giftPanelHeightAboveSafeArea {
            entryBottomConstraint?.update(offset: -giftPanelHeightAboveSafeArea)
            return
        }
        let welcomeOffset = isAudienceWelcomeVisible
            ? Constants.welcomeReservedHeight
            : 0
        entryBottomConstraint?.update(offset: -(
            toolbarAndMessageOffset
                + messageContentHeight
                + welcomeOffset
        ))
    }

    private func consumeLocalGiftReservations(comboKey: String, count: UInt) -> [UInt] {
        var unconsumedCount = count
        var visibleCounts: [UInt] = []
        var index = 0
        while index < localGiftReservations.count, unconsumedCount > 0 {
            guard localGiftReservations[index].comboKey == comboKey else {
                index += 1
                continue
            }
            let consumed = min(unconsumedCount, localGiftReservations[index].remainingCount)
            // Preserve each local send when an aggregated SDK event arrives
            // before the individual send completions. Already displayed sends
            // are only reconciled; they must not enqueue another animation.
            if !localGiftReservations[index].isDisplayed, consumed > 0 {
                visibleCounts.append(consumed)
            }
            unconsumedCount -= consumed
            localGiftReservations[index].remainingCount -= consumed
            if localGiftReservations[index].remainingCount == 0 {
                localGiftReservations.remove(at: index)
            } else {
                index += 1
            }
        }
        if unconsumedCount > 0 { visibleCounts.append(unconsumedCount) }
        return visibleCounts
    }

    private func removeLocalGiftReservation(id: UUID) {
        guard let index = localGiftReservations.firstIndex(where: { $0.id == id }) else { return }
        localGiftReservations.remove(at: index)
    }

    private static func copy(_ gift: LiveGiftEvent, count: UInt) -> LiveGiftEvent {
        LiveGiftEvent(
            giftID: gift.giftID,
            name: gift.name,
            iconURL: gift.iconURL,
            resourceURL: gift.resourceURL,
            coins: gift.coins,
            count: count,
            senderID: gift.senderID,
            senderName: gift.senderName,
            senderAvatarURL: gift.senderAvatarURL
        )
    }
}
