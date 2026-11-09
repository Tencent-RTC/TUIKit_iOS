import UIKit
import ReplayKit
import AtomicXCore

public struct RoomScreenShareError: Error {
    public let code: Int
    public let message: String

    public static let notConfigured = RoomScreenShareError(
        code: 10001,
        message: "appGroup/preferredExtension is empty. Call RoomScreenShareLauncher.shared.configure(appGroup:preferredExtension:) before start."
    )
}

public final class RoomScreenShareLauncher {

    public static let shared = RoomScreenShareLauncher()
    private var appGroup = ""
    private var preferredExtension = ""

    private let deviceStore = DeviceStore.shared
    private var isCapturing = false
    private var stopWorkItem: DispatchWorkItem?

    private init() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleCapturedDidChange),
            name: UIScreen.capturedDidChangeNotification,
            object: nil
        )
    }

    public func configure(appGroup: String, preferredExtension: String) {
        self.appGroup = appGroup
        self.preferredExtension = preferredExtension
    }

    public func start() throws {
        guard #available(iOS 12.0, *) else { return }
        guard !appGroup.isEmpty, !preferredExtension.isEmpty else {
            throw RoomScreenShareError.notConfigured
        }
        let picker = RPSystemBroadcastPickerView(frame: CGRect(x: 0, y: 0, width: 44, height: 44))
        picker.preferredExtension = preferredExtension
        picker.showsMicrophoneButton = false
        for subview in picker.subviews {
            guard let button = subview as? UIButton else { continue }
            button.sendActions(for: .touchUpInside)
            break
        }
    }

    public func stop() {
        guard isCapturing else { return }
        isCapturing = false
        deviceStore.stopScreenShare()
    }

    @objc private func handleCapturedDidChange() {
        guard #available(iOS 11.0, *) else { return }
        let captured = UIScreen.main.isCaptured
        NSLog("[ScreenShare] capturedDidChange isCaptured=%d isCapturing=%d", captured, isCapturing)
        guard captured else {
            scheduleStop()
            return
        }
        stopWorkItem?.cancel()
        stopWorkItem = nil
        guard !isCapturing else { return }
        isCapturing = true
        NSLog("[ScreenShare] startScreenShare appGroup=%@", appGroup)
        deviceStore.startScreenShare(appGroup: appGroup)
    }

    private func scheduleStop() {
        stopWorkItem?.cancel()
        let workItem = DispatchWorkItem { [weak self] in
            guard let self else { return }
            guard !UIScreen.main.isCaptured else { return }
            self.stop()
        }
        stopWorkItem = workItem
        DispatchQueue.main.asyncAfter(deadline: .now() + Self.STOP_DEBOUNCE, execute: workItem)
    }
}

private extension RoomScreenShareLauncher {
    static let STOP_DEBOUNCE: TimeInterval = 1.5
}
