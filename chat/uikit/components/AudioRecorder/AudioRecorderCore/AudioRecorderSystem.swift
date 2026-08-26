
import os.log
import AVFoundation
import Foundation

internal class AudioRecorderSystem: AudioRecorderInternalProtocol {
    let logger = Logger(subsystem: "AudioRecoder", category: "AudioRecorderSystem")

    private static let kMinDuration:Int = 1000

    private static let kMaxDuration: Int = 60000

    private static let meterUpdateInterval: TimeInterval = 0.2

    private static let toastDuration: TimeInterval = 5

    private var listener: AudioRecorderListener?

    private var recorder: AVAudioRecorder?

    private var minDurationMs : Int = AudioRecorderSystem.kMinDuration

    private var maxDurationMs : Int = AudioRecorderSystem.kMaxDuration

    private var recordTimer: Timer?

    private var currentPower: Int = 0

    private var currentTime: TimeInterval = 0

    private var recordSetting:[String: Any]

    init() {
        recordSetting = [
            AVSampleRateKey: 16000.0,
            AVFormatIDKey: kAudioFormatMPEG4AAC,
            AVLinearPCMBitDepthKey: 16,
            AVNumberOfChannelsKey: 1,
            AVEncoderAudioQualityKey: AVAudioQuality.high.rawValue
        ]
    }

    func startRecord(_ path : String, _ minDuration: Int, _ maxDuration: Int) {
        self.minDurationMs = minDuration
        self.maxDurationMs = maxDuration

        let session = AVAudioSession.sharedInstance()
        do {
            try session.setCategory(.playAndRecord)
            try session.setActive(true)
        } catch {
            logger.error("Failed to set audio session category or activate session: \(error)")
            listener?.onComplete(.errorRecordInnerFail);
            return
        }

        let url = URL(fileURLWithPath: path)
        do {
            recorder = try AVAudioRecorder(url: url, settings: recordSetting)
            recorder?.isMeteringEnabled = true
            recorder?.prepareToRecord()
            recorder?.record()
            recorder?.updateMeters()
        } catch {
            logger.error("Failed to initialize AVAudioRecorder: \(error)")
            listener?.onComplete(.errorRecordInnerFail);
            return
        }

        recordTimer = Timer.scheduledTimer(timeInterval: Self.meterUpdateInterval, target: self, selector: #selector(onRecordTimer), userInfo: nil, repeats: true)
        RunLoop.current.add(recordTimer!, forMode: .common)
        logger.info("start system recording")
    }

    func stopRecord() {
        guard AVAudioSession.sharedInstance().recordPermission != .denied else {
            return
        }
        onRecordTimer()

        recorder?.stop()
        recorder = nil

        recordTimer?.invalidate()
        recordTimer = nil

        if Int(currentTime) * 1000 < minDurationMs {
            listener?.onComplete(.errorLessThanMinDuration)
        } else if Int(currentTime) * 1000 > maxDurationMs {
            listener?.onComplete(.exceedMaxDuration)
        } else {
            listener?.onComplete(.success)
        }

        currentTime = 0
        logger.info("stop system recording")
    }

    func setListener(_ listener: AudioRecorderListener) {
        self.listener = listener
    }

    func enableAIDeNoise(_ enable : Bool) {
        if (!enable) {
            return;
        }

        logger.error("system audio record do not support ai de noise");
        #if DEBUG
          WindowToastManager.shared.show(LocalizedChatString("AudioAuthorizationPrompter"), type: .warning, duration: Self.toastDuration)
        #endif
    }

    @objc private func onRecordTimer() {
        recorder?.updateMeters()

        let time = recorder?.currentTime ?? 0
        print("record time = \(time)")
        if time > currentTime {
            currentTime = time
            listener?.onProgress(Int(time * 1000))
        }

        if Int(time * 1000) > maxDurationMs {
            stopRecord()
        }

        let power = recorder?.averagePower(forChannel: 0) ?? 0
        currentPower = Int(power)
        listener?.onPower(currentPower)
    }
}
