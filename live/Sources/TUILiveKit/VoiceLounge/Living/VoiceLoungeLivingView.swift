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
    private let noticeStore = VoiceLoungeNoticeStore()
    private let audienceWelcomeView = AudienceWelcomeView()
    private var audienceWelcomeBottomConstraint: Constraint?
    private var audienceEventCancellables = Set<AnyCancellable>()

    private let likeAnimationView = LikeAnimationView()
    private let giftPanel = GiftSendPanelView()
    private weak var floatingGiftSendCombo: GiftSendComboButton?

    private let commentComposer = BarrageInputView()
    private var giftPlayView: GiftDisplayView?
    private let commentStore = BarrageUIStore()
    private let likeStore = LiveUIStore()
    private let giftBarrageStore = GiftBarrageStore()

    private let audioEffectPanel = VoiceLoungeAudioEffectPanel()
    private var captureVolume = 100
    private let musicView: PusherMusicView
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
        self.musicView = PusherMusicView(liveID: liveID)
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
        likeAnimationView.activate(liveID: liveID) { [weak self] in
            guard let self else { return .zero }
            return self.role == .audience
                ? self.bottomBar.likeButtonCenter(in: self.likeAnimationView)
                : CGPoint(x: self.bounds.width - 40, y: self.bounds.height - 120)
        }
        installGiftPlayView(liveID: liveID)
        giftBarrageStore.onGiftBarrageSettled = { [weak self] gift in self?.commentStore.appendGiftBarrage(gift) }
        giftBarrageStore.hostUserID = hostUserID
        giftBarrageStore.activate(liveID: liveID)
        noticeStore.activate(liveID: liveID, role: role, topic: settings.topic)
        activateAudienceWelcome()
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
        giftPlayView?.setActive(false)
        giftPlayView?.removeFromSuperview()
        giftPlayView = nil
        commentComposer.reset()
        giftPanel.dismiss()
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
        addSubview(requestingView)
        addSubview(invitationView)
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
        requestingView.snp.makeConstraints { make in
            make.leading.trailing.equalToSuperview().inset(14)
            make.bottom.equalTo(bottomBar.snp.top).offset(-10)
        }
        invitationView.snp.makeConstraints { make in
            make.leading.trailing.equalToSuperview().inset(14)
            make.bottom.equalTo(bottomBar.snp.top).offset(-10)
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

    private func setupStyles() {
        backgroundColor = LiveTheme.Color.canvasBackground
        coreView.backgroundColor = .clear
        coreView.isUserInteractionEnabled = false
        backgroundView.clipsToBounds = true
        backgroundDimView.backgroundColor = UIColor(red: 0.051, green: 0.055, blue: 0.078, alpha: 0.45)
        backgroundDimView.isUserInteractionEnabled = false
    }

    private func setupBindings() {
        giftPanel.onSendGift = { [weak self] gift, count in self?.sendGift(gift, count: count) }
        giftPanel.onAdvancedComboStart = { [weak self] gift in self?.beginFloatingGiftSendCombo(with: gift) }
        commentComposer.onSend = { [weak self] text in self?.commentStore.sendComment(text) }
        audioEffectPanel.onSetCaptureVolume = { [weak self] volume in self?.captureVolume = volume }

        headerView.onClose = { [weak self] in self?.onClose?() }
        bottomBar.onComment = { [weak self] in self?.presentCommentComposer() }
        bottomBar.onLike = { [weak self] in self?.sendLike() }
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
        likeAnimationView.showButtonLike(from: bottomBar.likeButtonCenter(in: likeAnimationView))
        likeStore.sendLike()
    }

    private func presentAudioEffects() { audioEffectPanel.show(captureVolume: captureVolume) }

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
            make.bottom.equalTo(bottomBar.snp.top).offset(-30)
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
}

enum VoiceLoungeRole: Equatable {
    case host
    case audience
}
