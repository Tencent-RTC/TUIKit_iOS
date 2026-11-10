import AtomicXCore
import Combine
import UIKit
import SnapKit

/// Owns the "gift received -> gift rendered" loop by subscribing to
/// `GiftStore.giftEventPublisher` itself. Hosts may reserve local successful-send
/// previews, but never forward received gift events into the view.
final class GiftDisplayView: UIView {
    var onNoticeContentHeightChanged: ((CGFloat) -> Void)?
    var noticeContentHeight: CGFloat { noticeView.visibleContentHeight }

    private enum Constants {
        static let horizontalInset: CGFloat = 12
        static let channelHeight: CGFloat = 44
        static let channelSpacing: CGFloat = 4
    }

    private struct LocalGiftReservation {
        let id: UUID
        let comboKey: String
        let gift: GiftDisplayItem
        let presentationID: UUID?
        var remainingCount: UInt
        var isDisplayed: Bool
    }

    /// SDK events can arrive off the main thread, before Combine queues delivery.
    private final class PresentationGeneration {
        private let lock = NSLock()
        private var id = UUID()

        var current: UUID {
            lock.lock()
            defer { lock.unlock() }
            return id
        }

        func reset() {
            lock.lock()
            defer { lock.unlock() }
            id = UUID()
        }
    }

    private let noticeViewport = UIView()
    private let noticeClipMask = CAShapeLayer()
    private var noticeTopBoundary: CGFloat?
    private let noticeView = GiftNoticeView()
    private let animationView = GiftAnimationView()
    private var noticeBottomConstraint: Constraint?
    private var giftStore: GiftStore?
    private var cancellables = Set<AnyCancellable>()
    private var liveID = ""
    private var activatedLiveID: String?
    private var activationID = UUID()
    private let presentationGeneration = PresentationGeneration()
    private var isPresentationEnabled = true
    private var isInBackground = UIApplication.shared.applicationState == .background
    private var isActive = true
    private var localGiftReservations: [LocalGiftReservation] = []

    init(liveID: String) {
        self.liveID = liveID
        super.init(frame: .zero)
        configureUI()
        NotificationCenter.default.addObserver(
            self, selector: #selector(handleApplicationDidEnterBackground),
            name: UIApplication.didEnterBackgroundNotification, object: nil)
        NotificationCenter.default.addObserver(
            self, selector: #selector(handleApplicationDidBecomeActive),
            name: UIApplication.didBecomeActiveNotification, object: nil)
    }

    @available(*, unavailable) required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    deinit { NotificationCenter.default.removeObserver(self) }

    /// Window presence owns subscriptions; a retained, hidden stage can also
    /// deactivate its gift presentation without removing the view hierarchy.
    override func didMoveToWindow() {
        super.didMoveToWindow()
        if window == nil { deactivate() } else { activate() }
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        updateNoticeClip()
    }

    /// Final Y coordinates in this view; the full-screen effect keeps its own canvas.
    func updateNoticeLayout(bottom: CGFloat, topBoundary: CGFloat?) {
        noticeBottomConstraint?.update(offset: bottom)
        if noticeTopBoundary != topBoundary {
            noticeTopBoundary = topBoundary
            updateNoticeClip()
        }
    }

    private func updateNoticeClip() {
        guard let noticeTopBoundary else {
            noticeViewport.layer.mask = nil
            return
        }
        let top = min(max(0, noticeTopBoundary), bounds.height)
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        noticeClipMask.frame = noticeViewport.bounds
        noticeClipMask.path =
            UIBezierPath(rect: CGRect(x: 0, y: top, width: bounds.width, height: max(0, bounds.height - top))).cgPath
        noticeViewport.layer.mask = noticeClipMask
        CATransaction.commit()
    }

    func setActive(_ active: Bool) {
        isActive = active
        if active, window != nil { activate() } else { deactivate() }
    }

    /// Interruptions end the current presentation; enabling accepts only new gifts.
    func setPresentationEnabled(_ enabled: Bool) {
        guard isPresentationEnabled != enabled else { return }
        isPresentationEnabled = enabled
        resetPresentation()
    }

    private var canPresent: Bool {
        isActive && activatedLiveID != nil && window != nil && isPresentationEnabled && !isInBackground
    }

    func show(_ gift: GiftDisplayItem) {
        guard canPresent else { return }
        noticeView.enqueue(gift)
        if gift.isAdvanced { animationView.enqueue(resourceURL: gift.resourceURL) }
    }

    @discardableResult func reserveLocalGift(_ gift: GiftDisplayItem) -> UUID? {
        guard isActive, activatedLiveID != nil, gift.count > 0 else { return nil }
        let id = UUID()
        localGiftReservations.append(
            LocalGiftReservation(
                id: id, comboKey: gift.comboKey, gift: gift,
                // Hidden sends still need an SDK echo reservation, but never a preview.
                presentationID: canPresent ? presentationGeneration.current : nil, remainingCount: gift.count,
                isDisplayed: false))
        return id
    }

    func confirmLocalGift(id: UUID) {
        guard let index = localGiftReservations.firstIndex(where: { $0.id == id }),
            !localGiftReservations[index].isDisplayed, localGiftReservations[index].remainingCount > 0
        else { return }
        localGiftReservations[index].isDisplayed = true
        guard localGiftReservations[index].presentationID == presentationGeneration.current else { return }
        show(Self.copy(localGiftReservations[index].gift, count: localGiftReservations[index].remainingCount))
    }

    func cancelLocalGift(id: UUID) { removeLocalGiftReservation(id: id) }

    func resetNotices() { noticeView.reset() }

    func resetPresentation() {
        presentationGeneration.reset()
        resetNotices()
        animationView.reset()
    }

    private func resetSession() {
        localGiftReservations.removeAll()
        resetPresentation()
    }

    private func configureUI() {
        isUserInteractionEnabled = false
        clipsToBounds = false
        addSubview(noticeViewport)
        noticeViewport.addSubview(noticeView)
        noticeView.onVisibleContentHeightChanged = { [weak self] height in self?.onNoticeContentHeightChanged?(height) }
        addSubview(animationView)
        // Keep overlapping capsules below the effect, including newly animated entries.
        noticeView.layer.zPosition = 0
        animationView.layer.zPosition = 1
        noticeViewport.snp.makeConstraints { make in make.edges.equalToSuperview() }
        noticeView.snp.makeConstraints { make in
            make.leading.trailing.equalToSuperview().inset(Constants.horizontalInset)
            make.height.equalTo(Constants.channelHeight * 2 + Constants.channelSpacing)
            noticeBottomConstraint = make.bottom.equalTo(self.snp.top).constraint
        }
        animationView.snp.makeConstraints { make in make.edges.equalToSuperview() }
    }

    @objc private func handleApplicationDidEnterBackground() {
        isInBackground = true
        resetPresentation()
    }

    @objc private func handleApplicationDidBecomeActive() {
        guard isInBackground else { return }
        isInBackground = false
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
        giftStore.setLanguage(LiveKitResources.giftLanguageCode)

        let presentationGeneration = presentationGeneration
        giftStore.giftEventPublisher.map { ($0, presentationGeneration.current) }.receive(on: DispatchQueue.main).sink {
            [weak self] event, presentationID in
            guard let self, self.activationID == activationID else { return }
            self.receive(event, presentationID: presentationID)
        }.store(in: &cancellables)
    }

    private func deactivate() {
        activationID = UUID()
        cancellables.removeAll()
        giftStore = nil
        activatedLiveID = nil
        resetSession()
    }

    private func receive(_ event: GiftEvent, presentationID: UUID) {
        guard case let .onReceiveGift(eventLiveID, gift, count, sender) = event, eventLiveID == activatedLiveID,
            count > 0
        else { return }

        let receivedGift = GiftDisplayItem(
            giftID: gift.giftID, name: gift.name, iconURL: gift.iconURL, resourceURL: gift.resourceURL,
            coins: gift.coins, count: count, senderID: sender.userID, senderName: sender.userName,
            senderAvatarURL: sender.avatarURL)
        let visibleCounts = consumeLocalGiftReservations(comboKey: receivedGift.comboKey, count: receivedGift.count)
        guard presentationID == presentationGeneration.current else { return }
        for visibleCount in visibleCounts { show(Self.copy(receivedGift, count: visibleCount)) }
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
            // before individual completions. Displayed or interrupted sends
            // are only reconciled; they must not enqueue another animation.
            if !localGiftReservations[index].isDisplayed,
                localGiftReservations[index].presentationID == presentationGeneration.current, consumed > 0
            {
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

    private static func copy(_ gift: GiftDisplayItem, count: UInt) -> GiftDisplayItem {
        GiftDisplayItem(
            giftID: gift.giftID, name: gift.name, iconURL: gift.iconURL, resourceURL: gift.resourceURL,
            coins: gift.coins, count: count, senderID: gift.senderID, senderName: gift.senderName,
            senderAvatarURL: gift.senderAvatarURL)
    }
}

// MARK: - Display data

struct GiftDisplayItem: Equatable {
    let giftID: String
    let name: String
    let iconURL: String
    let resourceURL: String
    let coins: UInt
    let count: UInt
    let senderID: String
    let senderName: String
    let senderAvatarURL: String

    var comboKey: String { "\(senderID)_\(giftID)" }
    var isAdvanced: Bool { !resourceURL.isEmpty }
}
