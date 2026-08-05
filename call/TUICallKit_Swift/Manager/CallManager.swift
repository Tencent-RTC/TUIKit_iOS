import AtomicXCore
import RTCRoomEngine
import AVFoundation
import TUICore

class CallManager {
    static let shared = CallManager()

    private init() {}

    func calls(participantIds: [String],
               mediaType: CallMediaType,
               params: CallParams?,
               completion: CompletionClosure?) {
        let resolvedParams = params ?? defaultCallParams()
        Permission.ensurePermissions(callMediaType: mediaType) { granted in
            guard granted else {
                completion?(.failure(ErrorInfo(code: Int(ERROR_PERMISSION_DENIED),
                                               message: "call failed, authorization status is denied")))
                return
            }
            CallStore.shared.calls(participantIds: participantIds,
                                   mediaType: mediaType,
                                   params: resolvedParams,
                                   completion: completion)
        }
    }

    func accept(completion: CompletionClosure?) {
        let activeCall = CallStore.shared.state.value.activeCall
        guard let mediaType = activeCall.mediaType else {
            completion?(.failure(ErrorInfo(code: Int(ERROR_PARAM_INVALID), message: "accept failed, mediaType is nil")))
            return
        }
        let callId = activeCall.callId
        Permission.ensurePermissions(callMediaType: mediaType) { [weak self] granted in
            guard let self = self else { return }
            guard self.isStillSameCall(callId) else {
                completion?(.failure(ErrorInfo(code: Int(ERROR_PARAM_INVALID), message: "accept aborted, active call changed")))
                return
            }
            guard granted else {
                CallStore.shared.reject(completion: nil)
                completion?(.failure(ErrorInfo(code: Int(ERROR_PERMISSION_DENIED),
                                               message: "accept failed, authorization status is denied")))
                return
            }
            self.openDevices(mediaType: mediaType)
            CallStore.shared.accept(completion: completion)
        }
    }

    func reject(completion: CompletionClosure?) {
        CallStore.shared.reject(completion: completion)
    }

    func hangup(completion: CompletionClosure?) {
        CallStore.shared.hangup(completion: completion)
    }

    func join(callId: String, completion: CompletionClosure?) {
        CallStore.shared.join(callId: callId, completion: completion)
    }

    func openLocalCameraIfPermitted() {
        guard AVCaptureDevice.authorizationStatus(for: .video) == .authorized else { return }
        DeviceStore.shared.openLocalCamera(isFront: true, completion: nil)
    }

    func openLocalCamera(isFront: Bool) {
        Permission.ensureCameraPermission { granted in
            guard granted else { return }
            DeviceStore.shared.openLocalCamera(isFront: isFront) { result in
                switch result {
                case .success:
                    Logger.info("CallManager - openLocalCamera success.")
                case .failure(let error):
                    Logger.error("CallManager - openLocalCamera failed. Code: \(error.code), Message: \(error.message)")
                }
            }
        }
    }

    func closeLocalCamera() {
        DeviceStore.shared.closeLocalCamera()
    }

    func openLocalMicrophone() {
        DeviceStore.shared.openLocalMicrophone(completion: nil)
    }

    func closeLocalMicrophone() {
        DeviceStore.shared.closeLocalMicrophone()
    }

    func setAudioRoute(_ route: AudioRoute) {
        DeviceStore.shared.setAudioRoute(route)
    }

    func switchCamera(isFront: Bool) {
        DeviceStore.shared.switchCamera(isFront: isFront)
    }

    private func openDevices(mediaType: CallMediaType) {
        let deviceStore = DeviceStore.shared
        deviceStore.openLocalMicrophone(completion: nil)
        deviceStore.setAudioRoute(mediaType == .audio ? .earpiece : .speakerphone)
        if mediaType == .video {
            deviceStore.openLocalCamera(isFront: true, completion: nil)
        }
    }

    private func isStillSameCall(_ expectedCallId: String) -> Bool {
        return CallStore.shared.state.value.activeCall.callId == expectedCallId
    }

    private func defaultCallParams() -> CallParams {
        var callParams = CallParams()
        callParams.timeout = Int(TUI_CALLKIT_SIGNALING_MAX_TIME)
        return callParams
    }
}
