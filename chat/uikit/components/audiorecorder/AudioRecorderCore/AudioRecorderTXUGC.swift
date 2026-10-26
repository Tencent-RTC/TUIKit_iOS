import Foundation

import os.log

internal class AudioRecorderTXUGC: AudioRecorderInternalProtocol {
    let logger = Logger(subsystem: "AudioRecoder", category: "AudioRecorderTXUGC")

    static let AUDIO_SAMPLE_RATE: Int = 48000

    static let AUDIO_CHANNEL: Int = 2

    static let AUDIO_BITRATE_BPS: Int = 50 * 1024

    static let ERROR_LESS_THAN_MIN_DURATION = 2

    static let RECORD_RESULT_OK_BEYOND_MAX_DURATION = 3

    private var recorder: TXUGCAudioRecorderReflector?

    private var ugcRecoderReflectorListener: AudioRecorderListenerProxy?

    private var listener: AudioRecorderListener?

    init?() {
        recorder = TXUGCAudioRecorderReflector()
        guard let recorder = recorder else {
            logger.error("TXUGCAudioRecorderReflector init fail.")
            return nil
        }

        ugcRecoderReflectorListener = AudioRecorderListenerProxy()
        guard let ugcRecoderReflectorListener = ugcRecoderReflectorListener else {
            return nil
        }

        listener = nil

        ugcRecoderReflectorListener.recordProgressCallback =  self.onRecordProgress
        ugcRecoderReflectorListener.recordCompleteCallback = self.onRecordComplete
        if !recorder.setRecordDelegate(ugcRecoderReflectorListener) {
            logger.error("set record delegate fail.")
            return nil
        }
    }

    func startRecord(_ path : String, _ minDuration: Int, _ maxDuration: Int) {
        guard let recorder = recorder else {
            logger.error("start recoder fail. recoder is nil")
            return;
        }

        let config: [String: Any] = [
            "audioSampleRate": AudioRecorderTXUGC.AUDIO_SAMPLE_RATE,
            "audioChannel": AudioRecorderTXUGC.AUDIO_CHANNEL,
            "audioBitrateBps": AudioRecorderTXUGC.AUDIO_BITRATE_BPS,
            "minDurationMs": minDuration,
            "maxDurationMs": maxDuration
        ]

        let result = recorder.startRecord(videoPath: path, config: config)
        logger.info("start record. result:\(result.rawValue)")
        switch result {
        case .success:
            return
        case .noliteavsdk:
            listener?.onUnavailable()
        default:
            listener?.onComplete(.errorRecordInnerFail)
        }
    }

    func stopRecord() {
        if let recorder = recorder {
            recorder.stopRecord();
        }
    }

    func setListener(_ listener: AudioRecorderListener) {
        self.listener = listener;
    }

    private func onRecordProgress(milliSecond:Int) {
        if let listener = listener {
            listener.onProgress(milliSecond)
        }
    }

    private func onRecordComplete(_ retCode :Int, _ msg : String, _ videoPath :String) {
        if (retCode == 0) {
            listener?.onComplete(.success)
        } else if (retCode == AudioRecorderTXUGC.ERROR_LESS_THAN_MIN_DURATION) {
            listener?.onComplete(.errorLessThanMinDuration)
        } else if (retCode == AudioRecorderTXUGC.RECORD_RESULT_OK_BEYOND_MAX_DURATION) {
            listener?.onComplete(.exceedMaxDuration)
        } else {
            listener?.onComplete(.errorRecordInnerFail)
        }
    }
}
