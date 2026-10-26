import UIKit
import AtomicXCore

protocol MessageListConfigProtocol {
    var alignment: MessageAlignment { get }
    var isShowTimeMessage: Bool { get }
    var isShowLeftAvatar: Bool { get }
    var isShowLeftNickname: Bool { get }
    var isShowRightAvatar: Bool { get }
    var isShowRightNickname: Bool { get }
    var isShowTimeInBubble: Bool { get }
    var cellSpacing: CGFloat { get }
    var isShowSystemMessage: Bool { get }
    var isShowUnsupportMessage: Bool { get }
    var horizontalPadding: CGFloat { get }
    var avatarSpacing: CGFloat { get }
    var isSupportReaction: Bool { get }
    var isSupportQuote: Bool { get }
    var enableTyping: Bool { get }
    var enableChatbotReplyPlaceholder: Bool { get }
    var streamingMaxCharactersPerSecond: Double { get }
    var messageExclusionMatchers: [MessageMatcher] { get }
    var background: MessageListBackground? { get }
    var defaultBubbleAppearance: MessageBubbleAppearance? { get }
    var ownBubbleAppearance: MessageBubbleAppearance? { get }
    var incomingBubbleAppearance: MessageBubbleAppearance? { get }
    var leftBubbleAppearance: MessageBubbleAppearance? { get }
    var rightBubbleAppearance: MessageBubbleAppearance? { get }
    var bubbleMaxWidthRatio: CGFloat { get }
}

extension MessageListConfigProtocol {
    func resolvedBubbleAppearance(isSelf: Bool, isLeft: Bool) -> MessageBubbleAppearance? {
        let slot: MessageBubbleAppearance?
        switch alignment {
        case .left:
            slot = leftBubbleAppearance
        case .right:
            slot = rightBubbleAppearance
        case .twoSided:
            slot = isSelf ? ownBubbleAppearance : incomingBubbleAppearance
        }
        guard let slot = slot else { return defaultBubbleAppearance }
        return slot.merged(over: defaultBubbleAppearance)
    }
}

protocol MessageActionConfigProtocol {
    var isSupportCopy: Bool { get }
    var isSupportDelete: Bool { get }
    var isSupportRecall: Bool { get }
    var isSupportForward: Bool { get }
    var isSupportQuote: Bool { get }
    var isSupportMultiSelect: Bool { get }
    var isSupportConvertToText: Bool { get }
    var isSupportTranslate: Bool { get }
    var isSupportListenFromHere: Bool { get }
    var actionCustomizer: MessageActionCustomizer? { get }
}

extension ChatMessageListConfig: MessageListConfigProtocol, MessageActionConfigProtocol {}
