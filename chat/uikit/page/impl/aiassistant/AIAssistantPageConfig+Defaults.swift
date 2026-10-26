extension AIAssistantPageConfig {
    public init(
        streamingMaxCharactersPerSecond: Double? = nil,
        enableChatbotReplyPlaceholder: Bool? = nil,
        enableRealtimeVoiceToText: Bool? = nil,
        enableSendRecordedVoice: Bool? = nil,
        callConfig: AICallConfig? = nil
    ) {
        self.userStreamingMaxCharactersPerSecond = streamingMaxCharactersPerSecond
        self.userEnableChatbotReplyPlaceholder = enableChatbotReplyPlaceholder
        self.userEnableRealtimeVoiceToText = enableRealtimeVoiceToText
        self.userEnableSendRecordedVoice = enableSendRecordedVoice
        self.userCallConfig = callConfig
    }

    /// 流式文字每秒最多显示的 UTF-16 单位数，默认 0 表示不限速。
    public var streamingMaxCharactersPerSecond: Double {
        get { userStreamingMaxCharactersPerSecond ?? 0 }
        set { userStreamingMaxCharactersPerSecond = newValue }
    }

    /// 等待助手回复时是否显示占位气泡，默认 false。
    public var enableChatbotReplyPlaceholder: Bool {
        get { userEnableChatbotReplyPlaceholder ?? false }
        set { userEnableChatbotReplyPlaceholder = newValue }
    }

    /// 录音时是否实时识别文字，默认 true。
    public var enableRealtimeVoiceToText: Bool {
        get { userEnableRealtimeVoiceToText ?? true }
        set { userEnableRealtimeVoiceToText = newValue }
    }

    /// 是否允许发送原录音，默认 false：按住转文字、上滑取消；关闭实时识别时松手转换并自动发送。
    public var enableSendRecordedVoice: Bool {
        get { userEnableSendRecordedVoice ?? false }
        set { userEnableSendRecordedVoice = newValue }
    }

    public var callConfig: AICallConfig {
        get { userCallConfig ?? AICallConfig() }
        set { userCallConfig = newValue }
    }
}
