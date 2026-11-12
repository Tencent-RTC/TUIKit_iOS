import AtomicXCore
import AVFoundation
import Combine
import UIKit

final class CallLauncher {

    static let shared = CallLauncher()

    private let callWindow = CallWindow()
    private var cancellables = Set<AnyCancellable>()
    private var isHangingUp = false
    private var isAnswering = false
    private var preparedCallId = ""
    private var expandedIncomingCallId = ""
    private var didOpenCamera = false
    private var transcriber: AITranscriberStore?
    private var runningCallId = ""

    private init() {
        subscribeCallState()
        subscribeCallEvents()
        setupTranscriptionObserver()
    }

    func hangup() {
        let callId = CallStore.shared.state.value.activeCall.callId
        guard !isHangingUp, !callId.isEmpty else { return }
        isHangingUp = true
        CallStore.shared.hangup { result in
            if case .failure(let error) = result {
                CallKitLog.error("hangup failed: code=\(error.code) message=\(error.message)")
            }
            DispatchQueue.main.async { self.isHangingUp = false }
        }
    }

    func acceptIncoming() {
        respondIncoming(accept: true)
    }

    func rejectIncoming() {
        respondIncoming(accept: false)
    }

    private func respondIncoming(accept: Bool) {
        guard !isAnswering else { return }
        isAnswering = true
        let done: (Result<Void, ErrorInfo>) -> Void = { result in
            if case .failure(let error) = result {
                CallKitLog.error("respondIncoming(accept: \(accept)) failed: code=\(error.code) message=\(error.message)")
            }
            DispatchQueue.main.async { self.isAnswering = false }
        }
        accept ? CallStore.shared.accept(completion: done) : CallStore.shared.reject(completion: done)
    }

    private func subscribeCallState() {
        CallStore.shared.state
            .subscribe(StatePublisherSelector { state in
                let call = state.activeCall
                return "\(call.callId)|\(state.selfInfo.status.rawValue)|\(call.mediaType?.rawValue ?? 0)|\(call.inviterId)"
            })
            .removeDuplicates()
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in
                self?.routeToCurrentState()
            }
            .store(in: &cancellables)
    }

    private func subscribeCallEvents() {
        CallStore.shared.callEventPublisher
            .receive(on: RunLoop.main)
            .sink { [weak self] event in
                if case .onCallEnded(_, _, let reason, let userId) = event {
                    self?.handleCallEnded(reason: reason, endedBy: userId)
                }
            }
            .store(in: &cancellables)
    }

    private func setupTranscriptionObserver() {
        let callChanged = CallStore.shared.state
            .subscribe(StatePublisherSelector { "\($0.selfInfo.status.rawValue)|\($0.activeCall.callId)" })
            .removeDuplicates()
            .map { _ in }
        Publishers.Merge(CallKitConfig.shared.transcriptionChanged, callChanged)
            .receive(on: RunLoop.main)
            .sink { [weak self] in self?.applyTranscriptionState() }
            .store(in: &cancellables)
    }

    private func applyTranscriptionState() {
        let state = CallStore.shared.state.value
        let callId = state.activeCall.callId
        guard CallKitConfig.shared.enableAITranscriber, !callId.isEmpty, state.selfInfo.status == .accept else {
            stopTranscriber()
            return
        }
        guard transcriber == nil || runningCallId != callId else { return }
        stopTranscriber()
        let store = AITranscriberStore.create(roomID: callId)
        transcriber = store
        runningCallId = callId
        store.startTranscription(myLanguage: .chineseEnglish, config: TranscriptionConfig(enableTranslation: true)) { result in
            guard case .failure(let error) = result else { return }
            CallKitLog.error("startTranscription failed: code=\(error.code) message=\(error.message)")
            DispatchQueue.main.async {
                CallKitConfig.shared.updateAITranscriber(false)
            }
        }
    }

    private func stopTranscriber() {
        transcriber?.stopTranscription { result in
            guard case .failure(let error) = result else { return }
            CallKitLog.warning("stopTranscription failed: code=\(error.code) message=\(error.message)")
        }
        transcriber = nil
        runningCallId = ""
    }

    private func routeToCurrentState() {
        let state = CallStore.shared.state.value
        let call = state.activeCall
        let selfID = LoginStore.shared.state.value.loginUserInfo?.userID ?? ""
        let isOutgoing = !call.inviterId.isEmpty && call.inviterId == selfID
        let status = state.selfInfo.status

        guard !call.callId.isEmpty else {
            dismissAllCallUI()
            return
        }

        switch status {
        case .waiting where isOutgoing:
            prepareAudioSession(callId: call.callId, mediaType: call.mediaType)
            showCallViewIfNeeded()
            Ringtone.shared.startDialTone()
        case .waiting:
            let wantsBanner = CallKitConfig.shared.enableIncomingBanner
                && expandedIncomingCallId != call.callId
                && !callWindow.isShowing
            if wantsBanner {
                showIncomingBanner()
            } else {
                showCallViewIfNeeded()
            }
            Ringtone.shared.startRinging()
        case .accept:
            callWindow.dismissBanner()
            prepareAudioSession(callId: call.callId, mediaType: call.mediaType)
            showCallViewIfNeeded()
            Ringtone.shared.stopAll()
        default:
            break
        }
    }

    private func showIncomingBanner() {
        guard !callWindow.isBannerShowing else { return }
        let mediaType = CallStore.shared.state.value.activeCall.mediaType
        let banner = IncomingBannerView(mediaType: mediaType)
        banner.reload()
        banner.onAccept = { self.acceptIncoming() }
        banner.onReject = { self.rejectIncoming() }
        banner.onExpand = {
            self.expandedIncomingCallId = CallStore.shared.state.value.activeCall.callId
            self.callWindow.dismissBanner()
            self.showCallViewIfNeeded()
        }
        callWindow.showBanner(banner)
    }

    private func showCallViewIfNeeded() {
        guard !callWindow.isShowing else { return }
        callWindow.showFullScreen(CallViewController())
    }

    private func dismissAllCallUI() {
        Ringtone.shared.stopAll()
        callWindow.dismissBanner()
        callWindow.dismiss()
        teardownAudioSession()
        expandedIncomingCallId = ""
    }

    private func handleCallEnded(reason: CallEndReason, endedBy userId: String) {
        dismissAllCallUI()
        let selfID = LoginStore.shared.state.value.loginUserInfo?.userID ?? ""
        guard userId != selfID else { return }
        let key: String
        switch reason {
        case .reject, .lineBusy: key = "callkit.call.peer_rejected"
        case .noResponse: key = "callkit.call.peer_no_answer"
        case .canceled: key = "callkit.call.peer_canceled"
        case .hangup: key = "callkit.call.call_ended"
        default: return
        }
        CallKitToast.show(CallKitResources.text(key))
    }

    private func prepareAudioSession(callId: String, mediaType: CallMediaType?) {
        guard preparedCallId != callId else { return }
        preparedCallId = callId
        let isVideo = mediaType == .video
        requestMicrophonePermission { granted in
            guard granted else { return CallKitLog.warning("microphone permission denied") }
            DeviceStore.shared.openLocalMicrophone { result in
                guard case .failure(let error) = result else { return }
                CallKitLog.error("openLocalMicrophone failed: code=\(error.code) message=\(error.message)")
            }
        }
        if isVideo {
            requestCameraPermission { granted in
                guard granted else { return CallKitLog.warning("camera permission denied") }
                self.didOpenCamera = true
                DeviceStore.shared.openLocalCamera(isFront: true) { result in
                    guard case .failure(let error) = result else { return }
                    CallKitLog.error("openLocalCamera failed: code=\(error.code) message=\(error.message)")
                }
            }
        }
        setAudioRoute(earpiece: !isVideo)
    }

    private func teardownAudioSession() {
        preparedCallId = ""
        if didOpenCamera {
            didOpenCamera = false
            DeviceStore.shared.closeLocalCamera()
        }
        DeviceStore.shared.closeLocalMicrophone()
        setAudioRoute(earpiece: false)
    }

    private func setAudioRoute(earpiece: Bool) {
        let speakers = DeviceStore.shared.state.value.speakerList
        let targetName = earpiece ? "earpiece" : "speakerphone"
        guard let device = speakers.first(where: { $0.deviceName == targetName }) else { return }
        DeviceStore.shared.setCurrentSpeaker(device)
    }

    private func requestMicrophonePermission(completion: @escaping (Bool) -> Void) {
        let reply: (Bool) -> Void = { granted in DispatchQueue.main.async { completion(granted) } }
        if #available(iOS 17.0, *) {
            AVAudioApplication.requestRecordPermission(completionHandler: reply)
        } else {
            AVAudioSession.sharedInstance().requestRecordPermission(reply)
        }
    }

    private func requestCameraPermission(completion: @escaping (Bool) -> Void) {
        AVCaptureDevice.requestAccess(for: .video) { granted in
            DispatchQueue.main.async { completion(granted) }
        }
    }
}
