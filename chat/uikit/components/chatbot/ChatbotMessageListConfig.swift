import Foundation
import AtomicXCore

/// 机器人会话的列表配置包装，对齐 Android ChatbotMessageListConfig。
///
/// 机器人消息没有已读回执、撤回、多选、Reaction、引用、转文字、翻译、从这条听起这些能力，
/// 也不开对方正在输入；长按菜单不走自定义入口。
struct ChatbotMessageListConfig: MessageListConfigProtocol, MessageActionConfigProtocol {
    let base: MessageListConfigProtocol & MessageActionConfigProtocol

    var alignment: MessageAlignment { base.alignment }
    var isShowTimeMessage: Bool { base.isShowTimeMessage }
    var isShowLeftAvatar: Bool { base.isShowLeftAvatar }
    var isShowLeftNickname: Bool { base.isShowLeftNickname }
    var isShowRightAvatar: Bool { base.isShowRightAvatar }
    var isShowRightNickname: Bool { base.isShowRightNickname }
    var isShowTimeInBubble: Bool { base.isShowTimeInBubble }
    var cellSpacing: CGFloat { base.cellSpacing }
    var isShowSystemMessage: Bool { base.isShowSystemMessage }
    var isShowUnsupportMessage: Bool { base.isShowUnsupportMessage }
    var horizontalPadding: CGFloat { base.horizontalPadding }
    var avatarSpacing: CGFloat { base.avatarSpacing }
    var messageExclusionMatchers: [MessageMatcher] { base.messageExclusionMatchers }
    var background: MessageListBackground? { base.background }
    var defaultBubbleAppearance: MessageBubbleAppearance? { base.defaultBubbleAppearance }
    var ownBubbleAppearance: MessageBubbleAppearance? { base.ownBubbleAppearance }
    var incomingBubbleAppearance: MessageBubbleAppearance? { base.incomingBubbleAppearance }
    var leftBubbleAppearance: MessageBubbleAppearance? { base.leftBubbleAppearance }
    var rightBubbleAppearance: MessageBubbleAppearance? { base.rightBubbleAppearance }
    var bubbleMaxWidthRatio: CGFloat { base.bubbleMaxWidthRatio }
    var enableChatbotReplyPlaceholder: Bool { base.enableChatbotReplyPlaceholder }
    var streamingMaxCharactersPerSecond: Double { base.streamingMaxCharactersPerSecond }

    var isSupportCopy: Bool { base.isSupportCopy }
    var isSupportDelete: Bool { base.isSupportDelete }
    var isSupportForward: Bool { base.isSupportForward }

    var isSupportReaction: Bool { false }
    var isSupportQuote: Bool { false }
    var isSupportRecall: Bool { false }
    var isSupportMultiSelect: Bool { false }
    var isSupportConvertToText: Bool { false }
    var isSupportTranslate: Bool { false }
    var isSupportListenFromHere: Bool { false }
    var enableTyping: Bool { false }
    var actionCustomizer: MessageActionCustomizer? { nil }
}
