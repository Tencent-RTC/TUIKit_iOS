import UIKit
import AtomicXCore

public struct ChatMessageListConfig {
    static let defaultCellSpacing: CGFloat = 10.0

    static let defaultHorizontalPadding = CGFloat(SpacingScheme.bubbleSpacing)

    static let defaultAvatarSpacing = CGFloat(SpacingScheme.smallSpacing)

    var userAlignment: MessageAlignment? = nil

    var userIsShowTimeMessage: Bool? = nil

    var userIsShowLeftAvatar: Bool? = nil

    var userIsShowLeftNickname: Bool? = nil

    var userIsShowRightAvatar: Bool? = nil

    var userIsShowRightNickname: Bool? = nil

    var userIsShowTimeInBubble: Bool? = nil

    var userCellSpacing: CGFloat? = nil

    var userIsShowSystemMessage: Bool? = nil

    var userIsShowUnsupportMessage: Bool? = nil

    var userIsSupportCopy: Bool? = nil

    var userIsSupportDelete: Bool? = nil

    var userIsSupportRecall: Bool? = nil

    var userIsSupportForward: Bool? = nil

    var userIsSupportQuote: Bool? = nil

    var userIsSupportMultiSelect: Bool? = nil

    var userIsSupportConvertToText: Bool? = nil

    var userIsSupportTranslate: Bool? = nil

    var userIsSupportListenFromHere: Bool? = nil

    var userActionCustomizer: MessageActionCustomizer? = nil

    var userHorizontalPadding: CGFloat? = nil

    var userAvatarSpacing: CGFloat? = nil

    var userIsSupportReaction: Bool? = nil

    var userEnableTyping: Bool? = nil

    var userBackground: MessageListBackground? = nil

    var userDefaultBubbleAppearance: MessageBubbleAppearance? = nil

    var userOwnBubbleAppearance: MessageBubbleAppearance? = nil

    var userIncomingBubbleAppearance: MessageBubbleAppearance? = nil

    var userLeftBubbleAppearance: MessageBubbleAppearance? = nil

    var userRightBubbleAppearance: MessageBubbleAppearance? = nil

    var exclusionMatchers: [MessageMatcher] = []
}

extension ChatMessageListConfig {
    public init(
        alignment: MessageAlignment? = nil,
        isShowTimeMessage: Bool? = nil,
        isShowLeftAvatar: Bool? = nil,
        isShowLeftNickname: Bool? = nil,
        isShowRightAvatar: Bool? = nil,
        isShowRightNickname: Bool? = nil,
        isShowTimeInBubble: Bool? = nil,
        cellSpacing: CGFloat? = nil,
        isShowSystemMessage: Bool? = nil,
        isShowUnsupportMessage: Bool? = nil,
        isSupportCopy: Bool? = nil,
        isSupportDelete: Bool? = nil,
        isSupportRecall: Bool? = nil,
        isSupportForward: Bool? = nil,
        isSupportQuote: Bool? = nil,
        isSupportMultiSelect: Bool? = nil,
        isSupportConvertToText: Bool? = nil,
        isSupportTranslate: Bool? = nil,
        isSupportListenFromHere: Bool? = nil,
        actionCustomizer: MessageActionCustomizer? = nil,
        horizontalPadding: CGFloat? = nil,
        avatarSpacing: CGFloat? = nil,
        isSupportReaction: Bool? = nil,
        enableTyping: Bool? = nil,
        background: MessageListBackground? = nil,
        defaultBubbleAppearance: MessageBubbleAppearance? = nil,
        ownBubbleAppearance: MessageBubbleAppearance? = nil,
        incomingBubbleAppearance: MessageBubbleAppearance? = nil,
        leftBubbleAppearance: MessageBubbleAppearance? = nil,
        rightBubbleAppearance: MessageBubbleAppearance? = nil
    ) {
        self.userAlignment = alignment
        self.userIsShowTimeMessage = isShowTimeMessage
        self.userIsShowLeftAvatar = isShowLeftAvatar
        self.userIsShowLeftNickname = isShowLeftNickname
        self.userIsShowRightAvatar = isShowRightAvatar
        self.userIsShowRightNickname = isShowRightNickname
        self.userIsShowTimeInBubble = isShowTimeInBubble
        self.userCellSpacing = cellSpacing
        self.userIsShowSystemMessage = isShowSystemMessage
        self.userIsShowUnsupportMessage = isShowUnsupportMessage
        self.userIsSupportCopy = isSupportCopy
        self.userIsSupportDelete = isSupportDelete
        self.userIsSupportRecall = isSupportRecall
        self.userIsSupportForward = isSupportForward
        self.userIsSupportQuote = isSupportQuote
        self.userIsSupportMultiSelect = isSupportMultiSelect
        self.userIsSupportConvertToText = isSupportConvertToText
        self.userIsSupportTranslate = isSupportTranslate
        self.userIsSupportListenFromHere = isSupportListenFromHere
        self.userActionCustomizer = actionCustomizer
        self.userHorizontalPadding = horizontalPadding
        self.userAvatarSpacing = avatarSpacing
        self.userIsSupportReaction = isSupportReaction
        self.userEnableTyping = enableTyping
        self.userBackground = background
        self.userDefaultBubbleAppearance = defaultBubbleAppearance
        self.userOwnBubbleAppearance = ownBubbleAppearance
        self.userIncomingBubbleAppearance = incomingBubbleAppearance
        self.userLeftBubbleAppearance = leftBubbleAppearance
        self.userRightBubbleAppearance = rightBubbleAppearance
    }
}
