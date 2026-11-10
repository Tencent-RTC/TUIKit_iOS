import UIKit
import AtomicXCore
import Combine
import SnapKit

final class PusherLivingView: UIView {
    private enum InteractionLayout {
        static let gridGap: CGFloat = 8
        static let toolbarGap: CGFloat = 14
        static let composerGap: CGFloat = 6
        static let normalHeight: CGFloat = 184
    }

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
    var coGuestGridRegions: (() -> [CGRect])?

    // MARK: - Feature Dependencies

    private let liveID: String
    private let audienceStore: PusherAudienceStore
    private let likeStore: LikeStore
    private let commentStore = BarrageUIStore()
    private var commentToast: LiveToast?
    private let giftBarrageStore = GiftBarrageStore()
    private let musicView: PusherMusicView

    // MARK: - Child Views

    private let topScrim = LivingScrimView(direction: .top)
    private let bottomScrim = LivingScrimView(direction: .bottom)
    private let likeAnimationView = LikeAnimationView()
    private let giftDisplayView: GiftDisplayView
    private let headerView = LiveHeaderView()
    private let welcomeClipMask = CAShapeLayer()
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
    private var isAudienceWelcomeVisible = false
    private var isCommentComposerPresented = false
    private var normalCommentHeight = InteractionLayout.normalHeight
    private var composerCommentHeight = InteractionLayout.normalHeight
    private var composerNormalContentHeight: CGFloat?
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
    private let likeSender = LikeSender()
    private var likeCount = 0
    private var isLikeActive = false
    private var isCommentActive = false
    private var showsSystemAnnouncement = false

    init(liveID: String) {
        self.liveID = liveID
        giftDisplayView = GiftDisplayView(liveID: liveID)
        audienceStore = PusherAudienceStore(liveID: liveID)
        likeStore = LikeStore.create(liveID: liveID)
        musicView = PusherMusicView(liveID: liveID)
        liveStatusView = PusherLiveStatusView(liveID: liveID)
        super.init(frame: .zero)
        giftDisplayView.setActive(false)
        configureUI()
        bindAudienceStore()
        renderLikes()
    }

    @available(*, unavailable) required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    override func layoutSubviews() {
        super.layoutSubviews()
        updateInteractionLayout()
        updateCommentWidth()
    }

}

// MARK: - Stage Rendering

extension PusherLivingView {
    func updateHost(name: String, avatarURL: String) { headerView.bindHost(name: name, avatarURL: avatarURL) }

    func updateSettings(_ settings: PusherSettingsState) { settingsView.bind(settings) }

    func updateDeviceStatus(_ status: PusherDeviceStatusState, isMuted: Bool, captureVolume: Int) {
        headerView.bindNetworkQuality(status.networkQuality)
        liveStatusView.updateDeviceStatus(status, isMuted: isMuted, captureVolume: captureVolume)
    }

    func updateElapsedSeconds(_ seconds: Int) {
        headerView.bindElapsedSeconds(seconds)
        liveStatusView.updateElapsedSeconds(seconds)
    }

    func updatePause(isPaused: Bool, seconds: Int) {
        self.isPaused = isPaused
        giftDisplayView.setPresentationEnabled(!isPaused)
        updateMusicSuspension()
        pauseOverlay.bind(isPaused: isPaused, seconds: seconds)
    }

}

// MARK: - Audience Lifecycle

extension PusherLivingView {
    func activateAudience() { audienceStore.activate() }

    func refreshAudience() { audienceStore.refresh() }

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
        likeSender.activate { [likeStore] in likeStore.sendLike(count: $0, completion: nil) }
        updateLikeCount(likeStore.state.value.totalLikeCount)
        likeStore.state.subscribe().receive(on: DispatchQueue.main).sink { [weak self] state in
            guard let self, self.isLikeActive, self.likeSessionID == sessionID else { return }
            self.updateLikeCount(state.totalLikeCount)
        }.store(in: &likeCancellables)
        likeAnimationView.activate(liveID: liveID) { [weak self] in
            guard let self else { return .zero }
            return self.bottomToolbar.likeAnimationOrigin(in: self.likeAnimationView)
        }
    }

    func deactivateLikes(resetState: Bool, discardPending: Bool = false) {
        likeSessionID = nil
        isLikeActive = false
        likeSender.deactivate(discardPending: discardPending)
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
        giftDisplayView.setActive(true)
        commentStore.onStateChanged = { [weak self] state in
            guard let self, self.isCommentActive else { return }
            self.renderComments(state.comments)
        }
        commentStore.onSendError = { [weak self] message in
            guard let self, self.isCommentActive, self.window != nil, !self.isHidden else { return }
            self.commentToast = LiveToast.show(message)
        }
        commentStore.activate(liveID: liveID, hostUserID: LoginStore.shared.state.value.loginUserInfo?.userID ?? "")
        giftBarrageStore.onGiftBarrageSettled = { [weak self] gift in
            guard let self, self.isCommentActive else { return }
            self.commentStore.appendGiftBarrage(gift)
        }
        giftBarrageStore.activate(liveID: liveID)
    }

    func showSystemAnnouncement() {
        guard isCommentActive, !showsSystemAnnouncement else { return }
        showsSystemAnnouncement = true
        renderComments(commentStore.state.comments)
    }

    func pauseComments() {
        guard isCommentActive else { return }
        giftBarrageStore.setCollectionEnabled(false)
    }

    func resumeComments() {
        guard isCommentActive else { return }
        giftBarrageStore.setCollectionEnabled(true)
    }

    func deactivateComments(resetState: Bool) {
        isCommentActive = false
        showsSystemAnnouncement = false
        giftDisplayView.setActive(false)
        setCommentComposerPresented(false, animated: false)
        composerCommentHeight = InteractionLayout.normalHeight
        composerNormalContentHeight = nil
        messageListComposerHeightConstraint?.update(offset: composerCommentHeight)
        commentComposer.reset()
        commentStore.deactivate()
        commentToast?.dismiss()
        commentToast = nil
        giftBarrageStore.onGiftBarrageSettled = nil
        giftBarrageStore.deactivate()
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
        NotificationCenter.default.publisher(for: UIApplication.didEnterBackgroundNotification).sink { [weak self] _ in
            self?.isMusicInBackground = true
            self?.updateMusicSuspension()
        }.store(in: &musicLifecycleCancellables)
        NotificationCenter.default.publisher(for: UIApplication.didBecomeActiveNotification).sink { [weak self] _ in
            self?.isMusicInBackground = false
            self?.updateMusicSuspension()
        }.store(in: &musicLifecycleCancellables)
    }

    func deactivateMusic() {
        musicLifecycleCancellables.removeAll()
        musicView.deactivate()
    }

    private func updateMusicSuspension() { musicView.setSuspended(isPaused || isMusicInBackground) }
}

// MARK: - Root Coordination

extension PusherLivingView {
    func resetAfterStartFailure() {
        lastStageTapTime = 0
        deactivateAudience(resetState: true)
        deactivateLikes(resetState: true, discardPending: true)
        deactivateComments(resetState: true)
        deactivateMusic()
        updatePause(isPaused: false, seconds: 0)
        updateElapsedSeconds(0)
        settingsView.cancelPendingAction()
        audienceListView.cancelPendingSelection()
        let sheets: [BottomSheetView] = [
            settingsView, musicView, audienceListView, audienceManageView, endConfirmationView, coGuestSettingsView,
            liveStatusView, coGuestAudienceManageView,
        ]
        sheets.forEach { $0.dismiss() }
    }

    func resetAudienceWelcomes() { audienceWelcomeView.reset() }

    func updateCoGuest(_ state: PusherCoGuestStore.State) {
        let needsLayoutUpdate =
            coGuestState.layout != state.layout || coGuestState.connected.count != state.connected.count
        coGuestState = state
        // Restore from the confirmed layout immediately, including while a sheet is open.
        // SDK geometry callbacks may arrive later and must not keep the old narrow width.
        if needsLayoutUpdate {
            updateCommentWidth()
            setNeedsLayout()
        }
        coGuestSettingsView.bind(state)
        coGuestAudienceManageView.bind(state)
        bottomToolbar.setCoGuestUnread(state.hasUnreadApplicant)
        // Requests arriving while the drawer is already open are visible to the
        // host, so they must not leave the dot lit after the drawer closes.
        if state.hasUnreadApplicant, !coGuestSettingsView.isHidden { coGuestActionHandler?.markApplicantsSeen() }
    }

    func setCoGuestStageActive(_ isActive: Bool) { bottomToolbar.setCoGuestStageActive(isActive) }

    func showCoGuestActions(userID: String) {
        guard let user = coGuestState.connected.first(where: { $0.userID == userID }) else { return }
        coGuestAudienceManageView.show(user: user, isPending: coGuestState.pendingUserIDs.contains(userID))
    }
}

// MARK: - UI Assembly

private extension PusherLivingView {
    private func configureUI() {
        backgroundColor = .clear

        [
            topScrim, bottomScrim, headerView, messageListView, audienceWelcomeView, bottomToolbar, likeAnimationView,
            giftDisplayView, settingsView, commentComposer, musicView, pauseOverlay, audienceListView,
            audienceManageView, endConfirmationView, coGuestSettingsView, liveStatusView, coGuestAudienceManageView,
        ].forEach { addSubview($0) }

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
        headerView.onAudience = { [weak self] in self?.audienceListView.show() }
        headerView.onStatus = { [weak self] in self?.liveStatusView.show() }
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
        bottomToolbar.onMore = { [weak self] in self?.settingsView.show() }
        bottomToolbar.onPK = {
            LiveToast.show(LiveKitResources.localizedString("tuilivekit.pusher.living.pk_developing"))
        }
        bottomToolbar.onCoGuest = { [weak self] in
            self?.coGuestSettingsView.show()
            self?.coGuestActionHandler?.markApplicantsSeen()
        }
        settingsView.onToggleMute = { [weak self] in self?.onToggleMute?() }
        settingsView.onPause = { [weak self] in self?.onPause?() }
        bottomToolbar.onFlipCamera = { [weak self] in self?.onFlipCamera?() }
        settingsView.onShowBeauty = { [weak self] in self?.onShowBeauty?() }
        settingsView.onShowComment = { [weak self] in self?.commentComposer.show() }
        bottomToolbar.onShowBackgroundMusic = { [weak self] in self?.musicView.show() }
        commentComposer.onSend = { [weak self] in self?.sendComment($0) }
        commentComposer.onPresentationChanged = { [weak self] isPresented in
            self?.setCommentComposerPresented(isPresented)
        }
        pauseOverlay.onResume = { [weak self] in self?.onResume?() }
        messageListView.onContentHeightChanged = { [weak self] _ in self?.setNeedsLayout() }
        giftDisplayView.onNoticeContentHeightChanged = { [weak self] _ in self?.setNeedsLayout() }
        audienceWelcomeView.onVisibilityChanged = { [weak self] isVisible in
            guard let self else { return }
            self.isAudienceWelcomeVisible = isVisible
            self.setNeedsLayout()
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
        likeAnimationView.snp.makeConstraints { make in make.edges.equalToSuperview() }
        giftDisplayView.snp.makeConstraints { make in make.edges.equalToSuperview() }
        headerView.snp.makeConstraints { make in
            make.leading.trailing.equalToSuperview().inset(12)
            make.top.equalTo(safeAreaLayoutGuide.snp.top).offset(-1)
            make.height.equalTo(67)
        }
        bottomToolbar.snp.makeConstraints { make in
            make.leading.trailing.bottom.equalToSuperview()
            make.top.equalTo(safeAreaLayoutGuide.snp.bottom).offset(-68)
        }
        messageListView.snp.makeConstraints { make in
            make.leading.equalToSuperview().offset(12)
            messageListWidthConstraint = make.width.equalTo(0).constraint
            messageListNormalBottomConstraint =
                make.bottom.equalTo(bottomToolbar.snp.top).offset(-InteractionLayout.toolbarGap).constraint
            messageListNormalHeightConstraint = make.height.equalTo(InteractionLayout.normalHeight).constraint
            messageListComposerBottomConstraint =
                make.bottom.equalTo(commentComposer.inputBarLayoutView.snp.top).offset(-InteractionLayout.composerGap)
                .constraint
            messageListComposerHeightConstraint = make.height.equalTo(InteractionLayout.normalHeight).constraint
        }
        messageListComposerBottomConstraint?.deactivate()
        messageListComposerHeightConstraint?.deactivate()
        audienceWelcomeView.snp.makeConstraints { make in
            make.leading.trailing.equalToSuperview()
            make.height.equalTo(LiveInteractionLayout.welcomeHeight)
            audienceWelcomeBottomConstraint =
                make.bottom.equalTo(bottomToolbar.snp.top).offset(
                    -InteractionLayout.toolbarGap - LiveInteractionLayout.noticeSpacing
                ).constraint
        }
        [
            settingsView, commentComposer, musicView, pauseOverlay, audienceListView, audienceManageView,
            endConfirmationView, coGuestSettingsView, liveStatusView, coGuestAudienceManageView,
        ].forEach { $0.snp.makeConstraints { make in make.edges.equalToSuperview() } }
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
        audienceStore.onAudienceEntered = { [weak self] welcome in self?.showAudienceWelcome(welcome) }
        audienceStore.onActionCompleted = { [weak self] userID, action, succeeded in
            guard let self else { return }
            self.audienceManageView.completeAction(userID: userID, action: action, succeeded: succeeded)
            guard succeeded else { return }
            let toastKey: String
            switch action {
            case .mute: toastKey = "tuilivekit.pusher.audience.muted_toast"
            case .unmute: toastKey = "tuilivekit.pusher.audience.unmuted_toast"
            case .remove: toastKey = "tuilivekit.pusher.audience.removed_toast"
            case .follow, .unfollow: return
            }
            let name =
                self.audienceState.users.first(where: { $0.userID == userID }).map {
                    $0.userName.isEmpty ? $0.userID : $0.userName
                } ?? userID
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
        let announcement: [BarrageStreamView.Message] =
            showsSystemAnnouncement
            ? [
                BarrageStreamView.Message(
                    id: "pusher-system-announcement", userName: "",
                    content: LiveKitResources.localizedString("tuilivekit.pusher.system_announcement"), level: 0,
                    isSystemAnnouncement: true)
            ] : []
        messageListView.bind(
            announcement
                + comments.map {
                    BarrageStreamView.Message(
                        id: $0.id, userName: $0.senderName, content: $0.text, level: $0.level, isHost: $0.isHost,
                        gift: $0.gift)
                })
    }
}

// MARK: - Like Interaction

private extension PusherLivingView {
    private func showReceivedLikes(count: Int) {
        guard !isPaused, !isHidden else { return }
        likeAnimationView.showReceivedLikes(
            count: count, auxiliaryOrigin: bottomToolbar.likeAnimationOrigin(in: likeAnimationView))
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
        likeSender.sendLike()
    }
}

// MARK: - Comment Composer Layout

private extension PusherLivingView {
    private var usesGridCommentLayout: Bool {
        coGuestState.layout == .gridLayout || (coGuestState.layout == .dynamicLayout && !coGuestState.connected.isEmpty)
    }

    private var interactionTopBoundary: CGFloat? {
        guard usesGridCommentLayout else { return nil }
        // Until SDK seats have valid geometry, reserve the whole stage rather than overlaying it.
        let bottom =
            (coGuestGridRegions?() ?? []).filter { !$0.isEmpty && $0.intersects(bounds) }.map(\.maxY).max()
            ?? bounds.height
        return min(bounds.height, max(0, bottom + InteractionLayout.gridGap))
    }

    private func updateInteractionLayout() {
        guard bounds.width > 0, bounds.height > 0 else { return }
        let topBoundary = interactionTopBoundary
        let bottom = bottomToolbar.frame.minY - InteractionLayout.toolbarGap
        let layout = LiveInteractionLayout(
            topBoundary: topBoundary, bottom: bottom, defaultCommentHeight: InteractionLayout.normalHeight,
            contentHeight: composerNormalContentHeight ?? messageListView.contentHeight,
            isWelcomeVisible: isAudienceWelcomeVisible, giftNoticeHeight: giftDisplayView.noticeContentHeight,
            safeBottom: bounds.height - safeAreaInsets.bottom)
        applyWelcomeClip(topBoundary, bannerTop: layout.welcomeTop)
        applyInteractionLayout(layout, topBoundary: topBoundary)
    }

    private func applyWelcomeClip(_ topBoundary: CGFloat?, bannerTop: CGFloat) {
        guard let topBoundary else {
            audienceWelcomeView.layer.mask = nil
            return
        }
        let localTop = max(0, topBoundary - bannerTop)
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        welcomeClipMask.frame = audienceWelcomeView.bounds
        welcomeClipMask.path =
            UIBezierPath(
                rect: CGRect(
                    x: 0, y: localTop, width: audienceWelcomeView.bounds.width,
                    height: max(0, audienceWelcomeView.bounds.height - localTop))
            ).cgPath
        audienceWelcomeView.layer.mask = welcomeClipMask
        CATransaction.commit()
    }

    private func applyInteractionLayout(_ layout: LiveInteractionLayout, topBoundary: CGFloat?) {
        // Notices change only the upper crop. Do not resize or scroll the list for transient overlays.
        messageListView.setVisibleHeight(isCommentComposerPresented ? nil : layout.visibleCommentHeight)
        audienceWelcomeBottomConstraint?.update(offset: layout.welcomeBottomOffset - InteractionLayout.toolbarGap)
        giftDisplayView.updateNoticeLayout(bottom: layout.giftNoticeBottom, topBoundary: topBoundary)

        guard abs(normalCommentHeight - layout.commentHeight) > 0.5 else { return }
        normalCommentHeight = layout.commentHeight
        messageListNormalHeightConstraint?.update(offset: layout.commentHeight)
        setNeedsLayout()
    }

    private func updateCommentWidth() {
        guard bounds.width > 0 else { return }
        let defaultWidth = min(bounds.width * BarrageStreamView.defaultWidthRatio, bounds.width - 24)
        let width: CGFloat
        switch coGuestState.layout {
        case .floatLayout, .columnLayout:
            // Use the whole viewport so scrolling does not repeatedly change line widths.
            let commentFrame = messageListView.frame
            let rightEdge = (coGuestSmallWindowRegions?() ?? []).filter {
                $0.maxY > commentFrame.minY && $0.minY < commentFrame.maxY
            }.map { $0.minX - 8 }.min()
            width = rightEdge.map { min(defaultWidth, $0 - 12) } ?? defaultWidth
        default: width = defaultWidth
        }
        let resolvedWidth = max(17, width)
        guard abs(resolvedWidth - messageListWidth) > 0.5 else { return }
        messageListWidth = resolvedWidth
        messageListWidthConstraint?.update(offset: resolvedWidth)
        setNeedsLayout()
    }

    private func setCommentComposerPresented(_ isPresented: Bool, animated: Bool = true) {
        guard isCommentComposerPresented != isPresented else { return }
        if isPresented {
            layoutIfNeeded()
            messageListView.layoutIfNeeded()
            composerCommentHeight = messageListView.visibleHeight
            composerNormalContentHeight = messageListView.contentHeight
            messageListComposerHeightConstraint?.update(offset: composerCommentHeight)
        } else {
            composerNormalContentHeight = nil
        }
        isCommentComposerPresented = isPresented
        setNeedsLayout()
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

        let changes = { self.layoutIfNeeded() }
        guard animated else {
            changes()
            return
        }
        UIView.animate(
            withDuration: 0.25, delay: 0, options: [.curveEaseInOut, .beginFromCurrentState, .allowUserInteraction],
            animations: changes)
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
            at: point, auxiliaryOrigin: bottomToolbar.likeAnimationOrigin(in: likeAnimationView))
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
        !isPaused && settingsView.isHidden && commentComposer.isHidden && musicView.isHidden
            && audienceListView.isHidden && audienceManageView.isHidden && endConfirmationView.isHidden
            && coGuestSettingsView.isHidden && liveStatusView.isHidden && coGuestAudienceManageView.isHidden
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
        gradient.colors =
            direction == .top
            ? [UIColor.black.withAlphaComponent(0.5).cgColor, UIColor.clear.cgColor]
            : [UIColor.clear.cgColor, UIColor.black.withAlphaComponent(0.58).cgColor]
        gradient.startPoint = CGPoint(x: 0.5, y: 0)
        gradient.endPoint = CGPoint(x: 0.5, y: 1)
        layer.addSublayer(gradient)
    }

    @available(*, unavailable) required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    override func layoutSubviews() {
        super.layoutSubviews()
        gradient.frame = bounds
    }
}
