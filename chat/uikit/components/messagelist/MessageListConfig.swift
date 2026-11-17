import UIKit
import AtomicXCore

public struct ChatMessageListConfig {
    // 布局：对齐、消息间距、列表边距、头像间距与气泡宽度。
    public var alignment: MessageAlignment? = nil
    public var cellSpacing: CGFloat? = nil
    public var horizontalPadding: CGFloat? = nil
    public var avatarSpacing: CGFloat? = nil
    public var bubbleMaxWidthRatio: CGFloat? = nil

    // 身份展示：左右两侧的头像与昵称。
    public var isShowLeftAvatar: Bool? = nil
    public var isShowLeftNickname: Bool? = nil
    public var isShowRightAvatar: Bool? = nil
    public var isShowRightNickname: Bool? = nil

    // 消息展示与过滤：时间、系统消息、未支持消息及排除规则。
    public var isShowTimeMessage: Bool? = nil
    public var isShowTimeInBubble: Bool? = nil
    public var isShowSystemMessage: Bool? = nil
    public var isShowUnsupportMessage: Bool? = nil
    public var messageExclusionMatchers: [MessageMatcher]? = nil

    // 外观：列表背景、默认气泡及各方向气泡样式。
    public var background: MessageListBackground? = nil
    public var defaultBubbleAppearance: MessageBubbleAppearance? = nil
    public var ownBubbleAppearance: MessageBubbleAppearance? = nil
    public var incomingBubbleAppearance: MessageBubbleAppearance? = nil
    public var leftBubbleAppearance: MessageBubbleAppearance? = nil
    public var rightBubbleAppearance: MessageBubbleAppearance? = nil

    // 消息交互：复制、删除、撤回、转发、引用、多选与表情回应。
    public var isSupportCopy: Bool? = nil
    public var isSupportDelete: Bool? = nil
    public var isSupportRecall: Bool? = nil
    public var isSupportForward: Bool? = nil
    public var isSupportQuote: Bool? = nil
    public var isSupportMultiSelect: Bool? = nil
    public var isSupportReaction: Bool? = nil

    // 内容处理：语音转文字、翻译与连续播放语音。
    public var isSupportConvertToText: Bool? = nil
    public var isSupportTranslate: Bool? = nil
    public var isSupportListenFromHere: Bool? = nil

    // 扩展：自定义消息操作菜单。
    public var actionCustomizer: MessageActionCustomizer? = nil

    // 回复状态与流式渲染：正在输入、助手回复占位及每秒出字上限。
    public var enableTyping: Bool? = nil
    public var enableChatbotReplyPlaceholder: Bool? = nil
    public var streamingMaxCharactersPerSecond: Double? = nil
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
