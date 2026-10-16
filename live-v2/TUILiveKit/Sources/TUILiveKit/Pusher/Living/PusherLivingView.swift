import UIKit
import AtomicXCore
import Combine
import SnapKit

final class PusherLivingView: UIView {
    // MARK: - Outputs

    var onShowBeauty: (() -> Void)?
    var onEnd: (() -> Void)?
    var onToggleMute: (() -> Void)?
    var onPause: (() -> Void)?
    var onResume: (() -> Void)?
    var onFlipCamera: (() -> Void)?
    weak var settingsActionHandler: PusherSettingsActionHandling? {
        didSet { settingsView.settingsActionHandler = settingsActionHandler }
    }
    weak var coGuestActionHandler: PusherCoGuestActionHandling? {
        didSet {
            coGuestSettingsView.actionHandler = coGuestActionHandler
            coGuestAudienceManageView.actionHandler = coGuestActionHandler
        }
    }
    var onCoGuestStageTap: ((CGPoint) -> Bool)?
    var coGuestSmallWindowRegions: (() -> [CGRect])?

    // MARK: - Feature Dependencies

    private let liveID: String
    private let audienceStore: PusherAudienceStore
    private let likeStore: LikeStore
    private let commentStore = BarrageUIStore()
    private var commentToast: LiveToast?
    private let giftStore: PusherGiftStore
    private let musicView: PusherMusicView

    // MARK: - Child Views

    private let topScrim = LivingScrimView(direction: .top)
    private let bottomScrim = LivingScrimView(direction: .bottom)
    private let likeAnimationView = LikeAnimationView()
    private let giftPlayView: GiftPlayView
    private let headerView = LiveHeaderView()
    private let messageListView = BarrageStreamView()
    private let audienceWelcomeView = AudienceWelcomeView()
    private let bottomToolbar = LiveBottomToolbarView()
    private let settingsView = PusherLivingSettingsView()
    private let commentComposer = BarrageInputView()
    private let pauseOverlay = PusherPauseOverlayView()
    private let audienceListView = PusherAudienceListView()
    private let audienceManageView = PusherAudienceManageView()
    private let endConfirmationView = PusherEndConfirmationView()
    private let coGuestSettingsView = PusherCoGuestSettingsView()
    private let coGuestAudienceManageView = PusherCoGuestAudienceManageView()
    private let liveStatusView: PusherLiveStatusView

    // MARK: - Presentation State

    private var viewerCount = 0
    private var isPaused = false
    private var isMusicInBackground = false
    private var musicLifecycleCancellables = Set<AnyCancellable>()
    private var lastStageTapTime: TimeInterval = 0
    private var audienceWelcomeBottomConstraint: Constraint?
    private var messageListWidth: CGFloat = 0
    private var messageListWidthConstraint: Constraint?
    private var messageListNormalBottomConstraint: Constraint?
    private var messageListNormalHeightConstraint: Constraint?
    private var messageListComposerBottomConstraint: Constraint?
    private var messageListComposerHeightConstraint: Constraint?
    private var coGuestState = PusherCoGuestStore.State()
    private var audienceState = PusherAudienceStore.State()
    private var renderedAudienceState: PusherAudienceStore.State?
    private var likeCancellables = Set<AnyCancellable>()
    private var likeSessionID: UUID?
    private var likeFlushTimer: Timer?
    private var likeCount = 0
    private var pendingLikeCount: UInt = 0
    private var lastLikeSendTime: TimeInterval = 0
    private var isLikeActive = false
    private var isCommentActive = false

    init(liveID: String) {
        self.liveID = liveID
        giftPlayView = GiftPlayView(liveID: liveID)
        audienceStore = PusherAudienceStore(liveID: liveID)
        likeStore = LikeStore.create(liveID: liveID)
        giftStore = PusherGiftStore(liveID: liveID)
        musicView = PusherMusicView(liveID: liveID)
        liveStatusView = PusherLiveStatusView(liveID: liveID)
        super.init(frame: .zero)
        giftPlayView.setActive(false)
        configureUI()
        bindAudienceStore()
        renderLikes()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        updateCommentWidth()
    }

    deinit {
        likeFlushTimer?.invalidate()
    }
}

// MARK: - Stage Rendering

extension PusherLivingView {
    func updateHost(name: String, avatarURL: String) {
        headerView.bindHost(name: name, avatarURL: avatarURL)
    }

    func updateSettings(_ settings: PusherSettingsState) {
        settingsView.bind(settings)
    }

    func updateDeviceStatus(
        _ status: PusherDeviceStatusState,
        videoQuality: PusherVideoQualitySetting,
        isMuted: Bool,
        captureVolume: Int
    ) {
        headerView.bindNetworkQuality(status.networkQuality)
        liveStatusView.updateDeviceStatus(
            status,
            videoQuality: videoQuality,
            isMuted: isMuted,
            captureVolume: captureVolume
        )
    }

    func updateElapsedSeconds(_ seconds: Int) {
        headerView.bindElapsedSeconds(seconds)
        liveStatusView.updateElapsedSeconds(seconds)
    }

    func updatePause(isPaused: Bool, seconds: Int) {
        self.isPaused = isPaused
        giftPlayView.setSuspended(isPaused)
        updateMusicSuspension()
        pauseOverlay.bind(isPaused: isPaused, seconds: seconds)
    }

}

// MARK: - Audience Lifecycle

extension PusherLivingView {
    func activateAudience() {
        audienceStore.activate()
    }

    func refreshAudience() {
        audienceStore.refresh()
    }

    func deactivateAudience(resetState: Bool) {
        audienceStore.deactivate(resetState: resetState)
        resetAudienceWelcomes()
    }
}

// MARK: - Like Lifecycle

extension PusherLivingView {
    func activateLikes() {
        guard !isLikeActive else { return }
        isLikeActive = true
        let sessionID = UUID()
        likeSessionID = sessionID
        updateLikeCount(likeStore.state.value.totalLikeCount)
        likeStore.state.subscribe()
            .receive(on: DispatchQueue.main)
            .sink { [weak self] state in
                guard let self, self.isLikeActive, self.likeSessionID == sessionID else { return }
                self.updateLikeCount(state.totalLikeCount)
            }
            .store(in: &likeCancellables)
        likeAnimationView.activate(liveID: liveID) { [weak self] in
            guard let self else { return .zero }
            return self.bottomToolbar.likeAnimationOrigin(in: self.likeAnimationView)
        }
    }

    func deactivateLikes(resetState: Bool) {
        likeSessionID = nil
        if isLikeActive {
            isLikeActive = false
            flushPendingLikes()
        }
        likeCancellables.removeAll()
        likeAnimationView.deactivate()
        if resetState {
            likeCount = 0
            renderLikes()
        }
    }
}

// MARK: - Comment Lifecycle

extension PusherLivingView {
    func activateComments() {
        guard !isCommentActive else { return }
        isCommentActive = true
        giftPlayView.setActive(true)
        commentStore.onStateChanged = { [weak self] state in
            guard let self, self.isCommentActive else { return }
            self.renderComments(state.comments)
        }
        commentStore.onSendError = { [weak self] message in
            guard let self, self.isCommentActive, self.window != nil, !self.isHidden else { return }
            self.commentToast = LiveToast.show(message)
        }
        commentStore.activate(
            liveID: liveID,
            hostUserID: LoginStore.shared.state.value.loginUserInfo?.userID ?? ""
        )
        giftStore.onGiftCommentSettled = { [weak self] gift in
            guard let self, self.isCommentActive else { return }
            self.commentStore.appendGiftComment(gift)
        }
        giftStore.activate()
    }

    func pauseComments() {
        guard isCommentActive else { return }
        giftStore.setGiftCommentCollectionEnabled(false)
    }

    func resumeComments() {
        guard isCommentActive else { return }
        giftStore.setGiftCommentCollectionEnabled(true)
    }

    func deactivateComments(resetState: Bool) {
        isCommentActive = false
        giftPlayView.setActive(false)
        commentComposer.reset()
        commentStore.deactivate()
        commentToast?.dismiss()
        commentToast = nil
        giftStore.onGiftCommentSettled = nil
        giftStore.deactivate(resetStatistics: resetState)
        guard resetState else { return }
        renderComments([])
    }
}

// MARK: - Music Lifecycle

extension PusherLivingView {
    func activateMusic() {
        musicLifecycleCancellables.removeAll()
        isMusicInBackground = UIApplication.shared.applicationState == .background
        musicView.activate()
        updateMusicSuspension()
        NotificationCenter.default.publisher(for: UIApplication.didEnterBackgroundNotification)
            .sink { [weak self] _ in
                self?.isMusicInBackground = true
                self?.updateMusicSuspension()
            }
            .store(in: &musicLifecycleCancellables)
        NotificationCenter.default.publisher(for: UIApplication.didBecomeActiveNotification)
            .sink { [weak self] _ in
                self?.isMusicInBackground = false
                self?.updateMusicSuspension()
            }
            .store(in: &musicLifecycleCancellables)
    }

    func deactivateMusic() {
        musicLifecycleCancellables.removeAll()
        musicView.deactivate()
    }

    private func updateMusicSuspension() {
        musicView.setSuspended(isPaused || isMusicInBackground)
    }
}

// MARK: - Root Coordination

extension PusherLivingView {
    func resetAfterStartFailure() {
        // Discard unsent likes before the normal deactivation can flush them.
        pendingLikeCount = 0
        lastLikeSendTime = 0
        lastStageTapTime = 0
        deactivateAudience(resetState: true)
        deactivateLikes(resetState: true)
        deactivateComments(resetState: true)
        deactivateMusic()
        updatePause(isPaused: false, seconds: 0)
        updateElapsedSeconds(0)
        settingsView.cancelPendingAction()
        audienceListView.cancelPendingSelection()
        let sheets: [BottomSheetView] = [
            settingsView, musicView, audienceListView, audienceManageView,
            endConfirmationView, coGuestSettingsView, liveStatusView,
            coGuestAudienceManageView,
        ]
        sheets.forEach { $0.dismiss() }
    }

    func resetAudienceWelcomes() {
        audienceWelcomeView.reset()
    }

    func updateCoGuest(_ state: PusherCoGuestStore.State) {
        let needsLayoutUpdate = coGuestState.layout != state.layout ||
            coGuestState.connected.count != state.connected.count
        coGuestState = state
        // Restore from the confirmed layout immediately, including while a sheet is open.
        // SDK geometry callbacks may arrive later and must not keep the old narrow width.
        if needsLayoutUpdate {
            updateCommentWidth()
        }
        coGuestSettingsView.bind(state)
        coGuestAudienceManageView.bind(state)
        bottomToolbar.setCoGuestUnread(state.hasUnreadApplicant)
        // Requests arriving while the drawer is already open are visible to the
        // host, so they must not leave the dot lit after the drawer closes.
        if state.hasUnreadApplicant, !coGuestSettingsView.isHidden {
            coGuestActionHandler?.markApplicantsSeen()
        }
    }

    func setCoGuestStageActive(_ isActive: Bool) {
        bottomToolbar.setCoGuestStageActive(isActive)
    }

    func showCoGuestActions(userID: String) {
        guard let user = coGuestState.connected.first(where: { $0.userID == userID }) else { return }
        coGuestAudienceManageView.show(
            user: user,
            isPending: coGuestState.pendingUserIDs.contains(userID)
        )
    }
}

// MARK: - UI Assembly

private extension PusherLivingView {
    private func configureUI() {
        backgroundColor = .clear

        [topScrim, bottomScrim, headerView, messageListView, audienceWelcomeView, bottomToolbar, likeAnimationView, giftPlayView, settingsView, commentComposer, musicView, pauseOverlay, audienceListView, audienceManageView, endConfirmationView, coGuestSettingsView, liveStatusView, coGuestAudienceManageView].forEach {
            addSubview($0)
        }

        let stageTap = UITapGestureRecognizer(target: self, action: #selector(handleStageTap(_:)))
        stageTap.cancelsTouchesInView = false
        stageTap.delegate = self
        addGestureRecognizer(stageTap)

        bindActions()
        configureLayout()
    }

    private func bindActions() {
        headerView.onClose = { [weak self] in
            guard let self else { return }
            self.endConfirmationView.show(viewerCount: self.viewerCount)
        }
        headerView.onAudience = { [weak self] in
            self?.audienceListView.show()
        }
        headerView.onStatus = { [weak self] in
            self?.liveStatusView.show()
        }
        liveStatusView.onSetCaptureVolume = { [weak self] in self?.settingsActionHandler?.setCaptureVolume($0) }
        audienceListView.onRefresh = { [weak self] in self?.audienceStore.refresh() }
        audienceListView.onSelectAudience = { [weak self] user in
            guard let self else { return }
            self.audienceManageView.show(user: user, state: self.audienceState)
            self.audienceStore.refreshFollowStatus(userID: user.userID)
        }
        audienceManageView.onToggleFollow = { [weak self] in self?.audienceStore.toggleFollow(userID: $0) }
        audienceManageView.onToggleMessagePermission = { [weak self] in
            self?.audienceStore.toggleMessagePermission(userID: $0)
        }
        audienceManageView.onRemoveFromRoom = { [weak self] in self?.audienceStore.removeFromRoom(userID: $0) }
        endConfirmationView.onConfirmEnd = { [weak self] in self?.onEnd?() }
        bottomToolbar.onMore = { [weak self] in
            self?.settingsView.show()
        }
        bottomToolbar.onCoGuest = { [weak self] in
            self?.coGuestSettingsView.show()
            self?.coGuestActionHandler?.markApplicantsSeen()
        }
        settingsView.onToggleMute = { [weak self] in self?.onToggleMute?() }
        settingsView.onPause = { [weak self] in self?.onPause?() }
        settingsView.onFlipCamera = { [weak self] in self?.onFlipCamera?() }
        settingsView.onShowBeauty = { [weak self] in self?.onShowBeauty?() }
        settingsView.onShowComment = { [weak self] in self?.commentComposer.show() }
        settingsView.onShowBackgroundMusic = { [weak self] in self?.musicView.show() }
        commentComposer.onSend = { [weak self] in self?.sendComment($0) }
        commentComposer.onPresentationChanged = { [weak self] isPresented in
            self?.setCommentComposerPresented(isPresented)
        }
        pauseOverlay.onResume = { [weak self] in self?.onResume?() }
        messageListView.onVisibleContentHeightChanged = { [weak self] height in
            guard let self else { return }
            self.audienceWelcomeBottomConstraint?.update(offset: -(height + 18))
            self.giftPlayView.updateMessageContentHeight(height)
            UIView.animate(
                withDuration: 0.18,
                delay: 0,
                options: [.curveEaseOut, .beginFromCurrentState, .allowUserInteraction]
            ) {
                self.layoutIfNeeded()
            }
        }
        audienceWelcomeView.onVisibilityChanged = { [weak self] isVisible in
            guard let self else { return }
            self.giftPlayView.updateAudienceWelcomeVisible(isVisible)
            UIView.animate(
                withDuration: 0.12,
                delay: 0,
                options: [.curveEaseOut, .beginFromCurrentState, .allowUserInteraction]
            ) {
                self.layoutIfNeeded()
            }
        }
    }

    private func configureLayout() {
        topScrim.snp.makeConstraints { make in
            make.leading.trailing.top.equalToSuperview()
            make.height.equalTo(170)
        }
        bottomScrim.snp.makeConstraints { make in
            make.leading.trailing.bottom.equalToSuperview()
            make.height.equalTo(186)
        }
        likeAnimationView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }
        giftPlayView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }
        headerView.snp.makeConstraints { make in
            make.leading.trailing.equalToSuperview().inset(12)
            make.top.equalTo(safeAreaLayoutGuide.snp.top).offset(-1)
            make.height.equalTo(62)
        }
        bottomToolbar.snp.makeConstraints { make in
            make.leading.trailing.bottom.equalToSuperview()
            make.top.equalTo(safeAreaLayoutGuide.snp.bottom).offset(-68)
        }
        messageListView.snp.makeConstraints { make in
            make.leading.equalToSuperview().offset(12)
            messageListWidthConstraint = make.width.equalTo(0).constraint
            messageListNormalBottomConstraint = make.bottom.equalTo(bottomToolbar.snp.top).offset(-14).constraint
            messageListNormalHeightConstraint = make.height.equalTo(184).constraint
            messageListComposerBottomConstraint = make.bottom.equalTo(commentComposer.inputBarLayoutView.snp.top).offset(-6).constraint
            messageListComposerHeightConstraint = make.height.equalTo(132).constraint
        }
        messageListComposerBottomConstraint?.deactivate()
        messageListComposerHeightConstraint?.deactivate()
        audienceWelcomeView.snp.makeConstraints { make in
            make.leading.trailing.equalToSuperview()
            make.height.equalTo(28)
            audienceWelcomeBottomConstraint = make.bottom.equalTo(bottomToolbar.snp.top).offset(-18).constraint
        }
        [settingsView, commentComposer, musicView, pauseOverlay, audienceListView, audienceManageView, endConfirmationView, coGuestSettingsView, liveStatusView, coGuestAudienceManageView].forEach {
            $0.snp.makeConstraints { make in
                make.edges.equalToSuperview()
            }
        }
    }
}

// MARK: - Audience Binding And Rendering

private extension PusherLivingView {
    private func showAudienceWelcome(_ welcome: AudienceWelcome) {
        guard !isPaused, !isHidden else { return }
        audienceWelcomeView.enqueue(welcome)
    }

    private func bindAudienceStore() {
        audienceStore.onStateChanged = { [weak self] state in
            self?.audienceState = state
            self?.renderAudience()
        }
        audienceStore.onAudienceEntered = { [weak self] welcome in
            self?.showAudienceWelcome(welcome)
        }
        audienceStore.onActionCompleted = { [weak self] userID, action, succeeded in
            guard let self else { return }
            self.audienceManageView.completeAction(
                userID: userID,
                action: action,
                succeeded: succeeded
            )
            guard succeeded else { return }
            let toastKey: String
            switch action {
            case .mute: toastKey = "tuilivekit.pusher.audience.muted_toast"
            case .unmute: toastKey = "tuilivekit.pusher.audience.unmuted_toast"
            case .remove: toastKey = "tuilivekit.pusher.audience.removed_toast"
            case .follow, .unfollow: return
            }
            let name = self.audienceState.users
                .first(where: { $0.userID == userID })
                .map { $0.userName.isEmpty ? $0.userID : $0.userName } ?? userID
            LiveToast.show(LiveKitResources.localizedFormat(toastKey, name))
        }
    }

    private func renderAudience() {
        let state = audienceState
        guard renderedAudienceState != state else { return }
        renderedAudienceState = state
        viewerCount = state.count
        audienceListView.bind(state.users)
        audienceManageView.bind(state)
        headerView.bindAudience(state.users, count: state.count)
        liveStatusView.updateOnlineCount(state.count)
    }

}

// MARK: - Comment Rendering

private extension PusherLivingView {
    private func sendComment(_ text: String) {
        guard isCommentActive else { return }
        commentStore.sendComment(text)
    }

    private func renderComments(_ comments: [BarrageUIStore.Comment]) {
        messageListView.bind(comments.map {
            BarrageStreamView.Message(
                id: $0.id,
                userName: $0.senderName,
                content: $0.text,
                level: $0.level,
                isHost: $0.isHost,
                gift: $0.gift
            )
        })
    }
}

// MARK: - Like Interaction

private extension PusherLivingView {
    private func showReceivedLikes(count: Int) {
        guard !isPaused, !isHidden else { return }
        likeAnimationView.showReceivedLikes(
            count: count,
            auxiliaryOrigin: bottomToolbar.likeAnimationOrigin(in: likeAnimationView)
        )
    }

    private func updateLikeCount(_ count: UInt) {
        let value = Int(min(count, UInt(Int.max)))
        guard likeCount != value else { return }
        likeCount = value
        renderLikes()
    }

    private func renderLikes() {
        let count = likeCount
        headerView.bindLikeCount(count)
        liveStatusView.updateLikeCount(count)
    }

    private func registerLike() {
        guard isLikeActive, !isPaused else { return }
        pendingLikeCount += 1
        scheduleLikeFlush()
    }

    private func scheduleLikeFlush() {
        let now = ProcessInfo.processInfo.systemUptime
        let elapsed = now - lastLikeSendTime
        if elapsed >= 6 {
            flushPendingLikes()
            return
        }
        guard likeFlushTimer == nil else { return }
        let sessionID = likeSessionID
        let timer = Timer(timeInterval: 6 - elapsed, repeats: false) { [weak self] _ in
            Task { @MainActor in
                guard let self, self.isLikeActive, self.likeSessionID == sessionID else { return }
                self.flushPendingLikes()
            }
        }
        likeFlushTimer = timer
        RunLoop.main.add(timer, forMode: .common)
    }

    private func flushPendingLikes() {
        likeFlushTimer?.invalidate()
        likeFlushTimer = nil
        guard pendingLikeCount > 0 else { return }
        let count = pendingLikeCount
        pendingLikeCount = 0
        lastLikeSendTime = ProcessInfo.processInfo.systemUptime
        likeStore.sendLike(count: count, completion: nil)
    }
}

// MARK: - Comment Composer Layout

private extension PusherLivingView {
    private func updateCommentWidth() {
        guard bounds.width > 0 else { return }
        let defaultWidth = min(bounds.width * BarrageStreamView.defaultWidthRatio, bounds.width - 24)
        let width: CGFloat
        switch coGuestState.layout {
        case .grid2, .grid9:
            width = defaultWidth
        case .floating, .fixed:
            // Use the whole viewport so scrolling does not repeatedly change line widths.
            let commentFrame = messageListView.frame
            let rightEdge = (coGuestSmallWindowRegions?() ?? [])
                .filter { $0.maxY > commentFrame.minY && $0.minY < commentFrame.maxY }
                .map { $0.minX - 8 }
                .min()
            width = rightEdge.map { min(defaultWidth, $0 - 12) } ?? defaultWidth
        }
        let resolvedWidth = max(17, width)
        guard abs(resolvedWidth - messageListWidth) > 0.5 else { return }
        messageListWidth = resolvedWidth
        messageListWidthConstraint?.update(offset: resolvedWidth)
        setNeedsLayout()
    }

    private func setCommentComposerPresented(_ isPresented: Bool) {
        if isPresented {
            messageListNormalBottomConstraint?.deactivate()
            messageListNormalHeightConstraint?.deactivate()
            messageListComposerBottomConstraint?.activate()
            messageListComposerHeightConstraint?.activate()
        } else {
            messageListComposerBottomConstraint?.deactivate()
            messageListComposerHeightConstraint?.deactivate()
            messageListNormalBottomConstraint?.activate()
            messageListNormalHeightConstraint?.activate()
        }

        UIView.animate(
            withDuration: 0.25,
            delay: 0,
            options: [.curveEaseInOut, .beginFromCurrentState, .allowUserInteraction]
        ) {
            self.layoutIfNeeded()
        }
    }
}

// MARK: - Stage Gestures

extension PusherLivingView: UIGestureRecognizerDelegate {
    @objc private func handleStageTap(_ recognizer: UITapGestureRecognizer) {
        guard canHandleStageLike else {
            lastStageTapTime = 0
            return
        }
        let now = ProcessInfo.processInfo.systemUptime
        let stagePoint = recognizer.location(in: self)
        if onCoGuestStageTap?(stagePoint) == true {
            lastStageTapTime = 0
            return
        }
        let isContinuousTap = now - lastStageTapTime <= 0.42
        lastStageTapTime = now
        guard isContinuousTap else { return }

        let point = recognizer.location(in: likeAnimationView)
        likeAnimationView.showStageLike(
            at: point,
            auxiliaryOrigin: bottomToolbar.likeAnimationOrigin(in: likeAnimationView)
        )
        registerLike()
    }

    func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldReceive touch: UITouch) -> Bool {
        var view = touch.view
        while let current = view, current !== self {
            if current is UIControl { return false }
            view = current.superview
        }
        return true
    }

    private var canHandleStageLike: Bool {
        !isPaused &&
            settingsView.isHidden &&
            commentComposer.isHidden &&
            musicView.isHidden &&
            audienceListView.isHidden &&
            audienceManageView.isHidden &&
            endConfirmationView.isHidden &&
            coGuestSettingsView.isHidden &&
            liveStatusView.isHidden &&
            coGuestAudienceManageView.isHidden
    }

}

private final class LivingScrimView: UIView {
    enum Direction {
        case top
        case bottom
    }

    private let gradient = CAGradientLayer()

    init(direction: Direction) {
        super.init(frame: .zero)
        isUserInteractionEnabled = false
        gradient.colors = direction == .top
            ? [UIColor.black.withAlphaComponent(0.5).cgColor, UIColor.clear.cgColor]
            : [UIColor.clear.cgColor, UIColor.black.withAlphaComponent(0.58).cgColor]
        gradient.startPoint = CGPoint(x: 0.5, y: 0)
        gradient.endPoint = CGPoint(x: 0.5, y: 1)
        layer.addSublayer(gradient)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        gradient.frame = bounds
    }
}
