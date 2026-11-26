import UIKit
import Combine
import SnapKit
import AtomicXCore

public enum RoomBehavior {
    case createAndJoinRoom(options: CreateRoomOptions)
    case join
}

public struct RoomConnectConfig {
    public let autoEnableMicrophone: Bool
    public let autoEnableCamera: Bool
    public let autoEnableSpeaker: Bool

    public init(autoEnableMicrophone: Bool, autoEnableCamera: Bool, autoEnableSpeaker: Bool) {
        self.autoEnableMicrophone = autoEnableMicrophone
        self.autoEnableCamera = autoEnableCamera
        self.autoEnableSpeaker = autoEnableSpeaker
    }
}

public final class MeetingView: UIView {

    public weak var routerContext: RouterContext? {
        didSet {
            topBar.routerContext = routerContext
            toolBar.routerContext = routerContext
        }
    }

    private let roomID: String
    private let connectConfig: RoomConnectConfig
    private let participantStore: RoomParticipantStore
    private var cancellableSet = Set<AnyCancellable>()
    private var invitationDialogs: [DeviceType: RoomDialog] = [:]
    private var recordingDialog: RoomDialog?

    private let topBar: MeetingTopBar
    private let roomView: RoomView
    private let toolBar: MeetingToolBar

    private let sharingPlaceholder: RoomScreenSharingPlaceholderView
    private let captionOverlay: CaptionOverlay
    private let loadingView = MeetingLoadingView()

    public init(roomID: String, behavior: RoomBehavior, config: RoomConnectConfig) {
        self.roomID = roomID
        self.connectConfig = config
        self.topBar = MeetingTopBar(roomID: roomID)
        self.roomView = RoomView(roomID: roomID)
        self.toolBar = MeetingToolBar(roomID: roomID)
        self.participantStore = RoomParticipantStore.create(roomID: roomID)
        self.sharingPlaceholder = RoomScreenSharingPlaceholderView(roomID: roomID)
        self.captionOverlay = CaptionOverlay(roomID: roomID)
        super.init(frame: .zero)
        setupViews()
        setupConstraints()
        setupStyles()
        setupBindings()
        loadingView.show()
        RoomDataReporter.reportComponent()
        switch behavior {
        case .createAndJoinRoom(let options):
            quickStart(options: options)
        case .join:
            joinRoom()
        }
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func setupViews() {
        addSubview(topBar)
        addSubview(roomView)
        addSubview(sharingPlaceholder)
        addSubview(captionOverlay)
        addSubview(toolBar)
        addSubview(loadingView)
    }

    private func setupConstraints() {
        topBar.snp.makeConstraints {
            $0.top.equalTo(safeAreaLayoutGuide.snp.top)
            $0.leading.trailing.equalToSuperview()
            $0.height.equalTo(44)
        }
        
        roomView.snp.makeConstraints {
            $0.top.equalTo(topBar.snp.bottom)
            $0.leading.trailing.equalToSuperview()
            $0.bottom.equalTo(toolBar.snp.top)
        }
        
        sharingPlaceholder.snp.makeConstraints {
            $0.edges.equalTo(roomView)
        }

        captionOverlay.snp.makeConstraints {
            $0.leading.equalTo(roomView).offset(10)
            $0.trailing.equalTo(roomView).offset(-10)
            $0.bottom.equalTo(roomView).offset(-12)
            $0.top.greaterThanOrEqualTo(roomView)
        }
        
        toolBar.snp.makeConstraints {
            $0.leading.trailing.equalToSuperview()
            $0.bottom.equalTo(safeAreaLayoutGuide.snp.bottom)
            $0.height.equalTo(64)
        }

        loadingView.snp.makeConstraints { $0.edges.equalToSuperview() }
    }
    
    private func setupStyles() {
        backgroundColor = UIColor.roomKitBgSurface
        topBar.backgroundColor = .clear
        toolBar.backgroundColor = .clear
    }

    private func setupBindings() {
        topBar.popoverHost = self
        captionOverlay.onOpen = { [weak self] in self?.toolBar.showTranscript() }
        captionOverlay.onClose = { [weak self] in self?.toolBar.stopTranscription() }
        participantStore.participantEventPublisher
            .receive(on: RunLoop.main)
            .sink { [weak self] in self?.handleParticipantEvent($0) }
            .store(in: &cancellableSet)

        RoomStore.shared.roomEventPublisher
            .receive(on: RunLoop.main)
            .sink { [weak self] in self?.handleRoomEvent($0) }
            .store(in: &cancellableSet)
    }

    private func quickStart(options: CreateRoomOptions) {
        RoomStore.shared.createAndJoinRoom(roomID: roomID, roomType: .standard, options: options) { [weak self] result in
            guard let self else { return }
            switch result {
            case .success:
                loadingView.hide()
                applyConnectConfig()
                RoomParticipantStore.create(roomID: roomID).getParticipantList(cursor: nil, completion: nil)
            case .failure(let error):
                loadingView.hide()
                ErrorLocalized.showError(code: error.code, message: error.message)
                closeMeetingPage()
            }
        }
    }

    private func joinRoom(password: String? = nil) {
        RoomStore.shared.joinRoom(roomID: roomID,
                                  roomType: .standard,
                                  password: password) { [weak self] result in
            guard let self else { return }
            switch result {
            case .failure(let error) where ErrorLocalized.rule(code: error.code) == .passwordRequired ||
                                           ErrorLocalized.rule(code: error.code) == .wrongPassword:
                loadingView.hide()
                presentPassword(wrongPassword: ErrorLocalized.rule(code: error.code) == .wrongPassword)
            case .success:
                loadingView.hide()
                applyConnectConfig()
                RoomParticipantStore.create(roomID: roomID).getParticipantList(cursor: nil, completion: nil)
            case .failure(let error):
                loadingView.hide()
                ErrorLocalized.showError(code: error.code, message: error.message)
                closeMeetingPage()
            }
        }
    }

    private func applyConnectConfig() {
        DeviceStore.shared.setAudioRoute(connectConfig.autoEnableSpeaker ? .speakerphone : .earpiece)

        if connectConfig.autoEnableMicrophone && canOpenMicrophone() {
            RoomDevicePermission.requestMicrophonePermission { granted in
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

        if connectConfig.autoEnableCamera && canOpenCamera() {
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

    private func isLocalOwnerOrAdmin() -> Bool {
        let room = RoomStore.shared.state.value.currentRoom
        let localUserID = LoginStore.shared.state.value.loginUserInfo?.userID ?? ""
        let isOwner = !localUserID.isEmpty && localUserID == room?.roomOwner.userID
        let isAdmin = RoomParticipantStore.create(roomID: roomID).state.value.localParticipant?.role == .admin
        return isOwner || isAdmin
    }

    private func canOpenMicrophone() -> Bool {
        isLocalOwnerOrAdmin() || RoomStore.shared.state.value.currentRoom?.isAllMicrophoneDisabled != true
    }

    private func canOpenCamera() -> Bool {
        isLocalOwnerOrAdmin() || RoomStore.shared.state.value.currentRoom?.isAllCameraDisabled != true
    }

    private func presentPassword(wrongPassword: Bool) {
        MeetingPasswordDialog.present(
            in: self,
            wrongPassword: wrongPassword,
            onSubmit: { [weak self] password in
                self?.loadingView.show()
                self?.joinRoom(password: password)
            },
            onCancel: { [weak self] in self?.closeMeetingPage() }
        )
    }

    private func closeMeetingPage() {
        if let coordinator = routerContext?.navigationController?.transitionCoordinator {
            coordinator.animate(alongsideTransition: nil) { [weak self] _ in
                self?.popToRootSkippingIntermediateTransition()
            }
        } else {
            popToRootSkippingIntermediateTransition()
        }
    }

    private func popToRootSkippingIntermediateTransition() {
        guard let navigationController = routerContext?.navigationController else {
            routerContext?.popToRoot(animated: true)
            return
        }
        let stack = navigationController.viewControllers
        guard stack.count > 2, let root = stack.first, let top = stack.last else {
            navigationController.popToRootViewController(animated: true)
            return
        }
        navigationController.setViewControllers([root, top], animated: false)
        navigationController.popViewController(animated: true)
    }

    // RoomEvent
    private func handleRoomEvent(_ event: RoomEvent) {
        switch event {
        case .onRoomEnded:
            RoomToast.show(RoomKitResources.localizedString(.roomEndedByHost))
            closeMeetingPage()

        case .onRecordingStarted(_, let operatorUser):
            handleRecordingStarted(by: operatorUser)

        case .onRecordingStopped(_, let operatorUser, let reason):
            handleRecordingStopped(by: operatorUser, reason: reason)

        default:
            break
        }
    }

    // RoomParticipantEvent
    private func handleParticipantEvent(_ event: RoomParticipantEvent) {
        switch event {
        case .onAdminSet(let user):
            guard isLocal(user.userID) else { return }
            RoomToast.show(RoomKitResources.localizedString(.becomeAdmin))

        case .onAdminRevoked(let user):
            guard isLocal(user.userID) else { return }
            RoomToast.show(RoomKitResources.localizedString(.adminRevoked))

        case .onOwnerChanged(let newOwner, _):
            guard isLocal(newOwner.userID) else { return }
            RoomToast.show(RoomKitResources.localizedString(.becomeOwner))

        case .onKickedFromRoom(let reason, _):
            let message: String
            switch reason {
            case .kickedByAdmin: message = RoomKitResources.localizedString(.kickedByAdmin)
            case .kickedByServer: message = RoomKitResources.localizedString(.kickedByServer)
            case .replacedByAnotherDevice: message = RoomKitResources.localizedString(.replacedByAnotherDevice)
            case .connectionTimeout: message = RoomKitResources.localizedString(.connectionTimeout)
            case .invalidStatusOnReconnect: message = RoomKitResources.localizedString(.invalidStatusOnReconnect)
            case .roomLimitExceeded: message = RoomKitResources.localizedString(.roomLimitExceeded)
            @unknown default: message = RoomKitResources.localizedString(.defaultKickedOut)
            }
            RoomToast.show(message)
            closeMeetingPage()

        case .onParticipantDeviceClosed(let device, let operatorUser):
            let name = operatorUser.displayName
            switch device {
            case .microphone:
                RoomToast.show(RoomKitResources.localizedFormat(.microphoneClosed, name))
            case .camera:
                RoomToast.show(RoomKitResources.localizedFormat(.cameraClosed, name))
            case .screenShare:
                RoomToast.show(RoomKitResources.localizedFormat(.screenShareClosed, name))
            @unknown default:
                break
            }

        case .onUserMessageDisabled(let disable, _):
            RoomToast.show(RoomKitResources.localizedString(disable ? .messageMuted : .messageUnmuted))

        case .onAllDevicesDisabled(let device, let disable, let operatorUser):
            guard !isLocal(operatorUser.userID) else { return }
            switch device {
            case .microphone: RoomToast.show(RoomKitResources.localizedString(disable ? .allMicrophonesDisabled : .allMicrophonesEnabled))
            case .camera: RoomToast.show(RoomKitResources.localizedString(disable ? .allCamerasDisabled : .allCamerasEnabled))
            case .screenShare: RoomToast.show(RoomKitResources.localizedString(disable ? .allScreenSharesDisabled : .allScreenSharesEnabled))
            @unknown default: break
            }

        case .onAllMessagesDisabled(let disable, let operatorUser):
            guard !isLocal(operatorUser.userID) else { return }
            RoomToast.show(RoomKitResources.localizedString(disable ? .allMessagesDisabled : .allMessagesEnabled))

        case .onDeviceInvitationReceived(let invitation):
            presentDeviceInvitation(invitation)

        case .onDeviceInvitationCancelled(let invitation):
            dismissInvitation(device: invitation.device)

        case .onDeviceInvitationTimeout(let invitation):
            dismissInvitation(device: invitation.device)

        default:
            break
        }
    }

    private func presentDeviceInvitation(_ invitation: DeviceRequestInfo) {
        guard invitation.device == .microphone || invitation.device == .camera else { return }
        dismissInvitation(device: invitation.device) { [weak self] in
            guard let self else { return }
            let isMicrophone = invitation.device == .microphone
            let title = RoomKitResources.localizedFormat(
                isMicrophone ? .microphoneInvitationReceived : .cameraInvitationReceived,
                invitation.senderName
            )
            guard let presenter = self.routerContext as? UIViewController else { return }
            var dialog: RoomDialog?
            dialog = RoomDialog.Builder(in: presenter)
                .title(RoomKitResources.localizedString(.commonNotification))
                .message(title)
                .cancelable(false)
                .secondaryAction(RoomKitResources.localizedString(isMicrophone ? .keepMute : .keepOff)) { [weak self] in
                    dialog?.dismissDialog()
                    self?.invitationDialogs[invitation.device] = nil
                    self?.participantStore.declineOpenDeviceInvitation(
                        userID: invitation.senderUserID, device: invitation.device,
                        completion: { result in
                        if case .failure(let error) = result {
                            ErrorLocalized.showError(code: error.code, message: error.message)
                        }
                    }
                    )
                }
                .primaryAction(RoomKitResources.localizedString(isMicrophone ? .openMicrophone : .openCamera)) { [weak self] in
                    dialog?.dismissDialog()
                    self?.invitationDialogs[invitation.device] = nil
                    self?.participantStore.acceptOpenDeviceInvitation(
                        userID: invitation.senderUserID, device: invitation.device,
                        completion: { result in
                        if case .failure(let error) = result {
                            ErrorLocalized.showError(code: error.code, message: error.message)
                        }
                    }
                    )
                }
                .show()
            self.invitationDialogs[invitation.device] = dialog
        }
    }

    private func dismissInvitation(device: DeviceType, completion: (() -> Void)? = nil) {
        guard let dialog = invitationDialogs.removeValue(forKey: device) else {
            completion?()
            return
        }
        if let stacked = dialog.presentedViewController, let presenter = dialog.presentingViewController {
            presenter.dismiss(animated: false, completion: { [weak self] in
                self?.routerContext?.present(stacked, animated: true, completion: completion)
            })
        } else {
            dialog.dismissDialog(completion: completion)
        }
    }

    private func handleRecordingStarted(by operatorUser: RoomUser) {
        guard !operatorUser.userID.isEmpty, !isLocal(operatorUser.userID) else { return }
        recordingDialog?.dismiss(animated: false)
        CloudRecordingConfirm.dismiss { [weak self] in
            guard let self, let presenter = self.routerContext as? UIViewController else { return }
            self.recordingDialog = RoomDialog.Builder(in: presenter)
                .title(RoomKitResources.localizedString(.recordingNoticeTitle))
                .message(RoomKitResources.localizedFormat(.recordingNoticeContent, operatorUser.displayName))
                .secondaryAction(RoomKitResources.localizedString(.recordingNoticeLeave)) { [weak self] in
                    RoomStore.shared.leaveRoom(completion: nil)
                    self?.closeMeetingPage()
                }
                .primaryAction(RoomKitResources.localizedString(.recordingNoticeConfirm))
                .show()
        }
    }

    private func handleRecordingStopped(by operatorUser: RoomUser, reason: RecordingStopReason) {
        recordingDialog?.dismiss(animated: true)
        if reason == .recorderLeftRoom {
            RoomToast.show(RoomKitResources.localizedString(.recordingEndedAbnormal))
            return
        }
        if reason == .stoppedByUser, isLocal(operatorUser.userID) { return }
        RoomToast.show(RoomKitResources.localizedString(.recordingEnded))
    }

    private func isLocal(_ userID: String) -> Bool {
        !userID.isEmpty && userID == LoginStore.shared.state.value.loginUserInfo?.userID
    }

    private static func deviceName(_ device: DeviceType) -> String {
        switch device {
        case .microphone: return RoomKitResources.localizedString(.notificationsMicrophone)
        case .camera: return RoomKitResources.localizedString(.notificationsCamera)
        case .screenShare: return RoomKitResources.localizedString(.notificationsScreenShare)
        @unknown default: return ""
        }
    }

}

private extension String {
    static let commonNotification = "roomkit.common.notification"
    static let becomeOwner = "roomkit.room_notifications.become_owner"
    static let becomeAdmin = "roomkit.room_notifications.become_admin"
    static let adminRevoked = "roomkit.room_notifications.admin_revoked"
    static let kickedByAdmin = "roomkit.room_notifications.kicked_by_admin"
    static let kickedByServer = "roomkit.room_notifications.kicked_by_server"
    static let replacedByAnotherDevice = "roomkit.room_notifications.replaced_by_another_device"
    static let connectionTimeout = "roomkit.room_notifications.connection_timeout"
    static let invalidStatusOnReconnect = "roomkit.room_notifications.invalid_status_on_reconnect"
    static let roomLimitExceeded = "roomkit.room_notifications.room_limit_exceeded"
    static let defaultKickedOut = "roomkit.room_notifications.default_kicked_out"
    static let microphoneClosed = "roomkit.room_notifications.microphone_closed"
    static let cameraClosed = "roomkit.room_notifications.camera_closed"
    static let screenShareClosed = "roomkit.room_notifications.screen_share_closed"
    static let messageMuted = "roomkit.room_notifications.message_muted"
    static let messageUnmuted = "roomkit.room_notifications.message_unmuted"
    static let allMicrophonesDisabled = "roomkit.room_notifications.all_microphones_disabled"
    static let allMicrophonesEnabled = "roomkit.room_notifications.all_microphones_enabled"
    static let allCamerasDisabled = "roomkit.room_notifications.all_cameras_disabled"
    static let allCamerasEnabled = "roomkit.room_notifications.all_cameras_enabled"
    static let allScreenSharesDisabled = "roomkit.room_notifications.all_screen_shares_disabled"
    static let allScreenSharesEnabled = "roomkit.room_notifications.all_screen_shares_enabled"
    static let allMessagesDisabled = "roomkit.room_notifications.all_messages_disabled"
    static let allMessagesEnabled = "roomkit.room_notifications.all_messages_enabled"
    static let microphoneInvitationReceived = "roomkit.room_notifications.microphone_invitation_received"
    static let cameraInvitationReceived = "roomkit.room_notifications.camera_invitation_received"
    static let openMicrophone = "roomkit.room_notifications.open_microphone"
    static let openCamera = "roomkit.room_notifications.open_camera"
    static let keepMute = "roomkit.room_notifications.keep_mute"
    static let keepOff = "roomkit.room_notifications.keep_off"
    static let notificationsMicrophone = "roomkit.room_notifications.microphone"
    static let notificationsCamera = "roomkit.room_notifications.camera"
    static let notificationsScreenShare = "roomkit.room_notifications.screen_share"
    static let deviceRequestRejected = "roomkit.room_notifications.device_request_rejected"
    static let roomEndedByHost = "roomkit.main.room_ended_by_host"
    static let recordingNoticeTitle = "roomkit.cloud_recording.notify_title"
    static let recordingNoticeContent = "roomkit.cloud_recording.notify_content"
    static let recordingNoticeConfirm = "roomkit.cloud_recording.notify_confirm"
    static let recordingNoticeLeave = "roomkit.cloud_recording.notify_cancel"
    static let recordingEnded = "roomkit.cloud_recording.ended"
    static let recordingEndedAbnormal = "roomkit.cloud_recording.ended_abnormal"
}
