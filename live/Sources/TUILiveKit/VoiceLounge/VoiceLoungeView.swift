import AtomicXCore
import AVFoundation
import Combine
import TXLiteAVSDK_Professional
import UIKit

public final class VoiceLoungeView: UIView {
    public enum Mode {
        case create(liveID: String)
        case join(liveID: String)
    }

    public var onClose: (() -> Void)?
    public var onSwitchLive: ((LiveInfo) -> Void)?

    public var prepareAccessoryView: UIView? {
        get { isCreating ? prepareView.accessoryView : nil }
        set {
            guard isCreating, stage == .prepare, !didReleaseSession else { return }
            prepareView.accessoryView = newValue
        }
    }

    public var prepareTitle: String {
        get { isCreating ? prepareView.title : "" }
        set {
            guard isCreating, stage == .prepare, !didReleaseSession else { return }
            prepareView.title = newValue
        }
    }

    private let liveID: String
    private let role: VoiceLoungeRole
    private var isCreating: Bool { role == .host }

    private let livingView: VoiceLoungeLivingView
    private let pauseView: VoiceLoungePauseView
    private let roomSettings = VoiceLoungeSettings()
    private let livingActions = VoiceLoungeLivingActions()
    private let giftRankStore = VoiceLoungeGiftRankStore()
    private let coGuest = VoiceLoungeCoGuestStore()
    private let transcriberStore: VoiceLoungeAITranscriberStore
    private let muteCache = VoiceLoungeMuteCache()
    private let seatUIStore: VoiceLoungeSeatStore
    private var seatStore: LiveSeatStore?
    private let liveClock = VoiceLoungeLiveClock()
    private var sessionCancellables = Set<AnyCancellable>()
    private var accountCancellables = Set<AnyCancellable>()
    private var lifecycleCancellables = Set<AnyCancellable>()
    private let screenAwakeOwner = UUID()
    private var pushSessionID: UUID?
    private var isPusherAttached = false
    private var didReleaseSession = false
    private var hasConnected = false
    private lazy var player = AtomicPlayer()
    private var isPlaying = false

    private var hostUserID = ""
    private var hostName = ""
    private var hostAvatarURL = ""

    private enum Stage { case prepare, living, summary }
    private var stage: Stage = .prepare { didSet { updateScreenAwake() } }
    private lazy var prepareView = VoiceLoungePrepareView()
    private lazy var endPanel = VoiceLoungeEndPanel()
    private lazy var summaryView = VoiceLoungeSummaryView()
    private lazy var alertView = VoiceLoungeAlertView()
    private lazy var transcriberPanel = VoiceLoungeAITranscriberPanel()
    private lazy var audienceEndView = VoiceLoungeAudienceEndView()
    private var isFetchingNextLive = false
    private var latestLiveInfo = LiveInfo()
    private var pusherConfig: PusherInfo?
    private var hasConfiguredSeatMode = false
    private var endSummary: PusherEvent.PusherSummary?
    private var totalViewerCount = 1
    private var isEndingLive = false
    private var isMuted = false
    private var isPaused = false
    private var wasMutedBeforePause = false

    private var isLiving = false { didSet { updateScreenAwake() } }
    private var hasJoinedLive = false
    private var sessionToken = 0

    public init(mode: Mode) {
        let id: String
        let role: VoiceLoungeRole
        switch mode {
        case .create(let liveID):
            id = liveID
            role = .host
        case .join(let liveID):
            id = liveID
            role = .audience
        }
        liveID = id
        self.role = role
        let seatUIStore = VoiceLoungeSeatStore(
            liveID: id, role: role, coGuest: coGuest, muteCache: muteCache, settings: roomSettings)
        self.seatUIStore = seatUIStore
        let transcriberStore = VoiceLoungeAITranscriberStore(settings: roomSettings)
        self.transcriberStore = transcriberStore
        self.pauseView = VoiceLoungePauseView(role: role, clock: liveClock)
        self.livingView = VoiceLoungeLivingView(
            liveID: id, seatStore: seatUIStore, giftRankStore: giftRankStore, clock: liveClock,
            livingActions: livingActions, transcriberStore: transcriberStore)
        super.init(frame: .zero)
        setupViews()
        setupConstraints()
        setupStyles()
        setupBindings()
        configureMode()
        if isCreating { subscribeAccountEvents() }
        subscribeAppLifecycle()
    }

    @available(*, unavailable) required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    public override func didMoveToWindow() {
        super.didMoveToWindow()
        if isCreating, window == nil { releasePushSession() }
        updateScreenAwake()
    }

    private var stackedViews: [UIView] {
        isCreating
            ? [prepareView, livingView, summaryView, endPanel, pauseView, alertView, transcriberPanel]
            : [livingView, pauseView, audienceEndView, alertView, transcriberPanel]
    }

    private func setupViews() {
        stackedViews.forEach { child in
            child.translatesAutoresizingMaskIntoConstraints = false
            addSubview(child)
        }
    }

    private func setupConstraints() {
        stackedViews.forEach { child in
            NSLayoutConstraint.activate([
                child.leadingAnchor.constraint(equalTo: leadingAnchor),
                child.trailingAnchor.constraint(equalTo: trailingAnchor),
                child.topAnchor.constraint(equalTo: topAnchor), child.bottomAnchor.constraint(equalTo: bottomAnchor),
            ])
        }
    }

    private func setupStyles() {
        backgroundColor = .black
        guard isCreating else { return }
        livingView.isHidden = true
        summaryView.isHidden = true
    }

    private func setupBindings() {
        coGuest.onToast = { LiveToast.show($0) }
        coGuest.onMicrophoneDenied = { [weak self] in self?.showMicrophonePermissionAlert() }
        livingActions.confirm = { [weak self] title, message, confirmTitle, action in
            guard let self else { return }
            self.alertView.show(
                title: title, message: message, confirmTitle: confirmTitle, skin: self.roomSettings.skin,
                onConfirm: action)
        }
        if isCreating { bindCreateSession() } else { bindJoinSession() }
    }

    private func configureMode() {
        guard !liveID.isEmpty else {
            exitForEmptyLiveID()
            return
        }
        if isCreating { loadHostUserInfo() } else { joinLiving() }
    }

    deinit {
        if isPusherAttached { AtomicPusher.shared.release() }
        if isPlaying { player.stopPlay() }
        if hasJoinedLive { LiveListStore.shared.leaveLive(completion: nil) }
        Task { @MainActor [screenAwakeOwner] in LiveScreenAwake.setEnabled(screenAwakeOwner, false) }
    }
}

private extension VoiceLoungeView {
    var selfUserID: String { LoginStore.shared.state.value.loginUserInfo?.userID ?? "" }

    func updateScreenAwake() {
        let inRoom = isCreating ? stage == .living : isLiving
        let awake =
            window != nil && !didReleaseSession && inRoom && UIApplication.shared.applicationState != .background
        LiveScreenAwake.setEnabled(screenAwakeOwner, awake)
    }

    func subscribeAppLifecycle() {
        NotificationCenter.default.publisher(for: UIApplication.didEnterBackgroundNotification).sink { [weak self] _ in
            self?.updateScreenAwake()
        }.store(in: &lifecycleCancellables)
        NotificationCenter.default.publisher(for: UIApplication.didBecomeActiveNotification).sink { [weak self] _ in
            self?.updateScreenAwake()
        }.store(in: &lifecycleCancellables)
    }

    func showMicrophonePermissionAlert() {
        alertView.show(
            title: .micPermissionTitle, message: .micPermissionMessage, confirmTitle: .micPermissionSettings,
            skin: roomSettings.skin
        ) { VoiceLoungeMicrophonePermission.openSystemSettings() }
    }

    func exitForEmptyLiveID() {
        LiveKitLog.error("[VoiceLounge] liveID is empty, role=\(isCreating ? "host" : "audience")")
        DispatchQueue.main.async { [weak self] in
            LiveToast.show(.emptyLiveId)
            self?.onClose?()
        }
    }

    func syncHostInfo() {
        roomSettings.updateHost(name: hostName, avatarURL: hostAvatarURL, userID: hostUserID)
        giftRankStore.updateHostUserID(hostUserID)
    }

    func activateInteractions(hostUserID: String) {
        giftRankStore.activate(liveID: liveID, role: role, hostUserID: hostUserID)
        transcriberStore.activate(liveID: liveID)
        livingView.activateInteractions(hostUserID: hostUserID)
    }

    func deactivateInteractions() {
        giftRankStore.deactivate()
        transcriberStore.deactivate()
        livingView.deactivateInteractions()
    }
}

private extension VoiceLoungeView {
    func bindCreateSession() {
        prepareView.onExit = { [weak self] in self?.closeHost() }
        prepareView.onStart = { [weak self] input in self?.enterLiving(with: input) }
        livingView.onClose = { [weak self] in
            guard let self else { return }
            let online = LiveAudienceStore.create(liveID: self.liveID).state.value.audienceCount
            self.endPanel.show(viewerCount: Int(min(online, UInt(Int.max))))
        }
        endPanel.onConfirmEnd = { [weak self] in self?.confirmEndLive() }
        summaryView.onExit = { [weak self] in self?.closeHost() }
        bindLivingActions()
        giftRankStore.onPublish = { [weak self] in self?.syncRoomMetaToAudience() }
        pauseView.onResume = { [weak self] in self?.resumeLive() }
    }

    func loadHostUserInfo() {
        let profile = LoginStore.shared.state.value.loginUserInfo
        let nickname = profile?.nickname ?? ""
        hostName = nickname.isEmpty ? selfUserID : nickname
        hostAvatarURL = profile?.avatarURL ?? ""
        hostUserID = selfUserID
        prepareView.updateHost(avatarURL: hostAvatarURL, name: hostName)
        syncHostInfo()
    }

    func syncHostMicOff() { seatUIStore.isHostMicOff = isMuted || isPaused }

    func enterLiving(with input: VoiceLoungeConfig) {
        guard stage == .prepare, !didReleaseSession, window != nil else { return }
        stage = .living
        liveClock.start()
        endSummary = nil
        isEndingLive = false
        roomSettings.config = input
        prepareView.deactivate()
        hostUserID = selfUserID
        syncHostInfo()
        syncHostMicOff()

        livingView.isHidden = false
        summaryView.isHidden = true
        prepareView.isHidden = true

        startPush(with: roomSettings.displayRoomName)
    }

    func confirmEndLive() {
        guard stage == .living, !didReleaseSession, !isEndingLive, isPusherAttached else { return }
        isEndingLive = true
        AtomicPusher.shared.stopPush()
    }

    func enterSummary() {
        guard stage == .living, !didReleaseSession else { return }
        stage = .summary
        pushSessionID = nil
        sessionCancellables.removeAll()
        var summary = VoiceLoungeSummaryData()
        summary.startTime = liveClock.startDate
        summary.endTime = Date()
        if let endSummary {
            summary.viewers = endSummary.totalViewers
            summary.giftCount = endSummary.totalGiftsSent
            summary.gifters = endSummary.totalUniqueGiftSenders
            summary.likes = endSummary.totalLikesReceived
        } else {
            summary.viewers = totalViewerCount
            summary.likes = Int(LikeStore.create(liveID: liveID).state.value.totalLikeCount)
        }
        summaryView.bind(summary)
        liveClock.stop()

        summaryView.isHidden = false
        livingView.isHidden = true
    }

    func closeHost() {
        guard !didReleaseSession else { return }
        releasePushSession()
        onClose?()
    }

    func startPush(with liveName: String) {
        pushSessionID = UUID()
        hasConnected = false
        subscribePusher()
        AtomicPusher.shared.setView(livingView.coreView)
        isPusherAttached = true
        let config = PusherInfo(
            liveID: liveID, liveName: liveName, coverURL: roomSettings.config.coverURL, isPublicVisible: true,
            metaData: roomSettings.config.metaData)
        pusherConfig = config
        AtomicPusher.shared.startPush(config: config)
        seatStore = LiveSeatStore.create(liveID: liveID)
        seatUIStore.activate()
        seatUIStore.activateAudienceList()
        openHostMicrophone()
    }

    func openHostMicrophone() {
        guard let sessionID = pushSessionID else { return }
        let open: () -> Void = { [weak self] in
            guard let self, self.stage == .living, !self.didReleaseSession, self.pushSessionID == sessionID,
                self.window != nil
            else { return }
            if DeviceStore.shared.state.value.microphoneStatus == .on {
                if !self.isMuted { self.seatStore?.unmuteMicrophone(completion: nil) }
                return
            }
            DeviceStore.shared.openLocalMicrophone { [weak self] result in
                Task { @MainActor in
                    guard let self, !self.didReleaseSession, self.pushSessionID == sessionID, self.stage == .living
                    else { return }
                    if case .success = result, self.isMuted || self.isPaused { self.seatStore?.muteMicrophone() }
                }
            }
        }
        VoiceLoungeMicrophonePermission.request(
            onGranted: open,
            onDenied: { [weak self] in
                guard let self, self.stage == .living, !self.didReleaseSession, self.pushSessionID == sessionID,
                    self.window != nil
                else { return }
                self.showMicrophonePermissionAlert()
            })
    }

    func syncRoomMetaToAudience() {
        guard stage == .living, !didReleaseSession, var config = pusherConfig else { return }
        config.metaData = roomSettings.config.metaData.merging(giftRankStore.publishedMetaData()) { _, rank in rank }
            .merging([VoiceLoungeConfig.pausedMetaKey: isPaused ? "1" : "0"]) { _, paused in paused }
        pusherConfig = config
        AtomicPusher.shared.setMetaData(config.metaData)
    }

    func subscribePusher() {
        sessionCancellables.removeAll()
        guard let sessionID = pushSessionID else { return }

        AtomicPusher.shared.state.subscribe().receive(on: DispatchQueue.main).sink { [weak self] state in
            guard let self, !self.didReleaseSession, self.pushSessionID == sessionID, self.stage == .living,
                state.pusherInfo.liveID == self.liveID
            else { return }
            self.applyPusherState(state)
        }.store(in: &sessionCancellables)

        AtomicPusher.shared.pusherEvent.receive(on: DispatchQueue.main).sink { [weak self] event in
            guard let self, !self.didReleaseSession, self.pushSessionID == sessionID, self.window != nil else { return }
            self.handlePusherEvent(event)
        }.store(in: &sessionCancellables)
    }

    func applyPusherState(_ state: PusherState) {
        totalViewerCount = max(0, state.totalViewerCount)
        if state.networkState == .CONNECTED, !hasConfiguredSeatMode, let seatStore {
            hasConnected = true
            hasConfiguredSeatMode = true
            applyHifiAudioConfig()
            coGuest.activate(liveID: liveID, role: role)
            seatUIStore.enableStaleCleanup()
            activateInteractions(hostUserID: selfUserID)
            let sessionID = pushSessionID
            seatStore.setSeatMode(mode: .apply) { [weak self] result in
                Task { @MainActor in
                    guard let self, !self.didReleaseSession, self.pushSessionID == sessionID, self.stage == .living
                    else { return }
                    if case .failure(let error) = result { LiveToast.show(LiveKitErrorText.message(error)) }
                }
            }
        }
    }

    func handlePusherEvent(_ event: PusherEvent) {
        switch event {
        case let .pusherError(code, message):
            guard code != .OK else { return }
            LiveKitLog.error("[VoiceLounge] push failed liveID=\(liveID) code=\(code.rawValue) message=\(message)")
            if code == .ERROR_START_PUSH_REQUEST_FAILED, !hasConnected, !isEndingLive {
                returnToPrepareAfterStartFailure()
            }
            let key = code == .ERROR_START_PUSH_REQUEST_FAILED ? "start_failed" : "operation_failed"
            LiveToast.show(LiveKitResources.localizedString("tuilivekit.pusher.error.\(key)"))
        case .liveEnded(_, let summary):
            endSummary = summary
            enterSummary()
        case .kickedOut:
            endSummary = nil
            enterSummary()
        @unknown default: break
        }
    }

    func releasePushSession() {
        guard !didReleaseSession else { return }
        didReleaseSession = true
        updateScreenAwake()
        let hadSession = pushSessionID != nil
        pushSessionID = nil
        sessionCancellables.removeAll()
        accountCancellables.removeAll()
        prepareView.deactivate()
        liveClock.stop()
        coGuest.deactivate()
        deactivateInteractions()
        hasConfiguredSeatMode = false
        pusherConfig = nil
        seatStore = nil
        seatUIStore.deactivate()
        isPaused = false
        pauseView.setPaused(false)
        livingView.removeFromSuperview()
        guard isPusherAttached else { return }
        isPusherAttached = false
        DeviceStore.shared.closeLocalMicrophone()
        if hadSession, stage == .living, !isEndingLive { AtomicPusher.shared.stopPush() }
        AtomicPusher.shared.release()
    }

    func returnToPrepareAfterStartFailure() {
        pushSessionID = nil
        sessionCancellables.removeAll()
        coGuest.deactivate()
        deactivateInteractions()
        seatUIStore.deactivate()
        seatStore = nil
        pusherConfig = nil
        hasConfiguredSeatMode = false
        liveClock.stop()
        stage = .prepare
        livingView.isHidden = true
        summaryView.isHidden = true
        prepareView.isHidden = false
    }

    func subscribeAccountEvents() {
        LoginStore.shared.loginEventPublisher.receive(on: DispatchQueue.main).sink { [weak self] event in
            guard let self, !self.didReleaseSession, self.window != nil, case .kickedOffline = event else { return }
            if self.stage == .living {
                self.confirmEndLive()
            } else if self.stage == .prepare {
                DispatchQueue.main.async { [weak self] in self?.closeHost() }
            }
        }.store(in: &accountCancellables)
    }

    func bindLivingActions() {
        livingActions.isMuted = { [weak self] in self?.isMuted ?? false }
        livingActions.pauseLive = { [weak self] in self?.pauseLive() }
        livingActions.toggleMute = { [weak self] in self?.handleLivingToggleMute() }
        livingActions.changeLayout = { [weak self] layout in
            if layout == .duo { self?.confirmSwitchToDuo(layout) } else { self?.applyLivingLayout(layout) }
        }
        livingActions.changeTopic = { [weak self] topic in self?.commitTopic(topic) }
        livingActions.updateTranscriber = { [weak self] state in self?.applyTranscriberState(state) }
        livingActions.showTranscriberPanel = { [weak self] in self?.presentTranscriberPanel() }
    }

    func applyTranscriberState(_ state: VoiceLoungeAITranscriberPanel.State) {
        let current = roomSettings.config
        var next = current
        next.isTranscriberEnabled = state.isEnabled
        next.transcriberShowOriginal = state.showOriginal
        next.transcriberScale = state.scale
        next.transcriberLanguage = state.language
        if next != current {
            let enabledChanged = next.isTranscriberEnabled != current.isTranscriberEnabled
            roomSettings.config = next
            if enabledChanged { syncRoomMetaToAudience() }
        }
        if state.saveAsDefault {
            VoiceLoungeTranscriberDefaults.current = VoiceLoungeTranscriberDefaults(
                isEnabled: state.isEnabled, showOriginal: state.showOriginal, scale: state.scale,
                language: state.language)
        }
    }

    func presentTranscriberPanel() {
        let state = VoiceLoungeAITranscriberPanel.State(
            isEnabled: roomSettings.isTranscriberEnabled, showOriginal: roomSettings.transcriberShowOriginal,
            scale: roomSettings.transcriberScale, language: roomSettings.transcriberLanguage, saveAsDefault: false)
        transcriberPanel.onStateChanged = { [weak self] s in self?.applyTranscriberState(s) }
        transcriberPanel.show(initial: state, skin: roomSettings.skin)
    }

    func pauseLive() {
        guard stage == .living, !didReleaseSession, !isEndingLive, !isPaused else { return }
        isPaused = true
        liveClock.pause()
        pauseView.setPaused(true)
        livingView.setHostPaused(true)
        wasMutedBeforePause = isMuted
        if let seatStore, !isMuted { seatStore.muteMicrophone() }
        isMuted = true
        DeviceStore.shared.closeLocalMicrophone()
        syncHostMicOff()
        coGuest.broadcastPause(true)
        syncRoomMetaToAudience()
    }

    func resumeLive() {
        guard stage == .living, !didReleaseSession, !isEndingLive, isPaused else { return }
        liveClock.resume()
        isPaused = false
        pauseView.setPaused(false)
        livingView.setHostPaused(false)
        isMuted = wasMutedBeforePause
        openHostMicrophone()
        if !wasMutedBeforePause { seatStore?.unmuteMicrophone(completion: nil) }
        syncHostMicOff()
        coGuest.broadcastPause(false)
        syncRoomMetaToAudience()
    }

    func handleLivingToggleMute() {
        guard stage == .living, !didReleaseSession, !isEndingLive else { return }
        isMuted.toggle()
        if let seatStore {
            if isMuted { seatStore.muteMicrophone() } else { seatStore.unmuteMicrophone(completion: nil) }
        }
        syncHostMicOff()
    }

    func applyLivingLayout(_ layout: VoiceLoungeSeatLayout) {
        roomSettings.config.seatLayout = layout
        syncRoomMetaToAudience()
    }

    func confirmSwitchToDuo(_ layout: VoiceLoungeSeatLayout) {
        alertView.show(
            title: .duoConfirmTitle, message: .duoConfirmMessage, confirmTitle: .duoConfirmOk, skin: roomSettings.skin
        ) { [weak self] in self?.kickAllGuestsThenApply(layout) }
    }

    func kickAllGuestsThenApply(_ layout: VoiceLoungeSeatLayout) {
        if let seatStore {
            let guestIDs = seatUIStore.seatList.map(\.userInfo.userID).filter { !$0.isEmpty && $0 != selfUserID }
            for userID in guestIDs { seatStore.kickUserOutOfSeat(userID: userID, completion: nil) }
        }
        applyLivingLayout(layout)
    }

    func commitTopic(_ topic: String) {
        let trimmed = topic.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed != roomSettings.topic else { return }
        roomSettings.config.topic = trimmed
        syncRoomMetaToAudience()
        let text: String = trimmed.isEmpty ? .topicCleared : .topicChanged(trimmed)
        BarrageStore.create(liveID: liveID).sendTextMessage(text: text, extensionInfo: nil) { [liveID] result in
            guard case .failure(let error) = result else { return }
            LiveKitLog.error(
                "[VoiceLounge] send topic barrage failed liveID=\(liveID) code=\(error.code) message=\(error.message)")
        }
    }
}

private extension VoiceLoungeView {
    func bindJoinSession() {
        livingActions.showTranscriberPanel = { [weak self] in self?.presentTranscriberPanel() }
        livingView.onClose = { [weak self] in self?.leaveRoom() }
        pauseView.onResume = { [weak self] in self?.leaveRoom() }
        audienceEndView.onBack = { [weak self] in self?.onClose?() }
        audienceEndView.onSwipeUp = { [weak self] in self?.switchToNextLive() }
        coGuest.onHostPauseChanged = { [weak self] paused in self?.applyHostPause(paused) }
        coGuest.onMicOpenRequested = { [weak self] in
            guard let self, self.coGuest.guestStatus == .onSeat else { return }
            let selfID = self.selfUserID
            let info = self.seatUIStore.seatList.first { $0.userInfo.userID == selfID }?.userInfo
            guard info?.allowOpenMicrophone != false, info?.microphoneStatus != .on else { return }
            self.seatStore?.unmuteMicrophone(completion: nil)
        }
    }

    func joinLiving() {
        isLiving = true
        liveClock.start()

        var config = VoiceLoungeConfig()
        config.roomName = .loadingName
        config.isTranscriberEnabled = true
        roomSettings.config = config
        syncHostInfo()

        startPlay()
        subscribeRoom()
    }

    func leaveRoom() {
        isLiving = false
        liveClock.stop()
        releasePlaySession()
        onClose?()
    }

    func startPlay() {
        livingView.coreView.setLiveID(liveID)
        sessionToken += 1
        let token = sessionToken
        if !isPlaying {
            isPlaying = true
            player.setView(livingView.coreView)
            player.startPlay(url: "livekit://liveid=\(liveID)")
        }
        LiveListStore.shared.joinLive(liveID: liveID) { [weak self] result in
            Task { @MainActor in
                guard let self, token == self.sessionToken else { return }
                switch result {
                case .success(let info):
                    self.hasJoinedLive = true
                    self.applyHifiAudioConfig()
                    self.activateInteractions(hostUserID: info.liveOwner.userID)
                    self.coGuest.activate(liveID: self.liveID, role: self.role)
                    self.seatUIStore.activateAudienceList()
                    self.applyLiveInfo(info)
                    self.queryRoomMeta()
                case .failure(let error):
                    LiveKitLog.error(
                        "[VoiceLounge] joinLive failed liveID=\(self.liveID) code=\(error.code) message=\(error.message)"
                    )
                    LiveToast.show(LiveKitErrorText.message(error))
                }
            }
        }
        LiveListStore.shared.fetchLiveInfo(liveID: liveID) { [weak self] result in
            Task { @MainActor in
                guard let self, token == self.sessionToken else { return }
                switch result {
                case .success(let info): self.applyLiveInfo(info)
                case .failure(let error):
                    LiveKitLog.error(
                        "[VoiceLounge] fetchLiveInfo failed liveID=\(self.liveID) code=\(error.code) message=\(error.message)"
                    )
                }
            }
        }
        seatStore = LiveSeatStore.create(liveID: liveID)
        seatUIStore.activate()
    }

    func subscribeRoom() {
        sessionCancellables.removeAll()

        LiveListStore.shared.state.subscribe().receive(on: DispatchQueue.main).sink { [weak self] state in
            guard let self else { return }
            let info = state.currentLive
            if !info.liveID.isEmpty, info.liveID == self.liveID { self.applyLiveInfo(info) }
        }.store(in: &sessionCancellables)

        seatStore?.liveSeatEventPublisher.receive(on: DispatchQueue.main).sink { [weak self] event in
            switch event {
            case .onLocalMicrophoneClosedByAdmin: self?.seatStore?.muteMicrophone()
            case .onLocalMicrophoneOpenedByAdmin:
                guard let self, self.coGuest.guestStatus == .onSeat else { return }
                self.seatStore?.unmuteMicrophone(completion: nil)
            default: break
            }
        }.store(in: &sessionCancellables)

        LiveListStore.shared.liveListEventPublisher.receive(on: DispatchQueue.main).sink { [weak self] event in
            guard let self else { return }
            if case .onLiveEnded(let endedID, _, _) = event, endedID == self.liveID { self.showAudienceEnd() }
        }.store(in: &sessionCancellables)

        player.playerEvent.receive(on: DispatchQueue.main).sink { [weak self] event in
            guard let self else { return }
            switch event {
            case .liveEnded: self.showAudienceEnd()
            case let .kickedOut(reason, _):
                let key: String
                switch reason {
                case .BY_ADMIN: key = "removed"
                case .BY_LOGGED_ON_OTHER_DEVICE: key = "other_device"
                case .BY_SERVER: key = "server"
                case .FOR_NETWORK_DISCONNECTED: key = "network"
                case .FOR_LIVE_CHANNEL_EXPIRED: key = "expired"
                @unknown default: key = "removed"
                }
                let message = LiveKitResources.localizedString("tuilivekit.player.interruption." + key)
                self.showAudienceEnd(reason: message)
                LiveToast.show(message)
            default: break
            }
        }.store(in: &sessionCancellables)
    }

    func showAudienceEnd(reason: String? = nil) {
        guard isLiving else { return }
        isLiving = false
        liveClock.stop()
        BottomSheetView.dismissAll()
        endEditing(true)
        releasePlaySession()
        audienceEndView.show(liveInfo: latestLiveInfo, reason: reason)
    }

    func switchToNextLive() {
        guard !isFetchingNextLive else { return }
        isFetchingNextLive = true
        let currentID = liveID
        let selfID = selfUserID
        LiveListStore.shared.fetchLiveList(cursor: "", count: 20) { [weak self] result in
            Task { @MainActor in
                guard let self else { return }
                self.isFetchingNextLive = false
                switch result {
                case .success:
                    let next = LiveListStore.shared.state.value.liveList.first {
                        !$0.liveID.isEmpty && $0.liveID != currentID && $0.liveOwner.userID != selfID
                    }
                    if let next, let onSwitchLive = self.onSwitchLive {
                        onSwitchLive(next)
                    } else {
                        LiveToast.show(.noMoreLive)
                    }
                case .failure(let error):
                    LiveKitLog.error("[VoiceLounge] fetchLiveList failed code=\(error.code) message=\(error.message)")
                    LiveToast.show(LiveKitErrorText.message(error))
                }
            }
        }
    }

    func applyLiveInfo(_ info: LiveInfo) {
        if !info.liveOwner.userID.isEmpty { latestLiveInfo = info }
        hostName = info.liveOwner.userName
        hostAvatarURL = info.liveOwner.avatarURL
        if !info.liveOwner.userID.isEmpty, info.liveOwner.userID != hostUserID {
            hostUserID = info.liveOwner.userID
            livingView.updateHostUserID(hostUserID)
        }
        syncHostInfo()

        var config = roomSettings.config
        config.roomName = info.liveName.isEmpty ? liveID : info.liveName
        if VoiceLoungeConfig.hasMeta(in: info.metaData) { config.applyMeta(info.metaData, includeTranscriber: false) }
        roomSettings.config = config
        if let paused = info.metaData[VoiceLoungeConfig.pausedMetaKey] { applyHostPause(paused == "1") }
    }

    func queryRoomMeta() {
        let keys = VoiceLoungeConfig.metaKeys + [VoiceLoungeConfig.pausedMetaKey]
        let token = sessionToken
        LiveListStore.shared.queryMetaData(keys: keys) { [weak self] result in
            Task { @MainActor in
                guard let self, token == self.sessionToken else { return }
                defer { self.livingView.showOpeningTopic() }
                let metaData: [String: String]
                switch result {
                case .success(let value): metaData = value
                case .failure(let error):
                    LiveKitLog.error(
                        "[VoiceLounge] queryMetaData failed liveID=\(self.liveID) code=\(error.code) message=\(error.message)"
                    )
                    return
                }
                if let paused = metaData[VoiceLoungeConfig.pausedMetaKey] { self.applyHostPause(paused == "1") }
                guard VoiceLoungeConfig.hasMeta(in: metaData) else { return }
                self.roomSettings.config.applyMeta(metaData, includeTranscriber: false)
            }
        }
    }

    func applyHostPause(_ paused: Bool) {
        guard isLiving else { return }
        pauseView.setPaused(paused)
        if paused {
            BottomSheetView.dismissAll()
            endEditing(true)
        }
    }

    func releasePlaySession() {
        sessionToken += 1
        coGuest.deactivate()
        deactivateInteractions()
        sessionCancellables.removeAll()
        pauseView.setPaused(false)
        if isPlaying {
            player.stopPlay()
            isPlaying = false
        }
        if hasJoinedLive {
            LiveListStore.shared.leaveLive(completion: nil)
            hasJoinedLive = false
        }
        seatStore = nil
        seatUIStore.deactivate()
    }
}

private extension VoiceLoungeView {
    static let hifiAudioQualityJSON = "{\"api\":\"setAudioQualityEx\",\"params\":{\"audioScene\":18}}"
    static let hifiPrivateConfigJSON =
        "{\"api\":\"setPrivateConfig\",\"params\":{\"configs\":["
        + "{\"key\":\"Liteav.Audio.common.agc.version\",\"default\":\"0\",\"value\":\"6\"},"
        + "{\"key\":\"Liteav.Audio.common.ai.ec.model.type\",\"default\":\"0\",\"value\":\"6\"}" + "]}}"

    func applyHifiAudioConfig() {
        let cloud = TRTCCloud.sharedInstance()
        cloud.callExperimentalAPI(Self.hifiAudioQualityJSON)
        cloud.callExperimentalAPI(Self.hifiPrivateConfigJSON)
    }
}

private extension String {
    static var emptyLiveId: String { LiveKitResources.localizedString("tuilivekit.voiceroom.error.empty_live_id") }
    static func topicChanged(_ args: CVarArg...) -> String {
        LiveKitResources.localizedFormat("tuilivekit.voiceroom.topic.changed", args)
    }
    static var topicCleared: String { LiveKitResources.localizedString("tuilivekit.voiceroom.topic.cleared") }
    static var duoConfirmOk: String { LiveKitResources.localizedString("tuilivekit.voiceroom.layout.duo_confirm_ok") }
    static var duoConfirmMessage: String {
        LiveKitResources.localizedString("tuilivekit.voiceroom.layout.duo_confirm_message")
    }
    static var duoConfirmTitle: String {
        LiveKitResources.localizedString("tuilivekit.voiceroom.layout.duo_confirm_title")
    }
    static var noMoreLive: String { LiveKitResources.localizedString("tuilivekit.voiceroom.end.no_more_live") }
    static var loadingName: String { LiveKitResources.localizedString("tuilivekit.voiceroom.room.loading_name") }
    static var micPermissionTitle: String {
        LiveKitResources.localizedString("tuilivekit.voiceroom.mic_permission.title")
    }
    static var micPermissionMessage: String {
        LiveKitResources.localizedString("tuilivekit.voiceroom.mic_permission.message")
    }
    static var micPermissionSettings: String {
        LiveKitResources.localizedString("tuilivekit.voiceroom.mic_permission.settings")
    }
}
