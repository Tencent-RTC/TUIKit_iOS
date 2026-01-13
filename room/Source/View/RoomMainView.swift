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
    static let ok = "OK".localized
    static let cancel = "Cancel".localized
    static let roomClosed = "The room was closed.".localized
    
    // Admin and role changes
    static let becameAdmin = "You have become a conference admin".localized
    static let adminRevoked = "Your conference admin status has been revoked".localized
    static let becameHost = "You are now a host".localized
    static let administrator = "Administrator".localized
    
    // Device invitations
    static let inviteTurnOnCamera = "xxx invites you to turn on the camera"
    static let inviteTurnOnMicrophone = "xxx invites you to turn on the microphone"
    static let reject = "Reject".localized
    static let agree = "Agree".localized
    
    // Message and device restrictions
    static let bannedFromChat = "You have been banned from text chat".localized
    static let allowedToChat = "You are allowed to text chat".localized
    static let cameraClosedByHost = "You were closed camera by the host.".localized
    static let mutedByHost = "You were muted by the host.".localized
    static let removedByHost = "You were removed by the host.".localized
    
    // Room actions
    static let endRoomConfirm = "If you don't want to end the conference, please assign a new host before leaving the conference".localized
    static let endRoom = "End room".localized
    
    static let leaveRoomConfirm = "Are you sure you want to leave the room".localized
    static let leaveRoom = "Leave room".localized
    
    
    // Device restrictions for general users
    static let allMutedCannotUnmute = "All on mute audio unable to turn on microphone".localized
    static let allVideoOffCannotTurnOn = "All on mute video unable to turn on camera".localized
    
    // Mute all audio
    static let muteAllMembersTitle = "All current and incoming members will be muted".localized
    static let unmuteAllMembersTitle = "All members will be unmuted".localized
    static let muteAllMembersMessage = "Members will unable to turn on the microphone".localized
    static let unmuteAllMembersMessage = "Members will be able to turn on the microphone".localized
    static let muteAll = "Mute all".localized
    static let confirmRelease = "Confirm release".localized
    static let allAudiosDisabled = "All audios disabled".localized
    static let allAudiosEnabled = "All audios enabled".localized
    static let invitedToOpenAudio = "The audience has been invited to open the audio".localized
    
    // Mute all video
    static let stopAllVideoTitle = "All current and incoming members will be restricted from video".localized
    static let enableAllVideoTitle = "All members will not be restricted from video".localized
    static let stopAllVideoMessage = "Members will unable to turn on video".localized
    static let enableAllVideoMessage = "Members will be able to turn on video".localized
    static let stopAllVideo = "Stop all video".localized
    static let allVideosDisabled = "All videos disabled".localized
    static let allVideosEnabled = "All videos enabled".localized
    static let invitedToOpenVideo = "The audience has been invited to open the video".localized
    
    // Member actions
    static let kickOutConfirm = "Do you want to move xxx out of the room?"
    static let setAsAdminSuccess = "xxx has been set as conference admin"
    static let revokeAdminSuccess = "The conference admin status of xxx has been withdrawn"
    
    // Transfer host
    static let transferHostTitle = "Transfer the host to xxx"
    static let transferHostMessage = "After transfer the host you will become a general user".localized
    static let confirmTransfer = "Confirm transfer".localized
    static let hostTransferredSuccess = "The host has been transferred to xxx"
}
