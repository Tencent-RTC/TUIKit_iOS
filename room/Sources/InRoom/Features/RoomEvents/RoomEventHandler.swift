import UIKit
import Combine
import AtomicXCore

final class RoomEventHandler {

    var onLeave: ((String?) -> Void)?

    private let roomID: String
    private let participantStore: RoomParticipantStore
    private var cancellableSet = Set<AnyCancellable>()
    private var invitationDialog: RoomDialog?
    private var recordingDialog: RoomDialog?

    init(roomID: String) {
        self.roomID = roomID
        self.participantStore = RoomParticipantStore.create(roomID: roomID)
    }

    func start() {
        participantStore.participantEventPublisher
            .receive(on: RunLoop.main)
            .sink { [weak self] in self?.handleParticipantEvent($0) }
            .store(in: &cancellableSet)

        RoomStore.shared.roomEventPublisher
            .receive(on: RunLoop.main)
            .sink { [weak self] in self?.handleRoomEvent($0) }
            .store(in: &cancellableSet)
    }

    func stop() {
        cancellableSet.removeAll()
        invitationDialog?.dismiss(animated: false)
        recordingDialog?.dismiss(animated: false)
    }

    // MARK: - participant events

    private func handleParticipantEvent(_ event: RoomParticipantEvent) {
        switch event {
        case .onAdminSet(let user):
            guard isLocal(user.userID) else { return }
            toast(.becomeAdmin)

        case .onAdminRevoked(let user):
            guard isLocal(user.userID) else { return }
            toast(.adminRevoked)

        case .onOwnerChanged(let newOwner, _):
            guard isLocal(newOwner.userID) else { return }
            toast(.becomeOwner)

        case .onKickedFromRoom(let reason, _):
            leave(with: Self.kickedText(reason))

        case .onParticipantDeviceClosed(let device, let operatorUser):
            handleDeviceClosed(device, by: operatorUser)

        case .onUserMessageDisabled(let disable, _):
            toast(disable ? .messageMuted : .messageUnmuted)

        case .onAllDevicesDisabled(let device, let disable, _):
            switch device {
            case .microphone: toast(disable ? .allMicrophonesDisabled : .allMicrophonesEnabled)
            case .camera: toast(disable ? .allCamerasDisabled : .allCamerasEnabled)
            case .screenShare: toast(disable ? .allScreenSharesDisabled : .allScreenSharesEnabled)
            @unknown default: break
            }

        case .onAllMessagesDisabled(let disable, _):
            toast(disable ? .allMessagesDisabled : .allMessagesEnabled)

        case .onDeviceInvitationReceived(let invitation):
            presentDeviceInvitation(invitation)

        case .onDeviceInvitationCancelled(let invitation):
            dismissInvitation(device: invitation.device)

        case .onDeviceRequestRejected(let request, _):
            toast(RoomKitResources.localizedFormat(.deviceRequestRejected, Self.deviceName(request.device)))

        default:
            break
        }
    }

    private func handleDeviceClosed(_ device: DeviceType, by operatorUser: RoomUser) {
        let name = Self.displayName(of: operatorUser)
        switch device {
        case .microphone:
            DeviceStore.shared.closeLocalMicrophone()
            toast(RoomKitResources.localizedFormat(.microphoneClosed, name))
        case .camera:
            DeviceStore.shared.closeLocalCamera()
            toast(RoomKitResources.localizedFormat(.cameraClosed, name))
        case .screenShare:
            RoomScreenShareController.shared.stop()
            toast(RoomKitResources.localizedFormat(.screenShareClosed, name))
        @unknown default:
            break
        }
    }

    private func presentDeviceInvitation(_ invitation: DeviceRequestInfo) {
        guard invitation.device == .microphone || invitation.device == .camera else { return }
        invitationDialog?.dismiss(animated: false)
        invitationDialog = nil

        let isMicrophone = invitation.device == .microphone
        let title = RoomKitResources.localizedFormat(
            isMicrophone ? .microphoneInvitationReceived : .cameraInvitationReceived,
            Self.senderName(of: invitation)
        )
        guard let presenter = Self.topViewController() else { return }
        var dialog: RoomDialog?
        dialog = RoomDialog.Builder(in: presenter)
            .title(title)
            .closable(false)
            .cancelable(false)
            .secondaryAction(RoomKitResources.localizedString(isMicrophone ? .keepMute : .keepOff)) { [weak self] in
                dialog?.dismiss(animated: true)
                self?.invitationDialog = nil
                self?.participantStore.declineOpenDeviceInvitation(
                    userID: invitation.senderUserID, device: invitation.device,
                    completion: self?.reportOnFailure()
                )
            }
            .primaryAction(RoomKitResources.localizedString(isMicrophone ? .openMicrophone : .openCamera)) { [weak self] in
                dialog?.dismiss(animated: true)
                self?.invitationDialog = nil
                self?.participantStore.acceptOpenDeviceInvitation(
                    userID: invitation.senderUserID, device: invitation.device,
                    completion: self?.reportOnFailure()
                )
                self?.openDevice(invitation.device)
            }
            .show()
        invitationDialog = dialog
    }

    private func dismissInvitation(device: DeviceType) {
        invitationDialog?.dismiss(animated: true)
        invitationDialog = nil
    }

    private func reportOnFailure<T>() -> (Result<T, ErrorInfo>) -> Void {
        { result in
            if case .failure(let error) = result {
                ErrorLocalized.showError(code: error.code, message: error.message)
            }
        }
    }

    private func openDevice(_ device: DeviceType) {
        switch device {
        case .microphone:
            RoomLocalMediaUtils.openMicrophone(roomID: roomID)
        case .camera:
            RoomLocalMediaUtils.openCamera()
        default:
            break
        }
    }

    // MARK: - room events

    private func handleRoomEvent(_ event: RoomEvent) {
        switch event {
        case .onRoomEnded:
            leave(with: .roomEndedByHost)

        case .onRecordingStarted(_, let operatorUser):
            handleRecordingStarted(by: operatorUser)

        case .onRecordingStopped(_, let operatorUser, let reason):
            handleRecordingStopped(by: operatorUser, reason: reason)

        default:
            break
        }
    }

    private func handleRecordingStarted(by operatorUser: RoomUser) {
        guard !operatorUser.userID.isEmpty, !isLocal(operatorUser.userID) else { return }
        recordingDialog?.dismiss(animated: false)
        guard let presenter = Self.topViewController() else { return }
        recordingDialog = RoomDialog.Builder(in: presenter)
            .title(RoomKitResources.localizedString(.recordingNoticeTitle))
            .message(RoomKitResources.localizedFormat(.recordingNoticeContent, Self.displayName(of: operatorUser)))
            .closable(false)
            .cancelable(false)
            .secondaryAction(RoomKitResources.localizedString(.recordingNoticeLeave)) { [weak self] in
                self?.leave(with: nil)
            }
            .primaryAction(RoomKitResources.localizedString(.recordingNoticeConfirm))
            .show()
    }

    private func handleRecordingStopped(by operatorUser: RoomUser, reason: RecordingStopReason) {
        recordingDialog?.dismiss(animated: true)
        if reason == .recorderLeftRoom {
            toast(.recordingEndedAbnormal)
            return
        }
        if reason == .stoppedByUser, isLocal(operatorUser.userID) { return }
        toast(.recordingEnded)
    }

    // MARK: - helpers

    private func toast(_ key: String) {
        RoomToast.show(RoomKitResources.localizedString(key))
    }

    private func leave(with message: String?) {
        stop()
        onLeave?(message.map { RoomKitResources.localizedString($0) })
    }

    private func isLocal(_ userID: String) -> Bool {
        !userID.isEmpty && userID == LoginStore.shared.state.value.loginUserInfo?.userID
    }

    private static func displayName(of user: RoomUser) -> String {
        user.userName.isEmpty ? user.userID : user.userName
    }

    private static func senderName(of request: DeviceRequestInfo) -> String {
        if !request.senderNameCard.isEmpty { return request.senderNameCard }
        if !request.senderUserName.isEmpty { return request.senderUserName }
        return request.senderUserID
    }

    private static func deviceName(_ device: DeviceType) -> String {
        switch device {
        case .microphone: return RoomKitResources.localizedString(.notificationsMicrophone)
        case .camera: return RoomKitResources.localizedString(.notificationsCamera)
        case .screenShare: return RoomKitResources.localizedString(.notificationsScreenShare)
        @unknown default: return ""
        }
    }

    private static func kickedText(_ reason: KickedOutOfRoomReason) -> String {
        switch reason {
        case .kickedByAdmin: return RoomKitResources.localizedString(.kickedByAdmin)
        case .kickedByServer: return RoomKitResources.localizedString(.kickedByServer)
        case .replacedByAnotherDevice: return RoomKitResources.localizedString(.replacedByAnotherDevice)
        case .connectionTimeout: return RoomKitResources.localizedString(.connectionTimeout)
        case .invalidStatusOnReconnect: return RoomKitResources.localizedString(.invalidStatusOnReconnect)
        case .roomLimitExceeded: return RoomKitResources.localizedString(.roomLimitExceeded)
        @unknown default: return RoomKitResources.localizedString(.defaultKickedOut)
        }
    }

    private static func topViewController() -> UIViewController? {
        UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .flatMap { $0.windows }
            .first(where: { $0.isKeyWindow })?
            .rootViewController.map { topMost(of: $0) }
    }

    private static func topMost(of controller: UIViewController) -> UIViewController {
        if let nav = controller as? UINavigationController, let visible = nav.visibleViewController {
            return topMost(of: visible)
        }
        if let tab = controller as? UITabBarController, let selected = tab.selectedViewController {
            return topMost(of: selected)
        }
        if let presented = controller.presentedViewController { return topMost(of: presented) }
        return controller
    }
}

// MARK: - localized strings

private extension String {
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
