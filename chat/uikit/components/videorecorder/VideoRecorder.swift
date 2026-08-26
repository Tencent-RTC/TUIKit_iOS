import AtomicXCore
import Combine
import UIKit

enum RecordMode: Int {
    case videoPhotoMix = 0
    case photoOnly = 1
    case videoOnly = 2
}

func fetchVideoRecorderSignature() {
    if VideoRecordSignatureChecker.shareInstance().getSetSignatureResult() == .VIDEO_RECORD_SIGNATURE_SUCCESS {
        return
    }

    let currentLoginStatus = LoginStore.shared.state.value.loginStatus
    if currentLoginStatus == .logined {
        VideoRecordSignatureChecker.shareInstance().startUpdateSignature(
            NSNumber(value: LoginStore.shared.sdkAppID).stringValue)
        return
    }

    var cancellables = Set<AnyCancellable>()
    LoginStore.shared.state
        .subscribe(StatePublisherSelector(keyPath: \LoginState.loginStatus))
        .first()
        .sink { loginStatus in
            if loginStatus == .logined {
                VideoRecordSignatureChecker.shareInstance().startUpdateSignature(
                    NSNumber(value: LoginStore.shared.sdkAppID).stringValue)
            }
        }
        .store(in: &cancellables)
}
