import AtomicXCore
import UIKit

enum CloudRecordingConfirm {

    static func start(in presenter: UIViewController) {
        RoomDialog.Builder(in: presenter)
            .title(.cloudRecordingStartTitle)
            .message(.cloudRecordingStartContent)
            .closable(false)
            .primaryAction(.cloudRecordingStartConfirm) {
                RoomStore.shared.startRecording { result in
                    switch result {
                    case .success:
                        RoomToast.show(.cloudRecordingStartedToast)
                    case let .failure(error):
                        ErrorLocalized.showError(code: error.code, message: error.message)
                    }
                }
            }
            .secondaryAction(.roomCommonCancel)
            .show()
    }

    static func stop(in presenter: UIViewController) {
        RoomDialog.Builder(in: presenter)
            .title(.cloudRecordingStopTitle)
            .message(.cloudRecordingStopContent)
            .closable(false)
            .primaryAction(.cloudRecordingStopConfirm, variant: .danger) {
                RoomStore.shared.stopRecording { result in
                    switch result {
                    case .success:
                        RoomToast.show(.cloudRecordingStoppedToast)
                    case let .failure(error):
                        ErrorLocalized.showError(code: error.code, message: error.message)
                    }
                }
            }
            .secondaryAction(.roomCommonCancel)
            .show()
    }
}

private extension String {
    static let cloudRecordingStartTitle = RoomKitResources.localizedString("roomkit.cloud_recording.start_title")
    static let cloudRecordingStartContent = RoomKitResources.localizedString("roomkit.cloud_recording.start_content")
    static let cloudRecordingStartConfirm = RoomKitResources.localizedString("roomkit.cloud_recording.start_confirm")
    static let cloudRecordingStopTitle = RoomKitResources.localizedString("roomkit.cloud_recording.stop_title")
    static let cloudRecordingStopContent = RoomKitResources.localizedString("roomkit.cloud_recording.stop_content")
    static let cloudRecordingStopConfirm = RoomKitResources.localizedString("roomkit.cloud_recording.stop_confirm")
    static let cloudRecordingStartedToast = RoomKitResources.localizedString("roomkit.cloud_recording.started_toast")
    static let cloudRecordingStoppedToast = RoomKitResources.localizedString("roomkit.cloud_recording.stopped_toast")
    static let roomCommonCancel = RoomKitResources.localizedString("roomkit.common.cancel")
}
