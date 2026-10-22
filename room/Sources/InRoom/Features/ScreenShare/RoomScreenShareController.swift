import UIKit
import ReplayKit
import Combine
import AtomicXCore

public final class RoomScreenShareController {

    public static let shared = RoomScreenShareController()
    private static let appGroup = "group.com.tencent.liveadapter.demo"
    private static let preferredExtension = "com.tencent.liveadapter.demo.upload"

    @Published private(set) var isSharing = false
    @Published private(set) var sharerName: String?

    private let deviceStore = DeviceStore.shared
    private var isCapturing = false
    private var stopWorkItem: DispatchWorkItem?
    private var cancellableSet = Set<AnyCancellable>()
    private var boundRoomID: String?

    private init() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleCapturedDidChange),
            name: UIScreen.capturedDidChangeNotification,
            object: nil
        )
    }

    public func bind(roomID: String) {
        guard boundRoomID != roomID else { return }
        boundRoomID = roomID
        cancellableSet.removeAll()
        let store = RoomParticipantStore.create(roomID: roomID)
        store.state
            .subscribe(StatePublisherSelector(keyPath: \RoomParticipantState.localParticipant))
            .map { $0?.screenShareStatus == .on }
            .removeDuplicates()
            .receive(on: RunLoop.main)
            .sink { [weak self] in self?.isSharing = $0 }
            .store(in: &cancellableSet)
        store.state
            .subscribe(StatePublisherSelector(keyPath: \RoomParticipantState.participantWithScreen))
            .receive(on: RunLoop.main)
            .sink { [weak self] in self?.sharerName = $0?.displayName }
            .store(in: &cancellableSet)
    }

    public func start() {
        guard #available(iOS 12.0, *) else { return }
        let picker = RPSystemBroadcastPickerView(frame: CGRect(x: 0, y: 0, width: 44, height: 44))
        picker.preferredExtension = Self.preferredExtension
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
        NSLog("[ScreenShare] startScreenShare appGroup=%@", Self.appGroup)
        deviceStore.startScreenShare(appGroup: Self.appGroup)
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

// MARK: - private constants

private extension RoomScreenShareController {
    static let STOP_DEBOUNCE: TimeInterval = 1.5
}
