extension AICallConfig {
    public init(
        ttsSpeed: Float? = nil,
        syncTextWithSpeech: Bool? = nil,
        silenceHoldMs: Int? = nil,
        thinkingTimeoutMs: Int? = nil,
        enableVoiceprintDenoise: Bool? = nil
    ) {
        self.userTTSSpeed = ttsSpeed
        self.userSyncTextWithSpeech = syncTextWithSpeech
        self.userSilenceHoldMs = silenceHoldMs
        self.userThinkingTimeoutMs = thinkingTimeoutMs
        self.userEnableVoiceprintDenoise = enableVoiceprintDenoise
    }

    /// TTS 语速，范围 0.5～2.0，默认 1.0。
    public var ttsSpeed: Float {
        get { userTTSSpeed ?? 1.0 }
        set { userTTSSpeed = newValue }
    }

    /// 流式文字是否跟随 TTS 播放进度显示，默认 false。
    public var syncTextWithSpeech: Bool {
        get { userSyncTextWithSpeech ?? false }
        set { userSyncTextWithSpeech = newValue }
    }

    /// 结束一句话所需的静音或识别文本稳定时长，单位毫秒，默认 3000。
    public var silenceHoldMs: Int {
        get { userSilenceHoldMs ?? AICallConstants.silenceHoldMs }
        set { userSilenceHoldMs = newValue }
    }

    /// 等待 AI 回复的超时，单位毫秒，默认 30000。
    public var thinkingTimeoutMs: Int {
        get { userThinkingTimeoutMs ?? AICallConstants.thinkingTimeoutMs }
        set { userThinkingTimeoutMs = newValue }
    }

    public var enableVoiceprintDenoise: Bool {
        get { userEnableVoiceprintDenoise ?? true }
        set { userEnableVoiceprintDenoise = newValue }
    }
}
