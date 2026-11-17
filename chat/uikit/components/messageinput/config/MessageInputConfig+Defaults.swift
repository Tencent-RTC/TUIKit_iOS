import UIKit

extension ChatMessageInputConfig {
    static let defaultAudioMaxRecordDurationMs = 60_000
    static let defaultAlbumMaxSelectionCount = 9
    static let defaultAlbumMaxVideoDurationInSeconds = 600
    static let defaultAlbumMaxVideoOutputSizeInMB = 100

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
        actionCustomizer: ((CustomEditor<MessageInputMenuAction>) -> Void)? = nil,
        enableSendRecordedVoice: Bool? = nil,
        keepSendButtonVisible: Bool? = nil,
        appearance: MessageInputAppearance? = nil,
        enableVoiceprintDenoise: Bool? = nil,
        albumMaxSelectionCount: Int? = nil,
        albumMediaFilter: MessageInputAlbumMediaFilter? = nil,
        albumCompressQuality: MessageInputAlbumCompressQuality? = nil,
        albumMaxVideoDurationInSeconds: Int? = nil,
        albumMaxVideoOutputSizeInMB: Int? = nil
    ) {
        self.isShowAudioRecorder = isShowAudioRecorder
        self.isShowPhotoTaker = isShowPhotoTaker
        self.isShowMore = isShowMore
        self.isShowSendButton = isShowSendButton
        self.isShowEmoji = isShowEmoji
        self.enableReadReceipt = enableReadReceipt
        self.enableMention = enableMention
        self.enableLongPressToTalk = enableLongPressToTalk
        self.isShowVideoCall = isShowVideoCall
        self.isShowAudioCall = isShowAudioCall
        self.enableTyping = enableTyping
        self.audioMaxRecordDurationMs = audioMaxRecordDurationMs
        self.enableRealtimeVoiceToText = enableRealtimeVoiceToText
        self.realtimeVoiceToTextLanguage = realtimeVoiceToTextLanguage
        self.actionCustomizer = actionCustomizer
        self.enableSendRecordedVoice = enableSendRecordedVoice
        self.keepSendButtonVisible = keepSendButtonVisible
        self.appearance = appearance
        self.enableVoiceprintDenoise = enableVoiceprintDenoise
        self.albumMaxSelectionCount = albumMaxSelectionCount
        self.albumMediaFilter = albumMediaFilter
        self.albumCompressQuality = albumCompressQuality
        self.albumMaxVideoDurationInSeconds = albumMaxVideoDurationInSeconds
        self.albumMaxVideoOutputSizeInMB = albumMaxVideoOutputSizeInMB
    }

    var _isShowAudioRecorder: Bool {
        isShowAudioRecorder ?? true
    }

    var _isShowPhotoTaker: Bool {
        isShowPhotoTaker ?? true
    }

    var _isShowMore: Bool {
        isShowMore ?? true
    }

    var _isShowSendButton: Bool {
        isShowSendButton ?? !AppBuilderConfig.shared.hideSendButton
    }

    var _isShowEmoji: Bool {
        isShowEmoji ?? true
    }

    var _enableReadReceipt: Bool {
        enableReadReceipt ?? AppBuilderConfig.shared.enableReadReceipt
    }

    var _enableMention: Bool {
        enableMention ?? true
    }

    var _enableLongPressToTalk: Bool {
        enableLongPressToTalk ?? true
    }

    var _isShowVideoCall: Bool {
        isShowVideoCall ?? true
    }

    var _isShowAudioCall: Bool {
        isShowAudioCall ?? true
    }

    var _enableTyping: Bool {
        enableTyping ?? true
    }

    var _audioMaxRecordDurationMs: Int {
        audioMaxRecordDurationMs ?? Self.defaultAudioMaxRecordDurationMs
    }

    var _enableRealtimeVoiceToText: Bool {
        enableRealtimeVoiceToText ?? true
    }

    var _enableVoiceprintDenoise: Bool {
        enableVoiceprintDenoise ?? false
    }

    var _realtimeVoiceToTextLanguage: String {
        realtimeVoiceToTextLanguage ?? Locale.current.languageCode ?? "zh"
    }

    /// 允许发送原录音，默认 true。false 时按住转文字、上滑取消；非实时识别在松手后转换并自动发送。
    var _enableSendRecordedVoice: Bool {
        enableSendRecordedVoice ?? true
    }

    var _keepSendButtonVisible: Bool {
        keepSendButtonVisible ?? false
    }

    var _appearance: MessageInputAppearance? {
        appearance
    }

    var _actionCustomizer: ((CustomEditor<MessageInputMenuAction>) -> Void)? {
        actionCustomizer
    }

    var _albumMaxSelectionCount: Int {
        max(albumMaxSelectionCount ?? Self.defaultAlbumMaxSelectionCount, 1)
    }

    var _albumMediaFilter: MessageInputAlbumMediaFilter {
        albumMediaFilter ?? .imageAndVideo
    }

    var _albumCompressQuality: MessageInputAlbumCompressQuality {
        albumCompressQuality ?? .standard
    }

    var _albumMaxVideoDurationInSeconds: Int {
        max(albumMaxVideoDurationInSeconds ?? Self.defaultAlbumMaxVideoDurationInSeconds, 1)
    }

    var _albumMaxVideoOutputSizeInMB: Int {
        max(albumMaxVideoOutputSizeInMB ?? Self.defaultAlbumMaxVideoOutputSizeInMB, 1)
    }
}
