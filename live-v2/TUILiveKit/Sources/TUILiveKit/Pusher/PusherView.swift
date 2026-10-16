import AVFoundation
import UIKit
import AtomicXCore
import Combine
import SnapKit

struct PusherPresentationState: Equatable {
    var hostName = LiveKitResources.localizedString("tuilivekit.common.host")
    var hostAvatarURL = ""
    var settings = PusherSettingsState()
    var deviceStatus = PusherDeviceStatusState()
}

public final class PusherView: UIView {
    public var onExit: (() -> Void)?

    private enum Phase {
        case prepare
        case living
        case summary
    }

    private let liveID: String
    private let seatStore: LiveSeatStore
    private let coGuestStore: PusherCoGuestStore
    private let coGuestBackgroundView = UIImageView()
    private let videoView: PusherVideoView
    private let prepareView = PusherPrepareView()
    private let beautyPanel = BeautyPanel()
    private let livingView: PusherLivingView
    private let summaryView: PusherSummaryView
    private var connectedGuestCount = 0
    private var coGuestLayout: PusherCoGuestStore.Layout = .grid2
    private var phase: Phase = .prepare
    private var liveTitle = LiveKitResources.localizedString("tuilivekit.pusher.default_title")
    private var coverURL = LiveKitResources.defaultCoverURL
    private var liveStartTime: Date?
    private var liveEndTime: Date?
    private var elapsedSeconds = 0
    private var isPaused = false
    private var pausedSeconds = 0
    private var accumulatedPauseDuration: TimeInterval = 0
    private var pauseStartTime: Date?
    private var elapsedTimer: Timer?
    private var pauseTimer: Timer?
    private var pushSessionID: UUID?
    private var pusherCancellables = Set<AnyCancellable>()
    private var isPusherAttached = false
    private var hasConnected = false
    private var interruptionMessage: String?
    private var presentationState = PusherPresentationState()
    private var cancellables = Set<AnyCancellable>()
    private var previewOperationID: UUID?
    private var unmuteOperationID: UUID?
    private var didInitializeAudioSettings = false
    private var didInitializePreviewSettings = false
    private var didStartPreview = false
    private var isPreviewStarting = false
    private var backgroundDevices: (camera: Bool, microphone: Bool, isFront: Bool)?
    private var needsDeviceCleanup = false
    private var isEndingLive = false
    private var didReleaseSession = false
    private let endingOverlay = UIView()
    private let endingSpinner = UIActivityIndicatorView(style: .large)

    public init(liveID: String) {
        self.liveID = liveID
        let seatStore = LiveSeatStore.create(liveID: liveID)
        self.seatStore = seatStore
        coGuestStore = PusherCoGuestStore(
            liveID: liveID,
            seatStore: seatStore
        )
        videoView = PusherVideoView(liveID: liveID)
        livingView = PusherLivingView(liveID: liveID)
        summaryView = PusherSummaryView()
        super.init(frame: .zero)
        updateHostProfile(LoginStore.shared.state.value.loginUserInfo)
        // Set the fixed HD quality once, before reading settings or starting preview.
        DeviceStore.shared.updateVideoQuality(.quality720P)
        presentationState.settings = makeSettingsState()
        presentationState.deviceStatus = makeDeviceStatusState(DeviceStore.shared.state.value)
        configureUI()
        bindActions()
        bindState()
        subscribeDeviceStatus()
        subscribeThermalState()
        subscribeAVStatistics()
        subscribeUserProfile()
        subscribeAccountEvents()
        subscribeCaptureLifecycle()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    public override func didMoveToWindow() {
        super.didMoveToWindow()
        if window == nil {
            cleanupSession()
            summaryView.hide()
        } else {
            guard !didReleaseSession else { return }
            if phase != .summary {
                AtomicPusher.shared.setView(videoView.coreView)
                isPusherAttached = true
            }
            startPreviewIfNeeded()
        }
    }

    deinit {
        elapsedTimer?.invalidate()
        pauseTimer?.invalidate()
    }
}

// MARK: - UI Assembly And Rendering

private extension PusherView {
    private func configureUI() {
        backgroundColor = .black
        videoView.layer.cornerRadius = 16
        videoView.layer.masksToBounds = true

        coGuestBackgroundView.image = LiveKitResources.image(named: "livekit_pusher_coguest_background")
        coGuestBackgroundView.contentMode = .scaleToFill
        coGuestBackgroundView.isUserInteractionEnabled = false
        coGuestBackgroundView.isHidden = true

        addSubview(coGuestBackgroundView)
        [videoView, prepareView, livingView, summaryView, beautyPanel].forEach {
            addSubview($0)
        }

        endingOverlay.backgroundColor = UIColor.black.withAlphaComponent(0.55)
        endingOverlay.isHidden = true
        addSubview(endingOverlay)
        endingOverlay.snp.makeConstraints { $0.edges.equalToSuperview() }
        endingSpinner.color = .white
        let endingLabel = UILabel()
        endingLabel.text = LiveKitResources.localizedString("tuilivekit.pusher.ending")
        endingLabel.textColor = .white
        endingLabel.font = .systemFont(ofSize: 16)
        endingLabel.numberOfLines = 0
        endingLabel.textAlignment = .center
        let endingContent = UIStackView(arrangedSubviews: [endingSpinner, endingLabel])
        endingContent.axis = .vertical
        endingContent.alignment = .center
        endingContent.spacing = 16
        endingOverlay.addSubview(endingContent)
        endingContent.snp.makeConstraints { make in
            make.center.equalToSuperview()
            make.leading.greaterThanOrEqualToSuperview().offset(24)
            make.trailing.lessThanOrEqualToSuperview().offset(-24)
        }

        coGuestBackgroundView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }
        videoView.snp.makeConstraints { make in
            make.leading.trailing.top.equalToSuperview()
            make.bottom.equalToSuperview().offset(-112)
        }
        [prepareView, livingView, summaryView, beautyPanel].forEach {
            $0.snp.makeConstraints { make in
                make.edges.equalToSuperview()
            }
        }
    }

    private func bindActions() {
        prepareView.onExit = { [weak self] in
            self?.exitPage()
        }
        prepareView.onCountdownFinished = { [weak self] title in
            self?.startLive(title: title)
        }
        prepareView.onSelectCover = { [weak self] coverURL in
            self?.updateCoverURL(coverURL)
        }
        prepareView.onTitleChanged = { [weak self] title in
            guard let self, phase == .prepare, !didReleaseSession else { return }
            liveTitle = title
        }
        prepareView.onFlipCamera = { [weak self] in
            self?.switchCamera()
        }
        prepareView.onShowBeauty = { [weak self] in self?.showBeauty(for: .prepare) }
        livingView.onShowBeauty = { [weak self] in self?.showBeauty(for: .living) }
        prepareView.settingsActionHandler = self
        prepareView.onRefreshSettings = { [weak self] in self?.refreshSettings() }
        livingView.onEnd = { [weak self] in
            self?.endLive()
        }
        livingView.onToggleMute = { [weak self] in self?.toggleMute() }
        livingView.onPause = { [weak self] in self?.pauseLive() }
        livingView.onResume = { [weak self] in self?.resumeLive() }
        livingView.onFlipCamera = { [weak self] in self?.switchCamera() }
        livingView.settingsActionHandler = self
        livingView.coGuestActionHandler = coGuestStore
        livingView.coGuestSmallWindowRegions = { [weak self] in
            guard let self else { return [] }
            return self.videoView.coGuestSmallWindowRegions(in: self.livingView)
        }
        videoView.onCoGuestGeometryChanged = { [weak self] in
            self?.livingView.setNeedsLayout()
        }
        livingView.onCoGuestStageTap = { [weak self] point in
            guard let self else { return false }
            let videoPoint = self.videoView.convert(point, from: self.livingView)
            guard let userID = self.videoView.coGuestUserID(at: videoPoint) else { return false }
            self.livingView.showCoGuestActions(userID: userID)
            return true
        }
        summaryView.onExit = { [weak self] in
            self?.exitPage()
        }
    }

    private func bindState() {
        coGuestStore.onToast = { [weak self] message in
            guard let self, self.phase == .living, !self.isEndingLive, !self.didReleaseSession else { return }
            LiveToast.show(message)
        }
        coGuestStore.onStateChanged = { [weak self] state in
            guard let self else { return }
            if self.connectedGuestCount != state.connected.count || self.coGuestLayout != state.layout {
                self.connectedGuestCount = state.connected.count
                self.coGuestLayout = state.layout
                self.updateCoGuestPresentation()
            }
            self.livingView.updateCoGuest(state)
        }
        render()
    }

    private func showBeauty(for requestedPhase: Phase) {
        guard window != nil, !isEndingLive, !didReleaseSession, phase == requestedPhase, phase != .summary,
              beautyPanel.isHidden else { return }
        bringSubviewToFront(beautyPanel)
        beautyPanel.present()
    }

    private func render() {
        beautyPanel.dismiss()
        updateCoGuestPresentation()
        prepareView.isHidden = phase != .prepare
        livingView.isHidden = phase != .living
        if phase != .living {
            livingView.resetAudienceWelcomes()
        }
        let isSummary = phase == .summary
        summaryView.isHidden = !isSummary
        videoView.isHidden = isSummary

        if phase == .prepare {
            prepareView.bind(title: liveTitle, coverURL: coverURL)
        } else if phase == .living {
            livingView.updateHost(name: presentationState.hostName, avatarURL: presentationState.hostAvatarURL)
            livingView.updateElapsedSeconds(elapsedSeconds)
            livingView.updatePause(isPaused: isPaused, seconds: pausedSeconds)
        }
        updateSettings()
        updateDeviceStatus()
        if isSummary, window != nil {
            let totalPausedSeconds = Int(accumulatedPauseDuration + currentPauseDuration)
            summaryView.show(context: PusherSummaryContext(
                startTime: liveStartTime,
                endTime: liveEndTime ?? Date(),
                pausedSeconds: totalPausedSeconds,
                interruptionMessage: interruptionMessage
            ))
        } else {
            summaryView.hide()
        }
    }

    private func updateHostProfile(_ profile: UserProfile?) {
        let nickname = profile?.nickname?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let name = nickname.isEmpty
            ? (profile?.userID ?? LiveKitResources.localizedString("tuilivekit.common.host"))
            : nickname
        let avatarURL = profile?.avatarURL ?? ""
        guard presentationState.hostName != name || presentationState.hostAvatarURL != avatarURL else { return }
        presentationState.hostName = name
        presentationState.hostAvatarURL = avatarURL
        if phase == .living {
            livingView.updateHost(name: name, avatarURL: avatarURL)
        }
    }

    private func updateSettings() {
        let settings = presentationState.settings
        if phase == .prepare {
            prepareView.bind(settings: settings)
        } else if phase == .living {
            livingView.updateSettings(settings)
        }
    }

    private func updateDeviceStatus() {
        guard phase == .living else { return }
        livingView.updateDeviceStatus(
            presentationState.deviceStatus,
            videoQuality: presentationState.settings.videoQuality,
            isMuted: presentationState.settings.isMuted,
            captureVolume: presentationState.settings.captureVolume
        )
    }

    private func updateCoGuestPresentation() {
        let isLiving = phase == .living
        let isStageActive = isLiving && (connectedGuestCount > 0 || coGuestLayout != .floating)
        videoView.updateCoGuestVideoState(
            isLiving: isLiving,
            layout: coGuestLayout,
            connectedGuestCount: connectedGuestCount
        )
        coGuestBackgroundView.isHidden = !isStageActive
        livingView.setCoGuestStageActive(isStageActive)
    }

    private func updateCoverURL(_ value: String) {
        guard LiveKitResources.presetCoverURLs.contains(value), coverURL != value else { return }
        coverURL = value
        if phase == .prepare {
            prepareView.bind(title: liveTitle, coverURL: coverURL)
        }
    }
}

// MARK: - Preview And Permissions

private extension PusherView {
    private func startPreviewIfNeeded() {
        guard canCapture, !didStartPreview, !isPreviewStarting else { return }
        if !didInitializeAudioSettings {
            didInitializeAudioSettings = true
            AudioEffectView.resetForNewSession()
            setCaptureVolume(100)
        }
        let operationID = UUID()
        previewOperationID = operationID
        isPreviewStarting = true

        if backgroundDevices?.camera == false {
            requestMicrophoneAccess(operationID: operationID)
            return
        }
        requestAccess(for: .video) { [weak self] granted in
            guard let self, self.validatePreviewOperation(operationID) else { return }
            guard granted else {
                self.finishPreview()
                return
            }
            let isFront = self.backgroundDevices?.isFront ?? (self.didInitializePreviewSettings ? DeviceStore.shared.state.value.isFrontCamera : true)
            if !self.didInitializePreviewSettings {
                self.didInitializePreviewSettings = true
                DeviceStore.shared.switchMirror(mirrorType: .enable)
                self.presentationState.settings.isMirrorEnabled = true
                self.updateSettings()
            }
            BeautyPreferences.restore()
            self.needsDeviceCleanup = true
            DeviceStore.shared.openLocalCamera(isFront: isFront) { [weak self] result in
                Task { @MainActor in
                    guard let self else { return }
                    guard self.validatePreviewOperation(operationID) else {
                        return
                    }
                    switch result {
                    case .success:
                        self.requestMicrophoneAccess(operationID: operationID)
                    case .failure:
                        self.finishPreview()
                    }
                }
            }
        }
    }

    private func requestMicrophoneAccess(operationID: UUID) {
        guard validatePreviewOperation(operationID) else { return }
        if backgroundDevices?.microphone == false {
            finishPreview()
            didStartPreview = true
            backgroundDevices = nil
            return
        }
        requestAccess(for: .audio) { [weak self] granted in
            guard let self, self.validatePreviewOperation(operationID) else { return }
            guard granted else {
                self.finishPreview()
                return
            }
            self.needsDeviceCleanup = true
            if self.presentationState.settings.isMuted { self.seatStore.muteMicrophone() }
            let completion: CompletionClosure = { [weak self] result in
                Task { @MainActor in
                    guard let self else { return }
                    if !self.didReleaseSession, self.isPaused || UIApplication.shared.applicationState == .background {
                        self.seatStore.muteMicrophone()
                    }
                    guard self.validatePreviewOperation(operationID) else {
                        return
                    }
                    self.previewOperationID = nil
                    self.isPreviewStarting = false
                    if case .success = result {
                        self.didStartPreview = true
                        self.backgroundDevices = nil
                        if self.presentationState.settings.isMuted { self.seatStore.muteMicrophone() }
                    }
                }
            }
            if DeviceStore.shared.state.value.microphoneStatus == .on {
                if self.presentationState.settings.isMuted {
                    completion(.success(()))
                } else {
                    self.seatStore.unmuteMicrophone(completion: completion)
                }
            } else {
                DeviceStore.shared.openLocalMicrophone(completion: completion)
            }
        }
    }

    private func requestAccess(for mediaType: AVMediaType, completion: @escaping (Bool) -> Void) {
        switch AVCaptureDevice.authorizationStatus(for: mediaType) {
        case .authorized:
            completion(true)
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: mediaType) { granted in
                Task { @MainActor in completion(granted) }
            }
        default:
            completion(false)
        }
    }

    private func validatePreviewOperation(_ operationID: UUID) -> Bool {
        guard previewOperationID == operationID else { return false }
        guard canCapture else {
            // Permission sheets can return while the app is still inactive.
            // Leave the request restartable for didBecomeActive.
            finishPreview()
            return false
        }
        return true
    }

    private func finishPreview() {
        previewOperationID = nil
        isPreviewStarting = false
    }

    private func stopPreview(closeMicrophone: Bool = false) {
        previewOperationID = nil
        if needsDeviceCleanup {
            DeviceStore.shared.closeLocalCamera()
            if closeMicrophone {
                needsDeviceCleanup = false
                DeviceStore.shared.closeLocalMicrophone()
            } else {
                seatStore.muteMicrophone()
            }
        }
        didStartPreview = false
        isPreviewStarting = false
    }

    private func switchCamera() {
        DeviceStore.shared.switchCamera(isFront: !DeviceStore.shared.state.value.isFrontCamera)
    }
}

// MARK: - Settings Actions

extension PusherView: PusherSettingsActionHandling {
    private func refreshSettings() {
        presentationState.settings = makeSettingsState()
        updateSettings()
        updateDeviceStatus()
    }

    func toggleMirror() {
        let enabled = DeviceStore.shared.state.value.localMirrorType != .disable
        DeviceStore.shared.switchMirror(mirrorType: enabled ? .disable : .enable)
        presentationState.settings.isMirrorEnabled = !enabled
        updateSettings()
    }

    private func toggleMute() {
        guard phase == .living, !isPaused, !isEndingLive, !didReleaseSession,
              unmuteOperationID == nil else { return }
        let wasMuted = presentationState.settings.isMuted
        presentationState.settings.isMuted = !wasMuted
        updateSettings()
        updateDeviceStatus()
        guard wasMuted else {
            seatStore.muteMicrophone()
            return
        }
        let operationID = UUID()
        unmuteOperationID = operationID
        seatStore.unmuteMicrophone { [weak self] result in
            Task { @MainActor in
                guard let self else { return }
                if !self.didReleaseSession, self.isPaused || UIApplication.shared.applicationState == .background {
                    self.seatStore.muteMicrophone()
                }
                guard self.unmuteOperationID == operationID else { return }
                self.unmuteOperationID = nil
                guard self.phase == .living, !self.isEndingLive, !self.didReleaseSession else { return }
                if case .failure = result {
                    self.presentationState.settings.isMuted = wasMuted
                    self.updateSettings()
                    self.updateDeviceStatus()
                    LiveToast.show(LiveKitResources.localizedString("tuilivekit.pusher.error.mute_switch_failed"))
                }
            }
        }
    }

    func setCaptureVolume(_ volume: Int) {
        let value = min(100, max(0, volume))
        DeviceStore.shared.setCaptureVolume(volume: value)
        presentationState.settings.captureVolume = value
        updateSettings()
        updateDeviceStatus()
    }


}

// MARK: - Live Session

private extension PusherView {
    private func startLive(title: String) {
        guard phase == .prepare, !didReleaseSession, isPusherAttached, pushSessionID == nil else { return }
        // Keep the editable draft intact if this attempt fails.
        liveTitle = title
        guard !liveID.isEmpty, liveID.utf8.count <= 48 else {
            LiveToast.show(LiveKitResources.localizedString("tuilivekit.pusher.error.start_failed"))
            return
        }
        enterLivingPhase()
        requestStartLive()
    }

    private func enterLivingPhase() {
        livingView.activateAudience()
        livingView.activateLikes()
        livingView.activateComments()
        livingView.activateMusic()
        coGuestStore.activate()
        liveStartTime = Date()
        liveEndTime = nil
        elapsedSeconds = 0
        isPaused = false
        pausedSeconds = 0
        accumulatedPauseDuration = 0
        pauseStartTime = nil
        phase = .living
        render()

        let timer = Timer(timeInterval: 1, repeats: true) { [weak self] _ in
            Task { @MainActor in
                guard let self, self.phase == .living, !self.isEndingLive, !self.didReleaseSession else { return }
                self.updateElapsedTime()
                self.livingView.updateElapsedSeconds(self.elapsedSeconds)
            }
        }
        elapsedTimer = timer
        RunLoop.main.add(timer, forMode: .common)
    }

    private func requestStartLive() {
        guard pushSessionID == nil, isPusherAttached else { return }
        let sessionID = UUID()
        pushSessionID = sessionID
        hasConnected = false
        AtomicPusher.shared.state.subscribe()
            .receive(on: DispatchQueue.main)
            .sink { [weak self] state in
                guard let self, self.pushSessionID == sessionID,
                      self.phase == .living, !self.isEndingLive, !self.didReleaseSession, state.pusherInfo.liveID == self.liveID else { return }
                self.applyPushState(state)
            }
            .store(in: &pusherCancellables)
        AtomicPusher.shared.pusherEvent
            .receive(on: DispatchQueue.main)
            .sink { [weak self] event in
                guard let self, self.pushSessionID == sessionID, self.window != nil else { return }
                self.handlePushEvent(event)
            }
            .store(in: &pusherCancellables)
        KeyMetrics.reportAtomicMetrics(KeyMetrics.liveIntegrationSuccessful)
        KeyMetrics.setComponent(KeyMetrics.componentLiveStream)
        let title = liveTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        AtomicPusher.shared.startPush(config: PusherInfo(
            liveID: liveID,
            liveName: title.isEmpty ? LiveKitResources.localizedString("tuilivekit.pusher.default_title") : title,
            coverURL: coverURL,
            backgroundURL: "https://liteav.sdk.qcloud.com/app/res/picture/livekit/coGuestBackGroud.png",
            isPublicVisible: true
        ))
    }

    private func applyPushState(_ state: PusherState) {
        if state.networkState == .CONNECTED, !hasConnected {
            hasConnected = true
            let sessionID = pushSessionID
            seatStore.setSeatMode(mode: .apply) { [weak self] result in
                Task { @MainActor in
                    guard let self, self.pushSessionID == sessionID, self.phase == .living, !self.isEndingLive, !self.didReleaseSession else { return }
                    if case let .failure(error) = result {
                        LiveToast.show(LiveKitErrorText.message(error))
                    }
                }
            }
            coGuestStore.didConnect()
            livingView.refreshAudience()
        }
        let statistics = state.statistics
        var status = presentationState.deviceStatus
        status.videoBitrate = UInt(max(0, statistics.videoBitrate))
        status.videoWidth = max(0, statistics.videoWidth)
        status.videoHeight = max(0, statistics.videoHeight)
        status.frameRate = UInt(max(0, statistics.videoFps))
        status.audioBitrate = UInt(max(0, statistics.audioBitrate))
        status.hasAVStatistics = state.networkState == .CONNECTED
        guard status != presentationState.deviceStatus else { return }
        presentationState.deviceStatus = status
        updateDeviceStatus()
    }

    private func handlePushEvent(_ event: PusherEvent) {
        guard pushSessionID != nil, !didReleaseSession else { return }
        let reasonKey: String
        switch event {
        case let .pusherError(code, message):
            guard phase == .living, code != .OK else { return }
            LiveKitLog.error("[PusherView] push failed liveID=\(liveID) code=\(code.rawValue) message=\(message)")
            let text = Self.pushErrorMessage(code: code, message: message)
            if code == .ERROR_START_PUSH_REQUEST_FAILED, !hasConnected, !isEndingLive {
                returnToPrepareAfterStartFailure()
            }
            LiveToast.show(text)
            return
        case let .liveEnded(reason, summary):
            summaryView.updateSummary(summary)
            pushSessionID = nil
            pusherCancellables.removeAll()
            guard phase == .living else { return }
            if isEndingLive {
                settleLive()
                return
            }
            switch reason {
            case .ENDED_BY_HOST: reasonKey = "ended"
            case .ENDED_BY_SERVER: reasonKey = "server"
            @unknown default: reasonKey = "ended"
            }
        case let .kickedOut(reason, _):
            guard phase == .living else { return }
            switch reason {
            case .BY_ADMIN: reasonKey = "admin"
            case .BY_LOGGED_ON_OTHER_DEVICE: reasonKey = "other_device"
            case .BY_SERVER: reasonKey = "server"
            case .FOR_NETWORK_DISCONNECTED: reasonKey = "network"
            case .FOR_LIVE_CHANNEL_EXPIRED: reasonKey = "expired"
            @unknown default: reasonKey = "ended"
            }
        }
        interruptionMessage = LiveKitResources.localizedString("tuilivekit.pusher.interruption." + reasonKey)
        // Terminal SDK events must not issue another stopPush during cleanup.
        pushSessionID = nil
        pusherCancellables.removeAll()
        settleLive()
    }

    private static func pushErrorMessage(code: PusherCode, message: String) -> String {
        let key: String
        switch code {
        case .ERROR_START_PUSH_REQUEST_FAILED, .ERROR_UPDATE_CONFIG_REQUEST_FAILED:
            // The SDK exposes only a category code; the upstream code is currently
            // embedded in the SSO message. Match that field, never the message body.
            let isContentRejected = message.range(
                of: #"^\s*error_code:\s*100026(?:\s*[,|]|\s*$)"#,
                options: .regularExpression
            ) != nil
            if isContentRejected {
                key = "content_rejected"
            } else {
                key = code == .ERROR_START_PUSH_REQUEST_FAILED ? "start_failed" : "update_failed"
            }
        default:
            key = "operation_failed"
        }
        return LiveKitResources.localizedString("tuilivekit.pusher.error.\(key)")
    }

    private func returnToPrepareAfterStartFailure() {
        // The SDK already stops the failed attempt. Do not stop/release the
        // shared pusher or devices again: Prepare reuses the existing preview.
        pushSessionID = nil
        pusherCancellables.removeAll()
        unmuteOperationID = nil
        phase = .prepare
        elapsedTimer?.invalidate()
        elapsedTimer = nil
        finishPause()
        liveStartTime = nil
        liveEndTime = nil
        elapsedSeconds = 0
        accumulatedPauseDuration = 0
        interruptionMessage = nil
        livingView.resetAfterStartFailure()
        coGuestStore.deactivate()
        prepareView.deactivate()
        render()
        // This only opens devices if a user pause/background transition stopped
        // them; an already running (or starting) preview is left untouched.
        startPreviewIfNeeded()
    }

    private func subscribeUserProfile() {
        LoginStore.shared.state
            .subscribe(StatePublisherSelector(keyPath: \LoginState.loginUserInfo))
            .receive(on: DispatchQueue.main)
            .sink { [weak self] profile in
                guard let self, !self.didReleaseSession else { return }
                self.updateHostProfile(profile)
            }
            .store(in: &cancellables)
    }

    private func subscribeAccountEvents() {
        LoginStore.shared.loginEventPublisher
            .receive(on: DispatchQueue.main)
            .sink { [weak self] event in
                guard let self, self.window != nil, case .kickedOffline = event else { return }
                if self.phase == .living {
                    self.interruptionMessage = LiveKitResources.localizedString("tuilivekit.pusher.interruption.account")
                    self.endLive()
                } else if self.phase == .prepare {
                    // Allow the host's login observer to install its exit route.
                    DispatchQueue.main.async { [weak self] in self?.exitPage() }
                }
                // Keep an already displayed summary and its more specific reason.
            }
            .store(in: &cancellables)
    }

    private func releasePusher() {
        let hadSession = pushSessionID != nil
        pushSessionID = nil
        pusherCancellables.removeAll()
        guard isPusherAttached else { return }
        isPusherAttached = false
        if hadSession, phase == .living, !isEndingLive { AtomicPusher.shared.stopPush() }
        AtomicPusher.shared.release()
    }

    private func pauseLive() {
        guard phase == .living, !isEndingLive, !didReleaseSession, !isPaused else { return }
        pauseStartTime = Date()
        isPaused = true
        updateElapsedTime()
        livingView.updateElapsedSeconds(elapsedSeconds)
        backgroundDevices = nil
        pausedSeconds = 0
        livingView.pauseComments()
        stopPreview()
        livingView.updatePause(isPaused: isPaused, seconds: pausedSeconds)

        let timer = Timer(timeInterval: 1, repeats: true) { [weak self] _ in
            Task { @MainActor in
                guard let self, self.isPaused else { return }
                self.pausedSeconds = Int(self.currentPauseDuration)
                self.livingView.updatePause(isPaused: self.isPaused, seconds: self.pausedSeconds)
            }
        }
        pauseTimer = timer
        RunLoop.main.add(timer, forMode: .common)
    }

    private func resumeLive() {
        guard phase == .living, !isEndingLive, !didReleaseSession, isPaused else { return }
        finishPause()
        livingView.resumeComments()
        startPreviewIfNeeded()
        livingView.updatePause(isPaused: isPaused, seconds: pausedSeconds)
    }

    private func endLive() {
        guard phase == .living, !isEndingLive, !didReleaseSession else { return }
        isEndingLive = true
        beautyPanel.dismiss()
        endingOverlay.isHidden = false
        bringSubviewToFront(endingOverlay)
        endingSpinner.startAnimating()
        AtomicPusher.shared.stopPush()
    }

    private func finishLivePresentation() {
        guard liveEndTime == nil else { return }
        livingView.deactivateAudience(resetState: false)
        livingView.deactivateLikes(resetState: false)
        livingView.deactivateComments(resetState: false)
        livingView.deactivateMusic()
        coGuestStore.deactivate()
        finishPause()
        elapsedTimer?.invalidate()
        elapsedTimer = nil
        liveEndTime = Date()
        updateElapsedTime()
    }

    private func settleLive() {
        guard phase == .living, !didReleaseSession else { return }
        finishLivePresentation()
        phase = .summary
        render()
        cleanupSession()
    }

    private func exitPage() {
        cleanupSession()
        onExit?()
    }

    private func cleanupSession() {
        guard !didReleaseSession else { return }
        didReleaseSession = true
        backgroundDevices = nil
        previewOperationID = nil
        unmuteOperationID = nil
        beautyPanel.dismiss()
        prepareView.deactivate()
        if phase == .living { finishLivePresentation() }
        livingView.deactivateAudience(resetState: true)
        livingView.deactivateLikes(resetState: true)
        livingView.deactivateComments(resetState: true)
        livingView.deactivateMusic()
        coGuestStore.deactivate()
        cancellables.removeAll()
        // Detach SDK-backed children now so Summary exit cannot unbind a newer session.
        livingView.removeFromSuperview()
        videoView.removeFromSuperview()
        stopPreview(closeMicrophone: true)
        releasePusher()
        invalidateLifecycle()
        endingSpinner.stopAnimating()
        endingOverlay.isHidden = true
    }
}

// MARK: - Device Presentation

private extension PusherView {
    private func makeSettingsState() -> PusherSettingsState {
        let deviceState = DeviceStore.shared.state.value
        let quality: PusherVideoQualitySetting
        switch deviceState.localVideoQuality {
        case .quality1080P:
            quality = .fhd
        case .quality720P:
            quality = .hd
        case .quality360P, .quality540P:
            quality = .sd
        @unknown default:
            quality = .hd
        }
        return PusherSettingsState(
            videoQuality: quality,
            isMirrorEnabled: deviceState.localMirrorType != .disable,
            isMuted: presentationState.settings.isMuted,
            captureVolume: deviceState.captureVolume
        )
    }

    private func makeDeviceStatusState(_ deviceState: DeviceState) -> PusherDeviceStatusState {
        var status = presentationState.deviceStatus
        status.cameraStatus = deviceState.cameraStatus
        status.microphoneStatus = deviceState.microphoneStatus
        status.cameraError = deviceState.cameraLastError
        status.microphoneError = deviceState.microphoneLastError
        status.videoQuality = deviceState.localVideoQuality
        status.temperatureStatus = Self.temperatureStatus(ProcessInfo.processInfo.thermalState)
        switch deviceState.networkType {
        case .wifi: status.networkKind = .wifi
        case .cellular: status.networkKind = .cellular
        case .unknown: status.networkKind = .unknown
        @unknown default: status.networkKind = .unknown
        }
        status.networkQuality = deviceState.networkInfo.quality.rawValue
        status.delay = deviceState.networkInfo.delay
        status.downLoss = deviceState.networkInfo.downLoss
        status.upLoss = deviceState.networkInfo.upLoss
        return status
    }

    private static func temperatureStatus(
        _ thermalState: ProcessInfo.ThermalState
    ) -> PusherDeviceStatusState.TemperatureStatus {
        switch thermalState {
        case .nominal: return .normal
        case .fair: return .fair
        case .serious, .critical: return .serious
        @unknown default: return .normal
        }
    }

    private func subscribeThermalState() {
        NotificationCenter.default.publisher(for: ProcessInfo.thermalStateDidChangeNotification)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                guard let self else { return }
                let value = Self.temperatureStatus(ProcessInfo.processInfo.thermalState)
                guard self.presentationState.deviceStatus.temperatureStatus != value else { return }
                self.presentationState.deviceStatus.temperatureStatus = value
                self.updateDeviceStatus()
            }
            .store(in: &cancellables)
    }

    private func subscribeDeviceStatus() {
        DeviceStore.shared.state.subscribe()
            .receive(on: DispatchQueue.main)
            .sink { [weak self] deviceState in
                guard let self, !self.didReleaseSession else { return }
                self.videoView.updateLocalCameraStatus(deviceState.cameraStatus)
                let nextState = self.makeDeviceStatusState(deviceState)
                guard self.presentationState.deviceStatus != nextState else { return }
                self.presentationState.deviceStatus = nextState
                self.updateDeviceStatus()
            }
            .store(in: &cancellables)
    }

    private func subscribeAVStatistics() {
        seatStore.state.subscribe()
            .receive(on: DispatchQueue.main)
            .sink { [weak self] seatState in
                guard let self, !self.didReleaseSession else { return }
                var nextState = self.presentationState.deviceStatus
                // PusherStatistics does not expose audio sample rate.
                let userID = LoginStore.shared.state.value.loginUserInfo?.userID ?? ""
                let statistics = seatState.avStatistics.first { $0.userID == userID }
                    ?? seatState.avStatistics.first { $0.userID.isEmpty }
                nextState.audioSampleRate = statistics?.audioSampleRate ?? 0
                guard self.presentationState.deviceStatus != nextState else { return }
                self.presentationState.deviceStatus = nextState
                self.updateDeviceStatus()
            }
            .store(in: &cancellables)
    }
}

// MARK: - Lifecycle Helpers

private extension PusherView {
    private var canCapture: Bool {
        window != nil && UIApplication.shared.applicationState == .active &&
            !didReleaseSession && !isEndingLive && phase != .summary && !isPaused
    }

    private func subscribeCaptureLifecycle() {
        NotificationCenter.default.publisher(for: UIApplication.didEnterBackgroundNotification)
            .sink { [weak self] _ in self?.suspendCapture() }
            .store(in: &cancellables)
        NotificationCenter.default.publisher(for: UIApplication.didBecomeActiveNotification)
            .sink { [weak self] _ in self?.startPreviewIfNeeded() }
            .store(in: &cancellables)
    }

    private func suspendCapture() {
        guard window != nil, !didReleaseSession else { return }
        if backgroundDevices == nil, !isPaused, phase != .summary,
           didStartPreview || isPreviewStarting || needsDeviceCleanup {
            let state = DeviceStore.shared.state.value
            backgroundDevices = (
                camera: state.cameraStatus == .on || isPreviewStarting,
                microphone: state.microphoneStatus == .on || isPreviewStarting,
                isFront: didInitializePreviewSettings ? state.isFrontCamera : true
            )
        }
        stopPreview()
    }

    private func updateElapsedTime() {
        guard let liveStartTime else { return }
        let endTime = (isPaused ? pauseStartTime : liveEndTime) ?? Date()
        elapsedSeconds = max(0, Int(endTime.timeIntervalSince(liveStartTime) - accumulatedPauseDuration))
    }

    private var currentPauseDuration: TimeInterval {
        guard isPaused, let pauseStartTime else { return 0 }
        return max(0, Date().timeIntervalSince(pauseStartTime))
    }

    private func finishPause() {
        pauseTimer?.invalidate()
        pauseTimer = nil
        accumulatedPauseDuration += currentPauseDuration
        pauseStartTime = nil
        pausedSeconds = 0
        isPaused = false
    }

    private func invalidateLifecycle() {
        pushSessionID = nil
        pusherCancellables.removeAll()
        elapsedTimer?.invalidate()
        elapsedTimer = nil
        pauseTimer?.invalidate()
        pauseTimer = nil
    }
}
