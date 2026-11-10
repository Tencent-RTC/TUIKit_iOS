import AtomicXCore
import AVFoundation
import Combine
import UIKit

public final class VoiceLoungeView: UIView {
    public enum Mode {
        case create(liveID: String)
        case join(liveID: String)
    }

    public var onClose: (() -> Void)?

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

    private var hostUserID = ""
    private var hostName = ""
    private var hostAvatarURL = ""

    private enum Stage { case prepare, living, summary }
    private var stage: Stage = .prepare
    private lazy var prepareView = VoiceLoungePrepareView()
    private lazy var endPanel = VoiceLoungeEndPanel()
    private lazy var summaryView = VoiceLoungeSummaryView()
    private lazy var alertView = VoiceLoungeAlertView()
    private var pusherConfig: PusherInfo?
    private var hasConfiguredSeatMode = false
    private var endSummary: PusherEvent.PusherSummary?
    private var totalViewerCount = 1
    private var isEndingLive = false
    private var isMuted = false
    private var isPaused = false
    private var wasMutedBeforePause = false

    private var isLiving = false
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
    }

    @available(*, unavailable) required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    private var stackedViews: [UIView] {
        isCreating ? [prepareView, livingView, summaryView, endPanel, pauseView, alertView] : [livingView, pauseView]
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
        if isCreating { bindCreateSession() } else { bindJoinSession() }
    }

    private func configureMode() {
        guard !liveID.isEmpty else {
            exitForEmptyLiveID()
            return
        }
        if isCreating { loadHostUserInfo() } else { joinLiving() }
    }

    deinit { if role == .host { AtomicPusher.shared.release() } }
}

// MARK: - Shared

private extension VoiceLoungeView {
    var selfUserID: String { LoginStore.shared.state.value.loginUserInfo?.userID ?? "" }

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

// MARK: - Create: Prepare → Living → Summary, pushing audio

private extension VoiceLoungeView {
    func bindCreateSession() {
        prepareView.onExit = { [weak self] in self?.onClose?() }
        prepareView.onStart = { [weak self] input in self?.enterLiving(with: input) }
        livingView.onClose = { [weak self] in
            guard let self else { return }
            let online = LiveAudienceStore.create(liveID: self.liveID).state.value.audienceCount
            self.endPanel.show(viewerCount: Int(min(online, UInt(Int.max))))
        }
        endPanel.onConfirmEnd = { [weak self] in self?.confirmEndLive() }
        summaryView.onExit = { [weak self] in self?.closeSummary() }
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
        guard !isEndingLive else { return }
        isEndingLive = true
        AtomicPusher.shared.stopPush()
    }

    func enterSummary() {
        stage = .summary
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

        summaryView.isHidden = false
        livingView.isHidden = true
    }

    func closeSummary() {
        stage = .prepare
        summaryView.isHidden = true
        livingView.isHidden = true
        prepareView.isHidden = false
        liveClock.stop()
        releasePushSession()
        onClose?()
    }

    func startPush(with liveName: String) {
        subscribePusher()
        AtomicPusher.shared.setView(livingView.coreView)
        let config = PusherInfo(
            liveID: liveID, liveName: liveName, isPublicVisible: true, metaData: roomSettings.config.metaData)
        pusherConfig = config
        AtomicPusher.shared.startPush(config: config)
        seatStore = LiveSeatStore.create(liveID: liveID)
        seatUIStore.activate()
        seatUIStore.activateAudienceList()
        openHostMicrophone()
    }

    func openHostMicrophone() {
        let open: () -> Void = { [weak self] in
            guard let self, self.stage == .living else { return }
            if DeviceStore.shared.state.value.microphoneStatus == .on {
                if !self.isMuted { self.seatStore?.unmuteMicrophone(completion: nil) }
                return
            }
            DeviceStore.shared.openLocalMicrophone { [weak self] result in
                Task { @MainActor in
                    guard let self else { return }
                    if case .success = result, self.isMuted || self.isPaused { self.seatStore?.muteMicrophone() }
                }
            }
        }
        switch AVCaptureDevice.authorizationStatus(for: .audio) {
        case .authorized: open()
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .audio) { granted in
                guard granted else { return }
                Task { @MainActor in open() }
            }
        default: break
        }
    }

    func syncRoomMetaToAudience() {
        guard var config = pusherConfig else { return }
        config.metaData = roomSettings.config.metaData.merging(giftRankStore.publishedMetaData()) { _, rank in rank }
            .merging([VoiceLoungeConfig.pausedMetaKey: isPaused ? "1" : "0"]) { _, paused in paused }
        pusherConfig = config
        AtomicPusher.shared.updateConfig(config: config, modifyFlag: .metaData)
    }

    func subscribePusher() {
        sessionCancellables.removeAll()

        AtomicPusher.shared.state.subscribe().receive(on: DispatchQueue.main).sink { [weak self] state in
            self?.applyPusherState(state)
        }.store(in: &sessionCancellables)

        AtomicPusher.shared.pusherEvent.receive(on: DispatchQueue.main).sink { [weak self] event in
            self?.handlePusherEvent(event)
        }.store(in: &sessionCancellables)
    }

    func applyPusherState(_ state: PusherState) {
        totalViewerCount = max(0, state.totalViewerCount)
        if state.networkState == .CONNECTED, !hasConfiguredSeatMode, let seatStore {
            hasConfiguredSeatMode = true
            coGuest.activate(liveID: liveID, role: role)
            seatUIStore.enableStaleCleanup()
            activateInteractions(hostUserID: selfUserID)
            seatStore.setSeatMode(mode: .apply) { result in
                Task { @MainActor in
                    if case .failure(let error) = result { LiveToast.show(LiveKitErrorText.message(error)) }
                }
            }
        }
    }

    func handlePusherEvent(_ event: PusherEvent) {
        switch event {
        case .pusherError: break
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
        sessionCancellables.removeAll()
        coGuest.deactivate()
        deactivateInteractions()
        DeviceStore.shared.closeLocalMicrophone()
        hasConfiguredSeatMode = false
        pusherConfig = nil
        seatStore = nil
        seatUIStore.deactivate()
        isPaused = false
        pauseView.setPaused(false)
        AtomicPusher.shared.release()
    }

    func bindLivingActions() {
        livingActions.isMuted = { [weak self] in self?.isMuted ?? false }
        livingActions.pauseLive = { [weak self] in self?.pauseLive() }
        livingActions.toggleMute = { [weak self] in self?.handleLivingToggleMute() }
        livingActions.changeLayout = { [weak self] layout in
            if layout == .duo { self?.confirmSwitchToDuo(layout) } else { self?.applyLivingLayout(layout) }
        }
        livingActions.changeTopic = { [weak self] topic in self?.commitTopic(topic) }
    }

    func pauseLive() {
        guard !isPaused else { return }
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
        guard isPaused else { return }
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

// MARK: - Join: enter an existing room, pulling audio

private extension VoiceLoungeView {
    func bindJoinSession() {
        livingView.onClose = { [weak self] in self?.leaveRoom() }
        pauseView.onResume = { [weak self] in self?.leaveRoom() }
        coGuest.onHostPauseChanged = { [weak self] paused in self?.applyHostPause(paused) }
        coGuest.onMicOpenRequested = { [weak self] in
            guard let self, self.coGuest.guestStatus == .onSeat else { return }
            let selfID = self.selfUserID
            let info = self.seatUIStore.seatList.first { $0.userInfo.userID == selfID }?.userInfo
            guard info?.allowOpenMicrophone != false, info?.microphoneStatus != .on else { return }
            self.seatStore?.unmuteMicrophone(completion: nil)
            LiveToast.show(.microphoneUnlocked)
        }
    }

    func joinLiving() {
        isLiving = true
        liveClock.start()

        var config = VoiceLoungeConfig()
        config.roomName = .loadingName
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
        LiveListStore.shared.joinLive(liveID: liveID) { [weak self] result in
            Task { @MainActor in
                guard let self, token == self.sessionToken else { return }
                switch result {
                case .success(let info):
                    self.hasJoinedLive = true
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
            case .onLocalMicrophoneClosedByAdmin:
                LiveToast.show(.microphoneLocked)
                self?.seatStore?.muteMicrophone()
            case .onLocalMicrophoneOpenedByAdmin:
                LiveToast.show(.microphoneUnlocked)
                guard let self, self.coGuest.guestStatus == .onSeat else { return }
                self.seatStore?.unmuteMicrophone(completion: nil)
            default: break
            }
        }.store(in: &sessionCancellables)

        LiveListStore.shared.liveListEventPublisher.receive(on: DispatchQueue.main).sink { [weak self] event in
            guard let self else { return }
            if case .onLiveEnded(let endedID, _, _) = event, endedID == self.liveID { self.leaveRoom() }
        }.store(in: &sessionCancellables)
    }

    func applyLiveInfo(_ info: LiveInfo) {
        hostName = info.liveOwner.userName
        hostAvatarURL = info.liveOwner.avatarURL
        if !info.liveOwner.userID.isEmpty, info.liveOwner.userID != hostUserID {
            hostUserID = info.liveOwner.userID
            livingView.updateHostUserID(hostUserID)
        }
        syncHostInfo()

        var config = roomSettings.config
        config.roomName = info.liveName.isEmpty ? liveID : info.liveName
        if VoiceLoungeConfig.hasMeta(in: info.metaData) { config.applyMeta(info.metaData) }
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
                self.roomSettings.config.applyMeta(metaData)
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
        if hasJoinedLive {
            LiveListStore.shared.leaveLive(completion: nil)
            hasJoinedLive = false
        }
        seatStore = nil
        seatUIStore.deactivate()
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
    static var loadingName: String { LiveKitResources.localizedString("tuilivekit.voiceroom.room.loading_name") }
    static var microphoneLocked: String {
        LiveKitResources.localizedString("tuilivekit.player.coguest.microphone_locked")
    }
    static var microphoneUnlocked: String {
        LiveKitResources.localizedString("tuilivekit.player.coguest.microphone_unlocked")
    }
}
