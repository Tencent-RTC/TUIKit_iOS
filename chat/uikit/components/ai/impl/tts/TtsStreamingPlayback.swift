import AVFoundation
import Foundation
import ImSDK_Plus

final class TtsStreamingPlayback {
    private static let maximumPendingAudioBytes = 4 * 1024 * 1024
    private static let maximumBufferedMilliseconds = 300000
    private var playerToken = UUID()
    private var pendingResponses: [V2TIMTTSResponse] = []
    private var pendingAudioBytes = 0
    private var player: TtsAudioPlayback?
    private var decoder: TtsOpusDecoder?
    private var elem: V2TIMStreamElem?
    private var messageID: String?
    private var generation = 0
    private var startPending = false
    private var started = false
    private var synthesisFinished = false
    private var receivedAudioResponse = false
    private var synthesizedSamples = 0
    private var responseListener: TtsStreamingResponseListener?
    private var timer: DispatchSourceTimer?
    private var onStart: (() -> Void)?
    private var onProgress: ((TtsPlaybackProgress) -> Void)?
    private var onComplete: (() -> Void)?
    private var onError: ((Int32, String) -> Void)?

    private var onCompletePending = false
    private var progress: TtsPlaybackProgress? {
        guard let messageID else { return nil }
        return TtsPlaybackProgress(
            messageID: messageID,
            playedMilliseconds: player?.playedMilliseconds ?? 0,
            synthesizedMilliseconds: synthesizedSamples * 1000 / Int(TtsAudioConstants.sampleRate),
            isSynthesisFinished: synthesisFinished,
            audioLevel: player?.currentLevel ?? 0
        )
    }

    private func prepare() -> Bool {
        if decoder == nil { decoder = TtsOpusDecoder() }
        if player == nil {
            let token = UUID()
            playerToken = token
            player = TtsAudioPlayback { [weak self] in
                DispatchQueue.main.async { [weak self] in
                    guard let self, self.playerToken == token else { return }
                    self.finishPlayback()
                }
            }
        }
        return decoder != nil && player?.start() == true
    }

    func playStreamMessage(message: V2TIMMessage, voiceId: String, speed: Float,
                           onStart: (() -> Void)?, onProgress: ((TtsPlaybackProgress) -> Void)?,
                           onComplete: (() -> Void)?, onError: ((Int32, String) -> Void)?) {
        let id = message.msgID ?? ""
        if id == messageID, startPending || started { return }
        stop(notifyCompletion: false)
        guard !id.isEmpty, let elem = message.streamElem else {
            onError?(-2001, "message is not a valid stream message")
            return
        }
        do {
            let audioSession = AVAudioSession.sharedInstance()
            if audioSession.category != .playAndRecord && audioSession.category != .record {
                try audioSession.setCategory(.playback, mode: .default)
            }
            try audioSession.setActive(true)
        } catch {
            onError?(-2002, error.localizedDescription)
            return
        }
        guard prepare() else {
            stop(notifyCompletion: false)
            onError?(-2002, "streaming audio playback is unavailable")
            return
        }
        generation += 1
        let currentGeneration = generation
        messageID = id
        self.elem = elem
        self.onStart = onStart
        self.onProgress = onProgress
        self.onComplete = onComplete
        self.onError = onError
        onCompletePending = true
        startPending = true
        let listener = TtsStreamingResponseListener { [weak self] response in
            DispatchQueue.main.async { [weak self] in
                guard let self, self.generation == currentGeneration else { return }
                self.receive(response)
            }
        }
        responseListener = listener
        V2TIMManager.sharedInstance().addAdvancedMsgListener(listener: listener)
        let format = V2TIMTTSVoiceFormat()
        format.voiceID = voiceId
        format.speed = speed.isFinite && speed >= 0.5 && speed <= 2 ? speed : 1
        elem.startTTS(voiceFormat: format, succ: { [weak self] in
            DispatchQueue.main.async {
                guard let self, self.generation == currentGeneration, self.onCompletePending else { return }
                self.startPending = false
                self.started = true
                let callback = self.onStart
                self.onStart = nil
                callback?()
                guard self.generation == currentGeneration, self.onCompletePending else { return }
                let responses = self.pendingResponses
                self.pendingResponses.removeAll()
                self.pendingAudioBytes = 0
                for response in responses {
                    guard self.generation == currentGeneration, self.onCompletePending else { return }
                    self.receive(response)
                }
            }
        }, fail: { [weak self] code, desc in
            DispatchQueue.main.async {
                guard let self, self.generation == currentGeneration else { return }
                self.fail(code: code, message: desc ?? "")
            }
        })
    }

    func stop(notifyCompletion: Bool) {
        let callback = onCompletePending && notifyCompletion ? onComplete : nil
        generation += 1
        onCompletePending = false
        startPending = false
        started = false
        onStart = nil
        onProgress = nil
        onComplete = nil
        onError = nil
        timer?.cancel()
        timer = nil
        if let responseListener {
            V2TIMManager.sharedInstance().removeAdvancedMsgListener(listener: responseListener)
        }
        responseListener = nil
        let previousElem = elem
        elem = nil
        messageID = nil
        synthesisFinished = false
        receivedAudioResponse = false
        synthesizedSamples = 0
        pendingResponses.removeAll()
        pendingAudioBytes = 0
        playerToken = UUID()
        previousElem?.stopTTS(succ: nil, fail: nil)
        player?.stop()
        player = nil
        decoder = nil
        callback?()
    }

    deinit {
        stop(notifyCompletion: false)
    }

    private func receive(_ response: V2TIMTTSResponse) {
        guard onCompletePending, response.msgID == messageID, !synthesisFinished,
              let decoder, let player else { return }
        if startPending {
            let bytes = (response.audioDataList ?? []).reduce(0) { $0 + $1.count }
            guard bytes <= Self.maximumPendingAudioBytes - pendingAudioBytes, pendingResponses.count < 1024 else {
                fail(code: -2004, message: "streaming audio pending queue exceeded limit")
                return
            }
            pendingAudioBytes += bytes
            pendingResponses.append(response)
            return
        }
        let responseGeneration = generation
        receivedAudioResponse = true
        for packet in response.audioDataList ?? [] {
            guard !packet.isEmpty else { continue }
            guard let pcm = decoder.decode(packet: packet) else {
                fail(code: -2003, message: "streaming Opus decode failed")
                return
            }
            guard enqueue(pcm, player: player) else { return }
        }
        if response.isFinished {
            if let tail = decoder.finish() {
                guard enqueue(tail, player: player) else { return }
            } else {
                fail(code: -2003, message: "streaming Opus tail decode failed")
                return
            }
            synthesisFinished = true
        }
        publishProgress()
        guard generation == responseGeneration, onCompletePending else { return }
        startProgressTimer()
        if synthesisFinished { player.markEndOfStream() }
    }

    private func enqueue(_ pcm: [Int16], player: TtsAudioPlayback) -> Bool {
        let pendingSamples = synthesizedSamples - player.playedMilliseconds * Int(TtsAudioConstants.sampleRate) / 1000
        let limit = Self.maximumBufferedMilliseconds * Int(TtsAudioConstants.sampleRate) / 1000
        guard pcm.count <= limit - max(0, pendingSamples) else {
            fail(code: -2004, message: "streaming audio playback queue exceeded limit")
            return false
        }
        guard player.enqueue(pcm) else {
            fail(code: -2002, message: "streaming audio buffer could not be scheduled")
            return false
        }
        synthesizedSamples += pcm.count
        return true
    }

    private func startProgressTimer() {
        guard timer == nil else { return }
        let currentGeneration = generation
        let timer = DispatchSource.makeTimerSource(queue: .main)
        timer.schedule(deadline: .now() + .milliseconds(50), repeating: .milliseconds(50))
        timer.setEventHandler { [weak self] in
            guard let self, self.generation == currentGeneration else { return }
            self.publishProgress()
        }
        self.timer = timer
        timer.resume()
    }

    private func publishProgress() {
        guard receivedAudioResponse, let progress else { return }
        onProgress?(progress)
    }

    private func finishPlayback() {
        guard synthesisFinished, onCompletePending else { return }
        let currentGeneration = generation
        publishProgress()
        guard generation == currentGeneration, onCompletePending else { return }
        onCompletePending = false
        startPending = false
        timer?.cancel()
        timer = nil
        if let responseListener {
            V2TIMManager.sharedInstance().removeAdvancedMsgListener(listener: responseListener)
        }
        responseListener = nil
        let callback = onComplete
        onStart = nil
        onProgress = nil
        onComplete = nil
        onError = nil
        callback?()
    }

    private func fail(code: Int32, message: String) {
        let callback = onError
        stop(notifyCompletion: false)
        callback?(code, message)
    }
}

private final class TtsStreamingResponseListener: NSObject, V2TIMAdvancedMsgListener {
    private let onResponse: (V2TIMTTSResponse) -> Void

    init(onResponse: @escaping (V2TIMTTSResponse) -> Void) {
        self.onResponse = onResponse
    }

    func onRecvTTSResponse(response: V2TIMTTSResponse) {
        onResponse(response)
    }
}
