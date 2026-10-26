import Foundation

/// 机器人会话的输入框配置包装，对齐 Android ChatbotMessageInputConfig。
///
/// 机器人会话不提供音/视频通话入口和群 @ 提及；正在输入状态对机器人没有意义，一并关掉。
struct ChatbotMessageInputConfig: MessageInputConfigProtocol {
    let base: MessageInputConfigProtocol

    var isShowAudioRecorder: Bool { base.isShowAudioRecorder }
    var isShowPhotoTaker: Bool { base.isShowPhotoTaker }
    var isShowMore: Bool { base.isShowMore }
    var isShowSendButton: Bool { base.isShowSendButton }
    var isShowEmoji: Bool { base.isShowEmoji }
    var enableReadReceipt: Bool { base.enableReadReceipt }
    var enableLongPressToTalk: Bool { base.enableLongPressToTalk }
    var audioMaxRecordDurationMs: Int { base.audioMaxRecordDurationMs }
    var enableRealtimeVoiceToText: Bool { base.enableRealtimeVoiceToText }
    var enableVoiceprintDenoise: Bool { base.enableVoiceprintDenoise }
    var realtimeVoiceToTextLanguage: String { base.realtimeVoiceToTextLanguage }
    var enableSendRecordedVoice: Bool { base.enableSendRecordedVoice }
    var keepSendButtonVisible: Bool { base.keepSendButtonVisible }
    var appearance: MessageInputAppearance? { base.appearance }
    var actionCustomizer: MessageInputActionCustomizer? { base.actionCustomizer }

    var isShowAudioCall: Bool { false }
    var isShowVideoCall: Bool { false }
    var enableMention: Bool { false }
    var enableTyping: Bool { false }
}
