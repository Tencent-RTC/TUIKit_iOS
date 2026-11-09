import AtomicXCore
import Combine
import UIKit

enum CloudRecordingConfirm {

    private static var startDialog: RoomDialog?
    private static var stopDialog: RoomDialog?
    private static var autoDismissCancellable: AnyCancellable?

    static func showStartDialog(in presenter: UIViewController) {
        stopDialog?.dismissDialog()
        startDialog = RoomDialog.Builder(in: presenter)
            .title(.cloudRecordingStartTitle)
            .message(.cloudRecordingStartContent)
            .primaryAction(.cloudRecordingStartConfirm) {
                RoomStore.shared.startRecording { result in
                    if case .failure(let error) = result { ErrorLocalized.showError(code: error.code, message: error.message) }
                }
            }
            .secondaryAction(.roomCommonCancel)
            .show()
        watchAutoDismiss(isStartDialog: true)
    }

    static func showStopDialog(in presenter: UIViewController) {
        startDialog?.dismissDialog()
        stopDialog = RoomDialog.Builder(in: presenter)
            .title(.cloudRecordingStopTitle)
            .message(.cloudRecordingStopContent)
            .primaryAction(.cloudRecordingStopConfirm, variant: .danger) {
                RoomStore.shared.stopRecording { result in
                    if case .failure(let error) = result { ErrorLocalized.showError(code: error.code, message: error.message) }
                }
            }
            .secondaryAction(.roomCommonCancel)
            .show()
        watchAutoDismiss(isStartDialog: false)
    }

    static func dismiss(completion: (() -> Void)? = nil) {
        if let dialog = startDialog ?? stopDialog {
            dialog.dismissDialog(completion: completion)
        } else {
            completion?()
        }
    }

    private static func watchAutoDismiss(isStartDialog: Bool) {
        let roomID = RoomStore.shared.state.value.currentRoom?.roomID ?? ""
        autoDismissCancellable = Publishers.CombineLatest(
            RoomStore.shared.state.subscribe(StatePublisherSelector(keyPath: \RoomState.currentRoom)),
            RoomParticipantStore.create(roomID: roomID).state.subscribe(StatePublisherSelector(keyPath: \RoomParticipantState.localParticipant))
        )
        .receive(on: RunLoop.main)
        .sink { room, local in
            let recording = room?.roomID == roomID && room?.recordingInfo.status == .recording
            let canManage = local?.role == .owner || local?.role == .admin
            if !canManage || isStartDialog == recording {
                autoDismissCancellable = nil
                if isStartDialog {
                    startDialog?.dismissDialog()
                } else {
                    stopDialog?.dismissDialog()
                }
            }
        }
        if isStartDialog {
            startDialog?.onDismiss = { autoDismissCancellable = nil; startDialog = nil }
        } else {
            stopDialog?.onDismiss = { autoDismissCancellable = nil; stopDialog = nil }
        }
    }

}

private extension String {
    static let cloudRecordingStartTitle = RoomKitResources.localizedString("roomkit.cloud_recording.start_title")
    static let cloudRecordingStartContent = RoomKitResources.localizedString("roomkit.cloud_recording.start_content")
    static let cloudRecordingStartConfirm = RoomKitResources.localizedString("roomkit.cloud_recording.start_confirm")
    static let cloudRecordingStopTitle = RoomKitResources.localizedString("roomkit.cloud_recording.stop_title")
    static let cloudRecordingStopContent = RoomKitResources.localizedString("roomkit.cloud_recording.stop_content")
    static let cloudRecordingStopConfirm = RoomKitResources.localizedString("roomkit.cloud_recording.stop_confirm")

    static let roomCommonCancel = RoomKitResources.localizedString("roomkit.common.cancel")
}
