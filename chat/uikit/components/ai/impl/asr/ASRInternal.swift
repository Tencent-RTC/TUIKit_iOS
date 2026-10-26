import Foundation
import ImSDK_Plus
import TXLiteAVSDK_VoiceAI_iOS

struct RealtimeASRResponse {
    let sessionID: String
    let chunkIndex: Int
    let isFinished: Bool
    let text: String
}

final class RealtimeASRResponseListener: NSObject, V2TIMSDKListener {
    private let implementation: RealtimeASRResponseListenerImpl

    init(onResponse: @escaping (RealtimeASRResponse) -> Void) {
        implementation = RealtimeASRResponseListenerImpl(onResponse: onResponse)
        super.init()
        implementation.owner = self
    }

    func onExperimentalNotify(key: String, param: NSObject?) {
        implementation.onExperimentalNotify(key: key, param: param)
    }
}

protocol RealtimeASRSessionListener: AnyObject {
    func asrSessionDidStart(_ session: RealtimeASRSession)
    func asrSession(_ session: RealtimeASRSession, didFailToStart code: Int32, desc: String)
}

final class RealtimeASRSession {
    private let implementation: RealtimeASRSessionImpl
    weak var listener: RealtimeASRSessionListener?

    var language: String {
        get { implementation.language }
        set { implementation.language = newValue }
    }
    var startTimeoutMs: Int {
        get { implementation.startTimeoutMs }
        set { implementation.startTimeoutMs = newValue }
    }
    var onLog: ((String) -> Void)? {
        get { implementation.onLog }
        set { implementation.onLog = newValue }
    }
    var onError: ((Int32, String) -> Void)? {
        get { implementation.onError }
        set { implementation.onError = newValue }
    }
    var sessionID: String? { implementation.sessionID }
    var drainSessionID: String? { implementation.drainSessionID }
    var isLive: Bool { implementation.isLive }

    init(listener: RealtimeASRSessionListener?) {
        implementation = RealtimeASRSessionImpl()
        self.listener = listener
        implementation.owner = self
    }
    func start() { implementation.start() }
    func pushPacket(_ packet: Data) { implementation.pushPacket(packet) }
    func applyOpusFrameDuration(_ frameDurationMs: Int) { implementation.applyOpusFrameDuration(frameDurationMs) }
    func stop(onStopped: (() -> Void)? = nil) { implementation.stop(onStopped: onStopped) }
    func stopFlushingTail(tailTimeoutMs: Int, onStopped: @escaping () -> Void) {
        implementation.stopFlushingTail(tailTimeoutMs: tailTimeoutMs, onStopped: onStopped)
    }
    func endDrain() { implementation.endDrain() }
    func noteRemoteFinished(sessionID: String) { implementation.noteRemoteFinished(sessionID: sessionID) }
}

struct VoiceAIAudioConfig {
    var userLanguage: String
    var userEnableVoiceprintDenoise: Bool? = nil
    var userVoiceprintAutoEnrollMs: Int? = nil
    var userEnablePCMOutput: Bool? = nil
}

protocol VoiceAIAudioEngineDelegate: AnyObject {
    func voiceAIAudioEngine(_ engine: VoiceAIAudioEngine, didOutputPCM pcm: [Int16])
    func voiceAIAudioEngine(_ engine: VoiceAIAudioEngine, didOutputOpus packet: Data)
    func voiceAIAudioEngine(_ engine: VoiceAIAudioEngine, didDetectOpusFormat frameDurationMs: Int, sampleRate: Int, channels: Int)
    func voiceAIAudioEngine(_ engine: VoiceAIAudioEngine, didFail message: String)
}

final class VoiceAIAudioEngine: NSObject {
    private let implementation: VoiceAIAudioEngineImpl
    weak var delegate: VoiceAIAudioEngineDelegate?
    var errorHandler: ((Int32, String) -> Void)?
    var logHandler: ((String) -> Void)? {
        get { implementation.logHandler }
        set { implementation.logHandler = newValue }
    }
    override init() {
        implementation = VoiceAIAudioEngineImpl()
        super.init()
        implementation.owner = self
        implementation.addListener(self)
    }
    deinit { implementation.removeListener(self) }
    func start(config: VoiceAIAudioConfig) { implementation.start(config: config) }
    func stop() { implementation.stop() }
}

extension VoiceAIAudioEngine: TXRealtimeASRListener {
    func onRealtimeASRStarted(_ voiceId: String) { implementation.onRealtimeASRStarted(voiceId) }
    func onRealtimeASRStopped() { implementation.onRealtimeASRStopped() }
    func onRealtimeASRError(_ errorCode: Int32, errorMsg: String) {
        implementation.onRealtimeASRError(errorCode, errorMsg: errorMsg)
    }
    func onExperimentalEvent(_ code: String, params: String, data: Data) {
        withExtendedLifetime(self) { implementation.onExperimentalEvent(code, params: params, data: data) }
    }
}
