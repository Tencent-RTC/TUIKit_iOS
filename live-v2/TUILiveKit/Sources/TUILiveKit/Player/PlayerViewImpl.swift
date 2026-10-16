import AtomicXCore
import Combine
import SnapKit
import UIKit

@MainActor
final class PlayerViewImpl: UIView {
    static let onJoinChannelResultNotification = Notification.Name(
        "\(PlayerView.eventKeyPlayerView).\(PlayerView.eventSubKeyOnJoinChannelResult)"
    )

    var onCloseClicked: (() -> Void)?
    var onJoinLiveClicked: (() -> Void)?

    private let videoView = PlayerVideoView()
    private let overlayView = LivingView()
    private let previewView = PreviewView()
    private let summaryView = SummaryView()
    private let closeButton = UIButton(type: .custom)
    private let player: AtomicPlayer = AtomicPlayer()

    let statusPublisher = CurrentValueSubject<PlayerStatus, Never>(.idle)

    var joinLiveEntranceEnabled = true {
        didSet {
            guard joinLiveEntranceEnabled != oldValue else { return }
            applyStatusPresentation()
        }
    }

    private(set) var liveInfo: LiveInfo?
    private var activeToast: LiveToast?
    private var isJoinedChannel = false
    private var isEntranceInitiatedJoin = false
    private var joiningLiveID: String?
    private var isClosing = false
    private var activatedRoomLiveID: String?
    private var playingLiveID: String?
    private var backgroundCamera: (liveID: String, isFront: Bool)?
    private var cameraRestoreID: UUID?
    private var backgroundMicrophone: String?
    private var microphoneRestoreID: UUID?
    private var pendingJoinCompletions: [(Result<LiveInfo, Error>) -> Void] = []
    private var pendingLeaveCompletions: [(Result<Void, Error>) -> Void] = []
    private var cancellables = Set<AnyCancellable>()

    override init(frame: CGRect) {
        super.init(frame: frame)
        configureUI()
        bindOverlay()
        bindGlobalState()
        NotificationCenter.default.publisher(for: UIApplication.didEnterBackgroundNotification)
            .sink { [weak self] _ in self?.suspendCapture() }
            .store(in: &cancellables)
        NotificationCenter.default.publisher(for: UIApplication.didBecomeActiveNotification)
            .sink { [weak self] _ in
                self?.restoreCaptureIfNeeded()
                self?.restoreMicrophoneIfNeeded()
            }
            .store(in: &cancellables)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func didMoveToWindow() {
        super.didMoveToWindow()
        if window == nil {
            activeToast?.dismiss()
            backgroundCamera = nil
            cameraRestoreID = nil
            clearBackgroundMicrophone()
            overlayView.invalidateCoGuestCameraRequests(allowRestore: false)
            overlayView.invalidateCoGuestMicrophoneRequests()
        } else {
            restoreCaptureIfNeeded()
            restoreMicrophoneIfNeeded()
        }
    }

    func setLiveInfo(_ liveInfo: LiveInfo) {
        let liveIDChanged = self.liveInfo?.liveID != liveInfo.liveID
        guard liveIDChanged else {
            self.liveInfo = liveInfo
            videoView.setLiveInfo(liveInfo)
            previewView.bind(liveInfo)
            overlayView.updateLiveInfo(liveInfo)
            return
        }
        activeToast?.dismiss()
        backgroundCamera = nil
        cameraRestoreID = nil
        clearBackgroundMicrophone()
        stopPlay()
        leaveChannelSilently()
        isJoinedChannel = false
        overlayView.prepareForReuse()
        overlayView.dismissInteractionOverlays(resetCommentDraft: true)
        self.liveInfo = liveInfo
        videoView.setLiveInfo(liveInfo)
        previewView.bind(liveInfo)
        overlayView.bind(liveInfo)
        overlayView.setJoinedChannel(isJoinedChannel)
        updateStatus(.idle)
        applyStatusPresentation()
    }

    var contentSafeAreaInsets: UIEdgeInsets = .zero {
        didSet {
            guard contentSafeAreaInsets != oldValue else { return }
            overlayView.setContentSafeAreaInsets(contentSafeAreaInsets)
            layoutMargins = contentSafeAreaInsets
        }
    }

    func startPlay() {
        guard let liveID = liveInfo?.liveID, !liveID.isEmpty else { return }
        clearEndedState()
        if playingLiveID == liveID { return }
        stopPlay()
        playingLiveID = liveID
        videoView.coreView.setLiveID(liveID)
        player.setView(videoView.coreView)
        player.startPlay(url: "livekit://liveid=\(liveID)")
        if !isJoinedChannel {
            updateStatus(.playing)
        }
    }

    func stopPlay() {
        activeToast?.dismiss()
        guard playingLiveID != nil else { return }
        player.stopPlay()
        playingLiveID = nil
        if statusPublisher.value == .playing {
            updateStatus(.idle)
        }
    }

    func setVolume(_ volume: Int) {
        player.setVolume(volume)
    }

    func joinChannel(completion: ((Result<LiveInfo, Error>) -> Void)?) {
        guard let liveInfo else {
            completion?(.failure(PlayerViewImplError.noLiveInfo))
            return
        }
        if isJoinedChannel {
            completion?(.success(liveInfo))
            return
        }
        if let completion {
            pendingJoinCompletions.append(completion)
        }
        if joiningLiveID == liveInfo.liveID {
            return
        }
        joiningLiveID = liveInfo.liveID
        videoView.setLiveInfo(liveInfo)
        KeyMetrics.reportAtomicMetrics(KeyMetrics.liveIntegrationSuccessful)
        KeyMetrics.setComponent(KeyMetrics.componentLiveStream)
        player.joinChannel(liveID: liveInfo.liveID) { [weak self] result in
            Task { @MainActor in
                guard let self else { return }
                guard self.joiningLiveID == liveInfo.liveID,
                      self.liveInfo?.liveID == liveInfo.liveID
                else { return }
                self.joiningLiveID = nil
                switch result {
                case .success:
                    self.handleJoinSuccess(liveInfo: liveInfo)
                case .failure(let error):
                    self.handleJoinFailure(liveInfo: liveInfo, error: error)
                }
            }
        }
    }

    func leaveChannel(completion: ((Result<Void, Error>) -> Void)?) {
        activeToast?.dismiss()
        guard liveInfo?.liveID != nil, isJoinedChannel else {
            completion?(.success(()))
            return
        }
        if let completion {
            pendingLeaveCompletions.append(completion)
        }
        performLeave()
    }

    var liveID: String? {
        liveInfo?.liveID
    }

    private func leaveChannelSilently() {
        guard isJoinedChannel, liveInfo?.liveID != nil else { return }
        performLeave()
    }

    private func performLeave() {
        activeToast?.dismiss()
        backgroundCamera = nil
        cameraRestoreID = nil
        clearBackgroundMicrophone()
        overlayView.deactivateCoGuest()
        deactivateRoomFeatures()
        overlayView.setJoinedChannel(false)
        isJoinedChannel = false
        player.leaveChannel()
        if statusPublisher.value != .end {
            updateStatus(playingLiveID != nil ? .playing : .idle)
        }
        drainPendingLeaveCompletions(.success(()))
    }

    private func handleJoinSuccess(liveInfo: LiveInfo) {
        CoGuestStore.create(liveID: liveInfo.liveID).disConnect(completion: nil)
        isJoinedChannel = true
        let entranceInitiated = isEntranceInitiatedJoin
        isEntranceInitiatedJoin = false
        activateRoomFeatures(liveID: liveInfo.liveID)
        overlayView.setJoinedChannel(true)
        overlayView.bind(liveInfo)
        updateStatus(.inRoom)
        NotificationCenter.default.post(
            name: PlayerViewImpl.onJoinChannelResultNotification,
            object: nil,
            userInfo: [PlayerView.eventSubKeyOnJoinChannelParamsKey: liveInfo]
        )
        if entranceInitiated {
            onJoinLiveClicked?()
        }
        drainPendingJoinCompletions(.success(liveInfo))
    }

    private func handleJoinFailure(liveInfo: LiveInfo, error: Error) {
        isEntranceInitiatedJoin = false
        showSummaryView()
        drainPendingJoinCompletions(.failure(error))
    }

    private func showSummaryView(reason: String? = nil) {
        guard let liveInfo else { return }
        summaryView.bind(liveInfo, reason: reason)
        updateStatus(.end)
        applyStatusPresentation()
    }

    private func clearEndedState() {
        guard statusPublisher.value == .end else { return }
        updateStatus(playingLiveID != nil ? .playing : .idle)
    }

    private func configureUI() {
        backgroundColor = LiveTheme.Color.canvasBackground
        preservesSuperviewLayoutMargins = false
        insetsLayoutMarginsFromSafeArea = false
        layoutMargins = .zero

        configureCloseButton()

        [videoView, overlayView, previewView, summaryView, closeButton].forEach(addSubview)

        [videoView, overlayView, previewView, summaryView].forEach { view in
            view.snp.makeConstraints { make in
                make.edges.equalToSuperview()
            }
        }

        closeButton.snp.makeConstraints { make in
            make.trailing.equalTo(layoutMarginsGuide.snp.trailing).offset(-12)
            make.top.equalTo(layoutMarginsGuide.snp.top).offset(13)
            make.width.height.equalTo(26)
        }

        applyStatusPresentation()
    }

    private func configureCloseButton() {
        closeButton.setImage(LiveKitResources.image(named: "livekit_living_close"), for: .normal)
        closeButton.imageView?.contentMode = .center
        closeButton.backgroundColor = UIColor(red: 0.039, green: 0.047, blue: 0.071, alpha: 0.22)
        closeButton.layer.cornerRadius = 13
        closeButton.layer.masksToBounds = true
        closeButton.layer.borderColor = UIColor.white.withAlphaComponent(0.08).cgColor
        closeButton.layer.borderWidth = 1
        closeButton.accessibilityLabel = LiveKitResources.localizedString("tuilivekit.player.close_room")
        closeButton.addAction(UIAction { [weak self] _ in
            self?.handleClose()
        }, for: .touchUpInside)
    }

    private func applyStatusPresentation() {
        let status = statusPublisher.value
        let showsEntrance = joinLiveEntranceEnabled && (status == .idle || status == .playing)
        let showsOverlay = status == .inRoom || status == .coGuest
        let showsSummary = status == .end

        previewView.isHidden = !showsEntrance
        overlayView.isHidden = !showsOverlay
        summaryView.isHidden = !showsSummary
        videoView.isHidden = showsSummary
        closeButton.isHidden = !showsOverlay

        if showsSummary {
            bringSubviewToFront(summaryView)
        }
        if showsOverlay {
            bringSubviewToFront(closeButton)
        }
        if showsEntrance {
            previewView.setEnabled(true)
        }
    }

    private func bindOverlay() {
        overlayView.onToast = { [weak self] message in
            guard let self, self.isJoinedChannel else { return }
            self.showToast(message)
        }
        overlayView.onCoGuestUiStateChanged = { [weak self] state in
            self?.handleCoGuestUiState(state)
        }
        previewView.onTapEnter = { [weak self] in
            self?.handleJoinLiveEntranceTap()
        }
    }

    private func handleJoinLiveEntranceTap() {
        guard !isJoinedChannel else { return }
        previewView.setEnabled(false)
        isEntranceInitiatedJoin = true
        joinChannel(completion: nil)
    }

    private func handleClose() {
        guard !isClosing else { return }
        isClosing = true
        activeToast?.dismiss()
        leaveChannel { [weak self] _ in
            guard let self else { return }
            BottomSheetView.dismissAll()
            isClosing = false
            onCloseClicked?()
        }
    }

    private func bindGlobalState() {
        player.playerEvent
            .receive(on: DispatchQueue.main)
            .sink { [weak self] event in
                guard let self else { return }
                switch event {
                case .liveEnded:
                    guard self.isJoinedChannel || self.joiningLiveID != nil || self.playingLiveID != nil,
                          self.summaryView.isHidden else { return }
                    self.finishRoom()
                    self.showSummaryView()
                case let .kickedOut(reason, _):
                    guard self.isJoinedChannel || self.joiningLiveID != nil else { return }
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
                    self.finishRoom()
                    self.showSummaryView(reason: message)
                    self.showToast(message)
                default:
                    break
                }
            }
            .store(in: &cancellables)

    }

    private func isCurrentGuest(in liveID: String) -> Bool {
        guard let userID = LoginStore.shared.state.value.loginUserInfo?.userID, !userID.isEmpty else { return false }
        return CoGuestStore.create(liveID: liveID).state.value.connected.contains { $0.userID == userID }
    }

    private func suspendCapture() {
        guard window != nil, isJoinedChannel, statusPublisher.value == .coGuest,
              let liveID = liveInfo?.liveID else { return }
        let userID = LoginStore.shared.state.value.loginUserInfo?.userID ?? ""
        let seat = CoGuestStore.create(liveID: liveID).state.value.connected.first { $0.userID == userID }
        let onSeat = !userID.isEmpty && seat != nil
        let state = DeviceStore.shared.state.value
        if onSeat, backgroundCamera == nil, state.cameraStatus == .on {
            backgroundCamera = (liveID, state.isFrontCamera)
        }
        cameraRestoreID = nil
        let wasOpening = overlayView.invalidateCoGuestCameraRequests(allowRestore: backgroundCamera != nil)
        if (onSeat && backgroundCamera != nil) || wasOpening {
            DeviceStore.shared.closeLocalCamera()
        }
        microphoneRestoreID = nil
        if seat?.microphoneStatus == .on {
            if backgroundMicrophone == nil { backgroundMicrophone = liveID }
            LiveSeatStore.create(liveID: liveID).muteMicrophone()
        }
    }

    private func restoreCaptureIfNeeded() {
        guard let camera = backgroundCamera, cameraRestoreID == nil, window != nil,
              UIApplication.shared.applicationState == .active, isJoinedChannel,
              statusPublisher.value == .coGuest, liveInfo?.liveID == camera.liveID,
              isCurrentGuest(in: camera.liveID) else { return }
        let operationID = UUID()
        cameraRestoreID = operationID
        BeautyPreferences.restore()
        DeviceStore.shared.openLocalCamera(isFront: camera.isFront) { [weak self] result in
            Task { @MainActor in
                guard let self else { return }
                guard self.cameraRestoreID == operationID else {
                    if UIApplication.shared.applicationState != .active ||
                        (self.liveInfo?.liveID == camera.liveID &&
                         (!self.isJoinedChannel || self.statusPublisher.value != .coGuest)) {
                        DeviceStore.shared.closeLocalCamera()
                    }
                    return
                }
                self.cameraRestoreID = nil
                guard UIApplication.shared.applicationState == .active,
                      self.window != nil, self.isJoinedChannel,
                      self.statusPublisher.value == .coGuest,
                      self.liveInfo?.liveID == camera.liveID,
                      self.isCurrentGuest(in: camera.liveID) else {
                    self.backgroundCamera = nil
                    DeviceStore.shared.closeLocalCamera()
                    return
                }
                self.backgroundCamera = nil
                if case .failure = result { DeviceStore.shared.closeLocalCamera() }
            }
        }
    }

    private func clearBackgroundMicrophone() {
        backgroundMicrophone = nil
        microphoneRestoreID = nil
    }

    private func restoreMicrophoneIfNeeded() {
        guard let liveID = backgroundMicrophone, microphoneRestoreID == nil, window != nil,
              UIApplication.shared.applicationState == .active, isJoinedChannel,
              statusPublisher.value == .coGuest, liveInfo?.liveID == liveID,
              let userID = LoginStore.shared.state.value.loginUserInfo?.userID, !userID.isEmpty,
              let seat = CoGuestStore.create(liveID: liveID).state.value.connected.first(where: { $0.userID == userID })
        else { return }
        guard seat.allowOpenMicrophone else {
            clearBackgroundMicrophone()
            return
        }
        let operationID = UUID()
        microphoneRestoreID = operationID
        LiveSeatStore.create(liveID: liveID).unmuteMicrophone { [weak self] result in
            Task { @MainActor in
                guard let self else { return }
                guard self.microphoneRestoreID == operationID else {
                    if self.backgroundMicrophone == liveID, UIApplication.shared.applicationState != .active {
                        LiveSeatStore.create(liveID: liveID).muteMicrophone()
                    }
                    return
                }
                self.microphoneRestoreID = nil
                let currentSeat = CoGuestStore.create(liveID: liveID).state.value.connected.first {
                    $0.userID == userID
                }
                guard case .success = result, self.backgroundMicrophone == liveID,
                      UIApplication.shared.applicationState == .active, self.window != nil,
                      self.isJoinedChannel, self.statusPublisher.value == .coGuest,
                      self.liveInfo?.liveID == liveID, currentSeat?.allowOpenMicrophone == true else {
                    self.clearBackgroundMicrophone()
                    if currentSeat != nil, self.liveInfo?.liveID == liveID,
                       UIApplication.shared.applicationState != .active {
                        LiveSeatStore.create(liveID: liveID).muteMicrophone()
                    }
                    return
                }
                self.backgroundMicrophone = nil
            }
        }
    }

    private func handleCoGuestUiState(_ uiState: CoGuestStatus) {
        guard isJoinedChannel else { return }
        switch uiState {
        case .requesting, .coGuesting:
            updateStatus(.coGuest)
            if uiState == .coGuesting { restoreMicrophoneIfNeeded() }
        case .idle:
            backgroundCamera = nil
            cameraRestoreID = nil
            clearBackgroundMicrophone()
            if statusPublisher.value == .coGuest {
                updateStatus(.inRoom)
            }
        }
    }

    private func updateStatus(_ newValue: PlayerStatus) {
        guard statusPublisher.value != newValue else { return }
        statusPublisher.send(newValue)
        applyStatusPresentation()
    }

    private func showToast(_ message: String) {
        guard window != nil else { return }
        activeToast?.dismiss()
        activeToast = LiveToast.show(message)
    }

    private func finishRoom() {
        joiningLiveID = nil
        backgroundCamera = nil
        cameraRestoreID = nil
        clearBackgroundMicrophone()
        isJoinedChannel = false
        isEntranceInitiatedJoin = false
        stopPlay()
        overlayView.deactivateCoGuest()
        deactivateRoomFeatures()
        overlayView.setJoinedChannel(false)
        BottomSheetView.dismissAll()
        drainPendingJoinCompletions(.failure(PlayerViewImplError.roomEnded))
    }

    private func drainPendingJoinCompletions(_ result: Result<LiveInfo, Error>) {
        let completions = pendingJoinCompletions
        pendingJoinCompletions.removeAll()
        completions.forEach { $0(result) }
    }

    private func drainPendingLeaveCompletions(_ result: Result<Void, Error>) {
        let completions = pendingLeaveCompletions
        pendingLeaveCompletions.removeAll()
        completions.forEach { $0(result) }
    }

    private func activateRoomFeatures(liveID: String) {
        guard activatedRoomLiveID != liveID else { return }
        let hostUserID = liveInfo?.liveOwner.userID ?? ""
        overlayView.activateRoomFeatures(liveID: liveID, hostUserID: hostUserID)
        activatedRoomLiveID = liveID
    }

    private func deactivateRoomFeatures() {
        guard activatedRoomLiveID != nil else { return }
        overlayView.deactivateRoomFeatures()
        activatedRoomLiveID = nil
    }

}

enum PlayerViewImplError: Error {
    case noLiveInfo
    case roomEnded
}
