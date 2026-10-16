import AtomicXCore
import Combine
import Kingfisher
import SnapKit
import UIKit

enum CoGuestStatus: Equatable {
    case idle
    case requesting
    case coGuesting
}

final class CoGuestIcon: UIView {

    let uiState = CurrentValueSubject<CoGuestStatus, Never>(.idle)
    let openCameraAfterAccept = CurrentValueSubject<Bool, Never>(true)
    var onUiStateChanged: ((CoGuestStatus) -> Void)?

    private let entryImage = AnimatedImageView()
    private let idleImage = LiveKitResources.image(named: "livekit_coguest_idle")
    private let connectedImage = LiveKitResources.image(named: "livekit_coguest_connected")
    private let waveProvider = LiveKitResources.bundle
        .url(forResource: "livekit_coguest_wave", withExtension: "gif")
        .map { LocalFileImageDataProvider(fileURL: $0) }

    private lazy var applyPanel = RequestingPanel(
        uiState: uiState,
        openCameraAfterAccept: openCameraAfterAccept,
        updateUiState: { [weak self] in self?.updateUiState($0) }
    )
    private lazy var connectedPanel = CoGuestingPanel(openCameraAfterAccept: openCameraAfterAccept)
    private let settingsPanel = SettingsPanel()

    private var liveInfo: LiveInfo?
    private var subscribedLiveID: String?
    private var uiStateCancellable: AnyCancellable?
    private var storeCancellables = Set<AnyCancellable>()
    private var connected: [SeatUserInfo] = []
    private var cameraRequestID: UUID?
    private var allowCameraRestore = false
    private var microphoneRequestID: UUID?

    override init(frame: CGRect) {
        super.init(frame: frame)
        configureEntry()
        configurePanels()
        entryImage.image = idleImage
        uiStateCancellable = uiState
            .receive(on: DispatchQueue.main)
            .sink { [weak self] state in self?.applyUiState(state) }
    }

    private func updateUiState(_ state: CoGuestStatus) {
        guard uiState.value != state else { return }
        if uiState.value == .coGuesting, state == .idle {
            invalidateMicrophoneRequests()
            DeviceStore.shared.closeLocalMicrophone()
        }
        uiState.send(state)
        onUiStateChanged?(state)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override var intrinsicContentSize: CGSize {
        CGSize(width: 39, height: 39)
    }

    override func didMoveToWindow() {
        super.didMoveToWindow()
        guard let window else { return }
        attachPanelIfNeeded(applyPanel, to: window)
        attachPanelIfNeeded(connectedPanel, to: window)
        attachPanelIfNeeded(settingsPanel, to: window)
    }

    func activate(_ liveInfo: LiveInfo) {
        guard !liveInfo.liveID.isEmpty else { return }
        self.liveInfo = liveInfo
        applyPanel.bind(liveInfo)
        connectedPanel.bind(liveID: liveInfo.liveID)
        subscribeCoGuestStore(liveID: liveInfo.liveID)
    }

    @discardableResult
    func invalidateCameraRequests(allowRestore: Bool) -> Bool {
        let wasOpening = cameraRequestID != nil
        let panelWasOpening = connectedPanel.invalidateCameraRequest(allowRestore: allowRestore)
        cameraRequestID = nil
        allowCameraRestore = allowRestore
        return wasOpening || panelWasOpening
    }

    func invalidateMicrophoneRequests() {
        microphoneRequestID = nil
    }

    func deactivate() {
        invalidateCameraRequests(allowRestore: false)
        invalidateMicrophoneRequests()
        storeCancellables.removeAll()
        subscribedLiveID = nil
        connected = []
        liveInfo = nil
        updateUiState(.idle)
        openCameraAfterAccept.send(true)
        BottomSheetView.dismissAll()
        DeviceStore.shared.closeLocalMicrophone()
        DeviceStore.shared.closeLocalCamera()
    }

    private func subscribeCoGuestStore(liveID: String) {
        storeCancellables.removeAll()
        let store = CoGuestStore.create(liveID: liveID)
        subscribedLiveID = liveID
        connected = store.state.value.connected
        store.state.subscribe()
            .receive(on: DispatchQueue.main)
            .sink { [weak self] state in self?.applyCoGuestState(state) }
            .store(in: &storeCancellables)
        store.guestEventPublisher
            .receive(on: DispatchQueue.main)
            .sink { [weak self] event in self?.handleGuestEvent(event) }
            .store(in: &storeCancellables)
    }

    private func applyCoGuestState(_ state: CoGuestState) {
        if (uiState.value == .requesting) { return }
        let selfUserID = LoginStore.shared.state.value.loginUserInfo?.userID ?? ""
        guard !selfUserID.isEmpty else { return }
        let meConnected = state.connected.contains { $0.userID == selfUserID }
        let next: CoGuestStatus = meConnected ? .coGuesting : .idle
        updateUiState(next)

        let lastSeatUserInfo = connected.first(where: { $0.userID == selfUserID })
        connected = state.connected
        guard let lastSeatUserInfo,
              let seatUserInfo = state.connected.first(where: { $0.userID == selfUserID })
        else { return }
        if lastSeatUserInfo.allowOpenMicrophone != seatUserInfo.allowOpenMicrophone {
            let key = seatUserInfo.allowOpenMicrophone
                ? "tuilivekit.player.coguest.microphone_unlocked"
                : "tuilivekit.player.coguest.microphone_locked"
            LiveToast.show(LiveKitResources.localizedString(key))
        }
    }

    private func handleGuestEvent(_ event: GuestEvent) {
        switch event {
        case .onGuestApplicationResponded(let isAccept, _):
            if isAccept {
                BottomSheetView.dismissAll()
                let openCamera = openCameraAfterAccept.value
                updateUiState(.coGuesting)
                if UIApplication.shared.applicationState == .active, window != nil {
                    let requestID = UUID()
                    microphoneRequestID = requestID
                    DeviceStore.shared.openLocalMicrophone { [weak self] _ in
                        Task { @MainActor in
                            guard let self else {
                                if UIApplication.shared.applicationState != .active {
                                    DeviceStore.shared.closeLocalMicrophone()
                                }
                                return
                            }
                            if self.microphoneRequestID == requestID {
                                self.microphoneRequestID = nil
                                if self.liveInfo == nil || self.uiState.value != .coGuesting {
                                    DeviceStore.shared.closeLocalMicrophone()
                                }
                            } else if self.microphoneRequestID == nil {
                                DeviceStore.shared.closeLocalMicrophone()
                            }
                        }
                    }
                }
                if openCamera, UIApplication.shared.applicationState == .active {
                    let requestID = UUID()
                    cameraRequestID = requestID
                    BeautyPreferences.restore()
                    DeviceStore.shared.openLocalCamera(
                        isFront: DeviceStore.shared.state.value.isFrontCamera
                    ) { [weak self] _ in
                        Task { @MainActor in
                            guard let self else {
                                if UIApplication.shared.applicationState != .active {
                                    DeviceStore.shared.closeLocalCamera()
                                }
                                return
                            }
                            if self.cameraRequestID == requestID {
                                self.cameraRequestID = nil
                                if UIApplication.shared.applicationState != .active ||
                                    self.liveInfo == nil || self.uiState.value != .coGuesting {
                                    DeviceStore.shared.closeLocalCamera()
                                }
                            } else if UIApplication.shared.applicationState != .active ||
                                (!self.allowCameraRestore && self.cameraRequestID == nil) {
                                DeviceStore.shared.closeLocalCamera()
                            }
                        }
                    }
                }
            } else {
                LiveToast.show(
                    LiveKitResources.localizedString("tuilivekit.player.coguest.error.rejected")
                )
                openCameraAfterAccept.send(true)
                updateUiState(.idle)
            }
        case .onGuestApplicationNoResponse(let reason):
            let key = reason == .alreadySeated
                ? "tuilivekit.player.coguest.error.already_seated"
                : "tuilivekit.player.coguest.error.timeout"
            LiveToast.show(LiveKitResources.localizedString(key))
            openCameraAfterAccept.send(true)
            updateUiState(.idle)
        case .onKickedOffSeat:
            invalidateMicrophoneRequests()
            LiveToast.show(
                LiveKitResources.localizedString("tuilivekit.player.coguest.error.kicked_off")
            )
            DeviceStore.shared.closeLocalMicrophone()
            DeviceStore.shared.closeLocalCamera()
            updateUiState(.idle)
        default:
            break
        }
    }

    private func applyUiState(_ state: CoGuestStatus) {
        if state == .idle { openCameraAfterAccept.send(true) }
        if state == .coGuesting {
            entryImage.kf.setImage(with: waveProvider, placeholder: connectedImage)
        } else {
            entryImage.kf.cancelDownloadTask()
            entryImage.image = idleImage
            connectedPanel.dismiss()
        }
    }

    private func configureEntry() {
        // Ardot exports the glyph only; the 39pt shell matches the other bottom controls.
        entryImage.backgroundColor = UIColor(red: 0.04, green: 0.04, blue: 0.06, alpha: 0.18)
        entryImage.layer.cornerRadius = 19.5
        entryImage.layer.borderWidth = 1
        entryImage.layer.borderColor = UIColor.white.withAlphaComponent(0.06).cgColor
        entryImage.contentMode = .scaleAspectFit
        entryImage.isUserInteractionEnabled = true
        entryImage.accessibilityLabel = LiveKitResources.localizedString("tuilivekit.player.coguest")
        addSubview(entryImage)
        entryImage.snp.makeConstraints { make in make.edges.equalToSuperview() }
        let tap = UITapGestureRecognizer(target: self, action: #selector(handleTap))
        entryImage.addGestureRecognizer(tap)
    }

    @objc private func handleTap() {
        UIView.animate(withDuration: 0.12, animations: {
            self.entryImage.transform = CGAffineTransform(scaleX: 0.92, y: 0.92)
        }, completion: { _ in
            UIView.animate(withDuration: 0.12) {
                self.entryImage.transform = .identity
            }
        })
        presentPanelForCurrentState()
    }

    private func configurePanels() {
        applyPanel.onRequestSettings = { [weak self] in
            self?.presentSettingsPanel(mode: .preview)
        }
        connectedPanel.onShowSettings = { [weak self] in
            guard let self else { return }
            self.connectedPanel.dismiss()
            self.presentSettingsPanel(mode: .connected)
        }
        settingsPanel.onDismiss = { [weak self] in
            guard let self else { return }
            if self.uiState.value == .coGuesting {
                self.connectedPanel.present()
            }
        }
        settingsPanel.onApply = { [weak self] in
            self?.applyPanel.applyForSeat(requestVideo: true)
            self?.settingsPanel.dismiss()
        }
    }

    private func attachPanelIfNeeded(_ panel: BottomSheetView, to window: UIWindow) {
        guard panel.superview !== window else { return }
        panel.removeFromSuperview()
        window.addSubview(panel)
        panel.snp.remakeConstraints { make in
            make.edges.equalToSuperview()
        }
    }

    private func presentSettingsPanel(mode: SettingsPanel.Mode) {
        settingsPanel.present(mode: mode)
    }

    private func presentPanelForCurrentState() {
        switch uiState.value {
        case .idle, .requesting:
            applyPanel.present()
        case .coGuesting:
            connectedPanel.present()
        }
    }
}
