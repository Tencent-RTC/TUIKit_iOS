import AVFoundation
import UIKit
import SnapKit
import Combine
import AtomicXCore

final class RoomMicButton: UIControl {

    private static let roomDisabledAlpha: CGFloat = 0.45
    private static let localVolumeKey = ""

    private let roomID: String
    private var isMicOn = false {
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
    private var micVolume: Int? {
        didSet {
            guard let micVolume else {
                micLevelView.isHidden = true
                micLevelView.reset()
                return
            }
            micLevelView.isHidden = false
            micLevelView.setVolume(micVolume)
        }
    }
    private var cancellableSet = Set<AnyCancellable>()

    private let iconView = UIImageView()
    private let micLevelView = RoomMicLevelView()
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
        micLevelView.frame = RoomMicLevelView.cavityFrame(inIconBox: iconView.frame)
    }

    private func setupViews() {
        addSubview(micLevelView)
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
        micLevelView.isHidden = true
        micLevelView.isUserInteractionEnabled = false
        permissionBadge.image = RoomKitResources.image(named: "roomkit_icon_permission_badge")
        permissionBadge.contentMode = .scaleAspectFit
        permissionBadge.isHidden = true
        permissionBadge.isUserInteractionEnabled = false
    }

    private func setupBindings() {
        addTarget(self, action: #selector(handleTap), for: .touchUpInside)
        observeMicrophoneStatus()
        observeSpeakingVolume()
        observeRoomDisabled()
        refreshPermission()
        NotificationCenter.default.publisher(for: UIApplication.didBecomeActiveNotification)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in self?.refreshPermission() }
            .store(in: &cancellableSet)
    }
}

extension RoomMicButton {

    private func observeMicrophoneStatus() {
        RoomParticipantStore.create(roomID: roomID).state
            .subscribe(StatePublisherSelector(projector: { $0.localParticipant?.microphoneStatus == .on }))
            .removeDuplicates()
            .receive(on: RunLoop.main)
            .sink { [weak self] in self?.isMicOn = $0 }
            .store(in: &cancellableSet)
    }

    private func observeSpeakingVolume() {
        Publishers.CombineLatest(
            RoomParticipantStore.create(roomID: roomID).state
                .subscribe(StatePublisherSelector(keyPath: \RoomParticipantState.speakingUsers))
                .removeDuplicates()
                .throttle(for: .seconds(RoomMicLevelView.updateInterval), scheduler: RunLoop.main, latest: true),
            RoomParticipantStore.create(roomID: roomID).state
                .subscribe(StatePublisherSelector(projector: { $0.localParticipant?.microphoneStatus == .on }))
                .removeDuplicates()
        )
        .receive(on: RunLoop.main)
        .sink { [weak self] speakingUsers, isMicOn in
            self?.micVolume = isMicOn ? (speakingUsers[Self.localVolumeKey] ?? 0) : nil
        }
        .store(in: &cancellableSet)
    }

    private func observeRoomDisabled() {
        let roomDisabled = RoomStore.shared.state
            .subscribe(StatePublisherSelector(projector: { $0.currentRoom?.isAllMicrophoneDisabled == true }))
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
        if #available(iOS 17.0, *) {
            hasPermission = AVAudioApplication.shared.recordPermission == .granted
        } else {
            hasPermission = AVAudioSession.sharedInstance().recordPermission == .granted
        }
    }

    private func applyTheme() {
        backgroundColor = UIColor.roomKitBgHover
    }

    private func applyIcon() {
        if isMicOn {
            iconView.image = RoomKitResources.image(named: "roomkit_icon_microphone")
            alpha = 1
            return
        }
        iconView.image = RoomKitResources.image(named: "roomkit_icon_microphone_off")
        alpha = isRoomDisabled ? RoomMicButton.roomDisabledAlpha : 1
    }

    private func applyPermissionBadgeVisibility() {
        permissionBadge.isHidden = hasPermission || isRoomDisabled
    }
}

extension RoomMicButton {

    @objc private func handleTap() {
        if isMicOn {
            RoomParticipantStore.create(roomID: roomID).muteMicrophone()
        } else {
            if isRoomDisabled {
                RoomToast.show(.deviceAllMicDisabled)
            } else {
                RoomDevicePermission.requestMicrophonePermission { [weak self] granted in
                    guard let self else { return }
                    guard granted else {
                        RoomToast.show(RoomKitResources.localizedString("roomkit.device.mic_no_permission"))
                        return
                    }
                    DeviceStore.shared.openLocalMicrophone { result in
                        switch result {
                        case .success:
                            RoomParticipantStore.create(roomID: self.roomID).unmuteMicrophone { result in
                                if case .failure(let error) = result {
                                    ErrorLocalized.showError(code: error.code, message: error.message)
                                }
                            }
                        case .failure(let error):
                            ErrorLocalized.showError(code: error.code, message: error.message)
                        }
                    }
                }
            }
        }
    }
}

extension String {
    fileprivate static var deviceAllMicDisabled: String { RoomKitResources.localizedString("roomkit.device.all_mic_disabled") }
}
