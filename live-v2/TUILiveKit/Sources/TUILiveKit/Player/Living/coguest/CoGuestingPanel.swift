import AtomicXCore
import Combine
import SnapKit
import UIKit

final class CoGuestingPanel: BottomSheetView {
    override var sheetHeight: CGFloat { 160 }
    override var isDismissibleByTappingOutside: Bool { true }

    var onShowSettings: (() -> Void)?

    private let microphoneButton = UIButton(type: .custom)
    private let cameraButton = UIButton(type: .custom)
    private let adjustButton = UIButton(type: .custom)
    private let disconnectButton = UIButton(type: .custom)

    private let openCameraAfterAccept: CurrentValueSubject<Bool, Never>
    private var liveID = ""
    private var seatCancellable: AnyCancellable?
    private var cancellables = Set<AnyCancellable>()
    private var isBusy = false
    private var cameraRequestID: UUID?
    private var allowCameraRestore = false

    @discardableResult
    func invalidateCameraRequest(allowRestore: Bool) -> Bool {
        let wasOpening = cameraRequestID != nil
        cameraRequestID = nil
        allowCameraRestore = allowRestore
        return wasOpening
    }

    init(openCameraAfterAccept: CurrentValueSubject<Bool, Never>) {
        self.openCameraAfterAccept = openCameraAfterAccept
        super.init(frame: .zero)

        configureButton(microphoneButton, image: "livekit_player_connected_mic_on", size: 48)
        configureButton(cameraButton, image: "livekit_player_connected_camera_on", size: 48)
        configureButton(adjustButton, image: "livekit_player_connected_adjust", size: 48)
        configureButton(disconnectButton, image: "livekit_player_connected_disconnect", size: 48)
        disconnectButton.backgroundColor = UIColor(red: 1, green: 0.318, blue: 0.345, alpha: 1)
        disconnectButton.layer.shadowColor = UIColor(red: 1, green: 0.216, blue: 0.263, alpha: 1).cgColor
        disconnectButton.layer.shadowOpacity = 0.25
        disconnectButton.layer.shadowOffset = CGSize(width: 0, height: 7)
        disconnectButton.layer.shadowRadius = 9

        [microphoneButton, cameraButton, adjustButton, disconnectButton].forEach(contentView.addSubview)
        layoutButtons()

        microphoneButton.addAction(UIAction { [weak self] _ in self?.toggleMic() }, for: .touchUpInside)
        cameraButton.addAction(UIAction { [weak self] _ in self?.toggleCamera() }, for: .touchUpInside)
        adjustButton.addAction(UIAction { [weak self] _ in self?.onShowSettings?() }, for: .touchUpInside)
        disconnectButton.addAction(UIAction { [weak self] _ in self?.disconnect() }, for: .touchUpInside)

        openCameraAfterAccept
            .receive(on: DispatchQueue.main)
            .sink { [weak self] showVideo in
                guard let self else { return }
                self.cameraButton.isHidden = !showVideo
                self.adjustButton.isHidden = !showVideo
                self.layoutButtons()
            }
            .store(in: &cancellables)
    }

    func bind(liveID: String) {
        guard self.liveID != liveID else { return }
        self.liveID = liveID
        if !isHidden {
            observeSeatState()
        }
    }

    override func sheetWillPresent() {
        observeSeatState()
    }

    override func sheetDidDismiss() {
        invalidateCameraRequest(allowRestore: allowCameraRestore)
        seatCancellable = nil
        isBusy = false
        disconnectButton.isEnabled = true
    }

    private func observeSeatState() {
        seatCancellable = nil
        guard !liveID.isEmpty else { return }
        let store = CoGuestStore.create(liveID: liveID)
        seatCancellable = store.state.subscribe()
            .receive(on: DispatchQueue.main)
            .sink { [weak self] coGuestState in
                self?.applyCoGuestState(coGuestState)
            }
        applyCoGuestState(store.state.value)
    }

    private func applyCoGuestState(_ coGuestState: CoGuestState) {
        let selfUserID = LoginStore.shared.state.value.loginUserInfo?.userID ?? ""
        guard let seatUserInfo = coGuestState.connected.first(where: {
            $0.userID == selfUserID
        }) else { return }
        applyDeviceState(
            microphoneStatus: seatUserInfo.microphoneStatus,
            cameraStatus: seatUserInfo.cameraStatus
        )
    }

    private func applyDeviceState(microphoneStatus: DeviceStatus, cameraStatus: DeviceStatus) {
        let microphoneEnabled = microphoneStatus == .on
        microphoneButton.setImage(
            LiveKitResources.image(
                named: microphoneEnabled
                    ? "livekit_player_connected_mic_on"
                    : "livekit_player_connected_mic_off"
            ),
            for: .normal
        )
        microphoneButton.backgroundColor = microphoneEnabled
            ? UIColor.white.withAlphaComponent(0.09)
            : UIColor.white.withAlphaComponent(0.96)

        let cameraEnabled = cameraStatus == .on
        cameraButton.setImage(
            LiveKitResources.image(
                named: cameraEnabled
                    ? "livekit_player_connected_camera_on"
                    : "livekit_player_connected_camera_off"
            ),
            for: .normal
        )
        cameraButton.backgroundColor = cameraEnabled
            ? UIColor.white.withAlphaComponent(0.09)
            : UIColor.white.withAlphaComponent(0.96)
    }

    private func toggleMic() {
        guard !liveID.isEmpty else { return }
        let selfUserID = LoginStore.shared.state.value.loginUserInfo?.userID ?? ""
        let seatInfo = CoGuestStore.create(liveID: liveID).state.value.connected.first {
            $0.userID == selfUserID
        }
        if seatInfo?.microphoneStatus == .on {
            LiveSeatStore.create(liveID: liveID).muteMicrophone()
        } else if seatInfo?.allowOpenMicrophone == true {
            LiveSeatStore.create(liveID: liveID).unmuteMicrophone(completion: nil)
        } else if seatInfo?.allowOpenMicrophone == false {
            LiveToast.show(
                LiveKitResources.localizedString("tuilivekit.player.coguest.microphone_locked")
            )
        }
    }

    private func toggleCamera() {
        guard !liveID.isEmpty else { return }
        let selfUserID = LoginStore.shared.state.value.loginUserInfo?.userID ?? ""
        let isCameraOpened = CoGuestStore.create(liveID: liveID).state.value.connected.first {
            $0.userID == selfUserID
        }?.cameraStatus == .on
        if isCameraOpened {
            cameraRequestID = nil
            allowCameraRestore = false
            DeviceStore.shared.closeLocalCamera()
        } else if UIApplication.shared.applicationState == .active {
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
                        if UIApplication.shared.applicationState != .active || self.liveID.isEmpty {
                            DeviceStore.shared.closeLocalCamera()
                        }
                    } else if UIApplication.shared.applicationState != .active ||
                        (!self.allowCameraRestore && self.cameraRequestID == nil) {
                        DeviceStore.shared.closeLocalCamera()
                    }
                }
            }
        }
    }

    private func disconnect() {
        guard !isBusy, !liveID.isEmpty else { return }
        isBusy = true
        disconnectButton.isEnabled = false
        CoGuestStore.create(liveID: liveID).disConnect { [weak self] _ in
            Task { @MainActor in
                guard let self else { return }
                self.isBusy = false
                self.disconnectButton.isEnabled = true
                self.dismiss()
            }
        }
    }

    private func configureButton(_ button: UIButton, image: String, size: CGFloat) {
        button.setImage(LiveKitResources.image(named: image), for: .normal)
        button.backgroundColor = UIColor.white.withAlphaComponent(0.09)
        button.layer.cornerRadius = size / 2
        button.imageView?.contentMode = .scaleAspectFit
    }

    private func layoutButtons() {
        let visible = [microphoneButton, cameraButton, adjustButton, disconnectButton].filter { !$0.isHidden }
        let count = visible.count
        guard count > 0 else { return }
        for (index, button) in visible.enumerated() {
            button.snp.remakeConstraints { make in
                make.centerX.equalTo(contentView.snp.trailing).multipliedBy(Double(2 * index + 1) / Double(2 * count))
                make.centerY.equalToSuperview()
                make.width.height.equalTo(48)
            }
        }
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}
