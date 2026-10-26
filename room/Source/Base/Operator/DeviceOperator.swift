//
//  DeviceOperator.swift
//  AFNetworking
//
//  Created by adamsfliu on 2026/4/1.
//

import AtomicXCore
import ReplayKit

class DeviceOperator {
    private let deviceStore = DeviceStore.shared
    private var isScreenSharing: Bool = false
    private var stopDebounceWorkItem: DispatchWorkItem?
    private static let kAppGroup = "group.com.tencent.liteav.RPLiveStreamRelease"
    
    init() {
        startObserving()
    }
    
    deinit {
        stopObserving()
    }
    
    // MARK: - Public
    public func openLocalCamera() async throws {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            deviceStore.openLocalCamera(isFront: deviceStore.state.value.isFrontCamera) { result in
                switch result {
                case .success():
                    continuation.resume()
                case .failure(let err):
                    continuation.resume(throwing: ErrorInfo(code: err.code, message: err.message))
                }
            }
        }
    }
    
    public func closeLocalCamera() {
        deviceStore.closeLocalCamera()
    }
    
    public func openLocalMicrophone() async throws {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            deviceStore.openLocalMicrophone { result in
                switch result {
                case .success():
                    continuation.resume()
                case .failure(let err):
                    continuation.resume(throwing: ErrorInfo(code: err.code, message: err.message))
                }
            }
        }
    }
    
    public func closeLocalMicrophone() {
        deviceStore.closeLocalMicrophone()
    }
    
    public func unmuteMicrophone(participantStore: RoomParticipantStore) async throws {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            participantStore.unmuteMicrophone { result in
                switch result {
                case .success():
                    continuation.resume()
                case .failure(let err):
                    continuation.resume(throwing: ErrorInfo(code: err.code, message: err.message))
                }
            }
        }
    }
    
    public func muteMicrophone(participantStore: RoomParticipantStore) {
        participantStore.muteMicrophone()
    }
    
    public func setAudioRoute(route: AudioRoute) {
        deviceStore.setAudioRoute(route)
    }
    
    public func launchScreenShareBroadcast() {
        if #available(iOS 12.0, *) {
            let pickerView = RPSystemBroadcastPickerView(frame: CGRect(x: 0, y: 0, width: 44, height: 44))
            pickerView.preferredExtension = Bundle.main.bundleIdentifier.map { $0 + ".TUIKitReplay" }
            pickerView.showsMicrophoneButton = false
            
            for subview in pickerView.subviews {
                if let button = subview as? UIButton {
                    button.sendActions(for: .allTouchEvents)
                    break
                }
            }
        }
    }
    
    public func stopScreenShare() {
        if isScreenSharing {
            isScreenSharing = false
            deviceStore.stopScreenShare()
        }
    }

}

extension DeviceOperator {
    
    // MARK: - Private
    
    private func startObserving() {
        if #available(iOS 11.0, *) {
            NotificationCenter.default.addObserver(self,
                                                   selector: #selector(onScreenCapturedDidChange),
                                                   name: UIScreen.capturedDidChangeNotification,
                                                   object: nil)
        }
    }
    
    private func stopObserving() {
        if #available(iOS 11.0, *) {
            NotificationCenter.default.removeObserver(self,
                                                      name: UIScreen.capturedDidChangeNotification,
                                                      object: nil)
        }
        stopDebounceWorkItem?.cancel()
        stopDebounceWorkItem = nil
    }
    
    @objc private func onScreenCapturedDidChange() {
        if #available(iOS 11.0, *) {
            let isCaptured = UIScreen.main.isCaptured
            if isCaptured {
                stopDebounceWorkItem?.cancel()
                stopDebounceWorkItem = nil
                if !isScreenSharing {
                    isScreenSharing = true
                    deviceStore.startScreenShare(appGroup: Self.kAppGroup)
                }
            } else {
                stopDebounceWorkItem?.cancel()
                let workItem = DispatchWorkItem { [weak self] in
                    guard let self = self else { return }
                    if !UIScreen.main.isCaptured && self.isScreenSharing {
                        self.isScreenSharing = false
                        self.deviceStore.stopScreenShare()
                    }
                }
                stopDebounceWorkItem = workItem
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.5, execute: workItem)
            }
        }
    }
}
