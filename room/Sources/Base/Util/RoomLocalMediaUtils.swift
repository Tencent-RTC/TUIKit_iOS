import AtomicXCore
import AVFoundation
import Combine
import Foundation

public enum RoomDeviceKind {
    case microphone
    case camera

    public var localizedName: String {
        switch self {
        case .microphone: return RoomKitResources.localizedString("roomkit.main.device_name_microphone")
        case .camera: return RoomKitResources.localizedString("roomkit.main.device_name_camera")
        }
    }
}

public enum RoomAudioOutput {
    case speaker
    case earpiece
}

public enum RoomDeviceOpenResult {
    case opened
    case permissionDenied
    case failed(ErrorInfo)
}

public enum RoomLocalMediaUtils {

    public static let deviceOpenDidFinishNotification = Notification.Name("RoomLocalMediaDeviceOpenDidFinish")
    public static let isAudioOutputMuted = CurrentValueSubject<Bool, Never>(false)
    private static var volumeBeforeMute: Int?

    public static func setAudioOutput(_ output: RoomAudioOutput) {
        let deviceStore = DeviceStore.shared
        if isAudioOutputMuted.value {
            deviceStore.setOutputVolume(volumeBeforeMute ?? 100)
            volumeBeforeMute = nil
            isAudioOutputMuted.send(false)
        }
        deviceStore.setAudioRoute(output == .speaker ? .speakerphone : .earpiece)
    }

    public static func apply(roomID: String, isMicrophoneOn: Bool, isSpeakerOn: Bool, isCameraOn: Bool) {
        let deviceStore = DeviceStore.shared
        let room = RoomStore.shared.state.value.currentRoom
        let localUserID = LoginStore.shared.state.value.loginUserInfo?.userID ?? ""
        let isOwner = !localUserID.isEmpty && localUserID == room?.roomOwner.userID
        let isAdmin = RoomParticipantStore.create(roomID: roomID).state.value.localParticipant?.role == .admin

        if isMicrophoneOn && canOpenMicrophone(isOwner: isOwner, isAdmin: isAdmin, room: room) {
            openMicrophone(roomID: roomID)
        } else {
            deviceStore.closeLocalMicrophone()
        }

        if isCameraOn && canOpenCamera(isOwner: isOwner, isAdmin: isAdmin, room: room) {
            openCamera()
        } else {
            deviceStore.closeLocalCamera()
        }

        setAudioOutput(isSpeakerOn ? .speaker : .earpiece)
    }

    private static func canOpenMicrophone(isOwner: Bool, isAdmin: Bool, room: RoomInfo?) -> Bool {
        if isOwner { return true }
        if isAdmin { return true }
        return room?.isAllMicrophoneDisabled != true
    }

    private static func canOpenCamera(isOwner: Bool, isAdmin: Bool, room: RoomInfo?) -> Bool {
        if isOwner { return true }
        if room?.roomType == .standard && isAdmin { return true }
        return room?.isAllCameraDisabled != true
    }

    public static func isPermissionDenied(_ kind: RoomDeviceKind) -> Bool {
        switch kind {
        case .microphone:
            if #available(iOS 17.0, *) {
                return AVAudioApplication.shared.recordPermission == .denied
            }
            return AVAudioSession.sharedInstance().recordPermission == .denied
        case .camera:
            let status = AVCaptureDevice.authorizationStatus(for: .video)
            return status == .denied || status == .restricted
        }
    }

    public static func openSystemSettings() {
        guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
        UIApplication.shared.open(url)
    }

    public static func openMicrophone(roomID: String, completion: ((RoomDeviceOpenResult) -> Void)? = nil) {
        guard DeviceStore.shared.state.value.microphoneStatus != .on else {
            completion?(.opened)
            return
        }
        requestPermission(.microphone) { granted in
            guard granted else {
                finish(.permissionDenied, completion)
                return
            }
            DeviceStore.shared.openLocalMicrophone { result in
                DispatchQueue.main.async {
                    if case .failure(let error) = result {
                        finish(failure(error, kind: .microphone), completion)
                        return
                    }
                    RoomParticipantStore.create(roomID: roomID).unmuteMicrophone { result in
                        DispatchQueue.main.async {
                            switch result {
                            case .success: finish(.opened, completion)
                            case .failure(let error): finish(failure(error, kind: .microphone), completion)
                            }
                        }
                    }
                }
            }
        }
    }

    public static func openCamera(completion: ((RoomDeviceOpenResult) -> Void)? = nil) {
        guard DeviceStore.shared.state.value.cameraStatus != .on else {
            completion?(.opened)
            return
        }
        requestPermission(.camera) { granted in
            guard granted else {
                finish(.permissionDenied, completion)
                return
            }
            DeviceStore.shared.openLocalCamera(isFront: true) { result in
                DispatchQueue.main.async {
                    switch result {
                    case .success: finish(.opened, completion)
                    case .failure(let error): finish(failure(error, kind: .camera), completion)
                    }
                }
            }
        }
    }

    // MARK: - private
    public static func requestPermission(_ kind: RoomDeviceKind, completion: @escaping (Bool) -> Void) {
        let handler: (Bool) -> Void = { granted in
            DispatchQueue.main.async { completion(granted) }
        }
        switch kind {
        case .microphone:
            if #available(iOS 17.0, *) {
                AVAudioApplication.requestRecordPermission(completionHandler: handler)
            } else {
                AVAudioSession.sharedInstance().requestRecordPermission(handler)
            }
        case .camera:
            AVCaptureDevice.requestAccess(for: .video, completionHandler: handler)
        }
    }

    private static func failure(_ error: ErrorInfo, kind: RoomDeviceKind) -> RoomDeviceOpenResult {
        let state = DeviceStore.shared.state.value
        let lastError = kind == .microphone ? state.microphoneLastError : state.cameraLastError
        return lastError == .noSystemPermission ? .permissionDenied : .failed(error)
    }

    private static func finish(_ result: RoomDeviceOpenResult, _ completion: ((RoomDeviceOpenResult) -> Void)?) {
        if case .failed(let error) = result {
            RoomToast.show(RoomKitResources.localizedFormat("roomkit.main.device_failed_format", error.message))
        }
        NotificationCenter.default.post(name: deviceOpenDidFinishNotification, object: nil)
        completion?(result)
    }
}
