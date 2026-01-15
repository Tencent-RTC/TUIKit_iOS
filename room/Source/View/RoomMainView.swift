//
//  RoomMainView.swift
//  TUIRoomKit
//
//  Created on 2025/11/21.
//  Copyright © 2025 Tencent. All rights reserved.
//

import UIKit
import SnapKit
import Combine
import AtomicXCore
import AtomicX

public enum RoomBehavior {
    case create(options: CreateRoomOptions)
    case join
}

public struct ConnectConfig {
    public var autoEnableMicrophone: Bool
    public var autoEnableCamera: Bool
    public var autoEnableSpeaker: Bool
    
    public init(autoEnableMicrophone: Bool = true,
                autoEnableCamera: Bool = true,
                autoEnableSpeaker: Bool = true) {
        self.autoEnableMicrophone = autoEnableMicrophone
        self.autoEnableCamera = autoEnableCamera
        self.autoEnableSpeaker = autoEnableSpeaker
    }
}

public class RoomMainView: UIView, BaseView {
    // MARK: - Properties
    weak var routerContext: RouterContext?
    private let roomStore: RoomStore = RoomStore.shared
    private let deviceStore: DeviceStore = DeviceStore.shared
    
    private lazy var participantStore: RoomParticipantStore = {
        let store = RoomParticipantStore.create(roomID: roomID)
        return store
    }()
    
    private var cancellableSet = Set<AnyCancellable>()
    
    private let roomID: String
    private let behavior: RoomBehavior
    private let config: ConnectConfig
    private var currentRoom: RoomInfo?
    private var localParticipant: RoomParticipant?
    private var managerView: ParticipantManagerView?
    // MARK: - UI Components
    
    private lazy var topBarView: RoomTopBarView = {
        let view = RoomTopBarView(frame: .zero)
        return view
    }()
    
    private lazy var roomView: RoomView = {
        let roomView = RoomView(roomID: roomID)
        return roomView
    }()
    
    private lazy var participantView: RoomParticipantView = {
        return RoomParticipantView()
    }()
    
    private lazy var bottomBarView: RoomBottomBarView = {
        let view = RoomBottomBarView(roomID: roomID)
        return view
    }()
    
    private lazy var listView: ParticipantListView = {
        let listView = ParticipantListView(roomID: roomID)
        return listView
    }()
    
    private var inviteCameraAlertView: AtomicAlertView?
    private var inviteMicrophoneAlertView: AtomicAlertView?
    
    // MARK: - Initialization
    public init(roomID: String, behavior: RoomBehavior, config: ConnectConfig) {
        self.roomID = roomID
        self.behavior = behavior
        self.config = config
        super.init(frame: .zero)
        setupViews()
        setupConstraints()
        setupStyles()
        setupBindings()
        initializeRoom()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    // MARK: - BaseView Implementation
    func setupViews() {
        addSubview(roomView)
        addSubview(topBarView)
        addSubview(bottomBarView)
    }
    
    func setupConstraints() {
        roomView.snp.makeConstraints { make in
            make.left.right.equalToSuperview()
            make.top.equalTo(topBarView.snp.bottom)
            make.bottom.equalTo(bottomBarView.snp.top)
        }
        
        topBarView.snp.makeConstraints { make in
            make.top.equalTo(safeAreaLayoutGuide.snp.top)
            make.left.right.equalToSuperview()
            make.height.equalTo(53)
        }
        
        bottomBarView.snp.makeConstraints { make in
            make.left.right.equalToSuperview()
            make.bottom.equalTo(safeAreaLayoutGuide.snp.bottom)
            make.height.equalTo(52)
        }
    }
    
    func setupStyles() {
        backgroundColor = RoomColors.inRoomBackground
    }
    
    func setupBindings() {
        topBarView.delegate = self
        bottomBarView.delegate = self
        listView.delegate = self
        
        roomStore.state.subscribe(StatePublisherSelector(keyPath: \.currentRoom))
            .receive(on: RunLoop.main)
            .sink { [weak self] roomInfo in
                guard let self = self else { return }
                currentRoom = roomInfo
            }
            .store(in: &cancellableSet)
        
        participantStore.state.subscribe(StatePublisherSelector(keyPath: \.localParticipant))
            .receive(on: RunLoop.main)
            .sink { [weak self] participant in
                guard let self = self else { return }
                localParticipant = participant
            }
            .store(in: &cancellableSet)
        
        participantStore.participantEventPublisher
            .receive(on: RunLoop.main)
            .sink { [weak self] event in
                guard let self = self else { return }
                switch event {
                case .onAdminSet(let user):
                    handleOnAdminSet(user: user)
                case .onAdminRevoked(let user):
                    handleOnAdminRevoked(user: user)
                case .onOwnerChanged(let newUser, let oldUser):
                    handleOnOwnerChanged(newUser: newUser, oldUser: oldUser)
                case .onUserMessageDisabled(let disable, _):
                    handleOnUserMessageDisabled(disable: disable)
                case .onParticipantDeviceClosed(let deviceType, _):
                    handleOnParticipantDeviceClosed(deviceType: deviceType)
                case .onKickedFromRoom(reason: let reason, message: let message):
                    handleOnKickedFromRoom(reason: reason, message: message)
                case .onDeviceInvitationReceived(let request):
                    handleOnDeviceInvitationReceived(request: request)
                case .onDeviceInvitationCancelled(let request):
                    onDeviceInvitationCancelled(request: request)
                case .onAllDevicesDisabled(let deviceType, let disable, _):
                    handleOnAllDevicesDisabled(deviceType: deviceType, disable: disable)
                default: break
                }
            }
            .store(in: &cancellableSet)
        
        roomStore.roomEventPublisher
            .receive(on: RunLoop.main)
            .sink { [weak self] event in
                guard let self = self else { return }
                switch event {
                case .onRoomEnded(roomInfo: let roomInfo):
                    handleOnRoomEnd(roomInfo: roomInfo)
                default: break
                }
            }
            .store(in: &cancellableSet)
    }
}

extension RoomMainView {
    private func initializeRoom() {
        switch behavior {
        case .create(let options):
            createAndJoinRoom(options: options)
        case .join:
            joinRoom()
        }
    }
    
    private func createAndJoinRoom(options: CreateRoomOptions) {
        roomStore.createAndJoinRoom(roomID: roomID, options: options) { [weak self] result in
            guard let self = self else { return }
            switch result {
            case .success():
                handleDidEnterRoom()
            case .failure(let err):
                showToast(InternalError(code: err.code, message: err.message).localizedMessage)
                routerContext?.pop(animated: true)
            }
        }
    }
    
    private func joinRoom() {
        roomStore.joinRoom(roomID: roomID, password: nil) { [weak self] result in
            guard let self = self else { return }
            switch result {
            case .success():
                handleDidEnterRoom()
            case .failure(let err):
                showToast(InternalError(code: err.code, message: err.message).localizedMessage)
                routerContext?.pop(animated: true)
            }
        }
    }
    
    private func handleDidEnterRoom() {
        if config.autoEnableCamera {
            openLocalCamera()
        }
        
        if config.autoEnableMicrophone {
            unmuteMicrophone()
        }
        
        setAudioRoute(route: config.autoEnableSpeaker ? .speakerphone : .earpiece)
        participantStore.getParticipantList(cursor: "", completion: nil)
    }
    
    private func endRoom() {
        roomStore.endRoom { [weak self] result in
            guard let self = self else { return }
            switch result {
            case .success(): break
            case .failure(let err):
                showToast(InternalError(code: err.code, message: err.message).localizedMessage)
            }
            routerContext?.pop(animated: true)
        }
    }
    
    private func leaveRoom() {
        roomStore.leaveRoom { [weak self] result in
            guard let self = self else { return }
            switch result {
            case .success(): break
            case .failure(let err):
                showToast(InternalError(code: err.code, message: err.message).localizedMessage)
            }
            routerContext?.pop(animated: true)
        }
    }
}

extension RoomMainView {
    private func openLocalCamera() {
        deviceStore.openLocalCamera(isFront: deviceStore.state.value.isFrontCamera) { [weak self] result in
            guard let self = self else { return }
            switch result {
            case .success(): break
            case .failure(let err):
                showToast(InternalError(code: err.code, message: err.message).localizedMessage)
            }
        }
    }
    
    private func closeLocalCamera() {
        deviceStore.closeLocalCamera()
    }

    private func muteMicrophone() {
        participantStore.muteMicrophone()
    }
    
    private func unmuteMicrophone() {
        if deviceStore.state.value.microphoneStatus == .off {
            deviceStore.openLocalMicrophone { [weak self] result in
                guard let self = self else { return }
                switch result {
                case .success():
                    unmuteMicrophoneInner()
                case .failure(let err):
                    showToast(InternalError(code: err.code, message: err.message).localizedMessage)
                }
            }
        } else {
            unmuteMicrophoneInner()
        }
    }
    
    private func unmuteMicrophoneInner() {
        participantStore.unmuteMicrophone { [weak self] result in
            guard let self = self else { return }
            switch result {
            case .success(): break
            case .failure(let err):
                showToast(InternalError(code: err.code, message: err.message).localizedMessage)
            }
        }
    }
    
    private func setAudioRoute(route: AudioRoute) {
        deviceStore.setAudioRoute(route)
    }
}
// MARK: - RoomStore Event
extension RoomMainView {
    private func handleOnRoomEnd(roomInfo: RoomInfo) {
        let confirmButtonConfig = AlertButtonConfig(text: .ok, type: .blue) { [weak self] view in
            guard let self = self else { return }
            view.dismiss()
            routerContext?.pop(animated: true)
        }
        let config = AlertViewConfig(title: .roomClosed, confirmButton: confirmButtonConfig)
        AtomicAlertView(config: config).show()
    }
}

// MARK: - ParticipantStore Event
extension RoomMainView {
    private func handleOnAdminSet(user: RoomUser) {
        if user.userID == localParticipant?.userID {
            showToast(.becameAdmin)
        }
    }
    
    private func handleOnAdminRevoked(user: RoomUser) {
        if user.userID == localParticipant?.userID {
            showToast(.adminRevoked)
        }
    }
    
    private func handleOnOwnerChanged(newUser: RoomUser, oldUser: RoomUser) {
        if newUser.userID == localParticipant?.userID {
            showToast(.becameHost)
        }
    }
    
    private func handleOnDeviceInvitationReceived(request: DeviceRequestInfo) {
        switch request.device {
        case .camera:
            handleOnCameraInvitationReceived(request: request)
        case .microphone:
            handleOnMicrophoneInvitationReceived(request: request)
        default: break
        }
    }
    
    private func handleOnCameraInvitationReceived(request: DeviceRequestInfo) {
        if let inviteCameraAlertView = inviteCameraAlertView {
            inviteCameraAlertView.dismiss()
            self.inviteCameraAlertView = nil
        }
        let cancelButtonConfig = AlertButtonConfig(text: .reject) { [weak self] view in
            guard let self = self else { return }
            participantStore.declineOpenDeviceInvitation(
                userID: request.senderUserID,
                device: request.device
            ) { [weak self] result in
                guard let self = self else { return }
                inviteCameraAlertView = nil
            }
            view.dismiss()
        }
        let confirmButtonConfig = AlertButtonConfig(text: .agree, type: .blue) { [weak self] view in
            guard let self = self else { return }
            participantStore.acceptOpenDeviceInvitation(
                userID: request.senderUserID,
                device: request.device
            ) { [weak self] result in
                guard let self = self else { return }
                inviteCameraAlertView = nil
            }
            view.dismiss()
        }
        let config = AlertViewConfig(title: .inviteTurnOnCamera.localizedReplace(request.name),
                                     cancelButton: cancelButtonConfig,
                                     confirmButton: confirmButtonConfig)
        let view = AtomicAlertView(config: config)
        view.show()
        inviteCameraAlertView = view
    }
    
    private func handleOnMicrophoneInvitationReceived(request: DeviceRequestInfo) {
        if let inviteMicrophoneAlertView = inviteMicrophoneAlertView {
            inviteMicrophoneAlertView.dismiss()
            self.inviteMicrophoneAlertView = nil
        }
        
        let cancelButtonConfig = AlertButtonConfig(text: .reject) { [weak self] view in
            guard let self = self else { return }
            participantStore.declineOpenDeviceInvitation(
                userID: request.senderUserID,
                device: request.device
            ) { [weak self] result in
                guard let self = self else { return }
                inviteMicrophoneAlertView = nil
            }
            view.dismiss()
        }
        let confirmButtonConfig = AlertButtonConfig(text: .agree, type: .blue) { [weak self] view in
            guard let self = self else { return }
            participantStore.acceptOpenDeviceInvitation(
                userID: request.senderUserID,
                device: request.device
            ) { [weak self] result in
                guard let self = self else { return }
                inviteMicrophoneAlertView = nil
            }
            view.dismiss()
        }
        let config = AlertViewConfig(title: .inviteTurnOnMicrophone.localizedReplace(request.name),
                                     cancelButton: cancelButtonConfig,
                                     confirmButton: confirmButtonConfig)
        
        let view = AtomicAlertView(config: config)
        view.show()
        inviteMicrophoneAlertView = view
    }
    
    private func onDeviceInvitationCancelled(request: DeviceRequestInfo) {
        switch request.device {
        case .camera:
            inviteCameraAlertView?.dismiss()
            inviteCameraAlertView = nil
        case .microphone:
            inviteMicrophoneAlertView?.dismiss()
            inviteMicrophoneAlertView = nil
        default: break
        }
    }
    
    private func handleOnAllDevicesDisabled(deviceType: DeviceType, disable: Bool) {
        switch deviceType {
        case .camera:
            disable ? showToast(.allVideosDisabled) : showToast(.allVideosEnabled)
        case .microphone:
            disable ? showToast(.allAudiosDisabled) : showToast(.allAudiosEnabled)
        default:break
        }
    }
    
    private func handleOnUserMessageDisabled(disable: Bool) {
        let message = disable ? String.bannedFromChat : String.allowedToChat
        showToast(message)
    }
    
    private func handleOnParticipantDeviceClosed(deviceType: DeviceType) {
        switch deviceType {
        case .camera:
            closeLocalCamera()
            showToast(.cameraClosedByHost)
        case .microphone:
            muteMicrophone()
            showToast(.mutedByHost)
        default: break
        }
    }
    
    private func handleOnKickedFromRoom(reason: KickedOutOfRoomReason, message: String) {
        let confirmButtonConfig = AlertButtonConfig(text: .ok, type: .blue) { [weak self] view in
            guard let self = self else { return }
            view.dismiss()
            routerContext?.pop(animated: true)
        }
        let config = AlertViewConfig(title: .removedByHost, confirmButton: confirmButtonConfig)
        AtomicAlertView(config: config).show()
    }
}

extension RoomMainView: RoomTopBarViewDelegate {
    public func onEndButtonTapped() {
        if let localParticipant = localParticipant, localParticipant.role == .owner  {
            showEndActionSheet()
        } else {
            showLeaveActionSheet()
        }
    }
    
    public func onRoomInfoButtonTapped() {
        RoomInfoView(roomID: roomID).show(in: self, animated: true)
    }
    
    private func showEndActionSheet() {
        let actionSheet = RoomActionSheet(message: .endRoomConfirm,
                                          actions: [
                                            RoomActionSheet.Action(title: .leaveRoom,
                                                                   style: .default,
                                                                   handler: { [weak self] action in
                                                                       guard let self = self else { return }
                                                                       leaveRoom()
                                                                   }),
                                            RoomActionSheet.Action(title: .endRoom,
                                                                   style: .destructive,
                                                                   handler: { [weak self] action in
                                                                       guard let self = self else { return }
                                                                       endRoom()
                                                                   }),
                                         ])
        actionSheet.show(in: self, animated: true)
    }
    
    private func showLeaveActionSheet() {
        let actionSheet = RoomActionSheet(message: .leaveRoomConfirm,
                                          actions: [
                                            RoomActionSheet.Action(title: .leaveRoom,
                                                                   style: .default,
                                                                   handler: { [weak self] action in
                                                                       guard let self = self else { return }
                                                                       leaveRoom()
                                                                   })
                                         ])
        actionSheet.show(in: self, animated: true)
    }
}

extension RoomMainView: RoomBottomBarViewDelegate {
    public func onMembersButtonTapped() {
        listView.show(in: self, animated: true)
    }
    
    public func onMicrophoneButtonTapped() {
        guard let localParticipant = localParticipant else { return }
        localParticipant.microphoneStatus == .off ? unmuteMicrophone() : muteMicrophone()
    }
    
    public func onCameraButtonTapped() {
        guard let localParticipant = localParticipant else { return }
        localParticipant.cameraStatus == .off ? openLocalCamera() : closeLocalCamera()
    }
    
}

extension RoomMainView: ParticipantListViewDelegate {
    public func participantTapped(view: ParticipantListView, participant: RoomParticipant) {
        let managerView = ParticipantManagerView(participant: participant, roomID: roomID)
        managerView.delegate = self
        managerView.show(in: self, animated: true)
    }
    
    public func muteAllAudioButtonTapped(disable: Bool) {
        let title = disable ? String.muteAllMembersTitle : String.unmuteAllMembersTitle
        let message = disable ? String.muteAllMembersMessage : String.unmuteAllMembersMessage
        let sureTitle = disable ? String.muteAll : String.confirmRelease
        
        let cancelButtonConfig = AlertButtonConfig(text: .cancel) { view in
            view.dismiss()
        }
        
        let confirmButtonConfig = AlertButtonConfig(text: sureTitle, type: .blue) { [weak self] view in
            guard let self = self else { return }
            participantStore.disableAllDevices(device: .microphone, disable: disable) { [weak self] result in
                guard let self = self else { return }
                switch result {
                case .success(): break
                case .failure(let err):
                    showToast(InternalError(code: err.code, message: err.message).localizedMessage)
                }
            }
            view.dismiss()
        }
        let config = AlertViewConfig(title: title, content: message, cancelButton: cancelButtonConfig, confirmButton: confirmButtonConfig)
        AtomicAlertView(config: config).show()
    }
    
    public func muteAllVideoButtonTapped(disable: Bool) {
        let title = disable ? String.stopAllVideoTitle : String.enableAllVideoTitle
        let message = disable ? String.stopAllVideoMessage : String.enableAllVideoMessage
        let sureTitle = disable ? String.stopAllVideo : String.confirmRelease
        
        let cancelButtonConfig = AlertButtonConfig(text: .cancel) { view in
            view.dismiss()
        }
        
        let confirmButtonConfig = AlertButtonConfig(text: sureTitle, type: .blue) { [weak self] view in
            guard let self = self else { return }
            participantStore.disableAllDevices(device: .camera, disable: disable) { [weak self] result in
                guard let self = self else { return }
                switch result {
                case .success(): break
                case .failure(let err):
                    showToast(InternalError(code: err.code, message: err.message).localizedMessage)
                }
            }
            view.dismiss()
        }
        let config = AlertViewConfig(title: title, content: message, cancelButton: cancelButtonConfig, confirmButton: confirmButtonConfig)
        AtomicAlertView(config: config).show()
    }
}

extension RoomMainView: ParticipantManagerViewDelegate {
    public func handleInviteToOpenDevice(view: ParticipantManagerView, device: DeviceType, participant: AtomicXCore.RoomParticipant) {
        participantStore.inviteToOpenDevice(userID: participant.userID, device: device, timeout: 30) { [weak self] result in
            guard let self = self else { return }
            switch result {
            case .success: break
            case .failure(let err):
                showToast(InternalError(code: err.code, message: err.message).localizedMessage)
            }
        }
        view.dismiss(animated: true)
        showToast(device == .camera ? .invitedToOpenVideo : .invitedToOpenAudio)
    }
    
    public func handleKickOut(view: ParticipantManagerView, participant: RoomParticipant) {
        let cancelButtonConfig = AlertButtonConfig(text: .cancel) { view in
            view.dismiss()
        }
        let confirmButtonConfig = AlertButtonConfig(text: .ok, type: .blue) { [weak self] view in
            guard let self = self else { return }
            participantStore.kickUser(userID: participant.userID) { [weak self] result in
                guard let self = self else { return }
                switch result {
                case .success: break
                case .failure(let err):
                    showToast(InternalError(code: err.code, message: err.message).localizedMessage)
                }
            }
            view.dismiss()
        }
        let config = AlertViewConfig(title: String.kickOutConfirm.localizedReplace(participant.name),
                                     cancelButton: cancelButtonConfig,
                                     confirmButton: confirmButtonConfig)
        AtomicAlertView(config: config).show()
    }
    
    public func handleSetAsAdmin(view: ParticipantManagerView, participant: RoomParticipant) {
        if participant.role == .generalUser {
            participantStore.setAdmin(userID: participant.userID) { [weak self] result in
                guard let self = self else { return }
                switch result {
                case .success:
                    showToast(String.setAsAdminSuccess.localizedReplace(participant.name))
                case .failure(let err):
                    showToast(InternalError(code: err.code, message: err.message).localizedMessage)
                }
                view.dismiss(animated: true)
            }
        } else if participant.role == .admin {
            participantStore.revokeAdmin(userID: participant.userID) { [weak self] result in
                guard let self = self else { return }
                switch result {
                case .success:
                    showToast(String.revokeAdminSuccess.localizedReplace(participant.name))
                case .failure(let err):
                    showToast(InternalError(code: err.code, message: err.message).localizedMessage)
                }
                view.dismiss(animated: true)
            }
        }
    }
    
    public func handleTransferHost(view: ParticipantManagerView, participant: RoomParticipant) {
        let cancelButtonConfig = AlertButtonConfig(text: .cancel) { view in
            view.dismiss()
        }
        
        let confirmButtonConfig = AlertButtonConfig(text: .confirmTransfer, type: .blue) { [weak self] view in
            guard let self = self else { return }
            participantStore.transferOwner(userID: participant.userID) { [weak self] result in
                guard let self = self else { return }
                switch result {
                case .success:
                    showToast(String.hostTransferredSuccess.localizedReplace(participant.name))
                case .failure(let err):
                    showToast(InternalError(code: err.code, message: err.message).localizedMessage)
                }
            }
            view.dismiss()
        }
        let config = AlertViewConfig(title: String.transferHostTitle.localizedReplace(participant.name), content: .transferHostMessage, cancelButton: cancelButtonConfig, confirmButton: confirmButtonConfig)
        AtomicAlertView(config: config).show()
    }
}

fileprivate extension String {
    // Alert titles and messages
    static let ok = "roomkit_ok".localized
    static let cancel = "roomkit_cancel".localized
    static let roomClosed = "roomkit_toast_room_closed".localized
    
    // Admin and role changes
    static let becameAdmin = "roomkit_toast_you_are_admin".localized
    static let adminRevoked = "roomkit_toast_you_are_no_longer_admin".localized
    static let becameHost = "roomkit_toast_you_are_owner".localized
    static let administrator = "roomkit_role_admin".localized
    
    // Device invitations
    static let inviteTurnOnCamera = "roomkit_msg_invite_start_video"
    static let inviteTurnOnMicrophone = "roomkit_msg_invite_unmute_audio"
    static let reject = "roomkit_reject".localized
    static let agree = "roomkit_agree".localized
    
    // Message and device restrictions
    static let bannedFromChat = "roomkit_toast_text_chat_disabled".localized
    static let allowedToChat = "roomkit_toast_text_chat_enabled".localized
    static let cameraClosedByHost = "roomkit_toast_camera_closed_by_host".localized
    static let mutedByHost = "roomkit_toast_muted_by_host".localized
    static let removedByHost = "roomkit_toast_you_were_removed".localized
    
    // Room actions
    static let endRoomConfirm = "roomkit_confirm_leave_room_by_owner".localized
    static let endRoom = "roomkit_end_room".localized
    
    static let leaveRoomConfirm = "roomkit_confirm_leave_room_by_genera_user".localized
    static let leaveRoom = "roomkit_leave_room".localized
    
    
    // Device restrictions for general users
    static let allMutedCannotUnmute = "roomkit_tip_all_muted_cannot_unmute".localized
    static let allVideoOffCannotTurnOn = "roomkit_tip_all_video_off_cannot_start".localized
    
    // Mute all audio
    static let muteAllMembersTitle = "roomkit_msg_all_members_will_be_muted".localized
    static let unmuteAllMembersTitle = "roomkit_msg_all_members_will_be_unmuted".localized
    static let muteAllMembersMessage = "roomkit_msg_members_cannot_unmute".localized
    static let unmuteAllMembersMessage = "roomkit_msg_members_can_unmute".localized
    static let muteAll = "roomkit_mute_all_audio".localized
    static let confirmRelease = "roomkit_confirm_release".localized
    static let allAudiosDisabled = "roomkit_toast_all_audio_disabled".localized
    static let allAudiosEnabled = "roomkit_toast_all_audio_enabled".localized
    static let invitedToOpenAudio = "roomkit_toast_audio_invite_sent".localized
    
    // Mute all video
    static let stopAllVideoTitle = "roomkit_msg_all_members_video_disabled".localized
    static let enableAllVideoTitle = "roomkit_msg_all_members_video_enabled".localized
    static let stopAllVideoMessage = "roomkit_msg_members_cannot_start_video".localized
    static let enableAllVideoMessage = "roomkit_msg_members_can_start_video".localized
    static let stopAllVideo = "roomkit_disable_all_video".localized
    static let allVideosDisabled = "roomkit_toast_all_video_disabled".localized
    static let allVideosEnabled = "roomkit_toast_all_video_enabled".localized
    static let invitedToOpenVideo = "roomkit_toast_video_invite_sent".localized
    
    // Member actions
    static let kickOutConfirm = "roomkit_confirm_remove_member"
    static let setAsAdminSuccess = "roomkit_toast_admin_set"
    static let revokeAdminSuccess = "roomkit_toast_admin_revoked"
    
    // Transfer host
    static let transferHostTitle = "roomkit_msg_transfer_owner_to"
    static let transferHostMessage = "roomkit_msg_transfer_owner_tip".localized
    static let confirmTransfer = "roomkit_confirm_transfer".localized
    static let hostTransferredSuccess = "roomkit_toast_owner_transferred"
}
