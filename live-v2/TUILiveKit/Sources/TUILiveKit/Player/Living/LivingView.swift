import AtomicXCore
import SnapKit
import UIKit

@MainActor
final class LivingView: UIView, UIGestureRecognizerDelegate {
    private enum Constants {
        static let bottomBarBottomInset: CGFloat = 3
        static let bottomBarHeight: CGFloat = 39
        static let messageBottomSpacing: CGFloat = 12
        static let giftMessageSpacing: CGFloat = 4
        static let giftOverlayBaseOffset = bottomBarBottomInset
            + bottomBarHeight
            + messageBottomSpacing
            + giftMessageSpacing
    }

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
    private let giftView = GiftListView()
    private let audienceListView = AudienceListPanel()
    private weak var floatingGiftCombo: GiftComboButton?
    private var giftPlayView: GiftPlayView?

    private let commentStore = BarrageUIStore()
    private let giftStore = GiftUIStore()
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
    private var messageContentHeight: CGFloat = 0
    private var audienceWelcomeBottomConstraint: Constraint?

    override init(frame: CGRect) {
        super.init(frame: frame)
        configureUI()
        bindActions()
        bindStores()
        refresh()
    }

    override func didMoveToWindow() {
        super.didMoveToWindow()
        guard let window else { return }
        [giftView, audienceListView].forEach { panel in
            guard panel.superview !== window else { return }
            panel.removeFromSuperview()
            window.addSubview(panel)
            panel.snp.remakeConstraints { make in make.edges.equalToSuperview() }
        }
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

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
            if isCleanScreen {
                setCleanScreen(false, animated: false)
            }
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

    func activateCoGuest(_ liveInfo: LiveInfo) {
        coGuestView.activate(liveInfo)
    }

    func deactivateCoGuest() {
        coGuestView.deactivate()
    }

    @discardableResult
    func invalidateCoGuestCameraRequests(allowRestore: Bool) -> Bool {
        coGuestView.invalidateCameraRequests(allowRestore: allowRestore)
    }

    func invalidateCoGuestMicrophoneRequests() {
        coGuestView.invalidateMicrophoneRequests()
    }

    func activateRoomFeatures(liveID: String, hostUserID: String) {
        guard activatedRoomLiveID != liveID else { return }
        deactivateRoomFeatures()
        commentStore.activate(liveID: liveID, hostUserID: hostUserID)
        installGiftOverlay(liveID: liveID)
        giftStore.activate(liveID: liveID)
        audienceListView.activate(liveID: liveID)
        likeStore.activate(liveID: liveID)
        likeAnimationView.activate(liveID: liveID) { [weak self] in
            guard let self else { return .zero }
            return self.likeButtonCenter(in: self.likeAnimationView)
        }
        activatedRoomLiveID = liveID
        updateGiftPresentationState()
    }

    func deactivateRoomFeatures() {
        guard activatedRoomLiveID != nil else { return }
        commentStore.deactivate()
        giftStore.deactivate()
        removeGiftOverlay()
        audienceListView.deactivate()
        likeStore.deactivate()
        likeAnimationView.deactivate()
        audienceWelcomeView.reset()
        activatedRoomLiveID = nil
    }

    func prepareForReuse() {
        hostInfoView.prepareForReuse()
        audienceView.unbind()
        messageListView.prepareForReuse()
        messageContentHeight = 0
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
        [hostInfoView, messageListView, audienceWelcomeView, bottomBarContainer, likeAnimationView].forEach(movableContentView.addSubview)
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

        movableContentView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }
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
            messageListNormalBottomConstraint = make.bottom.equalTo(bottomBarContainer.snp.top)
                .offset(-Constants.messageBottomSpacing).constraint
            make.width.equalToSuperview().multipliedBy(BarrageStreamView.defaultWidthRatio)
            messageListNormalHeightConstraint = make.height.equalTo(152).constraint
            messageListComposerBottomConstraint = make.bottom.equalTo(commentComposerView.inputBarLayoutView.snp.top)
                .offset(-6).constraint
            messageListComposerHeightConstraint = make.height.equalTo(132).constraint
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
            make.height.equalTo(28)
            audienceWelcomeBottomConstraint = make.bottom.equalTo(bottomBarContainer.snp.top).offset(-18).constraint
        }
        likeAnimationView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }
        cleanScreenButton.snp.makeConstraints { make in
            make.width.height.equalTo(56)
            make.trailing.equalTo(layoutMarginsGuide.snp.trailing).offset(-18)
            make.bottom.equalTo(layoutMarginsGuide.snp.bottom).offset(-10)
        }

        cleanScreenButton.alpha = 0
        cleanScreenButton.isHidden = true
    }

    private func configureBottomBar() {
        configureBarButton(
            commentButton,
            accessibilityKey: "tuilivekit.player.comment"
        )
        commentButton.setTitle(LiveKitResources.localizedString("tuilivekit.player.comment_placeholder"), for: .normal)
        commentButton.setTitleColor(UIColor.white.withAlphaComponent(0.50), for: .normal)
        commentButton.titleLabel?.font = .systemFont(ofSize: 12.5, weight: .regular)
        commentButton.contentHorizontalAlignment = .left
        commentButton.contentEdgeInsets = UIEdgeInsets(top: 0, left: 15, bottom: 0, right: 15)
        commentButton.layer.borderColor = UIColor.white.withAlphaComponent(0.06).cgColor
        commentButton.layer.shadowOpacity = 0.20

        configureBarButton(
            giftButton,
            imageName: "livekit_player_gift",
            imageSize: CGSize(width: 39, height: 39),
            accessibilityKey: "tuilivekit.player.gift",
            hasBackground: false
        )
        configureBarButton(
            likeButton,
            imageName: "livekit_player_like",
            imageSize: CGSize(width: 39, height: 39),
            accessibilityKey: "tuilivekit.player.like",
            hasBackground: false
        )

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
        _ button: UIButton,
        imageName: String? = nil,
        imageSize: CGSize? = nil,
        accessibilityKey: String,
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
            self,
            action: #selector(endBarButtonPress(_:)),
            for: [.touchUpInside, .touchUpOutside, .touchCancel, .touchDragExit]
        )
    }

    private func resizedImage(named name: String, size: CGSize) -> UIImage? {
        guard let image = LiveKitResources.image(named: name) else { return nil }
        return UIGraphicsImageRenderer(size: size).image { _ in
            image.draw(in: CGRect(origin: .zero, size: size))
        }.withRenderingMode(.alwaysOriginal)
    }

    private func configureCleanScreenButton() {
        cleanScreenButton.setImage(LiveKitResources.image(named: "livekit_ic_controls_restore"), for: .normal)
        cleanScreenButton.imageView?.contentMode = .scaleAspectFit
        cleanScreenButton.adjustsImageWhenHighlighted = false
        cleanScreenButton.accessibilityLabel = LiveKitResources.localizedString(
            "tuilivekit.player.restore_controls_accessibility"
        )
    }

    private func likeButtonCenter(in view: UIView) -> CGPoint {
        likeButton.convert(
            CGPoint(x: likeButton.bounds.midX, y: likeButton.bounds.midY),
            to: view
        )
    }

    @objc private func beginBarButtonPress(_ sender: UIButton) {
        let scale: CGFloat = sender === commentButton ? 0.99 : 0.92
        UIView.animate(withDuration: 0.12) {
            sender.transform = CGAffineTransform(scaleX: scale, y: scale)
        }
    }

    @objc private func endBarButtonPress(_ sender: UIButton) {
        UIView.animate(withDuration: 0.12) {
            sender.transform = .identity
        }
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
            self?.giftPlayView?.updateAudienceWelcomeVisible(isVisible)
        }
        hostInfoView.onError = { [weak self] message in
            guard let self, self.isJoinedChannel else { return }
            self.onToast?(message)
        }

        commentButton.addAction(UIAction { [weak self] _ in self?.presentCommentComposer() }, for: .touchUpInside)
        giftButton.addAction(UIAction { [weak self] _ in self?.presentGiftView() }, for: .touchUpInside)
        likeButton.addAction(UIAction { [weak self] _ in
            guard let self else { return }
            let origin = self.likeButtonCenter(in: self.likeAnimationView)
            self.likeAnimationView.showButtonLike(from: origin)
            self.likeStore.sendLike()
        }, for: .touchUpInside)

        cleanScreenButton.addAction(UIAction { [weak self] _ in
            self?.setCleanScreen(false, animated: true)
        }, for: .touchUpInside)

        commentComposerView.onSend = { [weak self] text in
            self?.sendComment(text)
        }
        commentComposerView.onPresentationChanged = { [weak self] isPresented in
            self?.setCommentComposerPresented(isPresented)
        }
        giftView.onSendGift = { [weak self] gift, count in
            self?.sendGift(gift, count: count)
        }
        giftView.onAdvancedComboStart = { [weak self] gift in
            self?.beginFloatingGiftCombo(with: gift)
        }
        messageListView.onVisibleContentHeightChanged = { [weak self] height in
            guard let self else { return }
            self.messageContentHeight = height
            self.audienceWelcomeBottomConstraint?.update(offset: -(height + 18))
            self.giftPlayView?.updateMessageContentHeight(height)
            UIView.animate(
                withDuration: 0.18,
                delay: 0,
                options: [.curveEaseOut, .beginFromCurrentState, .allowUserInteraction]
            ) {
                self.layoutIfNeeded()
            }
        }
    }

    private func bindStores() {
        commentStore.onSendError = { [weak self] message in
            guard let self, self.isJoinedChannel, self.window != nil,
                  self.activatedRoomLiveID == self.liveInfo?.liveID else { return }
            self.onToast?(message)
        }
        commentStore.onStateChanged = { [weak self] state in
            guard let self, self.liveInfo?.liveID == state.liveID else { return }
            self.messageListView.bind(state.comments.map {
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
        giftStore.onGiftCommentSettled = { [weak self] gift in
            self?.commentStore.appendGiftComment(gift)
        }
        giftStore.onStateChanged = { [weak self] state in
            guard let self else { return }
            self.giftView.bind(
                categories: state.categories,
                isLoading: state.isLoading
            )
        }
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
                withDuration: 0.3,
                delay: 0,
                options: [.beginFromCurrentState, .curveEaseOut, .allowUserInteraction],
                animations: changes,
                completion: completion
            )
        } else {
            changes()
            completion(true)
        }
    }

    func dismissInteractionOverlays(resetCommentDraft: Bool = false) {
        if resetCommentDraft {
            commentComposerView.reset()
        } else {
            commentComposerView.dismiss()
        }
        giftView.dismiss()
        audienceListView.dismiss()
    }

    private func setCommentComposerPresented(_ isPresented: Bool, animated: Bool = true) {
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

        let changes: () -> Void = { [weak self] in
            self?.layoutIfNeeded()
        }
        guard animated else {
            changes()
            return
        }
        UIView.animate(
            withDuration: 0.25,
            delay: 0,
            options: [.curveEaseInOut, .beginFromCurrentState, .allowUserInteraction],
            animations: changes
        )
    }

    private func presentCommentComposer() {
        if isSelfMessageBanned() {
            LiveToast.show(
                BarrageUIStore.sendErrorMessage(code: 10017)
            )
            return
        }
        audienceListView.dismiss()
        giftView.dismiss()
        commentComposerView.show()
    }

    private func sendComment(_ text: String) {
        commentStore.sendComment(text)
    }

    private func isSelfMessageBanned() -> Bool {
        commentStore.isSelfMessageBanned()
    }

    private func installGiftOverlay(liveID: String) {
        removeGiftOverlay()
        let giftPlayView = GiftPlayView(liveID: liveID)
        giftPlayView.translatesAutoresizingMaskIntoConstraints = false
        insertSubview(giftPlayView, belowSubview: commentComposerView)
        NSLayoutConstraint.activate([
            giftPlayView.leadingAnchor.constraint(equalTo: leadingAnchor),
            giftPlayView.trailingAnchor.constraint(equalTo: trailingAnchor),
            giftPlayView.topAnchor.constraint(equalTo: topAnchor),
            giftPlayView.bottomAnchor.constraint(equalTo: bottomAnchor),
        ])
        giftPlayView.updateMessageContentHeight(messageContentHeight)
        giftPlayView.updateToolbarAndMessageOffset(Constants.giftOverlayBaseOffset)
        self.giftPlayView = giftPlayView
    }

    private func removeGiftOverlay() {
        giftPlayView?.removeFromSuperview()
        giftPlayView = nil
    }

    private func updateGiftPresentationState() {
        let isEnabled = activatedRoomLiveID != nil && !isCleanScreen
        giftStore.setGiftCommentCollectionEnabled(isEnabled)
        guard let giftPlayView else { return }
        giftPlayView.setSuspended(!isEnabled)
        if !isEnabled {
            giftPlayView.resetEntries()
        }
        giftPlayView.isHidden = !isEnabled
    }

    private func presentGiftView() {
        audienceListView.dismiss()
        commentComposerView.dismiss()
        giftView.present()
    }

    private func updateGiftPanelPresentation(
        isPresented: Bool,
        heightAboveSafeArea: CGFloat
    ) {
        guard let giftPlayView else { return }
        giftPlayView.updateGiftPanelHeightAboveSafeArea(
            isPresented ? heightAboveSafeArea + Constants.giftMessageSpacing : nil
        )
        if isPresented {
            bringSubviewToFront(giftPlayView)
        } else {
            insertSubview(giftPlayView, belowSubview: commentComposerView)
        }
    }

    private func sendGift(_ gift: GiftUIStore.GiftItem, count: Int) {
        let normalizedCount = UInt(max(1, count))
        let profile = LoginStore.shared.state.value.loginUserInfo
        let localGift = profile.map {
            LiveGiftEvent(
                giftID: gift.id,
                name: gift.name,
                iconURL: gift.iconURL?.absoluteString ?? "",
                resourceURL: gift.resourceURL?.absoluteString ?? "",
                coins: UInt(max(0, gift.coins)),
                count: normalizedCount,
                senderID: $0.userID,
                senderName: $0.nickname ?? "",
                senderAvatarURL: $0.avatarURL ?? ""
            )
        }
        let reservationID = localGift.flatMap { giftPlayView?.reserveLocalGift($0) }
        giftStore.sendGift(id: gift.id, count: count) { [weak giftPlayView] isSuccess in
            guard let reservationID else { return }
            if isSuccess {
                giftPlayView?.confirmLocalGift(id: reservationID)
            } else {
                giftPlayView?.cancelLocalGift(id: reservationID)
            }
        }
    }

    private func beginFloatingGiftCombo(with gift: GiftUIStore.GiftItem) {
        floatingGiftCombo?.end()
        floatingGiftCombo?.removeFromSuperview()

        let combo = GiftComboButton()
        combo.onSendOnce = { [weak self] in
            self?.sendGift(gift, count: 1)
        }
        combo.onExpired = { [weak combo] in
            combo?.removeFromSuperview()
        }
        addSubview(combo)
        combo.snp.makeConstraints { make in
            make.trailing.equalTo(safeAreaLayoutGuide.snp.trailing).offset(-16)
            make.bottom.equalTo(bottomBarContainer.snp.top).offset(-30)
            make.width.equalTo(72)
            make.height.equalTo(96)
        }
        floatingGiftCombo = combo
        combo.begin(with: gift)
    }

    private func presentAudienceList() {
        commentComposerView.dismiss()
        giftView.dismiss()
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
            y: min(max(rawPoint.y - 8, 62), max(likeAnimationView.bounds.height - 24, 62))
        )
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
        case .changed:
            updateCleanScreenTransition(translationX: translation.x)
        case .ended:
            endCleanScreenTransition(
                translationX: translation.x,
                velocityX: recognizer.velocity(in: self).x,
                cancelled: false
            )
        case .cancelled, .failed:
            endCleanScreenTransition(
                translationX: translation.x,
                velocityX: 0,
                cancelled: true
            )
        default:
            break
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
        movableContentView.transform = CGAffineTransform(
            translationX: travelDistance * clampedProgress,
            y: 0
        )
        movableContentView.alpha = 1 - clampedProgress
        audienceView.setCleanScreenProgress(clampedProgress, travelDistance: travelDistance)
        cleanScreenButton.alpha = clampedProgress
    }

    func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldReceive touch: UITouch) -> Bool {
        guard gestureRecognizer is UITapGestureRecognizer else { return true }
        var touchedView = touch.view
        while let current = touchedView, current !== self {
            if current is UIControl ||
                current === hostInfoView ||
                current === audienceView ||
                current === messageListView ||
                current === bottomBarContainer ||
                current === cleanScreenButton {
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
    ) -> Bool {
        true
    }
}
