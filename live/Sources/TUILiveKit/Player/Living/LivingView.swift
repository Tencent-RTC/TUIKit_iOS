import AtomicXCore
import SnapKit
import UIKit

@MainActor final class LivingView: UIView, UIGestureRecognizerDelegate {
    private enum Constants {
        static let bottomBarBottomInset: CGFloat = 3
        static let bottomBarHeight: CGFloat = 39
        static let messageBottomSpacing: CGFloat = 14
        static let gridGap: CGFloat = 8
        static let composerGap: CGFloat = 6
        static let normalCommentHeight: CGFloat = 184
    }

    var videoSeatRegions: (() -> [CGRect])?
    var onToast: ((String) -> Void)?
    var onCoGuestUiStateChanged: ((CoGuestStatus) -> Void)? {
        get { coGuestView.onUiStateChanged }
        set { coGuestView.onUiStateChanged = newValue }
    }

    private let movableContentView = UIView()
    private let audienceView = AudienceView()
    private let audienceWelcomeView = AudienceWelcomeView()
    private let messageListView = BarrageStreamView()
    private let likeAnimationView = LikeAnimationView()

    private let bottomBarContainer = UIView()
    private let commentButton = UIButton(type: .custom)
    private let coGuestView = CoGuestIcon()
    private let giftButton = UIButton(type: .custom)
    private let likeButton = UIButton(type: .custom)

    private let cleanScreenButton = UIButton(type: .custom)

    private let commentComposerView = BarrageInputView()
    private let giftSendPanel = GiftSendPanelView()
    private let audienceListView = AudienceListPanel()
    private var giftDisplayView: GiftDisplayView?

    private let commentStore = BarrageUIStore()
    private let giftBarrageStore = GiftBarrageStore()
    private let likeStore = LiveUIStore()
    private lazy var hostInfoView = HostInfoView(likeStore: likeStore)

    private var liveInfo: LiveInfo?
    private var isJoinedChannel = false
    private(set) var isCleanScreen = false
    private var activatedRoomLiveID: String?
    private var cleanScreenStateAtGestureStart = false
    private var lastStageLikeTapTime: TimeInterval = 0
    private var messageListNormalBottomConstraint: Constraint?
    private var messageListNormalHeightConstraint: Constraint?
    private var messageListComposerBottomConstraint: Constraint?
    private var messageListComposerHeightConstraint: Constraint?
    private var isAudienceWelcomeVisible = false
    private var isCommentComposerPresented = false
    private var giftPanelHeightAboveSafeArea: CGFloat?
    private var normalCommentHeight = Constants.normalCommentHeight
    private var composerCommentHeight = Constants.normalCommentHeight
    private var composerNormalContentHeight: CGFloat?
    private let welcomeClipMask = CAShapeLayer()
    private var audienceWelcomeBottomConstraint: Constraint?

    override init(frame: CGRect) {
        super.init(frame: frame)
        configureUI()
        bindActions()
        bindStores()
        refresh()
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        updateInteractionLayout()
    }

    override func didMoveToWindow() {
        super.didMoveToWindow()
        guard let window else { return }
        [giftSendPanel, audienceListView].forEach { panel in
            guard panel.superview !== window else { return }
            panel.removeFromSuperview()
            window.addSubview(panel)
            panel.snp.remakeConstraints { make in make.edges.equalToSuperview() }
        }
    }

    @available(*, unavailable) required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    func bind(_ liveInfo: LiveInfo) {
        updateLiveInfo(liveInfo)
        messageListView.bind([])
        refresh()
    }

    func updateLiveInfo(_ liveInfo: LiveInfo) {
        self.liveInfo = liveInfo
        hostInfoView.bind(liveInfo)
        audienceView.bind(liveInfo)
        coGuestView.activate(liveInfo)
    }

    func setContentSafeAreaInsets(_ insets: UIEdgeInsets) {
        guard layoutMargins != insets else { return }
        layoutMargins = insets
    }

    func setJoinedChannel(_ joined: Bool) {
        if isJoinedChannel == joined {
            refresh()
            return
        }
        isJoinedChannel = joined
        if !joined {
            dismissInteractionOverlays(resetCommentDraft: true)
            if isCleanScreen { setCleanScreen(false, animated: false) }
        }
        refresh()
    }

    func refresh() {
        let showBusiness = isJoinedChannel && !isCleanScreen
        movableContentView.isHidden = !showBusiness
        likeAnimationView.isHidden = !isJoinedChannel

        movableContentView.isUserInteractionEnabled = showBusiness
        movableContentView.accessibilityElementsHidden = !showBusiness

        let showJoinedChrome = isJoinedChannel && !isCleanScreen
        audienceView.isHidden = !showJoinedChrome

        cleanScreenButton.isHidden = !(isJoinedChannel && isCleanScreen)
    }

    func activateCoGuest(_ liveInfo: LiveInfo) { coGuestView.activate(liveInfo) }

    func deactivateCoGuest() { coGuestView.deactivate() }

    var isCoGuestOpeningCamera: Bool { coGuestView.isOpeningCamera }

    @discardableResult func invalidateCoGuestCameraRequests(allowRestore: Bool) -> Bool {
        coGuestView.invalidateCameraRequests(allowRestore: allowRestore)
    }

    func activateRoomFeatures(liveID: String, hostUserID: String) {
        guard activatedRoomLiveID != liveID else { return }
        deactivateRoomFeatures()
        commentStore.activate(liveID: liveID, hostUserID: hostUserID)
        installGiftDisplay(liveID: liveID)
        giftBarrageStore.activate(liveID: liveID)
        audienceListView.activate(liveID: liveID)
        likeStore.activate(liveID: liveID)
        likeAnimationView.activate(liveID: liveID) { [weak self] in
            guard let self else { return .zero }
            return self.likeButtonCenter(in: self.likeAnimationView)
        }
        activatedRoomLiveID = liveID
        renderComments(commentStore.state.comments)
        updateGiftPresentationState()
    }

    func deactivateRoomFeatures() {
        guard activatedRoomLiveID != nil else { return }
        commentStore.deactivate()
        giftBarrageStore.deactivate()
        removeGiftDisplay()
        audienceListView.deactivate()
        likeStore.deactivate()
        likeAnimationView.deactivate()
        audienceWelcomeView.reset()
        activatedRoomLiveID = nil
        messageListView.prepareForReuse()
        resetInteractionLayout()
    }

    func prepareForReuse() {
        hostInfoView.prepareForReuse()
        audienceView.unbind()
        messageListView.prepareForReuse()
        resetInteractionLayout()
        setCommentComposerPresented(false, animated: false)
        setCleanScreen(false, animated: false)
        dismissInteractionOverlays(resetCommentDraft: true)
        likeAnimationView.removeAllAnimations()
        lastStageLikeTapTime = 0
        liveInfo = nil
        isJoinedChannel = false
        coGuestView.deactivate()
        refresh()
    }

    private func configureUI() {
        backgroundColor = .clear
        preservesSuperviewLayoutMargins = false
        insetsLayoutMarginsFromSafeArea = false
        layoutMargins = .zero

        configureBottomBar()
        configureCleanScreenButton()

        addSubview(movableContentView)
        [hostInfoView, messageListView, audienceWelcomeView, bottomBarContainer, likeAnimationView].forEach(
            movableContentView.addSubview)
        addSubview(audienceView)
        addSubview(cleanScreenButton)

        addSubview(commentComposerView)
        commentComposerView.snp.makeConstraints { make in make.edges.equalToSuperview() }
        let stageTap = UITapGestureRecognizer(target: self, action: #selector(handleStageLikeTap(_:)))
        stageTap.cancelsTouchesInView = false
        stageTap.delegate = self
        addGestureRecognizer(stageTap)

        let horizontalPan = UIPanGestureRecognizer(target: self, action: #selector(handleHorizontalPan(_:)))
        horizontalPan.delegate = self
        horizontalPan.cancelsTouchesInView = false
        addGestureRecognizer(horizontalPan)

        movableContentView.snp.makeConstraints { make in make.edges.equalToSuperview() }
        hostInfoView.snp.makeConstraints { make in
            make.leading.equalTo(layoutMarginsGuide.snp.leading).offset(20)
            make.top.equalTo(layoutMarginsGuide.snp.top).offset(10)
            make.height.equalTo(36)
        }
        audienceView.snp.makeConstraints { make in
            make.trailing.equalTo(layoutMarginsGuide.snp.trailing).offset(-42)
            make.centerY.equalTo(hostInfoView)
            make.height.equalTo(26)
        }
        messageListView.snp.makeConstraints { make in
            make.leading.equalTo(layoutMarginsGuide.snp.leading).offset(12)
            messageListNormalBottomConstraint =
                make.bottom.equalTo(bottomBarContainer.snp.top).offset(-Constants.messageBottomSpacing).constraint
            make.width.equalToSuperview().multipliedBy(BarrageStreamView.defaultWidthRatio)
            messageListNormalHeightConstraint = make.height.equalTo(Constants.normalCommentHeight).constraint
            messageListComposerBottomConstraint =
                make.bottom.equalTo(commentComposerView.inputBarLayoutView.snp.top).offset(-Constants.composerGap)
                .constraint
            messageListComposerHeightConstraint = make.height.equalTo(Constants.normalCommentHeight).constraint
        }
        messageListComposerBottomConstraint?.deactivate()
        messageListComposerHeightConstraint?.deactivate()
        bottomBarContainer.snp.makeConstraints { make in
            make.leading.trailing.equalTo(layoutMarginsGuide).inset(12)
            make.bottom.equalTo(layoutMarginsGuide.snp.bottom).offset(-Constants.bottomBarBottomInset)
            make.height.equalTo(Constants.bottomBarHeight)
        }
        audienceWelcomeView.snp.makeConstraints { make in
            make.leading.trailing.equalToSuperview()
            make.height.equalTo(LiveInteractionLayout.welcomeHeight)
            audienceWelcomeBottomConstraint =
                make.bottom.equalTo(bottomBarContainer.snp.top).offset(
                    -Constants.messageBottomSpacing - LiveInteractionLayout.noticeSpacing
                ).constraint
        }
        likeAnimationView.snp.makeConstraints { make in make.edges.equalToSuperview() }
        cleanScreenButton.snp.makeConstraints { make in
            make.width.equalTo(42)
            make.height.equalTo(40)
            make.trailing.equalTo(layoutMarginsGuide.snp.trailing).offset(-25)
            make.bottom.equalTo(layoutMarginsGuide.snp.bottom).offset(-12)
        }

        cleanScreenButton.alpha = 0
        cleanScreenButton.isHidden = true
    }

    private func configureBottomBar() {
        configureBarButton(commentButton, accessibilityKey: "tuilivekit.player.comment")
        commentButton.setTitle(LiveKitResources.localizedString("tuilivekit.player.comment_placeholder"), for: .normal)
        commentButton.setTitleColor(UIColor.white.withAlphaComponent(0.50), for: .normal)
        commentButton.titleLabel?.font = .systemFont(ofSize: 12.5, weight: .regular)
        commentButton.contentHorizontalAlignment = .left
        commentButton.contentEdgeInsets = UIEdgeInsets(top: 0, left: 15, bottom: 0, right: 15)
        commentButton.layer.borderColor = UIColor.white.withAlphaComponent(0.06).cgColor
        commentButton.layer.shadowOpacity = 0.20

        configureBarButton(
            giftButton, imageName: "livekit_player_gift", imageSize: CGSize(width: 39, height: 39),
            accessibilityKey: "tuilivekit.player.gift", hasBackground: false)
        configureBarButton(
            likeButton, imageName: "livekit_player_like", imageSize: CGSize(width: 39, height: 39),
            accessibilityKey: "tuilivekit.player.like", hasBackground: false)

        let stack = UIStackView(arrangedSubviews: [commentButton, coGuestView, giftButton, likeButton])
        stack.axis = .horizontal
        stack.spacing = 8.5
        stack.alignment = .center
        bottomBarContainer.addSubview(stack)
        stack.snp.makeConstraints { make in make.edges.equalToSuperview() }
        [coGuestView, giftButton, likeButton].forEach { button in
            button.snp.makeConstraints { make in make.width.height.equalTo(39) }
        }
        commentButton.snp.makeConstraints { make in make.height.equalTo(39) }
        commentButton.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
    }

    private func configureBarButton(
        _ button: UIButton, imageName: String? = nil, imageSize: CGSize? = nil, accessibilityKey: String,
        hasBackground: Bool = true
    ) {
        if let imageName, let imageSize {
            button.setImage(resizedImage(named: imageName, size: imageSize), for: .normal)
            button.imageView?.contentMode = .center
        }
        if hasBackground {
            button.backgroundColor = UIColor(red: 0.04, green: 0.04, blue: 0.06, alpha: 0.18)
            button.layer.cornerRadius = 19.5
            button.layer.borderWidth = 1
            button.layer.borderColor = UIColor.white.withAlphaComponent(0.06).cgColor
        }
        button.accessibilityLabel = LiveKitResources.localizedString(accessibilityKey)
        button.addTarget(self, action: #selector(beginBarButtonPress(_:)), for: [.touchDown, .touchDragEnter])
        button.addTarget(
            self, action: #selector(endBarButtonPress(_:)),
            for: [.touchUpInside, .touchUpOutside, .touchCancel, .touchDragExit])
    }

    private func resizedImage(named name: String, size: CGSize) -> UIImage? {
        guard let image = LiveKitResources.image(named: name) else { return nil }
        return UIGraphicsImageRenderer(size: size).image { _ in image.draw(in: CGRect(origin: .zero, size: size)) }
            .withRenderingMode(.alwaysOriginal)
    }

    private func configureCleanScreenButton() {
        cleanScreenButton.setImage(LiveKitResources.image(named: "livekit_ic_controls_restore"), for: .normal)
        cleanScreenButton.imageView?.contentMode = .center
        cleanScreenButton.imageEdgeInsets = UIEdgeInsets(top: 6, left: 6, bottom: 4, right: 6)
        cleanScreenButton.backgroundColor = UIColor(red: 18 / 255, green: 18 / 255, blue: 22 / 255, alpha: 0.28)
        cleanScreenButton.layer.cornerRadius = 15
        cleanScreenButton.layer.shadowColor = UIColor.black.cgColor
        cleanScreenButton.layer.shadowOpacity = 0.25
        cleanScreenButton.layer.shadowOffset = CGSize(width: 0, height: 4)
        cleanScreenButton.layer.shadowRadius = 4
        cleanScreenButton.adjustsImageWhenHighlighted = false
        cleanScreenButton.accessibilityLabel = LiveKitResources.localizedString(
            "tuilivekit.player.restore_controls_accessibility")
    }

    private func likeButtonCenter(in view: UIView) -> CGPoint {
        likeButton.convert(CGPoint(x: likeButton.bounds.midX, y: likeButton.bounds.midY), to: view)
    }

    @objc private func beginBarButtonPress(_ sender: UIButton) {
        let scale: CGFloat = sender === commentButton ? 0.99 : 0.92
        UIView.animate(withDuration: 0.12) { sender.transform = CGAffineTransform(scaleX: scale, y: scale) }
    }

    @objc private func endBarButtonPress(_ sender: UIButton) {
        UIView.animate(withDuration: 0.12) { sender.transform = .identity }
    }

    private func bindActions() {
        audienceView.onToast = { [weak self] message in
            guard let self, self.isJoinedChannel else { return }
            self.onToast?(message)
        }
        audienceView.onAudience = { [weak self] in self?.presentAudienceList() }
        audienceView.onAudienceEntered = { [weak self] welcome in
            guard let self, self.isJoinedChannel, !self.isCleanScreen else { return }
            self.audienceWelcomeView.enqueue(welcome)
        }
        audienceWelcomeView.onVisibilityChanged = { [weak self] isVisible in
            self?.isAudienceWelcomeVisible = isVisible
            self?.setNeedsLayout()
        }
        hostInfoView.onError = { [weak self] message in
            guard let self, self.isJoinedChannel else { return }
            self.onToast?(message)
        }

        commentButton.addAction(UIAction { [weak self] _ in self?.presentCommentComposer() }, for: .touchUpInside)
        giftButton.addAction(UIAction { [weak self] _ in self?.presentGiftSendPanel() }, for: .touchUpInside)
        likeButton.addAction(
            UIAction { [weak self] _ in
                guard let self else { return }
                let origin = self.likeButtonCenter(in: self.likeAnimationView)
                self.likeAnimationView.showButtonLike(from: origin)
                self.likeStore.sendLike()
            }, for: .touchUpInside)

        cleanScreenButton.addAction(
            UIAction { [weak self] _ in self?.setCleanScreen(false, animated: true) }, for: .touchUpInside)

        commentComposerView.onSend = { [weak self] text in self?.sendComment(text) }
        commentComposerView.onPresentationChanged = { [weak self] isPresented in
            self?.setCommentComposerPresented(isPresented)
        }
        giftSendPanel.onPresentationChanged = { [weak self] in
            self?.updateGiftPanelPresentation(isPresented: $0, heightAboveSafeArea: $1)
        }
        messageListView.onContentHeightChanged = { [weak self] _ in self?.setNeedsLayout() }
    }

    private func renderComments(_ comments: [BarrageUIStore.Comment]) {
        guard activatedRoomLiveID != nil else { return }
        let announcement = BarrageStreamView.Message(
            id: "player-system-announcement", userName: "",
            content: LiveKitResources.localizedString("tuilivekit.player.system_announcement"), level: 0,
            isSystemAnnouncement: true)
        messageListView.bind(
            [announcement]
                + comments.map {
                    BarrageStreamView.Message(
                        id: $0.id, userName: $0.senderName, content: $0.text, level: $0.level, isHost: $0.isHost,
                        gift: $0.gift)
                })
    }

    private func bindStores() {
        commentStore.onSendError = { [weak self] message in
            guard let self, self.isJoinedChannel, self.window != nil, self.activatedRoomLiveID == self.liveInfo?.liveID
            else { return }
            self.onToast?(message)
        }
        commentStore.onStateChanged = { [weak self] state in
            guard let self, self.liveInfo?.liveID == state.liveID, self.activatedRoomLiveID == state.liveID else {
                return
            }
            self.renderComments(state.comments)
        }
        giftBarrageStore.onGiftBarrageSettled = { [weak self] gift in self?.commentStore.appendGiftBarrage(gift) }
    }

    func setCleanScreen(_ cleanScreen: Bool, animated: Bool) {
        isCleanScreen = cleanScreen
        updateGiftPresentationState()
        let targetProgress: CGFloat = cleanScreen ? 1 : 0
        cleanScreenButton.isHidden = false
        let changes = { [weak self] in
            guard let self else { return }
            self.applyCleanScreenProgress(targetProgress)
        }
        let completion: (Bool) -> Void = { [weak self] _ in
            guard let self else { return }
            self.refresh()
        }
        if animated {
            UIView.animate(
                withDuration: 0.3, delay: 0, options: [.beginFromCurrentState, .curveEaseOut, .allowUserInteraction],
                animations: changes, completion: completion)
        } else {
            changes()
            completion(true)
        }
    }

    func dismissInteractionOverlays(resetCommentDraft: Bool = false) {
        if resetCommentDraft { commentComposerView.reset() } else { commentComposerView.dismiss() }
        giftSendPanel.dismiss()
        audienceListView.dismiss()
    }

    private func setCommentComposerPresented(_ isPresented: Bool, animated: Bool = true) {
        if isPresented && !isCommentComposerPresented {
            layoutIfNeeded()
            messageListView.layoutIfNeeded()
            composerCommentHeight = messageListView.visibleHeight
            composerNormalContentHeight = messageListView.contentHeight
            messageListComposerHeightConstraint?.update(offset: composerCommentHeight)
        } else if !isPresented {
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

        let changes: () -> Void = { [weak self] in self?.layoutIfNeeded() }
        guard animated else {
            changes()
            return
        }
        UIView.animate(
            withDuration: 0.25, delay: 0, options: [.curveEaseInOut, .beginFromCurrentState, .allowUserInteraction],
            animations: changes)
    }

    private func presentCommentComposer() {
        if isSelfMessageBanned() {
            LiveToast.show(BarrageUIStore.sendErrorMessage(code: 10017))
            return
        }
        audienceListView.dismiss()
        giftSendPanel.dismiss()
        commentComposerView.show()
    }

    private func sendComment(_ text: String) { commentStore.sendComment(text) }

    private func isSelfMessageBanned() -> Bool { commentStore.isSelfMessageBanned() }

    private func installGiftDisplay(liveID: String) {
        removeGiftDisplay()
        let giftDisplayView = GiftDisplayView(liveID: liveID)
        giftDisplayView.translatesAutoresizingMaskIntoConstraints = false
        insertSubview(giftDisplayView, belowSubview: commentComposerView)
        NSLayoutConstraint.activate([
            giftDisplayView.leadingAnchor.constraint(equalTo: leadingAnchor),
            giftDisplayView.trailingAnchor.constraint(equalTo: trailingAnchor),
            giftDisplayView.topAnchor.constraint(equalTo: topAnchor),
            giftDisplayView.bottomAnchor.constraint(equalTo: bottomAnchor),
        ])
        giftDisplayView.onNoticeContentHeightChanged = { [weak self] _ in self?.setNeedsLayout() }
        self.giftDisplayView = giftDisplayView
        setNeedsLayout()
    }

    private func removeGiftDisplay() {
        giftDisplayView?.removeFromSuperview()
        giftDisplayView = nil
    }

    private func updateGiftPresentationState() {
        let isEnabled = activatedRoomLiveID != nil && !isCleanScreen
        giftBarrageStore.setCollectionEnabled(isEnabled)
        guard let giftDisplayView else { return }
        giftDisplayView.setPresentationEnabled(isEnabled)
        giftDisplayView.isHidden = !isEnabled
    }

    private func presentGiftSendPanel() {
        audienceListView.dismiss()
        commentComposerView.dismiss()
        giftSendPanel.present(liveID: activatedRoomLiveID ?? "")
    }

    private func updateGiftPanelPresentation(isPresented: Bool, heightAboveSafeArea: CGFloat) {
        giftPanelHeightAboveSafeArea = isPresented ? heightAboveSafeArea : nil
        setNeedsLayout()
    }

    private func resetInteractionLayout() {
        isAudienceWelcomeVisible = false
        giftPanelHeightAboveSafeArea = nil
        composerCommentHeight = Constants.normalCommentHeight
        composerNormalContentHeight = nil
        messageListComposerHeightConstraint?.update(offset: composerCommentHeight)
        messageListView.setVisibleHeight(nil)
        audienceWelcomeView.layer.mask = nil
        setNeedsLayout()
    }

    private var interactionTopBoundary: CGFloat? {
        guard isJoinedChannel,
            let bottom = (videoSeatRegions?() ?? []).filter({ !$0.isEmpty && $0.intersects(bounds) }).map(\.maxY).max()
        else { return nil }
        let top = min(bounds.maxY, max(0, bottom + Constants.gridGap))
        let normalBottom = bottomBarContainer.frame.minY - Constants.messageBottomSpacing
        // Use the normal layout so notices, the keyboard, and the gift panel do not change this threshold.
        return normalBottom - top >= Constants.normalCommentHeight ? top : nil
    }

    private func updateInteractionLayout() {
        guard bounds.width > 0, bounds.height > 0 else { return }
        let top = interactionTopBoundary
        let anchor = bottomBarContainer.frame.minY
        var bottom = anchor - Constants.messageBottomSpacing
        if let height = giftPanelHeightAboveSafeArea, giftSendPanel.window != nil, giftSendPanel.window === window {
            let panelTop = giftSendPanel.convert(
                CGPoint(x: 0, y: giftSendPanel.bounds.height - giftSendPanel.safeAreaInsets.bottom - height), to: self
            ).y
            bottom = min(bottom, panelTop - LiveInteractionLayout.noticeSpacing)
        }
        let layout = LiveInteractionLayout(
            topBoundary: top, bottom: bottom, defaultCommentHeight: Constants.normalCommentHeight,
            contentHeight: composerNormalContentHeight ?? messageListView.contentHeight,
            isWelcomeVisible: isAudienceWelcomeVisible, giftNoticeHeight: giftDisplayView?.noticeContentHeight ?? 0,
            safeBottom: bounds.height - safeAreaInsets.bottom)
        messageListView.setVisibleHeight(isCommentComposerPresented ? nil : layout.visibleCommentHeight)
        audienceWelcomeBottomConstraint?.update(offset: bottom - anchor + layout.welcomeBottomOffset)
        giftDisplayView?.updateNoticeLayout(bottom: layout.giftNoticeBottom, topBoundary: top)
        applyWelcomeClip(top, bannerTop: layout.welcomeTop)
        messageListNormalBottomConstraint?.update(offset: bottom - anchor)
        if abs(normalCommentHeight - layout.commentHeight) > 0.5 {
            normalCommentHeight = layout.commentHeight
            messageListNormalHeightConstraint?.update(offset: layout.commentHeight)
            setNeedsLayout()
        }
    }

    private func applyWelcomeClip(_ top: CGFloat?, bannerTop: CGFloat) {
        guard let top else {
            audienceWelcomeView.layer.mask = nil
            return
        }
        let localTop = max(0, top - bannerTop)
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

    private func presentAudienceList() {
        commentComposerView.dismiss()
        giftSendPanel.dismiss()
        audienceListView.show()
    }

    @objc private func handleStageLikeTap(_ recognizer: UITapGestureRecognizer) {
        guard isJoinedChannel, !isCleanScreen else { return }
        let now = ProcessInfo.processInfo.systemUptime
        let isContinuousTap = now - lastStageLikeTapTime <= 0.42
        lastStageLikeTapTime = now
        guard isContinuousTap else { return }

        let rawPoint = recognizer.location(in: likeAnimationView)
        let point = CGPoint(
            x: min(max(rawPoint.x, 28), max(likeAnimationView.bounds.width - 28, 28)),
            y: min(max(rawPoint.y - 8, 62), max(likeAnimationView.bounds.height - 24, 62)))
        let buttonOrigin = likeButtonCenter(in: likeAnimationView)
        likeAnimationView.showStageLike(at: point, auxiliaryOrigin: buttonOrigin)
        likeStore.sendLike()
    }

    @objc private func handleHorizontalPan(_ recognizer: UIPanGestureRecognizer) {
        guard isJoinedChannel else { return }
        let translation = recognizer.translation(in: self)
        switch recognizer.state {
        case .began:
            dismissInteractionOverlays()
            beginCleanScreenTransition()
        case .changed: updateCleanScreenTransition(translationX: translation.x)
        case .ended:
            endCleanScreenTransition(
                translationX: translation.x, velocityX: recognizer.velocity(in: self).x, cancelled: false)
        case .cancelled, .failed: endCleanScreenTransition(translationX: translation.x, velocityX: 0, cancelled: true)
        default: break
        }
    }

    private func beginCleanScreenTransition() {
        lastStageLikeTapTime = 0
        cleanScreenStateAtGestureStart = isCleanScreen
        cleanScreenButton.isHidden = false
        movableContentView.isUserInteractionEnabled = false
    }

    private func updateCleanScreenTransition(translationX: CGFloat) {
        let distance = max(bounds.width, 1)
        let gestureProgress: CGFloat
        if cleanScreenStateAtGestureStart {
            gestureProgress = min(max(-translationX / distance, 0), 1)
            applyCleanScreenProgress(1 - gestureProgress)
        } else {
            gestureProgress = min(max(translationX / distance, 0), 1)
            applyCleanScreenProgress(gestureProgress)
        }
    }

    private func endCleanScreenTransition(translationX: CGFloat, velocityX: CGFloat, cancelled: Bool) {
        guard !cancelled else {
            setCleanScreen(cleanScreenStateAtGestureStart, animated: true)
            return
        }
        let distance = max(bounds.width, 1)
        let gestureProgress = min(abs(translationX) / distance, 1)
        let shouldChange: Bool
        if cleanScreenStateAtGestureStart {
            shouldChange = translationX < 0 && (gestureProgress >= 0.22 || velocityX <= -450)
        } else {
            shouldChange = translationX > 0 && (gestureProgress >= 0.22 || velocityX >= 450)
        }
        setCleanScreen(shouldChange ? !cleanScreenStateAtGestureStart : cleanScreenStateAtGestureStart, animated: true)
    }

    private func applyCleanScreenProgress(_ progress: CGFloat) {
        let clampedProgress = min(max(progress, 0), 1)
        let travelDistance = max(bounds.width, 1)
        movableContentView.transform = CGAffineTransform(translationX: travelDistance * clampedProgress, y: 0)
        movableContentView.alpha = 1 - clampedProgress
        audienceView.setCleanScreenProgress(clampedProgress, travelDistance: travelDistance)
        cleanScreenButton.alpha = clampedProgress
    }

    func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldReceive touch: UITouch) -> Bool {
        guard gestureRecognizer is UITapGestureRecognizer else { return true }
        var touchedView = touch.view
        while let current = touchedView, current !== self {
            if current is UIControl || current === hostInfoView || current === audienceView
                || current === messageListView || current === bottomBarContainer || current === cleanScreenButton
            {
                lastStageLikeTapTime = 0
                return false
            }
            touchedView = current.superview
        }
        guard liveInfo != nil else {
            lastStageLikeTapTime = 0
            return false
        }
        return true
    }

    override func gestureRecognizerShouldBegin(_ gestureRecognizer: UIGestureRecognizer) -> Bool {
        guard let pan = gestureRecognizer as? UIPanGestureRecognizer else { return true }
        guard isJoinedChannel else { return false }
        let velocity = pan.velocity(in: self)
        return abs(velocity.x) > abs(velocity.y) * 1.15
    }

    func gestureRecognizer(
        _ gestureRecognizer: UIGestureRecognizer,
        shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer
    ) -> Bool { true }
}
