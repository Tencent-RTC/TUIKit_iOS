import AtomicXCore
import Foundation
import ImSDK_Plus

protocol AICallControllerDelegate: AnyObject {
    func callController(_ controller: AICallController, didChangeState state: AICallState)
    func callController(_ controller: AICallController, didChangeTranscript entries: [AICallTranscriptEntry])
    func callController(_ controller: AICallController, didUpdateAudioLevel level: Float)
    func callController(_ controller: AICallController, didEncounterError error: AICallError)
    func callControllerDidFailListening(_ controller: AICallController)
}

final class AICallController: NSObject {
    private let robotUserID: String
    private let config: AICallConfig
    private weak var delegate: AICallControllerDelegate?

    private let vad: AICallEnergyVad
    private lazy var asr = RealtimeASR(
        config: ChatRealtimeASRConfig(
            language: AICallConstants.asrLanguage,
            enableVoiceprintDenoise: config.enableVoiceprintDenoise,
            startTimeoutMs: AICallConstants.asrStartTimeoutMs
        ),
        listener: self
    )
    private lazy var advancedMsgListener = AICallAdvancedMsgListener(controller: self)

    private static let ttsPlaybackErrorCodes: ClosedRange<Int32> = -2004 ... -2001
    private let tts = TtsPlaybacker()
    private var ttsGeneration = 0
    private var lastTtsProgress: TtsPlaybackProgress?
    private var hasStartedTTS = false
    private var ttsStartPending = false
    private var ttsRequestActive = false
    private var currentStreamEnded = false

    private let messageInputStore: MessageInputStore

    private var state: AICallState = .idle
    private var lastSpeakingEndUptime: TimeInterval = 0
    private var released = false
    private var muted = false
    private var pausedExternally = false
    private var startFailed = false

    private var hasRecognizedText = false
    private var lastAsrTextChangeUptime: TimeInterval = 0
    private var committedChunkCeiling = -1
    private var committedSegments: [Int: String] = [:]
    private var sentences: [Int: String] = [:]
    private var lastSeenBargeInText: [Int: String] = [:]
    private var committedUserText = ""
    private var transcript: [AICallTranscriptEntry] = []
    private var aiEntryIndex = -1
    private var streamingMsgID: String?
    private var speechProgress: AICallSpeechProgress?

    private var drainGeneration = 0
    private var drainTimeoutWork: DispatchWorkItem?
    private var replyTimeoutWork: DispatchWorkItem?
    private var speakingWatchdogWork: DispatchWorkItem?
    private var awaitingAsrForListening = false

    init(robotUserID: String, delegate: AICallControllerDelegate, config: AICallConfig = AICallConfig()) {
        let config = config.validated()
        self.robotUserID = robotUserID
        self.config = config
        self.delegate = delegate
        vad = AICallEnergyVad()
        let conversationID = "c2c_\(robotUserID)"
        messageInputStore = MessageInputStore.create(conversationID: conversationID)
        super.init()
    }

    func start() -> Bool {
        guard !released else { return false }
        AIAssistantUsageReporter.reportInvokeCallOnce()
        V2TIMManager.sharedInstance().addAdvancedMsgListener(listener: advancedMsgListener)

        guard !released else { return false }
        asr.implementation.onLog = { AICallLog("[AICall] \($0)") }
        awaitingAsrForListening = true
        startNewASRSession()
        sendVoiceSessionPing(RobotControlMessages.voiceEnterAction)
        return true
    }

    func release() {
        guard !released else { return }
        released = true
        finalizeCurrentAIEntry()
        sendVoiceSessionPing(RobotControlMessages.voiceLeaveAction)
        cancelReplyTimeout()
        cancelSpeakingWatchdog()
        closeDrainWindow()
        stopCurrentTTS()
        asr.implementation.cancel(stopCapture: true)
        V2TIMManager.sharedInstance().removeAdvancedMsgListener(listener: advancedMsgListener)
        setState(.idle)
    }

    func setMuted(_ newMuted: Bool) {
        guard !released, muted != newMuted else { return }
        muted = newMuted
        if newMuted {
            applyMute()
        } else if !pausedExternally {
            resumeFromMute()
        }
    }

    private func applyMute() {
        speechProgress?.removeLimit()
        stopCurrentTTS()
        cancelSpeakingWatchdog()
        awaitingAsrForListening = false
        asr.implementation.uploadsEnabled = false

        switch state {
        case .listening:
            if hasRecognizedText {
                finishListeningTurn()
            } else {
                asr.implementation.cancel(stopCapture: false)
                committedUserText = ""
                clearSentences()
                notifyTranscript()
                setState(.idle)
            }
        case .thinking:
            if drainTimeoutWork != nil {
                return
            }
            asr.implementation.cancel(stopCapture: false)
            if replyTimeoutWork == nil {
                abandonCurrentReply()
                committedUserText = ""
                clearSentences()
                notifyTranscript()
                setState(.idle)
            }
        case .speaking:
            asr.implementation.cancel(stopCapture: false)
            setState(.thinking)
        case .idle:
            asr.implementation.cancel(stopCapture: false)
            committedUserText = ""
            clearSentences()
            notifyTranscript()
        }
    }

    private func resumeFromMute() {
        asr.implementation.uploadsEnabled = true
        switch state {
        case .thinking, .speaking:
            startNewASRSession()
        case .listening, .idle:
            enterListening()
        }
    }

    func pause() {
        guard !released, !pausedExternally else { return }
        pausedExternally = true
        abandonCurrentReply()
        asr.implementation.cancel(stopCapture: true)
        awaitingAsrForListening = false
        committedUserText = ""
        clearSentences()
        notifyTranscript()
        setState(.idle)
    }

    func resume() {
        guard !released, pausedExternally else { return }
        pausedExternally = false
        vad.resetCalibration()
        guard !muted else { return }
        enterListening()
    }

    func retryListening() {
        guard !released, startFailed, !muted, !pausedExternally else { return }
        enterListening()
    }

    private var frameCounter = 0

    private func onAudioFrame(_ pcm: [Int16]) {
        guard !released, !muted else { return }
        frameCounter += 1
        let frameState = state
        let rms = vad.accept(pcm: pcm)
        if frameCounter <= 5 || frameCounter % 250 == 0 {
            AICallLog("[AICall] frame #\(frameCounter) state=\(frameState) rms=\(Int(rms)) samples=\(pcm.count)")
        }
        let level: Float
        if frameState == .speaking {
            level = lastTtsProgress?.audioLevel ?? 0
        } else {
            level = Float(min(max(rms / 3000.0, 0.0), 1.0))
        }
        delegate?.callController(self, didUpdateAudioLevel: level)

        if frameState == .speaking, vad.hasSpeech(for: AICallConstants.bargeInSpeechHoldMs) {
            AICallLog("[AICall] vad barge-in speech=\(vad.speechAccumulationMs)ms")
            bargeIn()
            return
        }

        if frameState == .listening, hasRecognizedText {
            let energyEndpoint = vad.hasSilence(for: config.silenceHoldMs)
            let textEndpoint = ProcessInfo.processInfo.systemUptime - lastAsrTextChangeUptime
                >= TimeInterval(config.silenceHoldMs) / 1000.0
            if energyEndpoint || textEndpoint {
                AICallLog("[AICall] endpoint energy=\(energyEndpoint) text=\(textEndpoint)")
                finishListeningTurn()
            }
        }
    }

    private func startNewASRSession() {
        vad.reset()
        asr.startASR()
    }

    private func handleASRMessage(_ message: ChatRealtimeASRMessage) {
        guard !released, !pausedExternally, !muted || drainTimeoutWork != nil else { return }
        let isFinished = message.isCompleted
        let chunkIndex = message.segmentIndex
        let text = message.sourceText
        guard !text.isEmpty else { return }
        if chunkIndex <= committedChunkCeiling {
            guard state == .thinking || state == .speaking,
                  let committedText = committedSegments[chunkIndex],
                  committedText != text else { return }
            maybeBargeInFromASR(chunkIndex: chunkIndex, text: text, isFinished: isFinished)
            return
        }
        switch state {
        case .listening:
            if isInPostSpeakingEchoWindow,
               AICallBargeIn.looksLikeTtsEcho(text, llmText: currentLLMText()) {
                AICallLog("[AICall] asrResp echo dropped chunk=\(chunkIndex) text=\"\(text)\"")
                return
            }
            let changed = sentences[chunkIndex] != text
            sentences[chunkIndex] = text
            hasRecognizedText = true
            if changed {
                lastAsrTextChangeUptime = ProcessInfo.processInfo.systemUptime
            }
            notifyTranscript(pendingUserText: joinedText())
        case .thinking:
            if drainTimeoutWork != nil {
                sentences[chunkIndex] = text
                hasRecognizedText = true
                notifyTranscript(pendingUserText: joinedText())
            } else {
                maybeBargeInFromASR(chunkIndex: chunkIndex, text: text, isFinished: isFinished)
            }
        case .speaking:
            maybeBargeInFromASR(chunkIndex: chunkIndex, text: text, isFinished: isFinished)
        case .idle:
            break
        }
    }

    private func maybeBargeInFromASR(chunkIndex: Int, text: String, isFinished: Bool) {
        let previous = lastSeenBargeInText[chunkIndex] ?? ""
        lastSeenBargeInText[chunkIndex] = text
        var probe = sentences
        probe[chunkIndex] = text
        let candidate = probe.sorted { $0.key < $1.key }.map(\.value).joined()
        guard AICallBargeIn.shouldBargeIn(
            asrText: candidate,
            committed: committedUserText,
            llmText: currentLLMText(),
            minChars: AICallConstants.minBargeInTextLength
        ) else {
            AICallLog("[AICall] asr barge-in rejected state=\(state) text=\"\(candidate)\"")
            return
        }

        sentences[chunkIndex] = text
        hasRecognizedText = true
        lastAsrTextChangeUptime = ProcessInfo.processInfo.systemUptime
        if let extra = AICallBargeIn.extraBeyondCommitted(candidate, committed: committedUserText) {
            sentences.removeAll()
            sentences[chunkIndex] = extra
            lastSeenBargeInText = [chunkIndex: extra]
        }
        notifyTranscript(pendingUserText: joinedText())

        let stable = isFinished || AICallBargeIn.isStableContinuation(previous: previous, current: text)
        guard stable else {
            AICallLog("[AICall] asr barge-in deferred unstable chunk=\(chunkIndex) prev=\"\(previous)\" text=\"\(text)\"")
            return
        }
        if state == .speaking {
            bargeIn()
        } else {
            interruptThinking()
        }
    }

    private func clearSentences() {
        sentences.removeAll()
        lastSeenBargeInText.removeAll()
        hasRecognizedText = false
    }

    private func joinedText() -> String {
        sentences.sorted { $0.key < $1.key }.map(\.value).joined()
    }

    private func finishListeningTurn() {
        guard state == .listening else { return }
        drainGeneration += 1
        let gen = drainGeneration
        let work = DispatchWorkItem { [weak self] in
            self?.finishDrain(gen: gen)
        }
        drainTimeoutWork = work
        DispatchQueue.main.asyncAfter(deadline: .now() + .milliseconds(AICallConstants.drainWindowMs), execute: work)
        vad.reset()
        setState(.thinking)
        notifyTranscript(pendingUserText: joinedText())
    }

    private func finishDrain(gen: Int) {
        guard !released, gen == drainGeneration else { return }
        closeDrainWindow()

        let text = joinedText()
        committedUserText = text
        committedChunkCeiling = max(committedChunkCeiling, sentences.keys.max() ?? committedChunkCeiling)
        committedSegments = sentences
        clearSentences()

        guard state == .thinking else { return }
        guard !text.isEmpty else {
            enterListening()
            return
        }

        transcript.append(AICallTranscriptEntry(isUser: true, text: text))
        let entryIndex = transcript.count - 1
        notifyTranscript()
        armReplyTimeout()
        sendToRobot(text, entryIndex: entryIndex)
        if muted {
            asr.implementation.cancel(stopCapture: false)
        }
    }

    private func closeDrainWindow() {
        drainGeneration += 1
        drainTimeoutWork?.cancel()
        drainTimeoutWork = nil
    }

    private func sendToRobot(_ text: String, entryIndex: Int) {
        AICallLog("[AICall] sendToRobot \"\(text)\"")
        messageInputStore.sendMessage(payload: .text(TextSendMessagePayload(text: text)), option: nil) { [weak self] result in
            DispatchQueue.main.async {
                guard let self, !self.released else { return }
                self.handleSendResult(result, entryIndex: entryIndex)
            }
        }
    }

    private func handleSendResult(_ result: Result<Void, ErrorInfo>, entryIndex: Int) {
        switch result {
        case .success:
            AICallLog("[AICall] sendToRobot success")
        case let .failure(error):
            AICallLog("[AICall] sendToRobot FAILED \(error)")
            markUserEntryFailed(entryIndex)
            delegate?.callController(self, didEncounterError: .sendFailed)
            guard state == .thinking else { return }
            cancelReplyTimeout()
            enterListening()
        }
    }

    private func sendVoiceSessionPing(_ action: String) {
        var option = SendMessageOption()
        option.onlineUserOnly = true
        messageInputStore.sendMessage(
            payload: .custom(CustomSendMessagePayload(
                customData: "{\"action\":\"\(action)\"}",
                description: RobotControlMessages.voiceSessionDescription
            )),
            option: option
        ) { result in
            switch result {
            case .success:
                AICallLog("[AICall] voicePing \(action) success")
            case let .failure(error):
                AICallLog("[AICall] voicePing \(action) FAILED \(error)")
            }
        }
    }

    fileprivate func handleAdvancedNewMessage(_ message: V2TIMMessage) {
        DispatchQueue.main.async { [weak self] in
            self?.handleStreamMessage(message, isNewMessage: true)
        }
    }

    fileprivate func handleAdvancedMessageModified(_ message: V2TIMMessage) {
        DispatchQueue.main.async { [weak self] in
            self?.handleStreamMessage(message, isNewMessage: false)
        }
    }

    private func handleStreamMessage(_ message: V2TIMMessage, isNewMessage: Bool) {
        guard !released else { return }
        guard message.sender == robotUserID, let streamElem = message.streamElem else { return }
        let msgID = message.msgID ?? ""
        let isAwaitingReply = state == .thinking && drainTimeoutWork == nil && replyTimeoutWork != nil
        let isBoundReplyChunk = msgID == streamingMsgID && (state == .thinking || state == .speaking)
        guard isNewMessage ? isAwaitingReply : isBoundReplyChunk else {
            AICallLog("[AICall] dropStaleStream state=\(state) msgID=\(msgID) isNew=\(isNewMessage)")
            return
        }

        if streamingMsgID != msgID {
            AICallLog("[AICall] streamMsg \(streamingMsgID ?? "-") -> \(msgID)")
            streamingMsgID = msgID
            aiEntryIndex = -1
            hasStartedTTS = false
            ttsStartPending = false
            ttsRequestActive = false
            lastTtsProgress = nil
            ttsGeneration += 1
            let generation = ttsGeneration
            speechProgress = config.syncTextWithSpeech && !muted
                ? AICallSpeechProgress(speed: config.ttsSpeed) { [weak self] in
                    guard let self, self.ttsGeneration == generation,
                          self.lastTtsProgress?.messageID == msgID else { return 0 }
                    return self.lastTtsProgress?.playedMilliseconds ?? 0
                } : nil
        }

        currentStreamEnded = streamElem.isStreamEnded
        updateAITranscript(streamElem.markdown ?? "", isStreaming: !currentStreamEnded)

        if !hasStartedTTS, !ttsStartPending, !muted, state == .thinking {
            ttsStartPending = true
            ttsRequestActive = true
            let generation = ttsGeneration
            tts.playStreamMessage(message: message, speed: config.ttsSpeed, onStart: { [weak self] in
                guard let self, !self.released, self.ttsGeneration == generation else { return }
                self.ttsStartPending = false
                self.hasStartedTTS = true
            }, onProgress: { [weak self] progress in
                guard let self, !self.released, self.ttsGeneration == generation else { return }
                self.handleTtsProgress(progress)
            }, onComplete: { [weak self] in
                guard let self, !self.released, self.ttsGeneration == generation else { return }
                self.handlePlaybackFinished()
            }, onError: { [weak self] code, desc in
                guard let self, !self.released, self.ttsGeneration == generation else { return }
                self.ttsStartPending = false
                self.ttsRequestActive = false
                if self.hasStartedTTS || self.state == .speaking || Self.ttsPlaybackErrorCodes.contains(code) {
                    self.delegate?.callController(self, didEncounterError: .playbackUnavailable)
                    guard !self.released, self.ttsGeneration == generation else { return }
                    self.speechProgress?.removeLimit()
                    self.enterListening()
                } else {
                    AICallLog("[AICall] startTTS rejected (\(code) \(desc)), retry on next modify")
                    if self.currentStreamEnded {
                        self.speechProgress?.removeLimit()
                        self.enterListening()
                    }
                }
            })
        }

        if streamElem.isStreamEnded, !hasStartedTTS || muted, !ttsStartPending,
           state == .thinking, drainTimeoutWork == nil {
            AICallLog("[AICall] stream ended without TTS, fallback to text only")
            speechProgress?.removeLimit()
            enterListening()
        }
    }

    private func handleTtsProgress(_ progress: TtsPlaybackProgress) {
        guard !muted, progress.messageID == streamingMsgID else { return }
        let previous = lastTtsProgress
        lastTtsProgress = progress
        if progress.isSynthesisFinished {
            speechProgress?.markSynthesisFinished(totalMilliseconds: progress.synthesizedMilliseconds)
        }
        if state == .thinking {
            cancelReplyTimeout()
            setState(.speaking)
        }
        if state == .speaking, previous == nil || previous?.synthesizedMilliseconds != progress.synthesizedMilliseconds
            || previous?.playedMilliseconds != progress.playedMilliseconds
            || previous?.isSynthesisFinished != progress.isSynthesisFinished {
            armSpeakingWatchdog(pendingPlaybackMs: progress.isSynthesisFinished ? progress.synthesizedMilliseconds : 0)
        }
    }

    private func handlePlaybackFinished() {
        ttsRequestActive = false
        ttsStartPending = false
        guard !released, state == .speaking else { return }
        speechProgress?.removeLimit()
        enterListening()
    }

    private func updateAITranscript(_ markdown: String, isStreaming: Bool) {
        guard !markdown.isEmpty else { return }
        let entry = AICallTranscriptEntry(
            isUser: false,
            text: markdown,
            msgID: streamingMsgID,
            isStreaming: isStreaming,
            speechProgress: speechProgress
        )
        if aiEntryIndex >= 0, aiEntryIndex < transcript.count {
            transcript[aiEntryIndex] = entry
        } else {
            transcript.append(entry)
            aiEntryIndex = transcript.count - 1
        }
        notifyTranscript()
    }

    private func finalizeCurrentAIEntry() {
        let hadSpeechProgress = speechProgress != nil
        speechProgress?.settleAtCurrentPosition()
        speechProgress = nil
        guard transcript.indices.contains(aiEntryIndex) else { return }
        guard transcript[aiEntryIndex].isStreaming || hadSpeechProgress else { return }
        transcript[aiEntryIndex].isStreaming = false
        notifyTranscript(pendingUserText: joinedText())
    }

    private func bargeIn() {
        guard !released, state == .speaking else { return }
        enterListening(keepAsrText: true)
    }

    private func interruptThinking() {
        guard !released, state == .thinking, drainTimeoutWork == nil else { return }
        enterListening(keepAsrText: true)
    }

    private func enterListening(keepAsrText: Bool = false) {
        guard !released else { return }
        abandonCurrentReply()
        guard !muted, !pausedExternally else {
            asr.implementation.cancel(stopCapture: false)
            awaitingAsrForListening = false
            clearSentences()
            notifyTranscript()
            setState(.idle)
            return
        }
        if !keepAsrText {
            clearSentences()
        }
        vad.reset()
        if asr.implementation.isLive {
            awaitingAsrForListening = false
            setState(.listening)
            notifyTranscript(pendingUserText: joinedText())
            return
        }
        awaitingAsrForListening = true
        setState(.thinking)
        startNewASRSession()
    }

    private func abandonCurrentReply() {
        finalizeCurrentAIEntry()
        cancelReplyTimeout()
        cancelSpeakingWatchdog()
        closeDrainWindow()
        streamingMsgID = nil
        stopCurrentTTS()
    }

    private func stopCurrentTTS() {
        speechProgress?.settleAtCurrentPosition()
        ttsGeneration += 1
        ttsRequestActive = false
        ttsStartPending = false
        lastTtsProgress = nil
        tts.stop(notifyCompletion: false)
    }

    private func markUserEntryFailed(_ index: Int) {
        guard transcript.indices.contains(index) else { return }
        transcript[index].isFailed = true
        notifyTranscript()
    }

    private func armReplyTimeout() {
        cancelReplyTimeout()
        let work = DispatchWorkItem { [weak self] in
            guard let self, self.state == .thinking else { return }
            self.delegate?.callController(self, didEncounterError: .replyTimeout)
            self.enterListening()
        }
        replyTimeoutWork = work
        DispatchQueue.main.asyncAfter(deadline: .now() + .milliseconds(config.thinkingTimeoutMs), execute: work)
    }

    private func cancelReplyTimeout() {
        replyTimeoutWork?.cancel()
        replyTimeoutWork = nil
    }

    private func armSpeakingWatchdog(pendingPlaybackMs: Int = 0) {
        cancelSpeakingWatchdog()
        let work = DispatchWorkItem { [weak self] in
            guard let self, !self.released, self.state == .speaking else { return }
            self.enterListening()
        }
        speakingWatchdogWork = work
        let timeoutMs = AICallConstants.speakingStallTimeoutMs + pendingPlaybackMs
        DispatchQueue.main.asyncAfter(deadline: .now() + .milliseconds(timeoutMs), execute: work)
    }

    private func cancelSpeakingWatchdog() {
        speakingWatchdogWork?.cancel()
        speakingWatchdogWork = nil
    }

    private func currentLLMText() -> String {
        if transcript.indices.contains(aiEntryIndex) {
            return transcript[aiEntryIndex].text
        }
        return transcript.last { !$0.isUser }?.text ?? ""
    }

    private var isInPostSpeakingEchoWindow: Bool {
        ProcessInfo.processInfo.systemUptime - lastSpeakingEndUptime
            < TimeInterval(AICallConstants.postSpeakingEchoGuardMs) / 1000.0
    }

    private func setState(_ newState: AICallState) {
        guard state != newState else { return }
        if state == .speaking {
            lastSpeakingEndUptime = ProcessInfo.processInfo.systemUptime
        }
        AICallLog("[AICall] state \(state) -> \(newState)")
        state = newState
        delegate?.callController(self, didChangeState: newState)
    }

    private func notifyTranscript(pendingUserText: String = "") {
        let entries = pendingUserText.isEmpty
            ? transcript
            : transcript + [AICallTranscriptEntry(isUser: true, text: pendingUserText)]
        delegate?.callController(self, didChangeTranscript: entries)
    }
}

extension AICallController: RealtimeASRListener {
    func onReceiveTranscriberPCM(_ pcm: [Int16]) {
        onAudioFrame(pcm)
    }

    func onReceiveTranscriberMessage(_ message: ChatRealtimeASRMessage) {
        handleASRMessage(message)
    }

    func onRealtimeTranscriberStarted(_ voiceId: String) {
        guard !released else { return }
        startFailed = false
        guard awaitingAsrForListening else { return }
        awaitingAsrForListening = false
        if state == .speaking || ttsRequestActive { return }
        setState(.listening)
    }

    func onRealtimeTranscriberError(_ errorCode: Int32, errorMsg: String) {
        guard !released else { return }
        if asr.implementation.lastErrorWasCapture {
            awaitingAsrForListening = false
            startFailed = true
            delegate?.callController(self, didEncounterError: .audioUnavailable)
            delegate?.callControllerDidFailListening(self)
            setState(.idle)
        } else if !asr.implementation.isLive {
            awaitingAsrForListening = false
            startFailed = true
            delegate?.callController(self, didEncounterError: .asrStartFailed)
            delegate?.callControllerDidFailListening(self)
            setState(.idle)
        } else {
            AICallLog("[AICall] ASR error code=\(errorCode) desc=\(errorMsg)")
        }
    }
}

private final class AICallAdvancedMsgListener: NSObject, V2TIMAdvancedMsgListener {
    weak var controller: AICallController?

    init(controller: AICallController) {
        self.controller = controller
    }

    func onRecvNewMessage(msg: V2TIMMessage) {
        controller?.handleAdvancedNewMessage(msg)
    }

    func onRecvMessageModified(msg: V2TIMMessage) {
        controller?.handleAdvancedMessageModified(msg)
    }

}
