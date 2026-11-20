import AtomicXCore
import Combine
import SnapKit
import UIKit

final class VoiceLoungeLivingView: UIView {
    var onClose: (() -> Void)?

    let role: VoiceLoungeRole
    private let liveID: String
    private let seatStore: VoiceLoungeSeatStore

    private let backgroundView = VoiceLoungeBackgroundView()
    private let backgroundDimView = UIView()
    private let headerView: VoiceLoungeTopBar
    private let seatStage: VoiceLoungeSeatAreaView
    private let messageListView = BarrageStreamView()
    private let bottomBar: VoiceLoungeBottomBar

    private let requestingView: VoiceLoungeCoGuestBannerView
    private let invitationView: VoiceLoungeCoGuestBannerView
    private let leavingView: VoiceLoungeCoGuestBannerView
    private let noticeStore = VoiceLoungeNoticeStore()
    private let audienceWelcomeView = AudienceWelcomeView()
    private var audienceWelcomeBottomConstraint: Constraint?
    private var audienceEventCancellables = Set<AnyCancellable>()

    private let likeAnimationView = LikeAnimationView()
    private let likeButton: VoiceLoungeLikeButton
    private static let likeMargin: CGFloat = 14
    private var likeOffset: CGPoint = .zero
    private var likePanStartOffset: CGPoint = .zero
    private var hostLikeCancellables = Set<AnyCancellable>()
    private var lastHostLikeTotal: UInt?
    private let giftPanel = GiftSendPanelView()
    private weak var floatingGiftSendCombo: GiftSendComboButton?

    private let commentComposer = BarrageInputView()
    private var giftPlayView: GiftDisplayView?
    private let commentStore = BarrageUIStore()
    private let likeStore = LiveUIStore()
    private let giftBarrageStore = GiftBarrageStore()

    private let audioEffectPanel = VoiceLoungeAudioEffectPanel()
    private var captureVolume = 100
    private var audioEffectCancellables = Set<AnyCancellable>()
    private let musicView: VoiceLoungeMusicView
    private var musicLifecycleCancellables = Set<AnyCancellable>()
    private var isHostPaused = false
    private var isInBackground = false
    private var cancellables = Set<AnyCancellable>()

    let coreView: AtomicLiveView
    private let unitAdapter = HiddenSeatViewProvider()

    private var skin = VoiceLoungeSkin.defaultSkin

    init(
        liveID: String, seatStore: VoiceLoungeSeatStore, giftRankStore: VoiceLoungeGiftRankStore,
        clock: VoiceLoungeLiveClock, livingActions: VoiceLoungeLivingActions,
        transcriberStore: VoiceLoungeAITranscriberStore
    ) {
        let role = seatStore.role
        self.role = role
        self.liveID = liveID
        self.seatStore = seatStore
        self.headerView = VoiceLoungeTopBar(
            role: role, liveID: liveID, settings: seatStore.settings, giftRankStore: giftRankStore, clock: clock)
        self.bottomBar = VoiceLoungeBottomBar(liveID: liveID, seatStore: seatStore, livingActions: livingActions)
        self.seatStage = VoiceLoungeSeatAreaView(
            store: seatStore, transcriberStore: transcriberStore, livingActions: livingActions)
        self.requestingView = VoiceLoungeCoGuestBannerView(kind: .requesting, store: seatStore)
        self.invitationView = VoiceLoungeCoGuestBannerView(kind: .invitation, store: seatStore)
        self.leavingView = VoiceLoungeCoGuestBannerView(kind: .leaving, store: seatStore)
        self.musicView = VoiceLoungeMusicView(liveID: liveID)
        self.likeButton = VoiceLoungeLikeButton(isInteractive: role == .audience)
        self.coreView = AtomicLiveView(
            viewType: role == .host ? AtomicLiveViewType.pushView : AtomicLiveViewType.playView)
        super.init(frame: .zero)
        setupViews()
        setupConstraints()
        setupStyles()
        setupBindings()
        applySettings()
    }

    @available(*, unavailable) required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    func activateInteractions(hostUserID: String) {
        guard !liveID.isEmpty else { return }
        commentStore.activate(liveID: liveID, hostUserID: hostUserID)
        likeStore.activate(liveID: liveID)
        headerView.activate()
        activateLikes()
        installGiftPlayView(liveID: liveID)
        giftBarrageStore.onGiftBarrageSettled = { [weak self] gift in self?.commentStore.appendGiftBarrage(gift) }
        giftBarrageStore.hostUserID = hostUserID
        giftBarrageStore.activate(liveID: liveID)
        noticeStore.activate(liveID: liveID, role: role, topic: settings.topic)
        activateAudienceWelcome()
        activateAudioEffects()
        if role == .host { activateMusic() }
    }

    func updateHostUserID(_ hostUserID: String) {
        commentStore.activate(liveID: liveID, hostUserID: hostUserID)
        giftBarrageStore.hostUserID = hostUserID
    }

    func showOpeningTopic() { noticeStore.showOpeningTopic() }

    func deactivateInteractions() {
        giftBarrageStore.onGiftBarrageSettled = nil
        giftBarrageStore.deactivate()
        noticeStore.deactivate()
        audienceEventCancellables.removeAll()
        audienceWelcomeView.reset()
        commentStore.deactivate()
        likeStore.deactivate()
        headerView.deactivate()
        likeAnimationView.deactivate()
        likeAnimationView.removeAllAnimations()
        hostLikeCancellables.removeAll()
        lastHostLikeTotal = nil
        giftPlayView?.setActive(false)
        giftPlayView?.removeFromSuperview()
        giftPlayView = nil
        commentComposer.reset()
        giftPanel.dismiss()
        audioEffectCancellables.removeAll()
        audioEffectPanel.dismiss()
        VoiceLoungeVoiceTuner.shared.reset()
        deactivateMusic()
    }

    func setHostPaused(_ paused: Bool) {
        isHostPaused = paused
        updateMusicSuspension()
        giftBarrageStore.setCollectionEnabled(!paused)
    }

    private func setupViews() {
        coreView.setViewChangeAdapter(unitAdapter)
        addSubview(coreView)
        addSubview(backgroundView)
        addSubview(backgroundDimView)
        addSubview(headerView)
        addSubview(seatStage)
        addSubview(messageListView)
        addSubview(audienceWelcomeView)
        addSubview(bottomBar)
        addSubview(likeButton)
        addSubview(requestingView)
        addSubview(invitationView)
        addSubview(leavingView)
        addSubview(likeAnimationView)
        addSubview(giftPanel)
        addSubview(commentComposer)
        addSubview(audioEffectPanel)
        addSubview(musicView)
    }

    private func setupConstraints() {
        backgroundView.snp.makeConstraints { $0.edges.equalToSuperview() }
        backgroundDimView.snp.makeConstraints { $0.edges.equalToSuperview() }
        coreView.snp.makeConstraints { $0.edges.equalToSuperview() }
        likeAnimationView.snp.makeConstraints { $0.edges.equalToSuperview() }
        giftPanel.snp.makeConstraints { $0.edges.equalToSuperview() }
        commentComposer.snp.makeConstraints { $0.edges.equalToSuperview() }
        audioEffectPanel.snp.makeConstraints { $0.edges.equalToSuperview() }
        musicView.snp.makeConstraints { $0.edges.equalToSuperview() }

        headerView.snp.makeConstraints { make in
            make.leading.trailing.equalToSuperview()
            make.top.equalTo(safeAreaLayoutGuide.snp.top).offset(10)
            make.height.equalTo(82)
        }
        seatStage.snp.makeConstraints { make in
            make.leading.trailing.equalToSuperview().inset(16)
            make.top.equalTo(headerView.snp.bottom).offset(14)
        }
        bottomBar.snp.makeConstraints { make in
            make.leading.trailing.equalToSuperview()
            make.bottom.equalToSuperview()
            make.top.equalTo(safeAreaLayoutGuide.snp.bottom).offset(-62)
        }
        likeButton.snp.makeConstraints { make in
            make.trailing.equalTo(safeAreaLayoutGuide.snp.trailing).offset(-Self.likeMargin)
            make.bottom.equalTo(bottomBar.snp.top).offset(-Self.likeMargin)
            make.width.equalTo(VoiceLoungeLikeButton.size)
        }
        requestingView.snp.makeConstraints { make in
            make.leading.trailing.equalToSuperview().inset(14)
            make.bottom.equalTo(bottomBar.snp.top).offset(-10)
        }
        [invitationView, leavingView].forEach { banner in
            banner.snp.makeConstraints { make in
                make.leading.trailing.equalToSuperview().inset(14)
                make.bottom.equalTo(bottomBar.snp.top).offset(-10)
            }
        }
        messageListView.snp.makeConstraints { make in
            make.leading.equalToSuperview().inset(14)
            make.width.equalToSuperview().multipliedBy(0.78)
            make.bottom.equalTo(bottomBar.snp.top).offset(-8)
            make.top.equalTo(seatStage.barrageTopAnchor).offset(12)
        }
        audienceWelcomeView.snp.makeConstraints { make in
            make.leading.trailing.equalToSuperview()
            make.height.equalTo(28)
            audienceWelcomeBottomConstraint = make.bottom.equalTo(bottomBar.snp.top).offset(-18).constraint
        }
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        guard seatStage.frame.height > 0, bottomBar.frame.height > 0 else { return }
        let likeHomeTop = bottomBar.frame.minY - Self.likeMargin - VoiceLoungeLikeButton.size
        seatStage.updateColumnLimit(maxHeight: likeHomeTop - 12 - seatStage.frame.minY)
    }

    private func setupStyles() {
        backgroundColor = LiveTheme.Color.canvasBackground
        coreView.backgroundColor = .clear
        coreView.isUserInteractionEnabled = false
        backgroundView.clipsToBounds = true
        backgroundDimView.backgroundColor = UIColor(red: 0.051, green: 0.055, blue: 0.078, alpha: 0.45)
        backgroundDimView.isUserInteractionEnabled = false
        likeButton.isHidden = role == .host
    }

    private func setupBindings() {
        giftPanel.onSendGift = { [weak self] gift, count in self?.sendGift(gift, count: count) }
        giftPanel.onAdvancedComboStart = { [weak self] gift in self?.beginFloatingGiftSendCombo(with: gift) }
        commentComposer.onSend = { [weak self] text in self?.commentStore.sendComment(text) }
        audioEffectPanel.onSetCaptureVolume = { [weak self] volume in self?.applyCaptureVolume(volume) }

        headerView.onClose = { [weak self] in self?.onClose?() }
        bottomBar.onComment = { [weak self] in self?.presentCommentComposer() }
        likeButton.onLike = { [weak self] in self?.sendLike() }
        if role == .audience {
            likeButton.addGestureRecognizer(UIPanGestureRecognizer(target: self, action: #selector(handleLikePan(_:))))
        }
        bottomBar.onGift = { [weak self] in self?.presentGiftPanel() }
        seatStage.onSendGift = { [weak self] userID, name in
            self?.presentGiftPanel(receiver: (userID: userID, name: name))
        }
        bottomBar.onAudioEffects = { [weak self] in self?.presentAudioEffects() }
        bottomBar.onBackgroundMusic = { [weak self] in self?.presentBackgroundMusic() }
        messageListView.onVisibleContentHeightChanged = { [weak self] height in
            self?.audienceWelcomeBottomConstraint?.update(offset: -(height + 18))
        }

        commentStore.onStateChanged = { [weak self] state in
            guard let self, state.liveID == self.liveID else { return }
            self.renderBarrage(state.comments.filter { $0.gift != nil || !$0.text.isEmpty })
        }
        commentStore.onSendError = { message in LiveToast.show(message) }

        seatStore.settings.changes.sink { [weak self] in self?.applySettings() }.store(in: &cancellables)
    }

    private var settings: VoiceLoungeSettings { seatStore.settings }

    private func applySettings() {
        skin = settings.skin
        musicView.applySkin(skin)
        audioEffectPanel.applySkin(skin)
        backgroundView.show(settings.background)
        noticeStore.updateTopic(settings.topic)
    }

    private func activateAudienceWelcome() {
        audienceEventCancellables.removeAll()
        LiveAudienceStore.create(liveID: liveID).liveAudienceEventPublisher.receive(on: DispatchQueue.main).sink {
            [weak self] event in
            guard let self, case .onAudienceJoined(let user) = event, !user.userID.isEmpty, !self.isHostPaused else {
                return
            }
            self.audienceWelcomeView.enqueue(
                AudienceWelcome(
                    userID: user.userID, userName: user.userName.isEmpty ? user.userID : user.userName,
                    level: max(0, user.level)))
        }.store(in: &audienceEventCancellables)
    }

    private func activateMusic() {
        musicLifecycleCancellables.removeAll()
        isInBackground = UIApplication.shared.applicationState == .background
        musicView.activate()
        updateMusicSuspension()
        NotificationCenter.default.publisher(for: UIApplication.didEnterBackgroundNotification).sink { [weak self] _ in
            self?.isInBackground = true
            self?.updateMusicSuspension()
        }.store(in: &musicLifecycleCancellables)
        NotificationCenter.default.publisher(for: UIApplication.didBecomeActiveNotification).sink { [weak self] _ in
            self?.isInBackground = false
            self?.updateMusicSuspension()
        }.store(in: &musicLifecycleCancellables)
    }

    private func deactivateMusic() {
        musicLifecycleCancellables.removeAll()
        musicView.deactivate()
        musicView.dismiss()
        isHostPaused = false
    }

    private func updateMusicSuspension() { musicView.setSuspended(isHostPaused || isInBackground) }

    private func presentBackgroundMusic() { musicView.show() }

    private func renderBarrage(_ comments: [BarrageUIStore.Comment]) {
        messageListView.bind(
            comments.map {
                BarrageStreamView.Message(
                    id: $0.id, userName: $0.senderName, content: $0.text, level: $0.level, isHost: $0.isHost,
                    gift: $0.gift)
            })
    }

    private func presentCommentComposer() {
        giftPanel.dismiss()
        commentComposer.show()
    }

    private func presentGiftPanel(receiver: (userID: String, name: String)? = nil) {
        guard !liveID.isEmpty else { return }
        commentComposer.dismiss()
        giftPanel.setReceiver(userID: receiver?.userID, name: receiver?.name)
        giftPanel.present(liveID: liveID)
    }

    private func sendLike() {
        likeAnimationView.showButtonLike(from: likeButton.heartCenter(in: likeAnimationView))
        likeStore.sendLike()
    }

    @objc private func handleLikePan(_ gesture: UIPanGestureRecognizer) {
        switch gesture.state {
        case .began: likePanStartOffset = likeOffset
        case .changed:
            let translation = gesture.translation(in: self)
            likeOffset = clampedLikeOffset(
                CGPoint(x: likePanStartOffset.x + translation.x, y: likePanStartOffset.y + translation.y))
            likeButton.transform = CGAffineTransform(translationX: likeOffset.x, y: likeOffset.y)
        case .ended, .cancelled, .failed:
            let range = likeOffsetRange()
            let snapToLeft = likeOffset.x < (range.minX + range.maxX) / 2
            likeOffset = CGPoint(x: snapToLeft ? range.minX : range.maxX, y: likeOffset.y)
            UIView.animate(
                withDuration: 0.28, delay: 0, usingSpringWithDamping: 0.82, initialSpringVelocity: 0,
                options: [.allowUserInteraction, .beginFromCurrentState]
            ) { self.likeButton.transform = CGAffineTransform(translationX: self.likeOffset.x, y: self.likeOffset.y) }
        default: break
        }
    }

    private func likeOffsetRange() -> CGRect {
        let home = likeButton.frame.applying(likeButton.transform.inverted())
        let safe = bounds.inset(by: safeAreaInsets)
        let minX = safe.minX + Self.likeMargin - home.minX
        let minY = headerView.frame.maxY + Self.likeMargin - home.minY
        return CGRect(x: minX, y: min(minY, 0), width: max(0, -minX), height: max(0, -minY))
    }

    private func clampedLikeOffset(_ offset: CGPoint) -> CGPoint {
        let range = likeOffsetRange()
        return CGPoint(x: min(range.maxX, max(range.minX, offset.x)), y: min(range.maxY, max(range.minY, offset.y)))
    }

    private func activateLikes() {
        hostLikeCancellables.removeAll()
        lastHostLikeTotal = nil
        guard role == .host else {
            likeAnimationView.activate(liveID: liveID) { [weak self] in
                guard let self else { return .zero }
                return self.likeButton.heartCenter(in: self.likeAnimationView)
            }
            return
        }
        LikeStore.create(liveID: liveID).state.subscribe().map { $0.totalLikeCount }.removeDuplicates().receive(
            on: DispatchQueue.main
        ).sink { [weak self] total in
            guard let self else { return }
            defer { self.lastHostLikeTotal = total }
            guard let last = self.lastHostLikeTotal, total > last, !self.isHostPaused else { return }
            self.showReceivedLikes(Int(min(total - last, 8)))
        }.store(in: &hostLikeCancellables)
    }

    private func showReceivedLikes(_ count: Int) {
        likeButton.pulse()
        for index in 0..<max(1, count) {
            DispatchQueue.main.asyncAfter(deadline: .now() + Double(index) * 0.14) { [weak self] in
                guard let self, self.window != nil else { return }
                self.likeAnimationView.showButtonLike(from: self.likeButton.heartCenter(in: self.likeAnimationView))
            }
        }
    }

    private func presentAudioEffects() { audioEffectPanel.show(captureVolume: captureVolume) }

    private func applyCaptureVolume(_ volume: Int) {
        captureVolume = volume
        DeviceStore.shared.setCaptureVolume(volume: volume)
    }

    private func activateAudioEffects() {
        audioEffectCancellables.removeAll()
        guard role == .audience else { return }
        DeviceStore.shared.state.subscribe().map { $0.microphoneStatus == .on }.removeDuplicates().receive(
            on: DispatchQueue.main
        ).sink { [weak self] isOn in
            guard isOn, let self, self.seatStore.coGuest.guestStatus == .onSeat else { return }
            self.reapplySavedAudioEffects()
        }.store(in: &audioEffectCancellables)
    }

    private func reapplySavedAudioEffects() {
        let effects = AudioEffectStore.shared
        let state = effects.state.value
        effects.setAudioChangerType(type: state.audioChangerType)
        effects.setAudioReverbType(type: state.audioReverbType)
        effects.setVoiceEarMonitorVolume(volume: state.earMonitorVolume)
        effects.setVoiceEarMonitorEnable(enable: state.isEarMonitorOpened)
        VoiceLoungeVoiceTuner.shared.reapply()
        DeviceStore.shared.setCaptureVolume(volume: captureVolume)
    }

    private func sendGift(_ gift: GiftSendPanelView.GiftItem, count: Int) {
        let normalizedCount = UInt(max(1, count))
        let profile = LoginStore.shared.state.value.loginUserInfo
        let localGift = profile.map {
            GiftDisplayItem(
                giftID: gift.id, name: gift.name, iconURL: gift.iconURL?.absoluteString ?? "",
                resourceURL: gift.resourceURL?.absoluteString ?? "", coins: UInt(max(0, gift.coins)),
                count: normalizedCount, senderID: $0.userID, senderName: $0.nickname ?? "",
                senderAvatarURL: $0.avatarURL ?? "")
        }
        let playView = giftPlayView
        let reservationID = localGift.flatMap { playView?.reserveLocalGift($0) }
        let giftID = gift.id
        GiftStore.create(liveID: liveID).sendGift(
            giftID: giftID, count: normalizedCount, receiver: giftPanel.receiverID ?? ""
        ) { [weak playView] result in
            Task { @MainActor in
                if case .failure(let error) = result {
                    LiveKitLog.error("[VoiceLounge] send gift failed gift=\(giftID) error=\(error)")
                }
                guard let reservationID else { return }
                if case .success = result {
                    playView?.confirmLocalGift(id: reservationID)
                } else {
                    playView?.cancelLocalGift(id: reservationID)
                }
            }
        }
    }

    private func installGiftPlayView(liveID: String) {
        giftPlayView?.removeFromSuperview()
        let playView = GiftDisplayView(liveID: liveID)
        insertSubview(playView, belowSubview: giftPanel)
        playView.snp.makeConstraints { $0.edges.equalToSuperview() }
        playView.setActive(true)
        giftPlayView = playView
    }

    private func beginFloatingGiftSendCombo(with gift: GiftSendPanelView.GiftItem) {
        floatingGiftSendCombo?.end()
        floatingGiftSendCombo?.removeFromSuperview()

        let combo = GiftSendComboButton()
        combo.onSendOnce = { [weak self] in self?.sendGift(gift, count: 1) }
        combo.onExpired = { [weak combo] in combo?.removeFromSuperview() }
        addSubview(combo)
        combo.snp.makeConstraints { make in
            make.trailing.equalTo(safeAreaLayoutGuide.snp.trailing).offset(-16)
            make.bottom.equalTo(bottomBar.snp.top).offset(-(Self.likeMargin + VoiceLoungeLikeButton.size + 10))
            make.width.equalTo(72)
            make.height.equalTo(96)
        }
        floatingGiftSendCombo = combo
        combo.begin(with: gift)
    }
}

private final class HiddenSeatViewProvider: AtomicLiveViewChangeAdapter {
    func onCreateUnitView(unitInfo: UnitInfo?) -> UIView? { return UIView() }

    func onUpdateUnitView(unitInfo: UnitInfo?, view: UIView?) {}

    func onVideoViewFrameChanged(left: CGFloat, top: CGFloat, right: CGFloat, bottom: CGFloat) {}
}

@MainActor final class VoiceLoungeLiveClock {
    private(set) var startDate: Date?

    private var startUptime: TimeInterval?
    private var pausedDuration: TimeInterval = 0
    private var pauseStartUptime: TimeInterval?

    var isRunning: Bool { startUptime != nil }

    var elapsedSeconds: Int {
        guard let startUptime else { return 0 }
        let now = Self.now
        let currentPause = pauseStartUptime.map { now - $0 } ?? 0
        return max(0, Int(now - startUptime - pausedDuration - currentPause))
    }

    var currentPauseSeconds: Int {
        guard let pauseStartUptime else { return 0 }
        return max(0, Int(Self.now - pauseStartUptime))
    }

    func start() {
        startDate = Date()
        startUptime = Self.now
        pausedDuration = 0
        pauseStartUptime = nil
    }

    func pause() {
        guard isRunning, pauseStartUptime == nil else { return }
        pauseStartUptime = Self.now
    }

    func resume() {
        guard let pauseStartUptime else { return }
        pausedDuration += Self.now - pauseStartUptime
        self.pauseStartUptime = nil
    }

    func stop() {
        startDate = nil
        startUptime = nil
        pausedDuration = 0
        pauseStartUptime = nil
    }

    private static var now: TimeInterval { ProcessInfo.processInfo.systemUptime }
}

@MainActor final class VoiceLoungeLivingActions {
    var isMuted: () -> Bool = { false }
    var pauseLive: () -> Void = {}
    var toggleMute: () -> Void = {}
    var changeLayout: (VoiceLoungeSeatLayout) -> Void = { _ in }
    var changeTopic: (String) -> Void = { _ in }
    var updateTranscriber: (VoiceLoungeAITranscriberPanel.State) -> Void = { _ in }
    var showTranscriberPanel: () -> Void = {}
    var confirm: (_ title: String, _ message: String, _ confirmTitle: String, _ action: @escaping () -> Void) -> Void =
        { _, _, _, _ in }
}

enum VoiceLoungeRole: Equatable {
    case host
    case audience
}
