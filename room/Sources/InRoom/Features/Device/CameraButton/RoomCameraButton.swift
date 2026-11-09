import AVFoundation
import UIKit
import SnapKit
import Combine
import AtomicXCore

final class RoomCameraButton: UIControl {

    private static let roomDisabledAlpha: CGFloat = 0.45

    private let roomID: String
    private var isCameraOn = false {
        didSet { applyIcon() }
    }
    private var isRoomDisabled = false {
        didSet {
            applyIcon()
            applyPermissionBadgeVisibility()
        }
    }
    private var hasPermission = true {
        didSet { applyPermissionBadgeVisibility() }
    }
    private var cancellableSet = Set<AnyCancellable>()

    private let iconView = UIImageView()
    private let permissionBadge = UIImageView()

    init(roomID: String) {
        self.roomID = roomID
        super.init(frame: .zero)
        setupViews()
        setupConstraints()
        setupStyles()
        setupBindings()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override var isHighlighted: Bool {
        didSet {
            guard oldValue != isHighlighted else { return }
            transform = isHighlighted ? CGAffineTransform(scaleX: 0.92, y: 0.92) : .identity
        }
    }

    override func didMoveToWindow() {
        super.didMoveToWindow()
        guard window != nil else { return }
        applyTheme()
        refreshPermission()
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        layer.cornerRadius = min(bounds.width, bounds.height) / 2
    }

    private func setupViews() {
        addSubview(iconView)
        addSubview(permissionBadge)
    }

    private func setupConstraints() {
        iconView.snp.makeConstraints {
            $0.center.equalToSuperview()
            $0.size.equalTo(20)
        }
        permissionBadge.snp.makeConstraints {
            $0.size.equalTo(14)
            $0.leading.equalTo(iconView.snp.trailing).offset(-6)
            $0.top.equalTo(iconView.snp.top).offset(-6)
        }
    }

    private func setupStyles() {
        iconView.contentMode = .scaleAspectFit
        iconView.isUserInteractionEnabled = false
        permissionBadge.image = RoomKitResources.image(named: "roomkit_icon_permission_badge")
        permissionBadge.contentMode = .scaleAspectFit
        permissionBadge.isHidden = true
        permissionBadge.isUserInteractionEnabled = false
    }

    private func setupBindings() {
        addTarget(self, action: #selector(handleTap), for: .touchUpInside)
        observeCameraStatus()
        observeRoomDisabled()
        refreshPermission()
        NotificationCenter.default.publisher(for: UIApplication.didBecomeActiveNotification)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in self?.refreshPermission() }
            .store(in: &cancellableSet)
    }
}

extension RoomCameraButton {

    private func observeCameraStatus() {
        RoomParticipantStore.create(roomID: roomID).state
            .subscribe(StatePublisherSelector(projector: { $0.localParticipant?.cameraStatus == .on }))
            .removeDuplicates()
            .receive(on: RunLoop.main)
            .sink { [weak self] in self?.isCameraOn = $0 }
            .store(in: &cancellableSet)
    }

    private func observeRoomDisabled() {
        let roomDisabled = RoomStore.shared.state
            .subscribe(StatePublisherSelector(projector: { $0.currentRoom?.isAllCameraDisabled == true }))
            .removeDuplicates()
        let selfRole = RoomParticipantStore.create(roomID: roomID).state
            .subscribe(StatePublisherSelector(projector: { $0.localParticipant?.role }))
            .removeDuplicates()
        Publishers.CombineLatest(roomDisabled, selfRole)
            .map { disabled, role -> Bool in
                guard disabled, let role else { return false }
                return role != .owner && role != .admin
            }
            .removeDuplicates()
            .receive(on: RunLoop.main)
            .sink { [weak self] in self?.isRoomDisabled = $0 }
            .store(in: &cancellableSet)
    }

    private func refreshPermission() {
        hasPermission = AVCaptureDevice.authorizationStatus(for: .video) == .authorized
    }

    private func applyTheme() {
        backgroundColor = UIColor.roomKitBgHover
    }

    private func applyIcon() {
        if isCameraOn {
            iconView.image = RoomKitResources.image(named: "roomkit_icon_camera")
            alpha = 1
            return
        }
        iconView.image = RoomKitResources.image(named: "roomkit_icon_camera_off")
        alpha = isRoomDisabled ? RoomCameraButton.roomDisabledAlpha : 1
    }

    private func applyPermissionBadgeVisibility() {
        permissionBadge.isHidden = hasPermission || isRoomDisabled
    }
}

extension RoomCameraButton {
    
    @objc private func handleTap() {
        if isCameraOn {
            DeviceStore.shared.closeLocalCamera()
        } else {
            if isRoomDisabled {
                RoomToast.show(.deviceAllCamDisabled)
                return
            } else {
                RoomDevicePermission.requestCameraPermission { granted in
                    guard granted else {
                        RoomToast.show(RoomKitResources.localizedString("roomkit.device.camera_no_permission"))
                        return
                    }
                    DeviceStore.shared.openLocalCamera(isFront: DeviceStore.shared.state.value.isFrontCamera) { result in
                        if case .failure(let error) = result {
                            ErrorLocalized.showError(code: error.code, message: error.message)
                        }
                    }
                }
            }
        }
    }
}

extension String {
    fileprivate static var deviceAllCamDisabled: String { RoomKitResources.localizedString("roomkit.device.all_cam_disabled") }
}
