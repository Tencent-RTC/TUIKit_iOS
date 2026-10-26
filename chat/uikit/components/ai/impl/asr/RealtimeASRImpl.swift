import Foundation
import ImSDK_Plus

final class RealtimeASRImpl: NSObject {
    private static let tailUploadTimeoutMs = 400
    private static let drainTimeoutMs = 800
    private static let preRollExtraMs = 1000

    private let config: ChatRealtimeASRConfig
    private weak var listener: RealtimeASRListener?
    private var engine: VoiceAIAudioEngine?
    private var session: RealtimeASRSession?
    private var responseListener: RealtimeASRResponseListener?
    private var generation = 0
    private var active = false
    private var stopping = false
    private var restartRequested = false
    private var segmentBaseIndex = 0
    private var stopTimeoutWork: DispatchWorkItem?
    private var preRoll: [Data] = []
    private var frameDurationMs = 20
    private var segmentIndices: [Int: Int] = [:]
    private var segmentTexts: [Int: String] = [:]
    private var nextSegmentIndex = 0
    private var completedSegments: Set<Int> = []

    var uploadsEnabled = true
    var lastErrorWasCapture = false
    var onLog: ((String) -> Void)?
    var isLive: Bool { active && !stopping && session?.isLive == true }

    init(config: ChatRealtimeASRConfig, listener: RealtimeASRListener) {
        self.config = config
        self.listener = listener
        super.init()
    }

    func performOnMain(_ action: @escaping (RealtimeASRImpl) -> Void) {
        if Thread.isMainThread {
            action(self)
        } else {
            DispatchQueue.main.async { action(self) }
        }
    }

    func start() {
        if stopping {
            restartRequested = true
            return
        }
        if active {
            uploadsEnabled = true
            return
        }
        restartRequested = false
        segmentBaseIndex = nextSegmentIndex
        generation += 1
        let currentGeneration = generation
        active = true
        stopping = false
        uploadsEnabled = true
        preRoll.removeAll()
        segmentIndices.removeAll()
        segmentTexts.removeAll()
        completedSegments.removeAll()
        let session = RealtimeASRSession(listener: self)
        session.language = config.language
        session.startTimeoutMs = config.startTimeoutMs > 0 && config.startTimeoutMs <= 60000 ? config.startTimeoutMs : 5000
        session.onLog = { [weak self] in self?.onLog?($0) }
        session.onError = { [weak self] code, message in
            self?.performOnMain {
                guard $0.generation == currentGeneration, $0.active else { return }
                $0.reportError(code, message: message, capture: false)
            }
        }
        self.session = session
        let responseListener = RealtimeASRResponseListener { [weak self] response in
            guard let self, self.generation == currentGeneration else { return }
            self.handleResponse(response)
        }
        self.responseListener = responseListener
        V2TIMManager.sharedInstance().addIMSDKListener(listener: responseListener)
        session.start()
        guard active, !stopping, generation == currentGeneration else { return }
        if engine == nil {
            let engine = VoiceAIAudioEngine()
            engine.delegate = self
            engine.logHandler = { [weak self] in self?.onLog?($0) }
            engine.errorHandler = { [weak self, weak engine] code, message in
                self?.performOnMain {
                    guard let engine, $0.engine === engine else { return }
                    let wasStopping = $0.stopping
                    $0.cancel(stopCapture: true)
                    $0.reportError(code, message: message, capture: true)
                    if wasStopping { $0.listener?.onRealtimeTranscriberStopped() }
                }
            }
            self.engine = engine
            engine.start(config: VoiceAIAudioConfig(
                language: config.language,
                enableVoiceprintDenoise: config.enableVoiceprintDenoise,
                voiceprintAutoEnrollMs: config.voiceprintAutoEnrollMs > 0 ? config.voiceprintAutoEnrollMs : 3000,
                enablePCMOutput: config.enablePCMOutput
            ))
        }
    }

    func stop() {
        guard active, !stopping else { return }
        stopping = true
        uploadsEnabled = false
        engine?.stop()
        engine = nil
        let currentGeneration = generation
        let timeout = DispatchWorkItem { [weak self] in
            guard let self, self.generation == currentGeneration, self.stopping else { return }
            self.finishStop()
        }
        stopTimeoutWork = timeout
        DispatchQueue.main.asyncAfter(deadline: .now() + .milliseconds(Self.drainTimeoutMs), execute: timeout)
        if session?.sessionID != nil {
            flushAndStopSession()
        } else if session?.isLive != true {
            finishStop()
        }
    }

    func cancel(stopCapture: Bool) {
        generation += 1
        active = false
        stopping = false
        restartRequested = false
        uploadsEnabled = false
        stopTimeoutWork?.cancel()
        stopTimeoutWork = nil
        if let responseListener {
            V2TIMManager.sharedInstance().removeIMSDKListener(listener: responseListener)
        }
        responseListener = nil
        session?.stop()
        session?.endDrain()
        session = nil
        if stopCapture {
            engine?.stop()
            engine = nil
        }
        preRoll.removeAll()
        segmentTexts.removeAll()
        segmentIndices.removeAll()
        completedSegments.removeAll()
    }

    private func flushAndStopSession() {
        guard let session else { finishStop(); return }
        flushPreRoll()
        session.stopFlushingTail(tailTimeoutMs: Self.tailUploadTimeoutMs) {}
    }

    private func finishStop() {
        guard active, stopping else { return }
        let shouldRestart = restartRequested
        cancel(stopCapture: true)
        let stoppedGeneration = generation
        listener?.onRealtimeTranscriberStopped()
        if shouldRestart, generation == stoppedGeneration { start() }
    }

    private func handleResponse(_ response: RealtimeASRResponse) {
        guard active, let session else { return }
        let ids = [session.sessionID, session.drainSessionID].compactMap { $0 }
        guard !response.sessionID.isEmpty, ids.contains(response.sessionID) else { return }
        let currentGeneration = generation
        if !response.text.isEmpty {
            let index: Int
            if let existing = segmentIndices[response.chunkIndex] {
                index = existing
            } else {
                guard response.chunkIndex >= 0, response.chunkIndex < Int.max - segmentBaseIndex else { return }
                index = segmentBaseIndex + response.chunkIndex
                nextSegmentIndex = max(nextSegmentIndex, index + 1)
                segmentIndices[response.chunkIndex] = index
            }
            if segmentTexts[index] != response.text {
                segmentTexts[index] = response.text
                listener?.onReceiveTranscriberMessage(ChatRealtimeASRMessage(segmentIndex: index, sourceText: response.text, isCompleted: false))
            }
        }
        guard active, generation == currentGeneration, response.isFinished else { return }
        for index in segmentTexts.keys.sorted() {
            guard active, generation == currentGeneration else { return }
            guard completedSegments.insert(index).inserted, let text = segmentTexts[index] else { continue }
            listener?.onReceiveTranscriberMessage(ChatRealtimeASRMessage(segmentIndex: index, sourceText: text, isCompleted: true))
        }
        guard active, generation == currentGeneration else { return }
        if stopping {
            finishStop()
        } else {
            session.noteRemoteFinished(sessionID: response.sessionID)
            segmentBaseIndex = nextSegmentIndex
            segmentIndices.removeAll()
            segmentTexts.removeAll()
            completedSegments.removeAll()
            session.start()
        }
    }

    private func flushPreRoll() {
        let packets = preRoll
        preRoll.removeAll()
        for packet in packets { session?.pushPacket(packet) }
    }

    private func reportError(_ code: Int32, message: String, capture: Bool) {
        lastErrorWasCapture = capture
        listener?.onRealtimeTranscriberError(code, errorMsg: message)
    }
}

extension RealtimeASRImpl: RealtimeASRSessionListener {
    func asrSessionDidStart(_ session: RealtimeASRSession) {
        guard active, self.session === session, let id = session.sessionID else { return }
        guard !id.isEmpty else {
            let wasStopping = stopping
            cancel(stopCapture: true)
            reportError(-1002, message: "ASR session ID is empty", capture: false)
            if wasStopping { listener?.onRealtimeTranscriberStopped() }
            return
        }
        session.applyOpusFrameDuration(frameDurationMs)
        if stopping {
            flushAndStopSession()
        } else {
            flushPreRoll()
            guard active, !stopping, self.session === session else { return }
            listener?.onRealtimeTranscriberStarted(id)
        }
    }

    func asrSession(_ session: RealtimeASRSession, didFailToStart code: Int32, desc: String) {
        guard active, self.session === session else { return }
        let wasStopping = stopping
        cancel(stopCapture: true)
        reportError(code, message: desc, capture: false)
        if wasStopping { listener?.onRealtimeTranscriberStopped() }
    }
}

extension RealtimeASRImpl: VoiceAIAudioEngineDelegate {
    func voiceAIAudioEngine(_ engine: VoiceAIAudioEngine, didOutputPCM pcm: [Int16]) {
        performOnMain {
            guard $0.engine === engine else { return }
            $0.listener?.onReceiveTranscriberPCM(pcm)
        }
    }

    func voiceAIAudioEngine(_ engine: VoiceAIAudioEngine, didOutputOpus packet: Data) {
        performOnMain {
            guard $0.engine === engine, $0.active, !$0.stopping, $0.uploadsEnabled else { return }
            if $0.session?.sessionID != nil {
                $0.session?.pushPacket(packet)
            } else {
                let timeoutMs = $0.config.startTimeoutMs > 0 && $0.config.startTimeoutMs <= 60000 ? $0.config.startTimeoutMs : 5000
                let capacity = max(1, (timeoutMs + Self.preRollExtraMs) / max(1, $0.frameDurationMs))
                if $0.preRoll.count >= capacity { $0.preRoll.removeFirst() }
                $0.preRoll.append(packet)
            }
        }
    }

    func voiceAIAudioEngine(_ engine: VoiceAIAudioEngine, didDetectOpusFormat frameDurationMs: Int, sampleRate: Int, channels: Int) {
        performOnMain {
            guard $0.engine === engine else { return }
            if frameDurationMs > 0 { $0.frameDurationMs = frameDurationMs }
            $0.session?.applyOpusFrameDuration(frameDurationMs)
            $0.onLog?("ASR Opus format frameMs=\(frameDurationMs) rate=\(sampleRate) channels=\(channels)")
        }
    }

    func voiceAIAudioEngine(_ engine: VoiceAIAudioEngine, didFail message: String) {}
}
