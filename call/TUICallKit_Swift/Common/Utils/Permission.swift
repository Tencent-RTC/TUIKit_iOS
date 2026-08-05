//
//  Permission.swift
//  Pods
//
//  Created by vincepzhang on 2025/3/3.
//

import AVFoundation
import AtomicXCore
import RTCRoomEngine

enum AuthorizationDeniedType: Int {
    case audio
    case video
}

class Permission: NSObject {
    static func hasPermission(callMediaType: CallMediaType,
                              completion: CompletionClosure? = nil) -> Bool {
        if Permission.checkAuthorizationStatusIsDenied(mediaType: .audio) {
            Permission.showAuthorizationAlert(deniedType: .audio)
            completion?(.failure(ErrorInfo(code: Int(ERROR_PARAM_INVALID), message: "call failed, authorization status is denied")))
            return false
        }

        let needsCamera = callMediaType == .video
        if needsCamera && Permission.checkAuthorizationStatusIsDenied(mediaType: .video) {
            Permission.showAuthorizationAlert(deniedType: .video)
            completion?(.failure(ErrorInfo(code: Int(ERROR_PARAM_INVALID), message: "call failed, authorization status is denied")))
            return false
        }

        return true
    }

    static func checkAuthorizationStatusIsDenied(mediaType: AVMediaType) -> Bool {
        return AVCaptureDevice.authorizationStatus(for: mediaType) == .denied
    }

    static func ensurePermission(mediaType: AVMediaType, completion: @escaping (Bool) -> Void) {
        switch AVCaptureDevice.authorizationStatus(for: mediaType) {
        case .authorized:
            completion(true)
        case .denied, .restricted:
            completion(false)
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: mediaType) { granted in
                DispatchQueue.main.async {
                    completion(granted)
                }
            }
        @unknown default:
            completion(false)
        }
    }

    static func ensureCameraPermission(completion: @escaping (Bool) -> Void) {
        ensurePermission(mediaType: .video) { granted in
            if granted {
                completion(true)
                return
            }
            Permission.showAuthorizationAlert(deniedType: .video) {
                completion(false)
            }
        }
    }

    static func ensurePermissions(callMediaType: CallMediaType,
                                  completion: @escaping (Bool) -> Void) {
        let needsCamera = callMediaType == .video
        ensurePermission(mediaType: .audio) { audioGranted in
            guard audioGranted else {
                Permission.showAuthorizationAlert(deniedType: .audio) {
                    completion(false)
                }
                return
            }
            if !needsCamera {
                completion(true)
                return
            }
            ensurePermission(mediaType: .video) { videoGranted in
                if videoGranted {
                    completion(true)
                } else {
                    Permission.showAuthorizationAlert(deniedType: .video) {
                        completion(false)
                    }
                }
            }
        }
    }

    private static var permissionAlertWindow: UIWindow?

    static func showAuthorizationAlert(deniedType: AuthorizationDeniedType,
                                       completion: (() -> Void)? = nil) {
        var title: String
        var message: String
        var laterMessage: String
        var openSettingMessage: String

        let appName = Bundle.main.infoDictionary?["CFBundleDisplayName"] as? String
                   ?? Bundle.main.infoDictionary?["CFBundleName"] as? String
                   ?? "App"

        switch deniedType {
        case .audio:
            title = TUICallKitLocalize(key: "TUICallKit.FailedToGetMicrophonePermission.Title")
            let messageTemplate = TUICallKitLocalize(key: "TUICallKit.FailedToGetMicrophonePermission.Tips")
            message = String(format: messageTemplate, appName)
            laterMessage = TUICallKitLocalize(key: "TUICallKit.FailedToGetMicrophonePermission.Later")
            openSettingMessage = TUICallKitLocalize(key: "TUICallKit.FailedToGetMicrophonePermission.Enable")
        case .video:
            title = TUICallKitLocalize(key: "TUICallKit.FailedToGetCameraPermission.Title")
            let messageTemplate = TUICallKitLocalize(key: "TUICallKit.FailedToGetCameraPermission.Tips")
            message = String(format: messageTemplate, appName)
            laterMessage = TUICallKitLocalize(key: "TUICallKit.FailedToGetCameraPermission.Later")
            openSettingMessage = TUICallKitLocalize(key: "TUICallKit.FailedToGetCameraPermission.Enable")
        }

        let alertController = UIAlertController(title: title, message: message, preferredStyle: .alert)

        var didFinish = false
        let finish: () -> Void = {
            guard !didFinish else { return }
            didFinish = true
            Permission.tearDownAlertWindow()
            completion?()
        }

        alertController.addAction(UIAlertAction(title: laterMessage, style: .cancel, handler: { _ in
            finish()
        }))

        alertController.addAction(UIAlertAction(title: openSettingMessage, style: .default, handler: { _ in
            let app = UIApplication.shared
            if let url = URL(string: UIApplication.openSettingsURLString), app.canOpenURL(url) {
                if #available(iOS 10.0, *) {
                    app.open(url)
                } else {
                    app.openURL(url)
                }
            }
            finish()
        }))

        DispatchQueue.main.async {
            guard let presenter = Permission.bringUpAlertWindow() else {
                finish()
                return
            }
            presenter.present(alertController, animated: true)
        }
    }

    private static func bringUpAlertWindow() -> UIViewController? {
        if let existing = permissionAlertWindow?.rootViewController {
            return existing
        }
        let window = UIWindow(frame: UIScreen.main.bounds)
        window.windowLevel = .alert + 2
        window.backgroundColor = .clear
        window.rootViewController = UIViewController()
        if #available(iOS 13.0, *) {
            for scene in UIApplication.shared.connectedScenes {
                guard scene.activationState == .foregroundActive ||
                      scene.activationState == .foregroundInactive else { continue }
                if let windowScene = scene as? UIWindowScene {
                    window.windowScene = windowScene
                    break
                }
            }
        }
        window.makeKeyAndVisible()
        permissionAlertWindow = window
        return window.rootViewController
    }

    private static func tearDownAlertWindow() {
        guard let window = permissionAlertWindow else { return }
        window.isHidden = true
        window.rootViewController = nil
        permissionAlertWindow = nil
    }
}
