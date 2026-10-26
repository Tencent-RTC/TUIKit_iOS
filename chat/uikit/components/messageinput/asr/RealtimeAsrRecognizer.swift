import Foundation

final class RealtimeAsrRecognizer: NSObject {
    private let language: String
    private let enableVoiceprintDenoise: Bool
    private let onTextUpdated: (String) -> Void
    private lazy var asr = RealtimeASR(
        config: ChatRealtimeASRConfig(language: language, enableVoiceprintDenoise: enableVoiceprintDenoise, enablePCMOutput: false),
        listener: self
    )
    private var sentences: [Int: String] = [:]
    private var active = false
    private var draining = false
    private var finishCallback: ((String) -> Void)?

    init(language: String, enableVoiceprintDenoise: Bool = false, onTextUpdated: @escaping (String) -> Void) {
        self.language = language
        self.enableVoiceprintDenoise = enableVoiceprintDenoise
        self.onTextUpdated = onTextUpdated
        super.init()
    }

    var isRecognizing: Bool {
        return active && !draining && asr.implementation.isLive
    }

    var text: String {
        return sentences.sorted { $0.key < $1.key }.map(\.value).joined()
    }

    @discardableResult
    func prime() -> Bool {
        guard !active else { return true }
        sentences.removeAll()
        active = true
        asr.startASR()
        return active
    }

    func beginRecognize() {
        guard active, !draining else { return }
        asr.startASR()
    }

    func finish(onResult: @escaping (String) -> Void) {
        guard active else { onResult(""); return }
        draining = true
        finishCallback = onResult
        asr.stopASR()
    }

    func cancel() {
        guard active else { return }
        active = false
        draining = false
        finishCallback = nil
        asr.implementation.cancel(stopCapture: true)
        sentences.removeAll()
    }

    private func complete() {
        let callback = finishCallback
        let recognized = text
        finishCallback = nil
        active = false
        draining = false
        sentences.removeAll()
        callback?(recognized)
    }
}

extension RealtimeAsrRecognizer: RealtimeASRListener {
    func onReceiveTranscriberMessage(_ message: ChatRealtimeASRMessage) {
        guard active, !message.sourceText.isEmpty else { return }
        sentences[message.segmentIndex] = message.sourceText
        onTextUpdated(text)
    }

    func onRealtimeTranscriberStopped() {
        guard active, draining else { return }
        complete()
    }

    func onRealtimeTranscriberError(_ errorCode: Int32, errorMsg: String) {
        guard active else { return }
        if asr.implementation.isLive || draining { return }
        cancel()
    }
}
