import Foundation
import TXLiteAVSDK_VoiceAI_iOS

final class VoiceAIAudioEngineImpl: NSObject {
    private static let pcmEventCode = "onReceiveLocalPcm"
    private static let opusEventCode = "onReceiveLocalOpus"
    private static let pcmLogInterval = 250

    weak var owner: VoiceAIAudioEngine?
    var logHandler: ((String) -> Void)?

    private let engine = TXRealtimeASR()
    private var isRunning = false
    private var opusFormatDetected = false
    private var pcmFrameCount = 0
    private var config = VoiceAIAudioConfig(language: "")

    func addListener(_ listener: VoiceAIAudioEngine) {
        engine.addListener(listener)
    }

    func removeListener(_ listener: VoiceAIAudioEngine) {
        engine.removeListener(listener)
    }

    func start(config: VoiceAIAudioConfig) {
        guard !isRunning else { return }
        isRunning = true
        self.config = config
        opusFormatDetected = false
        pcmFrameCount = 0
        applyPrivateConfig()
        let params = TXRealtimeASRParams()
        params.sdkAppId = ""
        params.userSig = ""
        params.voiceId = UUID().uuidString
        params.sourceLanguage = config.language
        params.enableCustomCapture = false
        engine.startRealtimeASR(params)
        log("voiceAI start requested")
    }

    func stop() {
        guard isRunning else { return }
        isRunning = false
        engine.stopRealtimeASR()
    }

    private func applyPrivateConfig() {
        let volumeConfig = "{\"api\":\"setPrivateConfig\",\"params\":{\"configs\":[{\"key\":\"Liteav.Audio.common.force.system.volume.type\",\"default\":\"0\",\"value\":\"1\"}]}}"
        _ = engine.callExperimentalAPI(volumeConfig)
        _ = engine.callExperimentalAPI("{\"api\":\"enableCloudAsrChannel\",\"params\":{\"enable\":false}}")
        _ = engine.callExperimentalAPI("{\"api\":\"enableLocalOpusOutput\",\"params\":{\"enable\":true}}")
        if config.enablePCMOutput {
            _ = engine.callExperimentalAPI("{\"api\":\"enableLocalPcmOutput\",\"params\":{\"enable\":true}}")
        }
        let voiceprintEnable = config.enableVoiceprintDenoise ? "true" : "false"
        let voiceprintConfig = "{\"api\":\"enableVoiceprintDenoise\",\"params\":{\"enable\":\(voiceprintEnable),\"voiceprint_file_path\":\"\",\"auto_enroll_duration_ms\":\(config.voiceprintAutoEnrollMs)}}"
        _ = engine.callExperimentalAPI(voiceprintConfig)
    }

    private func handlePCM(_ data: Data) {
        guard isRunning, config.enablePCMOutput, !data.isEmpty else { return }
        let pcm = data.withUnsafeBytes { raw -> [Int16] in
            Array(raw.bindMemory(to: Int16.self))
        }
        pcmFrameCount += 1
        if pcmFrameCount <= 5 || pcmFrameCount % Self.pcmLogInterval == 0 {
            log("voiceAI pcm #\(pcmFrameCount) bytes=\(data.count) samples=\(pcm.count)")
        }
        if let owner {
            owner.delegate?.voiceAIAudioEngine(owner, didOutputPCM: pcm)
        }
    }

    private func handleOpus(_ data: Data, message: String) {
        guard isRunning, !data.isEmpty else { return }
        detectOpusFormatIfNeeded(message)
        if let owner {
            owner.delegate?.voiceAIAudioEngine(owner, didOutputOpus: data)
        }
    }

    private func detectOpusFormatIfNeeded(_ message: String) {
        guard !opusFormatDetected else { return }
        opusFormatDetected = true
        guard let jsonData = message.data(using: .utf8),
              let dict = try? JSONSerialization.jsonObject(with: jsonData) as? [String: Any] else {
            log("voiceAI opus meta parse failed: \(message)")
            return
        }
        let frameDurationMs = (dict["frameDurationMs"] as? NSNumber)?.intValue ?? 20
        let sampleRate = (dict["sampleRate"] as? NSNumber)?.intValue ?? 16000
        let channels = (dict["channels"] as? NSNumber)?.intValue ?? 1
        log("voiceAI opus format frameMs=\(frameDurationMs) rate=\(sampleRate) channels=\(channels)")
        if let owner {
            owner.delegate?.voiceAIAudioEngine(owner, didDetectOpusFormat: frameDurationMs, sampleRate: sampleRate, channels: channels)
        }
    }

    private func log(_ message: String) {
        logHandler?(message)
    }
}

extension VoiceAIAudioEngineImpl: TXRealtimeASRListener {
    func onRealtimeASRStarted(_ voiceId: String) {
        log("voiceAI started voiceId=\(voiceId)")
    }

    func onRealtimeASRStopped() {
        log("voiceAI stopped")
    }

    func onRealtimeASRError(_ errorCode: Int32, errorMsg: String) {
        log("voiceAI error code=\(errorCode) msg=\(errorMsg)")
        if let owner {
            if let errorHandler = owner.errorHandler {
                errorHandler(errorCode, errorMsg)
            } else {
                owner.delegate?.voiceAIAudioEngine(owner, didFail: "\(errorCode) \(errorMsg)")
            }
        }
    }

    func onExperimentalEvent(_ code: String, params: String, data: Data) {
        switch code {
        case Self.pcmEventCode:
            handlePCM(data)
        case Self.opusEventCode:
            handleOpus(data, message: params)
        default:
            break
        }
    }
}
