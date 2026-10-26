import UIKit

extension ChatMessageInputConfig {
    static let defaultAudioMaxRecordDurationMs = 60_000

    public init(
        isShowAudioRecorder: Bool? = nil,
        isShowPhotoTaker: Bool? = nil,
        isShowMore: Bool? = nil,
        isShowSendButton: Bool? = nil,
        isShowEmoji: Bool? = nil,
        enableReadReceipt: Bool? = nil,
        enableMention: Bool? = nil,
        enableLongPressToTalk: Bool? = nil,
        isShowVideoCall: Bool? = nil,
        isShowAudioCall: Bool? = nil,
        enableTyping: Bool? = nil,
        audioMaxRecordDurationMs: Int? = nil,
        enableRealtimeVoiceToText: Bool? = nil,
        realtimeVoiceToTextLanguage: String? = nil,
        actionCustomizer: MessageInputActionCustomizer? = nil,
        enableSendRecordedVoice: Bool? = nil,
        keepSendButtonVisible: Bool? = nil,
        appearance: MessageInputAppearance? = nil,
        enableVoiceprintDenoise: Bool? = nil
    ) {
        self.userIsShowAudioRecorder = isShowAudioRecorder
        self.userIsShowPhotoTaker = isShowPhotoTaker
        self.userIsShowMore = isShowMore
        self.userIsShowSendButton = isShowSendButton
        self.userIsShowEmoji = isShowEmoji
        self.userEnableReadReceipt = enableReadReceipt
        self.userEnableMention = enableMention
        self.userEnableLongPressToTalk = enableLongPressToTalk
        self.userIsShowVideoCall = isShowVideoCall
        self.userIsShowAudioCall = isShowAudioCall
        self.userEnableTyping = enableTyping
        self.userAudioMaxRecordDurationMs = audioMaxRecordDurationMs
        self.userEnableRealtimeVoiceToText = enableRealtimeVoiceToText
        self.userRealtimeVoiceToTextLanguage = realtimeVoiceToTextLanguage
        self.userActionCustomizer = actionCustomizer
        self.userEnableSendRecordedVoice = enableSendRecordedVoice
        self.userKeepSendButtonVisible = keepSendButtonVisible
        self.userAppearance = appearance
        self.userEnableVoiceprintDenoise = enableVoiceprintDenoise
    }

    public var isShowAudioRecorder: Bool {
        get { userIsShowAudioRecorder ?? true }
        set { userIsShowAudioRecorder = newValue }
    }

    public var isShowPhotoTaker: Bool {
        get { userIsShowPhotoTaker ?? true }
        set { userIsShowPhotoTaker = newValue }
    }

    public var isShowMore: Bool {
        get { userIsShowMore ?? true }
        set { userIsShowMore = newValue }
    }

    public var isShowSendButton: Bool {
        get { userIsShowSendButton ?? !AppBuilderConfig.shared.hideSendButton }
        set { userIsShowSendButton = newValue }
    }

    public var isShowEmoji: Bool {
        get { userIsShowEmoji ?? true }
        set { userIsShowEmoji = newValue }
    }

    public var enableReadReceipt: Bool {
        get { userEnableReadReceipt ?? AppBuilderConfig.shared.enableReadReceipt }
        set { userEnableReadReceipt = newValue }
    }

    public var enableMention: Bool {
        get { userEnableMention ?? true }
        set { userEnableMention = newValue }
    }

    public var enableLongPressToTalk: Bool {
        get { userEnableLongPressToTalk ?? true }
        set { userEnableLongPressToTalk = newValue }
    }

    public var isShowVideoCall: Bool {
        get { userIsShowVideoCall ?? true }
        set { userIsShowVideoCall = newValue }
    }

    public var isShowAudioCall: Bool {
        get { userIsShowAudioCall ?? true }
        set { userIsShowAudioCall = newValue }
    }

    public var enableTyping: Bool {
        get { userEnableTyping ?? true }
        set { userEnableTyping = newValue }
    }

    public var audioMaxRecordDurationMs: Int {
        get { userAudioMaxRecordDurationMs ?? Self.defaultAudioMaxRecordDurationMs }
        set { userAudioMaxRecordDurationMs = newValue }
    }

    public var enableRealtimeVoiceToText: Bool {
        get { userEnableRealtimeVoiceToText ?? true }
        set { userEnableRealtimeVoiceToText = newValue }
    }

    public var enableVoiceprintDenoise: Bool {
        get { userEnableVoiceprintDenoise ?? false }
        set { userEnableVoiceprintDenoise = newValue }
    }

    public var realtimeVoiceToTextLanguage: String {
        get { userRealtimeVoiceToTextLanguage ?? Locale.current.languageCode ?? "zh" }
        set { userRealtimeVoiceToTextLanguage = newValue }
    }

    /// 允许发送原录音，默认 true。false 时按住转文字、上滑取消；非实时识别在松手后转换并自动发送。
    public var enableSendRecordedVoice: Bool {
        get { userEnableSendRecordedVoice ?? true }
        set { userEnableSendRecordedVoice = newValue }
    }

    public var keepSendButtonVisible: Bool {
        get { userKeepSendButtonVisible ?? false }
        set { userKeepSendButtonVisible = newValue }
    }

    public var appearance: MessageInputAppearance? {
        get { userAppearance }
        set { userAppearance = newValue }
    }

    public var actionCustomizer: MessageInputActionCustomizer? {
        get { userActionCustomizer }
        set { userActionCustomizer = newValue }
    }
}
