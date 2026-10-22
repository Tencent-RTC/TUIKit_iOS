import UIKit
import SnapKit
import Combine
import AtomicXCore

enum RoomToolBarActiveKind {
    case chat
    case participant
    case more
}

final class RoomToolBar: UIView {

    var onRequestOpenDevice: ((RoomDeviceKind) -> Void)?

    var onBlocked: ((RoomDeviceKind) -> Void)?
    var onSpeakerTap: (() -> Void)?
    var onChatTap: (() -> Void)?
    var onParticipantTap: (() -> Void)?
    var onMoreTap: (() -> Void)?

    var participantCount: Int? {
        get { partButton.badgeCount }
        set { partButton.badgeCount = newValue }
    }

    private let micButton: RoomToolbarButton = {
        let button = RoomToolbarButton(icon: RoomKitResources.image(named: "roomkit_icon_microphone"))
        button.roomDisabledIcon = RoomKitResources.image(named: "roomkit_icon_microphone_off")
        return button
    }()

    private let camButton: RoomToolbarButton = {
        let button = RoomToolbarButton(icon: RoomKitResources.image(named: "roomkit_icon_camera"))
        button.roomDisabledIcon = RoomKitResources.image(named: "roomkit_icon_camera_off")
        return button
    }()
    private let speakerButton = RoomToolbarButton(icon: RoomKitResources.image(named: "roomkit_icon_speaker"))
    private let partButton = RoomToolbarButton(icon: RoomKitResources.image(named: "roomkit_icon_members"))
    private let chatButton = RoomToolbarButton(icon: RoomKitResources.image(named: "roomkit_icon_chat"))
    private let moreButton = RoomToolbarButton(icon: RoomKitResources.image(named: "roomkit_icon_more"))

    private var cancellableSet = Set<AnyCancellable>()
    private var roomID = ""
    private var roomDisabledKinds: Set<RoomDeviceKind> = []

    override init(frame: CGRect) {
        super.init(frame: frame)
        backgroundColor = .clear
        setupViews()
        setupBindings()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func setupViews() {
        let stack = UIStackView(arrangedSubviews: [micButton, camButton, speakerButton, partButton, chatButton, moreButton])
        stack.axis = .horizontal
        stack.spacing = 12
        stack.distribution = .equalSpacing
        addSubview(stack)
        stack.snp.makeConstraints {
            $0.center.equalToSuperview()
            $0.height.equalTo(44)
        }
        for button in stack.arrangedSubviews {
            button.snp.makeConstraints { $0.size.equalTo(44) }
        }
    }

    private func setupBindings() {
        micButton.addTarget(self, action: #selector(handleMicTap), for: .touchUpInside)
        camButton.addTarget(self, action: #selector(handleCamTap), for: .touchUpInside)
        speakerButton.addTarget(self, action: #selector(handleSpeakerTap), for: .touchUpInside)
        chatButton.addTarget(self, action: #selector(handleChatTap), for: .touchUpInside)
        partButton.addTarget(self, action: #selector(handlePartTap), for: .touchUpInside)
        moreButton.addTarget(self, action: #selector(handleMoreTap), for: .touchUpInside)

        DeviceStore.shared.state
            .subscribe(StatePublisherSelector(projector: { state in
                (state.microphoneStatus == .on, state.cameraStatus == .on)
            }))
            .removeDuplicates { $0 == $1 }
            .receive(on: RunLoop.main)
            .sink { [weak self] micOn, camOn in
                guard let self else { return }
                self.micButton.icon = micOn
                    ? RoomKitResources.image(named: "roomkit_icon_microphone")
                    : RoomKitResources.image(named: "roomkit_icon_microphone_off")
                self.camButton.icon = camOn
                    ? RoomKitResources.image(named: "roomkit_icon_camera")
                    : RoomKitResources.image(named: "roomkit_icon_camera_off")
            }
            .store(in: &cancellableSet)

        Publishers.CombineLatest(
            DeviceStore.shared.state
                .subscribe(StatePublisherSelector(keyPath: \DeviceState.currentAudioRoute))
                .removeDuplicates(),
            RoomLocalMediaUtils.isAudioOutputMuted.removeDuplicates()
        )
        .receive(on: RunLoop.main)
        .sink { [weak self] _, _ in
            guard let self else { return }
            self.speakerButton.icon = self.currentAudioOutput.toolbarIcon
        }
        .store(in: &cancellableSet)
    }

    private func observeRoomPermissions(roomID: String) {
        observeRoomPermission(isMicrophone: true)
        observeRoomPermission(isMicrophone: false)
    }

    private func observeRoomPermission(isMicrophone: Bool) {
        let roomDisabled = RoomStore.shared.state
            .subscribe(StatePublisherSelector(projector: { state -> Bool in
                guard let room = state.currentRoom else { return false }
                return isMicrophone ? room.isAllMicrophoneDisabled : room.isAllCameraDisabled
            }))
            .removeDuplicates()
        let selfRole = RoomParticipantStore.create(roomID: roomID).state
            .subscribe(StatePublisherSelector(projector: { state -> ParticipantRole? in
                state.localParticipant?.role
            }))
            .removeDuplicates()
        Publishers.CombineLatest(roomDisabled, selfRole)
            .map { disabled, role -> Bool in
                guard disabled, let role else { return false }
                return role != .owner && role != .admin
            }
            .removeDuplicates()
            .receive(on: RunLoop.main)
            .sink { [weak self] disabled in
                guard let self else { return }
                if isMicrophone {
                    self.micButton.isRoomDisabled = disabled
                } else {
                    self.camButton.isRoomDisabled = disabled
                }
                let kind: RoomDeviceKind = isMicrophone ? .microphone : .camera
                if disabled {
                    self.roomDisabledKinds.insert(kind)
                } else {
                    self.roomDisabledKinds.remove(kind)
                }
            }
            .store(in: &cancellableSet)
    }

    // MARK: - actions

    @objc private func handleMicTap() {
        if DeviceStore.shared.state.value.microphoneStatus == .on {
            DeviceStore.shared.closeLocalMicrophone()
        } else {
            requestOpen(.microphone)
        }
    }

    @objc private func handleCamTap() {
        if DeviceStore.shared.state.value.cameraStatus == .on {
            DeviceStore.shared.closeLocalCamera()
        } else {
            requestOpen(.camera)
        }
    }

    private func requestOpen(_ kind: RoomDeviceKind) {
        guard !roomDisabledKinds.contains(kind) else {
            onBlocked?(kind)
            return
        }
        onRequestOpenDevice?(kind)
    }

    @objc private func handleSpeakerTap() {
        onSpeakerTap?()
    }

    @objc private func handleChatTap() {
        onChatTap?()
    }

    @objc private func handlePartTap() {
        onParticipantTap?()
    }

    @objc private func handleMoreTap() {
        onMoreTap?()
    }

    private var currentAudioOutput: RoomAudioOutput {
        DeviceStore.shared.state.value.currentAudioRoute == .speakerphone ? .speaker : .earpiece
    }
}

// MARK: - public methods

extension RoomToolBar {

    func bind(roomID: String) {
        self.roomID = roomID
        observeSpeakingVolume(roomID: roomID)
        observeRoomPermissions(roomID: roomID)
    }

    private func observeSpeakingVolume(roomID: String) {
        Publishers.CombineLatest(
            RoomParticipantStore.create(roomID: roomID).state
                .subscribe(StatePublisherSelector(keyPath: \RoomParticipantState.speakingUsers))
                .removeDuplicates()
                .throttle(for: .seconds(RoomMicLevelView.updateInterval), scheduler: RunLoop.main, latest: true),
            DeviceStore.shared.state
                .subscribe(StatePublisherSelector(keyPath: \DeviceState.microphoneStatus))
                .removeDuplicates()
        )
        .receive(on: RunLoop.main)
        .sink { [weak self] speakingUsers, microphoneStatus in
            guard let self else { return }
            let localUserID = LoginStore.shared.state.value.loginUserInfo?.userID ?? ""
            self.micButton.micVolume = microphoneStatus == .on ? (speakingUsers[localUserID] ?? 0) : nil
        }
        .store(in: &cancellableSet)
    }

    func setFault(_ hasFault: Bool, for kind: RoomDeviceKind) {
        switch kind {
        case .microphone: micButton.hasFault = hasFault
        case .camera: camButton.hasFault = hasFault
        }
    }

    func setActive(_ isActive: Bool, for kind: RoomToolBarActiveKind) {
        switch kind {
        case .chat: chatButton.isActive = isActive
        case .participant: partButton.isActive = isActive
        case .more: moreButton.isActive = isActive
        }
    }
}

private extension RoomAudioOutput {
    var toolbarIcon: UIImage? {
        switch self {
        case .speaker: return RoomKitResources.image(named: "roomkit_icon_speaker")
        case .earpiece: return RoomKitResources.image(named: "roomkit_icon_earpiece")
        }
    }
}
