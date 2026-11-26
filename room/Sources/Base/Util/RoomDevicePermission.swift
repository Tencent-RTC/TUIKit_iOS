import AVFoundation
import Combine

public enum RoomDevicePermission {

    public static let microphonePermissionGranted = PassthroughSubject<Void, Never>()
    public static let cameraPermissionGranted = PassthroughSubject<Void, Never>()

    public static func requestMicrophonePermission(completion: @escaping (Bool) -> Void) {
        let handler: (Bool) -> Void = { granted in
            DispatchQueue.main.async {
                if granted {
                    RoomDevicePermission.microphonePermissionGranted.send(())
                }
                completion(granted)
            }
        }
        if #available(iOS 17.0, *) {
            AVAudioApplication.requestRecordPermission(completionHandler: handler)
        } else {
            AVAudioSession.sharedInstance().requestRecordPermission(handler)
        }
    }

    public static func requestCameraPermission(completion: @escaping (Bool) -> Void) {
        AVCaptureDevice.requestAccess(for: .video) { granted in
            DispatchQueue.main.async {
                if granted {
                    RoomDevicePermission.cameraPermissionGranted.send(())
                }
                completion(granted)
            }
        }
    }
}
