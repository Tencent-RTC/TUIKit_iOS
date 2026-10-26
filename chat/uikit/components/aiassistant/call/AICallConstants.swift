import Foundation

enum AICallConstants {
    static let sampleRate: Int32 = 16000
    static let channels: UInt32 = 1
    static let frameDurationMs = 20
    static let frameSampleCount = 320

    static let opusMaxBytes = 4000

    static let uploadBatchFrames = 5

    static let silenceHoldMs = 3000
    static let textStableHoldMs = 3000
    static let drainWindowMs = 700
    static let thinkingTimeoutMs = 30000
    static let speakingStallTimeoutMs = 10000
    static let asrStartTimeoutMs = 8000
    static let minBargeInTextLength = 2
    static let bargeInSpeechHoldMs = 120
    static let postSpeakingEchoGuardMs = 2500

    static let vadCalibrationFrames = 15
    static let vadSilenceThresholdFactor = 2.0
    static let vadSpeechThresholdFactor = 2.5
    static let vadMinNoiseFloor = 100.0
    static let vadMaxNoiseFloor = 2000.0
    static let vadSpeechHangoverMs = 240

    static let asrLanguage = "zh"
}
