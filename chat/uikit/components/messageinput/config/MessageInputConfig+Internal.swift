import UIKit

protocol MessageInputConfigProtocol {
    var isShowAudioRecorder: Bool { get }
    var isShowPhotoTaker: Bool { get }
    var isShowMore: Bool { get }
    var isShowSendButton: Bool { get }
    var isShowEmoji: Bool { get }
    var enableReadReceipt: Bool { get }
    var enableMention: Bool { get }
    var enableLongPressToTalk: Bool { get }
    var isShowVideoCall: Bool { get }
    var isShowAudioCall: Bool { get }
    var enableTyping: Bool { get }
    var audioMaxRecordDurationMs: Int { get }
    var enableRealtimeVoiceToText: Bool { get }
    var enableVoiceprintDenoise: Bool { get }
    var realtimeVoiceToTextLanguage: String { get }
    var enableSendRecordedVoice: Bool { get }
    var keepSendButtonVisible: Bool { get }
    var appearance: MessageInputAppearance? { get }
    var actionCustomizer: MessageInputActionCustomizer? { get }
}

extension MessageInputConfigProtocol {
    var isShowVideoCall: Bool { true }
    var isShowAudioCall: Bool { true }
    var enableTyping: Bool { true }
    var audioMaxRecordDurationMs: Int { ChatMessageInputConfig.defaultAudioMaxRecordDurationMs }
    var enableRealtimeVoiceToText: Bool { true }
    var enableVoiceprintDenoise: Bool { false }
    var realtimeVoiceToTextLanguage: String { Locale.current.languageCode ?? "zh" }
    var enableSendRecordedVoice: Bool { true }
    var keepSendButtonVisible: Bool { false }
    var appearance: MessageInputAppearance? { nil }
    var actionCustomizer: MessageInputActionCustomizer? { nil }
}

extension ChatMessageInputConfig: MessageInputConfigProtocol {}
