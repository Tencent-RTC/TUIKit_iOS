import Foundation

final class AICallEnergyVad {
    private let frameDurationMs: Int
    private let calibrationFrames: Int
    private let silenceThresholdFactor: Double
    private let speechThresholdFactor: Double
    private let minNoiseFloor: Double
    private let maxNoiseFloor: Double
    private let speechHangoverMs: Int

    private var noiseFloor = Double.infinity
    private(set) var calibratedFrames = 0
    private var calibrationAttempts = 0
    private var silenceAccumMs = 0
    private var speechAccumMs = 0
    private var speechGapMs = 0
    private var pendingReset = false
    private var pendingRecalibrate = false

    var isCalibrated: Bool {
        calibratedFrames >= calibrationFrames ||
            calibrationAttempts >= calibrationFrames * Self.calibrationAttemptFactor
    }

    var rawNoiseFloor: Double {
        noiseFloor.isFinite ? noiseFloor : .nan
    }

    var effectiveNoiseFloor: Double {
        noiseFloor.isFinite ? min(max(noiseFloor, minNoiseFloor), maxNoiseFloor) : minNoiseFloor
    }

    var silenceThreshold: Double {
        effectiveNoiseFloor * silenceThresholdFactor
    }

    var speechThreshold: Double {
        effectiveNoiseFloor * speechThresholdFactor
    }

    var speechAccumulationMs: Int { speechAccumMs }
    var silenceAccumulationMs: Int { silenceAccumMs }

    init(
        frameDurationMs: Int = AICallConstants.frameDurationMs,
        calibrationFrames: Int = AICallConstants.vadCalibrationFrames,
        silenceThresholdFactor: Double = AICallConstants.vadSilenceThresholdFactor,
        speechThresholdFactor: Double = AICallConstants.vadSpeechThresholdFactor,
        minNoiseFloor: Double = AICallConstants.vadMinNoiseFloor,
        maxNoiseFloor: Double = AICallConstants.vadMaxNoiseFloor,
        speechHangoverMs: Int = AICallConstants.vadSpeechHangoverMs
    ) {
        self.frameDurationMs = frameDurationMs
        self.calibrationFrames = calibrationFrames
        self.silenceThresholdFactor = silenceThresholdFactor
        self.speechThresholdFactor = speechThresholdFactor
        self.minNoiseFloor = minNoiseFloor
        self.maxNoiseFloor = maxNoiseFloor
        self.speechHangoverMs = speechHangoverMs
    }

    func reset() {
        pendingReset = true
    }

    func resetCalibration() {
        pendingRecalibrate = true
    }

    @discardableResult
    func accept(pcm: [Int16]) -> Double {
        if pendingRecalibrate {
            noiseFloor = .infinity
            calibratedFrames = 0
            calibrationAttempts = 0
            pendingRecalibrate = false
            pendingReset = true
        }
        if pendingReset {
            silenceAccumMs = 0
            speechAccumMs = 0
            speechGapMs = 0
            pendingReset = false
        }

        let rms = Self.rms(pcm)
        if !isCalibrated {
            calibrationAttempts += 1
            if rms >= Self.minCalibrationRMS {
                noiseFloor = min(noiseFloor, rms)
                calibratedFrames += 1
            }
            return rms
        }
        let floor = effectiveNoiseFloor
        if rms < floor * silenceThresholdFactor {
            silenceAccumMs = min(silenceAccumMs + frameDurationMs, Self.maxAccumMs)
        } else {
            silenceAccumMs = 0
        }
        if rms > floor * speechThresholdFactor {
            speechGapMs = 0
            speechAccumMs = min(speechAccumMs + frameDurationMs, Self.maxAccumMs)
        } else if speechAccumMs > 0 {
            speechGapMs += frameDurationMs
            if speechGapMs >= speechHangoverMs {
                speechAccumMs = 0
                speechGapMs = 0
            }
        }
        return rms
    }

    func hasSilence(for holdMs: Int) -> Bool {
        isCalibrated && silenceAccumMs >= holdMs
    }

    func hasSpeech(for holdMs: Int) -> Bool {
        isCalibrated && speechAccumMs >= holdMs
    }

    private static func rms(_ pcm: [Int16]) -> Double {
        guard !pcm.isEmpty else { return 0 }
        var sum = 0.0
        for sample in pcm {
            let v = Double(sample)
            sum += v * v
        }
        return (sum / Double(pcm.count)).squareRoot()
    }

    private static let maxAccumMs = 60000
    private static let minCalibrationRMS = 1.0
    private static let calibrationAttemptFactor = 4
}
