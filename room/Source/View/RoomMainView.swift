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
    public weak var routerContext: RouterContext?
    private let roomStore: RoomStore = RoomStore.shared
    
    private lazy var participantStore: RoomParticipantStore = {
        RoomParticipantStore.create(roomID: roomID)
    }()
    
    private lazy var repository: AITranscriberRepository = {
        AITranscriberRepository(roomID: roomID)
    }()
    
    private var cancellableSet = Set<AnyCancellable>()
    
    private let roomID: String
    private let behavior: RoomBehavior
    private let config: ConnectConfig
    private var roomType: RoomType = .standard
    private var localParticipant: RoomParticipant?
    private let deviceOperator = DeviceOperator()
    
    // MARK: - UI Components
    private lazy var topBarView: RoomTopBarView = {
        let view = RoomTopBarView(roomID: roomID, roomType: roomType)
        return view
    }()
    
    private lazy var roomView: RoomView = {
        let roomView = RoomView(roomID: roomID, roomType: roomType)
        return roomView
    }()
    
    private lazy var bottomBarView: RoomBottomBarView = {
        let view = RoomBottomBarView(roomID: roomID, roomType: roomType)
        return view
    }()
    
    private lazy var barrageInputView: BarrageInputView = {
        let view = BarrageInputView(roomId: roomID)
        view.layer.cornerRadius = 20
        view.layer.masksToBounds = true
        return view
    }()
    
    private lazy var barrageStreamView: BarrageStreamView = {
        let view = BarrageStreamView(liveID: roomID)
        return view
    }()
    
    private lazy var screenShareOverlay: RoomScreenShareOverlayView = {
        let overlayView = RoomScreenShareOverlayView()
        overlayView.isHidden = true
        return overlayView
    }()
    
    private lazy var listView: ParticipantListView = {
        let listView = ParticipantListView(roomID: roomID, roomType: roomType)
        return listView
    }()
    
    private lazy var passwordView: EnterRoomPasswordView = {
        let passwordView = EnterRoomPasswordView { [weak self] in
            guard let self = self else { return }
            routerContext?.pop(animated: true)
        } onJoin: { [weak self] password in
            guard let self = self else { return }
            guard let password = password, !password.isEmpty else {
                showAtomicToast(text: .pleaseInputPassword, style: .error)
                return
            }
            joinRoom(password: password)
        }
        return passwordView
    }()
    
    private var subtitleView: AISubtitleView?
    private lazy var handsUpView: HandsUpListView = {
        let view = HandsUpListView(roomID: roomID)
        return view
    }()
    
    private var inviteCameraAlertView: AtomicAlertView?
    private var inviteMicrophoneAlertView: AtomicAlertView?
    private var isFirstJoinRoom: Bool = false
    
    // MARK: - Initialization
    public init(roomID: String, behavior: RoomBehavior, config: ConnectConfig) {
        self.roomID = roomID
        self.behavior = behavior
        self.config = config
        super.init(frame: .zero)
        self.roomType = getRoomType(roomID)
        setupViews()
        setupConstraints()
        setupStyles()
        setupBindings()
        initializeRoom()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    private func getRoomType(_ roomID: String) -> RoomType {
        return !roomID.hasPrefix("webinar_") ? .standard : .webinar 
    }
    
    // MARK: - BaseView Implementation
    public func setupViews() {
        addSubview(topBarView)
        addSubview(roomView)
        roomView.addSubview(screenShareOverlay)
        
        addSubview(barrageStreamView)
        addSubview(barrageInputView)
        addSubview(bottomBarView)
    }
    
    public func setupConstraints() {
        topBarView.snp.makeConstraints { make in
            make.top.equalTo(safeAreaLayoutGuide.snp.top)
            make.left.right.equalToSuperview()
            make.height.equalTo(53)
        }
        
        roomView.snp.makeConstraints { make in
            make.left.right.equalToSuperview()
            make.top.equalTo(topBarView.snp.bottom)
            make.bottom.equalTo(bottomBarView.snp.top).offset(-10)
        }
        
        screenShareOverlay.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }
        
        barrageStreamView.snp.makeConstraints { make in
            make.height.equalTo(206)
            make.left.equalToSuperview().offset(RoomSpacing.standard)
            make.right.equalToSuperview().offset(-45)
            make.bottom.equalTo(barrageInputView.snp.top).offset(-RoomSpacing.standard)
        }
        
        barrageInputView.snp.makeConstraints { make in

            make.left.equalToSuperview().offset(RoomSpacing.standard)
            make.height.equalTo(40)
            make.width.equalTo(130)
            make.bottom.equalTo(bottomBarView.snp.top).offset(-20)
        }
        
        bottomBarView.snp.makeConstraints { make in
            make.centerX.equalToSuperview()
            make.bottom.equalTo(safeAreaLayoutGuide.snp.bottom)
            make.height.equalTo(52)
        }
    }
    
    public func setupStyles() {
        backgroundColor = RoomColors.inRoomBackground
        if roomType == .standard {
            barrageStreamView.isHidden = true
            barrageInputView.isHidden = true
        }
    }
    
    public func setupBindings() {
        listView.delegate = self
        topBarView.delegate = self
        bottomBarView.delegate = self
        screenShareOverlay.delegate = self
        roomStore.state.subscribe(StatePublisherSelector(keyPath: \.currentRoom))
            .receive(on: RunLoop.main)
            .sink { [weak self] roomInfo in
                guard let self = self else { return }
                if let roomInfo = roomInfo, !roomInfo.roomID.isEmpty {
                    barrageStreamView.setOwnerId(roomInfo.roomOwner.userID)
                    if !isFirstJoinRoom {
                        handleConnectConfig(roomInfo: roomInfo)
                        isFirstJoinRoom = true
                    }
                }
            }
            .store(in: &cancellableSet)
        
        participantStore.state.subscribe(StatePublisherSelector(keyPath: \.localParticipant))
            .receive(on: RunLoop.main)
            .sink { [weak self] participant in
                guard let self = self else { return }
                localParticipant = participant
                let screenShareStatus = participant?.screenShareStatus ?? .off
                screenShareOverlay.isHidden = screenShareStatus == .off
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
                case .onParticipantDeviceClosed(let deviceType, let operatorUser):
                    handleOnParticipantDeviceClosed(deviceType: deviceType, operatorUser: operatorUser)
                case .onKickedFromRoom(reason: let reason, message: let message):
                    handleOnKickedFromRoom(reason: reason, message: message)
                case .onDeviceInvitationReceived(let request):
                    handleOnDeviceInvitationReceived(request: request)
                case .onDeviceInvitationCancelled(let request):
                    onDeviceInvitationCancelled(request: request)
                case .onAllDevicesDisabled(let deviceType, let disable, _):
                    handleOnAllDevicesDisabled(deviceType: deviceType, disable: disable)
                case .onAudiencePromotedToParticipant(userInfo: let user):
                    handleOnAudiencePromotedToParticipant(userInfo: user)
                case .onParticipantDemotedToAudience(userInfo: let user):
                    handleOnParticipantDemotedToAudience(userInfo: user)
                case .onDeviceRequestRejected(let request, let operatorUser):
                    handleOnDeviceRequestRejected(request: request, operatorUser: operatorUser)
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
        
        repository.$selectedSourceLanguage
            .receive(on: DispatchQueue.main)
            .sink { [weak self] sourceLanguage in
                guard let self = self else { return }
                guard let localParticipant = localParticipant else { return }
                if localParticipant.role != .owner {
                    showAtomicToast(text: .ownerChangedSourceLanguage, style: .info)
                }
            }
            .store(in: &cancellableSet)
    }
}

extension RoomMainView {
    private func initializeRoom() {
        RoomDataReporter.setFramework()
        switch behavior {
        case .create(let options):
            createAndJoinRoom(options: options)
        case .join:
            joinRoom()
        }
    }
    
    private func createAndJoinRoom(options: CreateRoomOptions) {
        roomStore.createAndJoinRoom(roomID: roomID, roomType: roomType, options: options) { [weak self] result in
            guard let self = self else { return }
            switch result {
            case .success():
                handleDidEnterRoom()
            case .failure(let err):
                showAtomicToast(text: InternalError(code: err.code, message: err.message).localizedMessage, style: .error)
                routerContext?.pop(animated: true)
            }
        }
    }
    
    private func joinRoom(password: String? = "") {
        roomStore.joinRoom(roomID: roomID, roomType: roomType, password: password) { [weak self] result in
            guard let self = self else { return }
            switch result {
            case .success():
                dismissPasswordView()
                handleDidEnterRoom()
            case .failure(let err):
                if err.code == RoomError.requiresPassword.rawValue {
                    showPasswordView()
                } else if err.code == RoomError.roomEntryPasswordError.rawValue {
                    showAtomicToast(text: .passwordError, style: .error)
                } else {
                    showAtomicToast(text: InternalError(code: err.code, message: err.message).localizedMessage, style: .error)
                    routerContext?.pop(animated: true)
                }
            }
        }
    }
    
    private func handleDidEnterRoom() {
        deviceOperator.setAudioRoute(route: config.autoEnableSpeaker ? .speakerphone : .earpiece)
        participantStore.getParticipantList(cursor: "", completion: nil)
        
        if roomType == .webinar {
            participantStore.getAudienceList(cursor: "", completion: nil)
        }
    }
    
    private func handleConnectConfig(roomInfo: RoomInfo) {
        if roomInfo.roomType == .standard {
            if config.autoEnableCamera && !roomInfo.isAllCameraDisabled {
                openLocalCamera()
            }
            
            if config.autoEnableMicrophone && !roomInfo.isAllMicrophoneDisabled {
                unmuteMicrophone()
            }
        }
        
        if roomInfo.roomType == .webinar {
            switch behavior {
            case .create(let options):
                if config.autoEnableCamera {
                    openLocalCamera()
                }
                
                if config.autoEnableMicrophone {
                    unmuteMicrophone()
                }
                break
            case .join:
                break
            }
        }
    }
    
    private func endRoom() {
        repository.stopTranscription()
        roomStore.endRoom { [weak self] result in
            guard let self = self else { return }
            switch result {
            case .success(): break
            case .failure(let err):
                showAtomicToast(text: InternalError(code: err.code, message: err.message).localizedMessage, style: .error)
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
                showAtomicToast(text: InternalError(code: err.code, message: err.message).localizedMessage, style: .error)
            }
            routerContext?.pop(animated: true)
        }
    }
    
    private func showPasswordView() {
        guard passwordView.superview == nil else { return }
        passwordView.show(in: self)
    }
    
    private func dismissPasswordView() {
        passwordView.dismiss()
    }
}

extension RoomMainView {
    private func openLocalCamera() {
        Task { @MainActor in
            do {
                try await deviceOperator.openLocalCamera()
            } catch let error as ErrorInfo {
                if error.code == RoomError.openCameraNeedPermissionFromAdmin.rawValue {
                    showAtomicToast(text: InternalError(code: error.code, message: error.message).localizedMessage, style: .warning)
                } else {
                    showAtomicToast(text: InternalError(code: error.code, message: error.message).localizedMessage, style: .error)
                }
            }
        }
    }
    
    private func unmuteMicrophone() {
        Task { @MainActor in
            do {
                try await deviceOperator.openLocalMicrophone()
                try await deviceOperator.unmuteMicrophone(participantStore: participantStore)
            } catch let error as ErrorInfo {
                if error.code == RoomError.openMicrophoneNeedPermissionFromAdmin.rawValue {
                    showAtomicToast(text: InternalError(code: error.code, message: error.message).localizedMessage, style: .warning)
                } else {
                    showAtomicToast(text: InternalError(code: error.code, message: error.message).localizedMessage, style: .error)
                }
            }
        }
    }
    
    private func kickOutRoom(userID: String, name: String) {
        let cancelButtonConfig = AlertButtonConfig(text: .cancel) { view in
            view.dismiss()
        }
        let confirmButtonConfig = AlertButtonConfig(text: .ok, type: .blue) { [weak self] view in
            guard let self = self else { return }
            participantStore.kickUser(userID: userID) { [weak self] result in
                guard let self = self else { return }
                switch result {
                case .success: break
                case .failure(let err):
                    showAtomicToast(text: InternalError(code: err.code, message: err.message).localizedMessage, style: .error)
                }
            }
            view.dismiss()
        }
        let config = AlertViewConfig(title: String.kickOutConfirm.localizedReplace(name),
                                     cancelButton: cancelButtonConfig,
                                     confirmButton: confirmButtonConfig)
        AtomicAlertView(config: config).show()
    }
    
    private func setAdmin(userID: String, userName: String, completion: @escaping () -> Void) {
        participantStore.setAdmin(userID: userID) { [weak self] result in
            guard let self = self else { return }
            switch result {
            case .success:
                showAtomicToast(text: String.setAsAdminSuccess.localizedReplace(userName), style: .success)
            case .failure(let err):
                showAtomicToast(text: InternalError(code: err.code, message: err.message).localizedMessage, style: .error)
            }
            completion()
        }
    }
    
    private func revokeAdmin(userID: String, userName: String, completion: @escaping () -> Void) {
        participantStore.revokeAdmin(userID: userID) { [weak self] result in
            guard let self = self else { return }
            switch result {
            case .success:
                showAtomicToast(text: String.revokeAdminSuccess.localizedReplace(userName), style: .success)
            case .failure(let err):
                showAtomicToast(text: InternalError(code: err.code, message: err.message).localizedMessage, style: .error)
            }
            completion()
        }
    }
}

// MARK: - RoomStore Event
extension RoomMainView {
    private func handleOnRoomEnd(roomInfo: RoomInfo) {
        let confirmButtonConfig = AlertButtonConfig(text: .ok, type: .blue) { [weak self] view in
            guard let self = self else { return }
            view.dismiss()
            popRoomViewController(animated: true)
        }
        let config = AlertViewConfig(title: .roomClosed, confirmButton: confirmButtonConfig)
        AtomicAlertView(config: config).show()
    }
    
    private func popRoomViewController(animated: Bool) {
        guard let roomVC = routerContext as? UIViewController,
              let nav = roomVC.navigationController,
              let index = nav.viewControllers.firstIndex(of: roomVC), index > 0 else {
            routerContext?.pop(animated: animated)
            return
        }
        nav.popToViewController(nav.viewControllers[index - 1], animated: animated)
    }
}

// MARK: - ParticipantStore Event
extension RoomMainView {
    private func handleOnAdminSet(user: RoomUser) {
        if user.userID == localParticipant?.userID {
            showAtomicToast(text: .becameAdmin, style: .info)
        }
    }
    
    private func handleOnAdminRevoked(user: RoomUser) {
        if user.userID == localParticipant?.userID {
            showAtomicToast(text: .adminRevoked, style: .info)
        }
    }
    
    private func handleOnOwnerChanged(newUser: RoomUser, oldUser: RoomUser) {
        if newUser.userID == localParticipant?.userID {
            showAtomicToast(text: .becameHost, style: .info)
        }
        if subtitleView != nil {
            hiddenAISubtitleView()
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
            disable ? showAtomicToast(text: .allVideosDisabled, style: .warning) : showAtomicToast(text: .allVideosEnabled, style: .info)
        case .microphone:
            disable ? showAtomicToast(text: .allAudiosDisabled, style: .warning) : showAtomicToast(text: .allAudiosEnabled, style: .info)
        case .screenShare:
            disable ? showAtomicToast(text: .allScreenShareDisabled, style: .warning) : showAtomicToast(text: .allScreenShareEnabled, style: .info)
        }
    }
    
    private func handleOnParticipantDemotedToAudience(userInfo: RoomUser) {
        if userInfo.userID == LoginStore.shared.state.value.loginUserInfo?.userID {
            deviceOperator.closeLocalMicrophone()
            deviceOperator.closeLocalCamera()
        }
    }
    
    private func handleOnAudiencePromotedToParticipant(userInfo: RoomUser) {
        if userInfo.userID == LoginStore.shared.state.value.loginUserInfo?.userID {
            showAtomicToast(text: .switchToParticipantBySelf, style: .info)
        } else {
            showAtomicToast(text: .switchToParticipant.localizedReplace(userInfo.name), style: .info)
        }
    }
    
    private func handleOnUserMessageDisabled(disable: Bool) {
        let message = disable ? String.bannedFromChat : String.allowedToChat
        showAtomicToast(text: message, style: disable ? .warning : .info)
    }
    
    private func handleOnParticipantDeviceClosed(deviceType: DeviceType, operatorUser: RoomUser) {
        switch deviceType {
        case .camera:
            deviceOperator.closeLocalCamera()
            showAtomicToast(text: .cameraClosedByHost.localizedReplace(operatorUser.name), style: .warning)
        case .microphone:
            deviceOperator.muteMicrophone(participantStore: participantStore)
            showAtomicToast(text: .mutedByHost.localizedReplace(operatorUser.name), style: .warning)
        case .screenShare:
            showAtomicToast(text: .screenShareClosedByHost.localizedReplace(operatorUser.name), style: .warning)
        }
    }
    
    private func handleOnDeviceRequestRejected(request: DeviceRequestInfo, operatorUser: RoomUser) {
        if request.device == .microphone {
            showAtomicToast(text: .raiseHandRejected, style: .warning)
        }
    }
    
    private func handleOnKickedFromRoom(reason: KickedOutOfRoomReason, message: String) {
        let confirmButtonConfig = AlertButtonConfig(text: .ok, type: .blue) { [weak self] view in
            guard let self = self else { return }
            view.dismiss()
            popRoomViewController(animated: true)
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
                                                                   titleColor: RoomColors.defaultActionButtonTitleColor,
                                                                   handler: { [weak self] action in
                                                                       guard let self = self else { return }
                                                                       if repository.isTranscriptionStart {
                                                                           repository.stopTranscription(completion: nil)
                                                                       }
                                                                       leaveRoom()
                                                                   }),
                                            RoomActionSheet.Action(title: .endRoom,
                                                                   titleColor: RoomColors.destructiveActionButtonTitleColor,
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
                                                                   titleColor: RoomColors.defaultActionButtonTitleColor,
                                                                   handler: { [weak self] action in
                                                                       guard let self = self else { return }
                                                                       leaveRoom()
                                                                   })
                                         ])
        actionSheet.show(in: self, animated: true)
    }
    
    private func showAISubtitleView() {
        let subtitleView = AISubtitleView()
        subtitleView.bindRepository(repository)
        subtitleView.onTap = { [weak self] in
            guard let self = self else { return }
            let aiSettingViewController = AITranscriptionSettingViewController()
            aiSettingViewController.bindRepository(repository)
            routerContext?.push(aiSettingViewController, animated: true)
        }
        
        addSubview(subtitleView)
        subtitleView.snp.makeConstraints { make in
            make.leading.equalToSuperview().offset(16)
            make.trailing.equalToSuperview().offset(-16)
            make.bottom.equalTo(bottomBarView.snp.top).offset(-10)
        }
        
        self.subtitleView = subtitleView
    }
    
    private func hiddenAISubtitleView() {
        self.subtitleView?.removeFromSuperview()
        self.subtitleView = nil
    }
}

extension RoomMainView: RoomBottomBarViewDelegate {
    public func onShowToast(message: String, style: AtomicX.ToastStyle) {
        showAtomicToast(text: message, style: style)
    }
    
    public func onAIToolsButtonTapped() {
        let isSubtitleShow = subtitleView != nil
        
        let actionSheet = RoomActionSheet(actions: [
            RoomActionSheet.Action(icon: ResourceLoader.loadImage("room_ai_subtitle"),
                                   title: isSubtitleShow ? .closeSubtitle : .openSubtitle,
                                   titleColor: RoomColors.segmentTitleColor,
                                   titleFont: RoomFonts.pingFangSCFont(size: 14, weight: .regular),
                                   handler: { [weak self] action in
                                       guard let self = self else { return }
                                       if !isSubtitleShow {
                                           showAISubtitleView()
                                           if let localParticipant = localParticipant, localParticipant.role == .owner {
                                               repository.startTranscription()
                                           }
                                       } else {
                                           hiddenAISubtitleView()
                                       }
                                   }),
            RoomActionSheet.Action(icon: ResourceLoader.loadImage("room_ai_minutes"),
                                   title: .openMinutes,
                                   titleColor: RoomColors.segmentTitleColor,
                                   titleFont: RoomFonts.pingFangSCFont(size: 14, weight: .regular),
                                   handler: { [weak self] action in
                                       guard let self = self else { return }
                                       if let localParticipant = localParticipant, localParticipant.role == .owner {
                                           repository.startTranscription()
                                       }
                                       let minutesViewController = AIMinutesViewController()
                                       minutesViewController.bindRepository(repository)
                                       routerContext?.push(minutesViewController, animated: true)
                                   })
        ])
        actionSheet.show(in: self, animated: true)
    }
    
    public func onMembersButtonTapped() {
        if roomType == .webinar {
            participantStore.getAudienceList(cursor: "", completion: nil)
        }
        listView.show(in: self, animated: true)
    }
    
    public func onHandsUpManagerButtonTapped() {
        handsUpView.show(in: self, animated: true)
    }
}

extension RoomMainView: ParticipantListViewDelegate {
    public func participantTapped(view: ParticipantListView, participant: RoomParticipant, isAudience: Bool) {
        if isAudience {
            var audience = RoomUser()
            audience.userID = participant.userID
            audience.userName = participant.userName
            audience.avatarURL = participant.avatarURL
            let managerView = AudienceManagerView(audience: audience, roomID: roomID)
            managerView.delegate = self
            managerView.show(in: self, animated: true)
        } else {
            let managerView = ParticipantManagerView(participant: participant, roomID: roomID, roomType: roomType)
            managerView.delegate = self
            managerView.show(in: self, animated: true)
        }
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
                    showAtomicToast(text: InternalError(code: err.code, message: err.message).localizedMessage, style: .error)
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
                    showAtomicToast(text: InternalError(code: err.code, message: err.message).localizedMessage, style: .error)
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
                showAtomicToast(text: InternalError(code: err.code, message: err.message).localizedMessage, style: .error)
            }
        }
        view.dismiss(animated: true)
        showAtomicToast(text: device == .camera ? .invitedToOpenVideo : .invitedToOpenAudio, style: .info)
    }
    
    public func handleKickOut(view: ParticipantManagerView, participant: RoomParticipant) {
        kickOutRoom(userID: participant.userID, name: participant.name)
    }
    
    public func handleSetAsAdmin(view: ParticipantManagerView, participant: RoomParticipant) {
        if participant.role == .generalUser {
            setAdmin(userID: participant.userID, userName: participant.name) {
                view.dismiss()
            }
        } else if participant.role == .admin {
            revokeAdmin(userID: participant.userID, userName: participant.name) {
                view.dismiss()
            }
        }
    }
    
    public func handleTransferHost(view: ParticipantManagerView, participant: RoomParticipant) {
        let cancelButtonConfig = AlertButtonConfig(text: .cancel) { alertView in
            alertView.dismiss()
        }
        
        let confirmButtonConfig = AlertButtonConfig(text: .confirmTransfer, type: .blue) { [weak self] alertView in
            guard let self = self else { return }
            if repository.isTranscriptionStart {
                repository.stopTranscription { [weak self] result in
                    guard let self = self else { return }
                    switch result {
                    case .success:
                        transferOwner(participant: participant) { [weak self] result in
                            guard let self = self else { return }
                            if result {
                                hiddenAISubtitleView()
                            }
                        }
                    case .failure(let err) :
                        showAtomicToast(text: InternalError(code: err.code, message: err.message).localizedMessage, style: .error)
                    }
                }
            } else {
                transferOwner(participant: participant)
            }
            alertView.dismiss()
            view.dismiss()
        }
        let config = AlertViewConfig(title: String.transferHostTitle.localizedReplace(participant.name), content: repository.isTranscriptionStart ? .transferHostWithAsrMessage : .transferHostMessage, cancelButton: cancelButtonConfig, confirmButton: confirmButtonConfig)
        AtomicAlertView(config: config).show()
    }
    
    private func transferOwner(participant: RoomParticipant, completion: ((Bool) -> Void)? = nil) {
        participantStore.transferOwner(userID: participant.userID) { [weak self] result in
            guard let self = self else { return }
            switch result {
            case .success:
                showAtomicToast(text: String.hostTransferredSuccess.localizedReplace(participant.name), style: .success)
                completion?(true)
            case .failure(let err):
                showAtomicToast(text: InternalError(code: err.code, message: err.message).localizedMessage, style: .error)
                completion?(false)
            }
        }
    }
}

extension RoomMainView: AudienceManagerViewDelegate {
    public func handleSetAsAdmin(view: AudienceManagerView, audience: RoomUser, isAdmin: Bool) {
        if isAdmin {
            revokeAdmin(userID: audience.userID, userName: audience.name) {
                view.dismiss()
            }
        } else {
            setAdmin(userID: audience.userID, userName: audience.name) {
                view.dismiss()
            }
        }
    }
    
    public func handleKickOut(view: AudienceManagerView, audience: RoomUser) {
        kickOutRoom(userID: audience.userID, name: audience.name)
    }
}

extension RoomMainView: RoomScreenShareOverlayViewDelegate {
    public func onStopScreenShareButtonTapped() {
        let cancelButtonConfig = AlertButtonConfig(text: .cancel, type: .grey, isBold: false) { view in
            view.dismiss()
        }
        
        let stopButtonConfig = AlertButtonConfig(text: .ok, type: .blue, isBold: false) { [weak self] view in
            guard let self = self else { return }
            deviceOperator.stopScreenShare()
            view.dismiss()
        }
        
        let config = AlertViewConfig(title: .stopScreenShare,
                                     content: .stopScreenShareConfirm,
                                     cancelButton: cancelButtonConfig,
                                     confirmButton: stopButtonConfig)
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
    
    // Device invitations
    static let inviteTurnOnCamera = "roomkit_msg_invite_start_video"
    static let inviteTurnOnMicrophone = "roomkit_msg_invite_unmute_audio"
    static let reject = "roomkit_reject".localized
    static let agree = "roomkit_agree".localized
    
    // Raise Hands
    static let raiseHandRejected = "roomkit_toast_raise_hand_rejected".localized
    
    // Message and device restrictions
    static let bannedFromChat = "roomkit_toast_text_chat_disabled".localized
    static let allowedToChat = "roomkit_toast_text_chat_enabled".localized
    static let cameraClosedByHost = "roomkit_toast_camera_closed_by_host"
    static let mutedByHost = "roomkit_toast_muted_by_host"
    static let removedByHost = "roomkit_toast_you_were_removed".localized
    
    // Room actions
    static let endRoomConfirm = "roomkit_confirm_leave_room_by_owner".localized
    static let endRoom = "roomkit_end_room".localized
    
    static let leaveRoomConfirm = "roomkit_confirm_leave_room_by_genera_user".localized
    static let leaveRoom = "roomkit_leave_room".localized
    
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
    static let transferHostWithAsrMessage = "roomkit_transfer_host_with_asr_warning".localized
    static let confirmTransfer = "roomkit_confirm_transfer".localized
    static let hostTransferredSuccess = "roomkit_toast_owner_transferred"
    
    // Transfer participant
    static let switchToParticipant = "roomkit_switch_to_participant"
    static let switchToParticipantBySelf = "roomkit_switch_to_participant_byself".localized
    
    // Transfer audience
    static let switchToAudience = "roomkit_switch_to_audience"
    static let switchToAudienceBySelf = "roomkit_switch_to_audience_byself".localized
    
    // AITools
    static let openSubtitle = "roomkit_transcription_open_subtitle".localized
    static let openMinutes = "roomkit_transcription_open_minutes".localized
    
    static let closeSubtitle = "roomkit_transcription_close_subtitle".localized
    static let closeMinutes = "roomkit_transcription_close_minutes".localized
    
    static let ownerChangedSourceLanguage = "roomkit_transcription_owner_changed_source_language".localized

    // Screen Share
    static let stopScreenShare = "roomkit_stop_screen_share".localized
    static let stopScreenShareConfirm = "roomkit_stop_screen_share_confirm".localized
    static let stop = "roomkit_btn_stop".localized
    static let screenShareClosedByHost = "roomkit_toast_screen_share_closed_by_host"
    static let allScreenShareDisabled = "roomkit_all_screen_share_disabled".localized
    static let allScreenShareEnabled = "roomkit_all_screen_share_enabled".localized
    
    // Password
    static let passwordError = "roomkit_password_error".localized
    static let pleaseInputPassword = "roomkit_please_input_room_password".localized
}
