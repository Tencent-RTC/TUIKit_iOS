import UIKit
import AtomicXCore

public struct ChatMessageListConfig {
    // 布局：对齐、消息间距、列表边距、头像间距与气泡宽度。
    public var userAlignment: MessageAlignment? = nil
    public var userCellSpacing: CGFloat? = nil
    public var userHorizontalPadding: CGFloat? = nil
    public var userAvatarSpacing: CGFloat? = nil
    public var userBubbleMaxWidthRatio: CGFloat? = nil

    // 身份展示：左右两侧的头像与昵称。
    public var userIsShowLeftAvatar: Bool? = nil
    public var userIsShowLeftNickname: Bool? = nil
    public var userIsShowRightAvatar: Bool? = nil
    public var userIsShowRightNickname: Bool? = nil

    // 消息展示与过滤：时间、系统消息、未支持消息及排除规则。
    public var userIsShowTimeMessage: Bool? = nil
    public var userIsShowTimeInBubble: Bool? = nil
    public var userIsShowSystemMessage: Bool? = nil
    public var userIsShowUnsupportMessage: Bool? = nil
    public var userMessageExclusionMatchers: [MessageMatcher]? = nil

    // 外观：列表背景、默认气泡及各方向气泡样式。
    public var userBackground: MessageListBackground? = nil
    public var userDefaultBubbleAppearance: MessageBubbleAppearance? = nil
    public var userOwnBubbleAppearance: MessageBubbleAppearance? = nil
    public var userIncomingBubbleAppearance: MessageBubbleAppearance? = nil
    public var userLeftBubbleAppearance: MessageBubbleAppearance? = nil
    public var userRightBubbleAppearance: MessageBubbleAppearance? = nil

    // 消息交互：复制、删除、撤回、转发、引用、多选与表情回应。
    public var userIsSupportCopy: Bool? = nil
    public var userIsSupportDelete: Bool? = nil
    public var userIsSupportRecall: Bool? = nil
    public var userIsSupportForward: Bool? = nil
    public var userIsSupportQuote: Bool? = nil
    public var userIsSupportMultiSelect: Bool? = nil
    public var userIsSupportReaction: Bool? = nil

    // 内容处理：语音转文字、翻译与连续播放语音。
    public var userIsSupportConvertToText: Bool? = nil
    public var userIsSupportTranslate: Bool? = nil
    public var userIsSupportListenFromHere: Bool? = nil

    // 扩展：自定义消息操作菜单。
    public var userActionCustomizer: MessageActionCustomizer? = nil

    // 回复状态与流式渲染：正在输入、助手回复占位及每秒出字上限。
    public var userEnableTyping: Bool? = nil
    public var userEnableChatbotReplyPlaceholder: Bool? = nil
    public var userStreamingMaxCharactersPerSecond: Double? = nil
}

public enum MessageListBackground {
    case color(UIColor)
    case gradient(colors: [UIColor], startPoint: CGPoint, endPoint: CGPoint)
    case image(UIImage)
}

public enum MessageBubbleBackground {
    case color(UIColor)
    case gradient(colors: [UIColor], startPoint: CGPoint, endPoint: CGPoint)
    case image(UIImage)
}

public struct MessageBubbleCornerRadius {
    // 圆角：气泡四个角的半径。
    public var userTopLeft: CGFloat? = nil
    public var userTopRight: CGFloat? = nil
    public var userBottomLeft: CGFloat? = nil
    public var userBottomRight: CGFloat? = nil
}

public struct MessageBubbleStroke {
    // 描边：线宽与颜色。
    public var userWidth: CGFloat? = nil
    public var userColor: UIColor? = nil
}

public struct MessageBubbleSize {
    // 尺寸：气泡宽度与高度。
    public var userWidth: CGFloat? = nil
    public var userHeight: CGFloat? = nil
}

public struct MessageBubbleAppearance {
    // 外观：气泡背景、圆角与描边。
    public var userBackground: MessageBubbleBackground? = nil
    public var userCornerRadius: MessageBubbleCornerRadius? = nil
    public var userStroke: MessageBubbleStroke? = nil

    // 布局：内容内边距与气泡最小尺寸。
    public var userContentInsets: UIEdgeInsets? = nil
    public var userMinimumSize: MessageBubbleSize? = nil
}
