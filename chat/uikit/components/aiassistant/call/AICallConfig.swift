public struct AICallConfig {
    /// TTS 语速，范围 0.5～2.0，默认 1.0。
    public var userTTSSpeed: Float? = nil

    /// 流式文字是否跟随 TTS 播放进度显示，默认 false。
    public var userSyncTextWithSpeech: Bool? = nil

    /// 结束一句话所需的静音或识别文本稳定时长，单位毫秒，默认 3000。
    public var userSilenceHoldMs: Int? = nil

    /// 等待 AI 回复的超时，单位毫秒，默认 30000。
    public var userThinkingTimeoutMs: Int? = nil

    public var userEnableVoiceprintDenoise: Bool? = nil
}
