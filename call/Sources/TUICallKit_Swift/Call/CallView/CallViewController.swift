import AtomicXCore
import Combine
import SnapKit
import UIKit

final class CallViewController: UIViewController {

    private let callView = CallView()
    private var previousIdleTimerDisabled: Bool?

    override func loadView() {
        view = callView
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        previousIdleTimerDisabled = UIApplication.shared.isIdleTimerDisabled
        UIApplication.shared.isIdleTimerDisabled = true
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        if let previousIdleTimerDisabled {
            UIApplication.shared.isIdleTimerDisabled = previousIdleTimerDisabled
            self.previousIdleTimerDisabled = nil
        }
    }

    override var preferredStatusBarStyle: UIStatusBarStyle {
        .lightContent
    }

    override var supportedInterfaceOrientations: UIInterfaceOrientationMask {
        switch CallKitConfig.shared.screenOrientation {
        case 1: return .landscape
        case 2: return .all
        default: return .portrait
        }
    }

    override var shouldAutorotate: Bool {
        CallKitConfig.shared.screenOrientation == 2
    }
}

final class CallView: UIView {

    private let gradientLayer = CallKitTheme.makeAudioGradient()
    private let backdropImageView = UIImageView()
    private let callCoreView = CallCoreView(frame: .zero)
    private let avatarImageView = UIImageView()
    private let nameLabel = UILabel()
    private let statusLabel = UILabel()
    private let avatarRingView = UIView()
    private var avatarCenterYConstraint: Constraint?
    private var avatarSizeConstraint: Constraint?
    private var nameCenterYConstraint: Constraint?
    private let topBar = TopBarView()
    private let controlPanel = CallControlPanel()
    private let routeBubble = AudioRouteBubble()
    private let moreBubble = MoreMenuBubble()
    private let immersiveOverlay = UIControl()
    private let bubbleDismissOverlay = UIControl()
    private let waitingParticipantsView = WaitingParticipantsView()
    private let previewShadeView = UIView()
    private let previewShadeGradient = CAGradientLayer()
    private let videoCallingOverlay = VideoCallingOverlay()
    private let transcriptView = TranscriptView()
    private let tapHintPill = TapHintPill()
    private var cancellables = Set<AnyCancellable>()
    private var hasConnected = false
    private var didOpenCameraPreview = false
    private var isImmersive = false
    private var openSheetCount = 0
    private var lastTranscriptionEnabled = false
    private var barBackgroundLatched = false
    private var lastParticipantStatuses: [String: CallParticipantStatus] = [:]
    private var backdropToken = 0
    private var didEnterMultiMode = false
    private var wasIncomingRinging = false

    private var isIncomingRinging: Bool {
        let state = CallStore.shared.state.value
        let selfID = LoginStore.shared.state.value.loginUserInfo?.userID ?? ""
        return state.selfInfo.status == .waiting
            && !state.activeCall.inviterId.isEmpty
            && state.activeCall.inviterId != selfID
    }

    private var isVideo: Bool { CallStore.shared.state.value.isVideoCall }
    private var isMulti: Bool { CallStore.shared.state.value.isMultiCall }

    private static var defaultAvatar: UIImage? {
        CallKitResources.image(named: "callkit_default_avatar")
    }

    private static func makeWaitingDotsImage() -> UIImage? {
        let dot: CGFloat = 8
        let gap: CGFloat = 7
        let size = CGSize(width: dot * 3 + gap * 2, height: dot)
        let period: TimeInterval = 1.2
        let delays: [TimeInterval] = [0, 0.2, 0.4]
        let reduceMotion = UIAccessibility.isReduceMotionEnabled
        var frames: [UIImage] = []
        for frame in 0..<12 {
            let t = TimeInterval(frame) * 0.1
            let image = UIGraphicsImageRenderer(size: size).image { ctx in
                ctx.cgContext.setShadow(offset: CGSize(width: 0, height: 1),
                                        blur: 4,
                                        color: UIColor.black.withAlphaComponent(0.3).cgColor)
                for (index, delay) in delays.enumerated() {
                    let phase = max(0, (t - delay).truncatingRemainder(dividingBy: period) / period)
                    let p = phase < 0.35 ? phase / 0.35 : (phase < 0.7 ? 1 - (phase - 0.35) / 0.35 : 0)
                    let alpha: CGFloat = reduceMotion ? 0.9 : 0.28 + 0.72 * p
                    let diameter = dot * (reduceMotion ? 1 : 0.8 + 0.2 * p)
                    let centerX = dot / 2 + CGFloat(index) * (dot + gap)
                    let rect = CGRect(x: centerX - diameter / 2,
                                      y: (size.height - diameter) / 2,
                                      width: diameter,
                                      height: diameter)
                    UIColor.white.withAlphaComponent(0.92 * alpha).setFill()
                    ctx.cgContext.fillEllipse(in: rect)
                }
            }
            frames.append(image)
        }
        return UIImage.animatedImage(with: frames, duration: period)
    }

    override init(frame: CGRect) {
        super.init(frame: frame)
        setupCoreViewStaticResources()
        setupViews()
        bindState()
        applyBackdrop(Self.defaultAvatar)
        loadPeerProfile()
        if isIncomingRinging {
            enterRingingMode()
        } else if isMulti {
            enterMultiMode()
        } else if isVideo {
            enterVideoCallingMode()
        }
    }

    deinit {
        if didOpenCameraPreview {
            DeviceStore.shared.closeLocalCamera()
        }
    }

    private func setupCoreViewStaticResources() {
        CallCoreView.defaultAvatarImage = Self.defaultAvatar
        CallCoreView.waitingAnimationImage = Self.makeWaitingDotsImage()
        let badges: [VolumeLevel: String] = [.mute: "micoff", .low: "volume_low", .medium: "volume_medium",
                                             .high: "volume_high", .peak: "volume_peak"]
        callCoreView.setVolumeLevelIcons(icons: badges.compactMapValues { CallKitResources.badgeIconPath("callkit_badge_\($0).png") })
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        gradientLayer.frame = bounds
        previewShadeGradient.frame = previewShadeView.bounds
        avatarRingView.layer.cornerRadius = avatarRingView.bounds.width / 2
        applyTranscriptConstraints()
        if isIncomingRinging, !waitingParticipantsView.isHidden {
            syncAvatarToRingingSlot()
        }
    }

    private func gridHit(at point: CGPoint) -> (grid: UICollectionView, point: CGPoint)? {
        guard let grid = findGridCollectionView(in: callCoreView) else { return nil }
        let gridPoint = grid.convert(point, from: self)
        return grid.indexPathForItem(at: gridPoint) == nil ? nil : (grid, gridPoint)
    }

    private func syncAvatarToRingingSlot() {
        let slot = waitingParticipantsView.avatarSlotCenter(in: self)
        let offsetY = slot.y - bounds.midY
        avatarCenterYConstraint?.update(offset: offsetY)
        avatarSizeConstraint?.update(offset: 96)
        nameCenterYConstraint?.update(offset: offsetY + 72)
    }

    private func startRingingPulse() {
        guard !UIAccessibility.isReduceMotionEnabled else { return }
        let pulse = CABasicAnimation(keyPath: "transform.scale")
        pulse.fromValue = 1
        pulse.toValue = 1.05
        pulse.duration = 0.9
        pulse.autoreverses = true
        pulse.repeatCount = .infinity
        pulse.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
        avatarImageView.layer.add(pulse, forKey: "incoming.pulse")
    }

    private func setupViews() {
        layer.insertSublayer(gradientLayer, at: 0)

        backdropImageView.contentMode = .scaleAspectFill
        backdropImageView.clipsToBounds = true

        nameLabel.font = .systemFont(ofSize: 20, weight: .semibold)
        nameLabel.textColor = .white
        nameLabel.textAlignment = .center
        nameLabel.lineBreakMode = .byTruncatingTail

        avatarImageView.contentMode = .scaleAspectFill
        avatarImageView.clipsToBounds = true
        avatarImageView.layer.cornerRadius = 16
        avatarImageView.image = Self.defaultAvatar

        statusLabel.font = .systemFont(ofSize: 12)
        statusLabel.textColor = CallKitTheme.audioStateText
        statusLabel.textAlignment = .center
        statusLabel.text = CallKitResources.text("callkit.call.calling")

        let immersiveTap = UITapGestureRecognizer(target: self, action: #selector(handleImmersiveTap))
        immersiveTap.delegate = self
        immersiveTap.cancelsTouchesInView = false
        addGestureRecognizer(immersiveTap)

        avatarRingView.backgroundColor = UIColor.white.withAlphaComponent(0.04)
        avatarRingView.alpha = 0

        [backdropImageView, callCoreView, avatarRingView, avatarImageView, nameLabel, statusLabel, immersiveOverlay, transcriptView, tapHintPill, topBar, controlPanel, bubbleDismissOverlay, routeBubble, moreBubble].forEach { addSubview($0) }
        [callCoreView, immersiveOverlay, bubbleDismissOverlay, routeBubble, moreBubble, transcriptView].forEach { $0.isHidden = true }
        [backdropImageView, callCoreView, immersiveOverlay, bubbleDismissOverlay].forEach { $0.snp.makeConstraints { $0.edges.equalToSuperview() } }

        immersiveOverlay.isUserInteractionEnabled = false
        bubbleDismissOverlay.addAction(UIAction { [weak self] _ in self?.dismissBubbles() }, for: .touchUpInside)

        controlPanel.onSpeakerBubbleToggle = { [weak self] in
            guard let self else { return }
            self.toggleBubble(self.routeBubble, anchor: self.controlPanel.speakerAnchor, width: BubbleWidth.route)
        }
        controlPanel.onMoreBubbleToggle = { [weak self] in
            guard let self else { return }
            self.toggleBubble(self.moreBubble, anchor: self.controlPanel.moreAnchor, width: BubbleWidth.more)
        }
        controlPanel.onExpand = { [weak self] in self?.setImmersive(false) }
        transcriptView.onPickSettings = { [weak self] in self?.presentTranscriptionSettings() }
        transcriptView.onTap = { [weak self] in self?.handleTranscriptTap() }
        applyTranscriptConstraints()
        lastTranscriptionEnabled = CallKitConfig.shared.enableAITranscriber
        tapHintPill.snp.makeConstraints { make in
            make.centerX.equalToSuperview()
            make.top.equalTo(safeAreaLayoutGuide.snp.top).offset(392)
        }
        moreBubble.onSelect = { [weak self] item in
            self?.dismissBubbles()
            self?.presentSheet(item == .beauty ? BeautyPanel() as UIView : BackgroundPanel())
        }
        topBar.onInviteTap = { [weak self] in self?.presentInviteSheet() }
        routeBubble.onSelect = { [weak self] device in
            DeviceStore.shared.setCurrentSpeaker(device)
            self?.dismissBubbles()
        }

        avatarImageView.snp.makeConstraints { make in
            make.centerX.equalToSuperview()
            avatarCenterYConstraint = make.centerY.equalToSuperview().offset(-100).constraint
            avatarSizeConstraint = make.size.equalTo(100).constraint
        }
        avatarRingView.snp.makeConstraints { make in
            make.center.equalTo(avatarImageView)
            make.size.equalTo(avatarImageView).offset(20)
        }
        nameLabel.snp.makeConstraints { make in
            make.centerX.equalToSuperview()
            nameCenterYConstraint = make.centerY.equalToSuperview().offset(-26).constraint
            make.width.lessThanOrEqualToSuperview().offset(-48)
        }
        statusLabel.snp.makeConstraints { make in
            make.centerX.equalToSuperview()
            make.top.equalTo(nameLabel.snp.bottom).offset(12)
        }
        topBar.snp.makeConstraints { make in
            make.top.equalTo(safeAreaLayoutGuide.snp.top)
            make.leading.trailing.equalToSuperview()
            make.height.equalTo(CallKitTheme.topBarHeight)
        }
        applyControlPanelConstraints(barMode: false)
    }

    private func toggleBubble(_ bubble: CallKitBubble, anchor: UIView?, width: CGFloat) {
        let shouldShow = bubble.isHidden
        dismissBubbles()
        guard shouldShow, let anchor else { return }
        layoutIfNeeded()
        let anchorFrame = anchor.convert(anchor.bounds, to: self)
        if bubble === routeBubble {
            reloadRouteBubble()
        }
        bubbleDismissOverlay.isHidden = false
        bubble.isHidden = false
        let bubbleX = min(max(anchorFrame.midX - width / 2, 12), bounds.width - width - 12)
        bubble.snp.remakeConstraints { make in
            make.width.equalTo(width)
            make.leading.equalToSuperview().offset(bubbleX)
            make.bottom.equalToSuperview().offset(-(bounds.height - anchorFrame.minY + 12))
        }
        bubble.setArrowCenterX(anchorFrame.midX - bubbleX)
    }

    private func reloadRouteBubble() {
        let state = DeviceStore.shared.state.value
        routeBubble.reload(devices: state.speakerList, current: state.currentSpeaker)
    }

    private var lastTranscriptConstraintKey = ""

    private func gridContentBottom() -> CGFloat {
        guard didEnterMultiMode, let grid = findGridCollectionView(in: callCoreView),
              let attrs = grid.collectionViewLayout.layoutAttributesForElements(in: grid.bounds),
              !attrs.isEmpty else { return 0 }
        let union = attrs.reduce(CGRect.null) { $0.union($1.frame) }
        return grid.convert(union, to: self).maxY
    }

    private func applyTranscriptConstraints() {
        let defaultTop: CGFloat = didEnterMultiMode ? 398 : 399
        let topOffset = didEnterMultiMode
            ? max(defaultTop, gridContentBottom() + 12 - safeAreaInsets.top)
            : defaultTop
        let bottomInset: CGFloat? = isImmersive ? (didEnterMultiMode ? 110 : 34) : (didEnterMultiMode ? nil : 220)
        let key = "\(topOffset)|\(bottomInset ?? -1)"
        guard key != lastTranscriptConstraintKey else { return }
        lastTranscriptConstraintKey = key
        transcriptView.snp.remakeConstraints { make in
            make.leading.trailing.equalToSuperview().inset(24)
            transcriptView.remakeHeightConstraint(in: make)
            make.top.equalTo(safeAreaLayoutGuide.snp.top).offset(topOffset)
            if let bottomInset {
                make.bottom.lessThanOrEqualToSuperview().offset(-bottomInset)
            }
        }
    }

    private func scheduleTranscriptGeometryRefresh() {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) { [weak self] in
            guard let self else { return }
            self.applyTranscriptConstraints()
            UIView.animate(withDuration: 0.15) { self.layoutIfNeeded() }
        }
    }

    private func refreshTranscriptVisibility() {
        transcriptView.isHidden = !CallKitConfig.shared.enableAITranscriber || !hasConnected
    }

    private func presentTranscriptionSettings() {
        let content = TranscriptionSettingsSheet()
        content.onPickLanguage = { [weak self] in self?.presentLanguagePicker() }
        let sheet = presentSheet(content, style: .generic)
        content.onClose = { [weak sheet] in sheet?.dismiss() }
    }

    private func presentLanguagePicker() {
        let picker = LanguagePickerSheet()
        let sheet = presentSheet(picker, style: .generic)
        picker.onFinish = { [weak sheet] in sheet?.dismiss() }
    }

    @discardableResult
    private func presentSheet(_ content: UIView, style: CallKitBottomSheet.Style = .callPanel) -> CallKitBottomSheet {
        let sheet = CallKitBottomSheet(style: style)
        sheet.onDismiss = { [weak self] in self?.openSheetCount -= 1 }
        openSheetCount += 1
        sheet.show(in: self, content: content)
        return sheet
    }

    private func dismissBubbles() {
        routeBubble.isHidden = true
        moreBubble.isHidden = true
        bubbleDismissOverlay.isHidden = true
    }

    private func presentInviteSheet() {
        let content = InviteMemberSheet()
        let sheet = presentSheet(content, style: .generic)
        content.onClose = { [weak sheet] in sheet?.dismiss() }
        content.onInvite = { [weak self, weak sheet] picks in
            sheet?.dismiss()
            if !picks.isEmpty { self?.invite(picks: picks) }
        }
    }

    private func invite(picks: [InviteMemberSheet.Pick]) {
        CallStore.shared.invite(participantIds: picks.map(\.userID), params: nil) { result in
            DispatchQueue.main.async {
                switch result {
                case .success:
                    let names = picks.map(\.displayName).joined(separator: "、")
                    CallKitToast.show(String(format: CallKitResources.text("callkit.invite.sent"), names))
                case .failure:
                    CallKitToast.show(CallKitResources.text("callkit.invite.failed"))
                }
            }
        }
    }

    private func enterRingingMode() {
        wasIncomingRinging = true
        topBar.isHidden = true
        controlPanel.isHidden = true
        statusLabel.isHidden = true
        startRingingPulse()

        if isVideo {
            callCoreView.setLayoutTemplate(.float)
            callCoreView.isHidden = false
            previewShadeGradient.colors = [
                UIColor.black.withAlphaComponent(0.42).cgColor,
                UIColor.black.withAlphaComponent(0.18).cgColor,
                UIColor.black.withAlphaComponent(0.80).cgColor,
            ]
            previewShadeGradient.locations = [0, 0.42, 1]
            previewShadeView.layer.insertSublayer(previewShadeGradient, at: 0)
            insertSubview(previewShadeView, aboveSubview: callCoreView)
            previewShadeView.snp.makeConstraints { $0.edges.equalToSuperview() }
            DeviceStore.shared.openLocalCamera(isFront: true) { result in
                guard case .failure(let error) = result else { return }
                CallKitLog.error("ringing preview openLocalCamera failed: code=\(error.code) message=\(error.message)")
            }
            didOpenCameraPreview = true
        }

        waitingParticipantsView.reload()
        waitingParticipantsView.onAccept = { CallLauncher.shared.acceptIncoming() }
        waitingParticipantsView.onReject = { CallLauncher.shared.rejectIncoming() }
        addSubview(waitingParticipantsView)
        waitingParticipantsView.snp.makeConstraints { $0.edges.equalToSuperview() }
    }

    private func enterVideoCallingMode() {
        [avatarImageView, nameLabel, statusLabel, backdropImageView].forEach { $0.isHidden = true }
        callCoreView.isHidden = false
        insertSubview(videoCallingOverlay, belowSubview: topBar)
        videoCallingOverlay.snp.makeConstraints { $0.edges.equalToSuperview() }
        videoCallingOverlay.reload()
    }

    private func enterMultiMode() {
        didEnterMultiMode = true
        applyBackdrop(Self.defaultAvatar, radius: 30)
        backdropImageView.isHidden = false
        [avatarImageView, nameLabel, statusLabel].forEach { $0.isHidden = true }
        callCoreView.isHidden = false
        callCoreView.setLayoutTemplate(.grid)
        applyTranscriptConstraints()
        refreshTranscriptLayoutMode()
        loadAllParticipantAvatars()
    }

    private func refreshTranscriptLayoutMode() {
        guard didEnterMultiMode else {
            transcriptView.layoutMode = .single
            return
        }
        let count = CallStore.shared.state.value.allParticipants.count
        let columns = count <= 4 ? 2 : 3
        let rows = Int(ceil(Double(count) / Double(columns)))
        transcriptView.layoutMode = .multi(rows: rows)
    }

    private func diffParticipantChanges() {
        let state = CallStore.shared.state.value
        let selfID = state.selfInfo.id
        let current = Dictionary(uniqueKeysWithValues: state.allParticipants
            .filter { $0.id != selfID }
            .map { ($0.id, $0.status) })
        defer { lastParticipantStatuses = current }

        guard !lastParticipantStatuses.isEmpty, !state.activeCall.callId.isEmpty, isMulti || didEnterMultiMode else { return }

        for (id, status) in current where status == .accept && lastParticipantStatuses[id] != .accept {
            showMemberToast("callkit.call.member_joined", userID: id)
        }
        for (id, previous) in lastParticipantStatuses where current[id] == nil && previous == .accept {
            showMemberToast("callkit.call.member_left", userID: id)
        }
    }

    private func showMemberToast(_ key: String, userID: String) {
        CallKitContactLoader.load(userIDs: [userID]) { _, nickname, _ in
            let name = nickname.flatMap { $0.isEmpty ? nil : $0 } ?? userID
            CallKitToast.show(String(format: CallKitResources.text(key), name))
        }
    }

    private func loadAllParticipantAvatars() {
        let state = CallStore.shared.state.value
        var ids = state.allParticipants.map(\.id)
        for id in state.activeCall.inviteeIds + [state.activeCall.inviterId, state.selfInfo.id] where !id.isEmpty && !ids.contains(id) {
            ids.append(id)
        }
        guard !ids.isEmpty else { return }
        let apply: ([String: String]) -> Void = { [weak self] avatars in
            guard let self else { return }
            self.callCoreView.setParticipantAvatars(avatars: avatars)
            guard self.didEnterMultiMode,
                  let path = avatars[CallStore.shared.state.value.selfInfo.id],
                  let image = UIImage(contentsOfFile: path) else { return }
            self.applyBackdrop(image, radius: 30)
        }
        ContactStore.shared.getContactInfo(userIDList: ids, completion: ContactInfoHandler(success: { infos in
            var results: [String: String] = [:]
            let group = DispatchGroup()
            for info in infos {
                group.enter()
                CallKitAvatarLoader.file(from: info.avatarURL, name: info.userID) { path in
                    results[info.userID] = path
                    group.leave()
                }
            }
            group.notify(queue: .main) { apply(results) }
        }, failure: { code, desc in
            CallKitLog.error("multi avatar getContactInfo failed: code=\(code) desc=\(desc)")
            DispatchQueue.main.async { apply([:]) }
        }))
    }

    @objc private func handleImmersiveTap() {
        setImmersive(!isImmersive)
    }

    private func handleTranscriptTap() {
        guard isImmersive || isVideo || isMulti, hasConnected, openSheetCount == 0,
              routeBubble.isHidden, moreBubble.isHidden else { return }
        setImmersive(!isImmersive)
    }

    private func setImmersive(_ immersive: Bool) {
        isImmersive = immersive
        dismissBubbles()
        topBar.setImmersive(immersive)
        immersiveOverlay.isHidden = !immersive
        transcriptView.isImmersiveExpanded = immersive
        applyTranscriptConstraints()
        if isMulti {
            if immersive { barBackgroundLatched = true }
            controlPanel.isHidden = false
            controlPanel.setCollapsed(immersive)
            controlPanel.setBarBackground(barBackgroundLatched)
            applyControlPanelConstraints(barMode: barBackgroundLatched)
        } else {
            controlPanel.isHidden = immersive
        }
    }

    private func applyControlPanelConstraints(barMode: Bool) {
        controlPanel.snp.remakeConstraints { make in
            make.leading.trailing.equalToSuperview().inset(barMode ? 0 : 16)
            make.bottom.equalToSuperview()
        }
    }

    private func bindState() {
        CallKitConfig.shared.transcriptionChanged.sinkOnMain(in: &cancellables) { [weak self] in
            guard let self else { return }
            self.refreshTranscriptVisibility()
            let enabled = CallKitConfig.shared.enableAITranscriber
            if enabled, !self.lastTranscriptionEnabled, self.hasConnected, self.isVideo {
                self.tapHintPill.showTemporarily()
            }
            self.lastTranscriptionEnabled = enabled
        }
        DeviceStore.shared.state
            .subscribe(StatePublisherSelector { "\($0.currentSpeaker.deviceId)|\($0.speakerList.map { $0.deviceId }.joined(separator: ","))" })
            .sinkOnMain(in: &cancellables) { [weak self] _ in
                guard let self, !self.routeBubble.isHidden else { return }
                self.reloadRouteBubble()
            }
        CallStore.shared.state
            .subscribe(StatePublisherSelector { $0.allParticipants.map { "\($0.id):\($0.status.rawValue)" }.joined(separator: ",") })
            .sinkOnMain(in: &cancellables) { [weak self] _ in self?.diffParticipantChanges() }
        CallStore.shared.state
            .subscribe(StatePublisherSelector { $0.allParticipants.count })
            .sinkOnMain(in: &cancellables) { [weak self] _ in
                guard let self else { return }
                if self.isIncomingRinging {
                    self.waitingParticipantsView.reload()
                }
                if !self.didEnterMultiMode, !self.isIncomingRinging, self.isMulti {
                    self.enterMultiMode()
                }
                self.refreshTranscriptLayoutMode()
            }
        CallStore.shared.state
            .subscribe(StatePublisherSelector { $0.activeCall.inviteeIds })
            .sinkOnMain(in: &cancellables) { [weak self] _ in
                guard let self, self.isIncomingRinging else { return }
                self.waitingParticipantsView.reload()
            }
        CallStore.shared.state
            .subscribe(StatePublisherSelector { $0.selfInfo.status })
            .sinkOnMain(in: &cancellables) { [weak self] status in
                guard let self, status == .accept, !self.hasConnected else { return }
                self.hasConnected = true
                self.refreshTranscriptVisibility()
                self.topBar.isHidden = false
                self.controlPanel.isHidden = false
                if self.isMulti {
                    self.enterMultiMode()
                }
                self.topBar.handleConnected()
                self.transitionToConnected()
                if self.isVideo {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 2) { [weak self] in
                        self?.tapHintPill.showTemporarily()
                    }
                }
            }
        DeviceStore.shared.state
            .subscribe(StatePublisherSelector { $0.cameraStatus })
            .sinkOnMain(in: &cancellables) { [weak self] status in
                guard let self, self.isVideo else { return }
                self.videoCallingOverlay.setCameraOff(status != .on)
            }
    }

    private func transitionToConnected() {
        let isAudioOneToOne = !isVideo && !isMulti
        let fading = ([waitingParticipantsView, videoCallingOverlay, previewShadeView] as [UIView]
            + (isAudioOneToOne ? [statusLabel] : [avatarImageView, nameLabel])).filter { !$0.isHidden }

        avatarImageView.layer.removeAnimation(forKey: "incoming.pulse")

        if wasIncomingRinging {
            topBar.alpha = 0
            controlPanel.alpha = 0
        }

        callCoreView.isHidden = isAudioOneToOne
        if !isAudioOneToOne || wasIncomingRinging {
            statusLabel.isHidden = true
        }

        UIView.animate(withDuration: 0.25) {
            fading.forEach { $0.alpha = 0 }
            self.topBar.alpha = 1
            self.controlPanel.alpha = 1
            if isAudioOneToOne {
                self.avatarCenterYConstraint?.update(offset: -100)
                self.avatarSizeConstraint?.update(offset: 96)
                self.nameCenterYConstraint?.update(offset: -26)
                self.avatarImageView.layer.cornerRadius = 48
                self.avatarRingView.alpha = 1
                self.layoutIfNeeded()
            }
        } completion: { _ in
            fading.forEach { $0.isHidden = true; $0.alpha = 1 }
        }
    }

    private func loadPeerProfile() {
        guard let peerID = CallStore.shared.state.value.primaryPeerID else { return }
        nameLabel.text = peerID
        ContactStore.shared.getContactInfo(userIDList: [peerID], completion: ContactInfoHandler(success: { [weak self] infos in
            let info = infos.first
            DispatchQueue.main.async {
                if let nickname = info?.nickname, !nickname.isEmpty { self?.nameLabel.text = nickname }
            }
            CallKitAvatarLoader.file(from: info?.avatarURL, name: peerID) { [weak self] path in
                guard let self, let path, !self.didEnterMultiMode else { return }
                self.callCoreView.setParticipantAvatars(avatars: [peerID: path])
                let image = UIImage(contentsOfFile: path)
                self.avatarImageView.image = image ?? Self.defaultAvatar
                self.avatarImageView.isHidden = self.isVideo && !self.isIncomingRinging
                if let image, !self.isVideo {
                    self.applyBackdrop(image)
                }
            }
        }, failure: { code, desc in
            CallKitLog.error("peer avatar getContactInfo failed: code=\(code) desc=\(desc)")
        }))
    }

    private func applyBackdrop(_ image: UIImage?, radius: Double = 26) {
        backdropToken += 1
        let token = backdropToken
        guard let image else {
            backdropImageView.image = nil
            return
        }
        let targetSize = bounds.isEmpty ? UIScreen.main.bounds.size : bounds.size
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            let blurred = CallKitImageBlur.blurred(image, targetSize: targetSize, radius: radius)
            DispatchQueue.main.async {
                guard let self, self.backdropToken == token else { return }
                self.backdropImageView.image = blurred ?? image
            }
        }
    }

    private final class ContactInfoHandler: GetContactInfoCompletionHandler {
        private let success: ([ContactInfo]) -> Void
        private let failure: (Int, String) -> Void

        init(success: @escaping ([ContactInfo]) -> Void, failure: @escaping (Int, String) -> Void) {
            self.success = success
            self.failure = failure
        }

        func onSuccess(contactInfoList: [ContactInfo]) { success(contactInfoList) }
        func onFailure(code: Int, desc: String) { failure(code, desc) }
    }

    private enum BubbleWidth {
        static let route: CGFloat = 264
        static let more: CGFloat = 212
    }
}

extension CallView: UIGestureRecognizerDelegate {
    fileprivate func findGridCollectionView(in view: UIView) -> UICollectionView? {
        (view as? UICollectionView) ?? view.subviews.lazy.compactMap { self.findGridCollectionView(in: $0) }.first
    }

    func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldReceive touch: UITouch) -> Bool {
        guard isVideo || isMulti, hasConnected, openSheetCount == 0,
              routeBubble.isHidden, moreBubble.isHidden else { return false }
        if touch.view?.isDescendant(of: transcriptView) == true { return false }
        let point = touch.location(in: self)
        if !topBar.isHidden, topBar.frame.contains(point) { return false }
        if !controlPanel.isHidden, controlPanel.frame.contains(point) { return false }
        if gridHit(at: point) != nil {
            scheduleTranscriptGeometryRefresh()
            return false
        }
        var view = hitTest(point, with: nil)
        while let current = view {
            if String(describing: type(of: current)) == "CallParticipantView",
               isMulti || current.bounds.width < 200 {
                return false
            }
            view = current.superview
        }
        return true
    }

    func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer,
                           shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer) -> Bool {
        true
    }
}

extension CallState {
    var primaryPeerID: String? {
        allParticipants.first(where: { $0.id != selfInfo.id })?.id ?? activeCall.inviteeIds.first
    }

    var isVideoCall: Bool { activeCall.mediaType == .video }

    var isMultiCall: Bool {
        !activeCall.chatGroupId.isEmpty || activeCall.inviteeIds.count > 1 || allParticipants.count > 2
    }
}

private extension Publisher where Failure == Never {
    func sinkOnMain(in cancellables: inout Set<AnyCancellable>, _ handler: @escaping (Output) -> Void) {
        receive(on: RunLoop.main).sink(receiveValue: handler).store(in: &cancellables)
    }
}

private final class TapHintPill: UIView {

    private var hideWorkItem: DispatchWorkItem?

    override init(frame: CGRect) {
        super.init(frame: frame)
        isUserInteractionEnabled = false
        backgroundColor = CallKitTheme.toastBackground
        layer.shadowColor = UIColor.black.cgColor
        layer.shadowOpacity = 0.25
        layer.shadowRadius = 8
        layer.shadowOffset = CGSize(width: 0, height: 6)
        alpha = 0
        transform = CGAffineTransform(translationX: 0, y: 6)

        let iconView = UIImageView(image: CallKitResources.image(named: "callkit_icon_tap_hint")?.withRenderingMode(.alwaysTemplate))
        iconView.tintColor = CallKitTheme.sheetText3
        iconView.contentMode = .scaleAspectFit
        iconView.snp.makeConstraints { make in
            make.size.equalTo(22)
        }

        let label = UILabel()
        label.text = CallKitResources.text("callkit.cc.tap_hint")
        label.font = .systemFont(ofSize: 13)
        label.textColor = CallKitTheme.sheetText3

        let row = UIStackView(arrangedSubviews: [iconView, label])
        row.spacing = 8
        row.alignment = .center
        addSubview(row)
        row.snp.makeConstraints { make in
            make.edges.equalToSuperview().inset(UIEdgeInsets(top: 8, left: 10, bottom: 8, right: 14))
        }
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        layer.cornerRadius = bounds.height / 2
    }

    func showTemporarily() {
        hideWorkItem?.cancel()
        UIView.animate(withDuration: 0.28) {
            self.alpha = 1
            self.transform = .identity
        }
        let work = DispatchWorkItem { [weak self] in
            UIView.animate(withDuration: 0.2) {
                self?.alpha = 0
                self?.transform = CGAffineTransform(translationX: 0, y: 6)
            }
        }
        hideWorkItem = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 3, execute: work)
    }
}
