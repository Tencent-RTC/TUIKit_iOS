extension ChatRealtimeASRConfig {
    public init(language: String? = nil,
                enableVoiceprintDenoise: Bool? = nil,
                voiceprintAutoEnrollMs: Int? = nil,
                enablePCMOutput: Bool? = nil,
                startTimeoutMs: Int? = nil) {
        userLanguage = language
        userEnableVoiceprintDenoise = enableVoiceprintDenoise
        userVoiceprintAutoEnrollMs = voiceprintAutoEnrollMs
        userEnablePCMOutput = enablePCMOutput
        userStartTimeoutMs = startTimeoutMs
    }

    public var language: String {
        get { userLanguage ?? "zh" }
        set { userLanguage = newValue }
    }
    public var enableVoiceprintDenoise: Bool {
        get { userEnableVoiceprintDenoise ?? false }
        set { userEnableVoiceprintDenoise = newValue }
    }
    public var voiceprintAutoEnrollMs: Int {
        get { userVoiceprintAutoEnrollMs ?? 3000 }
        set { userVoiceprintAutoEnrollMs = newValue }
    }
    public var enablePCMOutput: Bool {
        get { userEnablePCMOutput ?? true }
        set { userEnablePCMOutput = newValue }
    }
    public var startTimeoutMs: Int {
        get { userStartTimeoutMs ?? 5000 }
        set { userStartTimeoutMs = newValue }
    }
}

public extension RealtimeASRListener {
    func onRealtimeTranscriberStarted(_ voiceId: String) {}
    func onReceiveTranscriberMessage(_ message: ChatRealtimeASRMessage) {}
    func onRealtimeTranscriberStopped() {}
    func onRealtimeTranscriberError(_ errorCode: Int32, errorMsg: String) {}
    func onReceiveTranscriberPCM(_ pcm: [Int16]) {}
}
