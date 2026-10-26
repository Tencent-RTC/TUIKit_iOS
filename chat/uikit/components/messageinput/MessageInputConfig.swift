import UIKit

public struct ChatMessageInputConfig {
    // 输入入口：录音、拍照、更多面板与表情按钮。
    public var userIsShowAudioRecorder: Bool? = nil
    public var userIsShowPhotoTaker: Bool? = nil
    public var userIsShowMore: Bool? = nil
    public var userIsShowEmoji: Bool? = nil

    // 消息发送与状态：发送按钮、已读回执、提及与正在输入。
    public var userIsShowSendButton: Bool? = nil
    public var userKeepSendButtonVisible: Bool? = nil
    public var userEnableReadReceipt: Bool? = nil
    public var userEnableMention: Bool? = nil
    public var userEnableTyping: Bool? = nil

    // 语音输入：长按录音、录音时长、实时识别、识别语言与原录音发送。
    public var userEnableLongPressToTalk: Bool? = nil
    public var userAudioMaxRecordDurationMs: Int? = nil
    public var userEnableRealtimeVoiceToText: Bool? = nil
    public var userRealtimeVoiceToTextLanguage: String? = nil
    public var userEnableSendRecordedVoice: Bool? = nil
    public var userEnableVoiceprintDenoise: Bool? = nil

    // 通话入口：视频通话与音频通话。
    public var userIsShowVideoCall: Bool? = nil
    public var userIsShowAudioCall: Bool? = nil

    // 外观与扩展：输入框样式及更多面板动作定制。
    public var userAppearance: MessageInputAppearance? = nil
    public var userActionCustomizer: MessageInputActionCustomizer? = nil
}

public enum MessageInputGradientDirection {
    case topBottom, bottomTop, leftRight, rightLeft, topLeftBottomRight, bottomRightTopLeft
}

public enum MessageInputFill {
    case none
    case color(UIColor)
    case gradient(colors: [UIColor], direction: MessageInputGradientDirection = .leftRight)
}

public struct MessageInputAppearance {
    // 容器：背景填充与顶部分隔线。
    public var userFill: MessageInputFill? = nil
    public var userShowTopDivider: Bool? = nil

    // 文本输入区：输入字段样式。
    public var userField: MessageInputFieldAppearance? = nil

    // 按钮：录音、表情、更多与发送按钮样式。
    public var userAudioRecordButton: MessageInputButtonAppearance? = nil
    public var userEmojiButton: MessageInputButtonAppearance? = nil
    public var userMoreButton: MessageInputButtonAppearance? = nil
    public var userSendButton: MessageInputButtonAppearance? = nil

    // 更多面板：菜单容器与菜单项样式。
    public var userMorePanel: MessageInputMorePanelAppearance? = nil
}

public struct MessageInputButtonAppearance {
    // 布局：按钮尺寸、圆角与水平内边距。
    public var userWidth: CGFloat? = nil
    public var userHeight: CGFloat? = nil
    public var userCornerRadius: CGFloat? = nil
    public var userHorizontalPadding: CGFloat? = nil

    // 背景：按钮填充样式。
    public var userFill: MessageInputFill? = nil

    // 图标：尺寸、颜色及普通与激活状态图片。
    public var userIconSize: CGFloat? = nil
    public var userIconTint: UIColor? = nil
    public var userIcon: UIImage? = nil
    public var userActiveIcon: UIImage? = nil

    // 标题：文字、颜色与字号。
    public var userTitle: String? = nil
    public var userTitleColor: UIColor? = nil
    public var userTitleSize: CGFloat? = nil
}

public struct MessageInputFieldAppearance {
    // 容器：背景、圆角、最小高度与水平内边距。
    public var userFill: MessageInputFill? = nil
    public var userCornerRadius: CGFloat? = nil
    public var userMinHeight: CGFloat? = nil
    public var userHorizontalPadding: CGFloat? = nil

    // 文本与提示：输入文字颜色、提示颜色与提示文案。
    public var userTextColor: UIColor? = nil
    public var userHintColor: UIColor? = nil
    public var userHintText: String? = nil
}

public struct MessageInputMorePanelAppearance {
    // 面板背景：更多菜单容器的填充样式。
    public var userFill: MessageInputFill? = nil

    // 菜单项容器：尺寸、圆角与填充样式。
    public var userItemSize: CGFloat? = nil
    public var userItemCornerRadius: CGFloat? = nil
    public var userItemFills: [MessageInputFill]? = nil

    // 菜单项图标：尺寸与颜色。
    public var userItemIconSize: CGFloat? = nil
    public var userItemIconTint: UIColor? = nil

    // 菜单项标题：颜色与字号。
    public var userItemTitleColor: UIColor? = nil
    public var userItemTitleSize: CGFloat? = nil
}
