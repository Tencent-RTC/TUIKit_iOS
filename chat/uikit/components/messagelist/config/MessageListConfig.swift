import Foundation
import UIKit
import AtomicXCore

extension ChatMessageListConfig {
    static let defaultCellSpacing: CGFloat = 10.0
    static let defaultHorizontalPadding = CGFloat(SpacingScheme.bubbleSpacing)
    static let defaultAvatarSpacing = CGFloat(SpacingScheme.smallSpacing)
    static let defaultBubbleMaxWidthRatio: CGFloat = 0.72
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
        rightBubbleAppearance: MessageBubbleAppearance? = nil,
        bubbleMaxWidthRatio: CGFloat? = nil,
        enableChatbotReplyPlaceholder: Bool? = nil,
        streamingMaxCharactersPerSecond: Double? = nil
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
        self.userBubbleMaxWidthRatio = bubbleMaxWidthRatio
        self.userEnableChatbotReplyPlaceholder = enableChatbotReplyPlaceholder
        self.userStreamingMaxCharactersPerSecond = streamingMaxCharactersPerSecond
    }
}

public typealias MessageMatcher = (MessageInfo) -> Bool

extension ChatMessageListConfig {
    public var enableChatbotReplyPlaceholder: Bool {
        get { userEnableChatbotReplyPlaceholder ?? true }
        set { userEnableChatbotReplyPlaceholder = newValue }
    }

    /// 流式文字每秒最多显示的 UTF-16 单位数，0 表示不限速。
    public var streamingMaxCharactersPerSecond: Double {
        get { userStreamingMaxCharactersPerSecond ?? 0 }
        set { userStreamingMaxCharactersPerSecond = newValue }
    }

    public var alignment: MessageAlignment {
        get { userAlignment ?? AppBuilderConfig.shared.messageAlignment }
        set { userAlignment = newValue }
    }

    public var isShowTimeMessage: Bool {
        get { userIsShowTimeMessage ?? true }
        set { userIsShowTimeMessage = newValue }
    }

    public var isShowLeftAvatar: Bool {
        get { userIsShowLeftAvatar ?? true }
        set { userIsShowLeftAvatar = newValue }
    }

    public var isShowLeftNickname: Bool {
        get { userIsShowLeftNickname ?? true }
        set { userIsShowLeftNickname = newValue }
    }

    public var isShowRightAvatar: Bool {
        get { userIsShowRightAvatar ?? false }
        set { userIsShowRightAvatar = newValue }
    }

    public var isShowRightNickname: Bool {
        get { userIsShowRightNickname ?? true }
        set { userIsShowRightNickname = newValue }
    }

    public var isShowTimeInBubble: Bool {
        get { userIsShowTimeInBubble ?? true }
        set { userIsShowTimeInBubble = newValue }
    }

    public var cellSpacing: CGFloat {
        get { userCellSpacing ?? Self.defaultCellSpacing }
        set { userCellSpacing = newValue }
    }

    public var isShowSystemMessage: Bool {
        get { userIsShowSystemMessage ?? true }
        set { userIsShowSystemMessage = newValue }
    }

    public var isShowUnsupportMessage: Bool {
        get { userIsShowUnsupportMessage ?? true }
        set { userIsShowUnsupportMessage = newValue }
    }

    public var horizontalPadding: CGFloat {
        get { userHorizontalPadding ?? Self.defaultHorizontalPadding }
        set { userHorizontalPadding = newValue }
    }

    public var avatarSpacing: CGFloat {
        get { userAvatarSpacing ?? Self.defaultAvatarSpacing }
        set { userAvatarSpacing = newValue }
    }

    public var isSupportReaction: Bool {
        get { userIsSupportReaction ?? true }
        set { userIsSupportReaction = newValue }
    }

    public var enableTyping: Bool {
        get { userEnableTyping ?? true }
        set { userEnableTyping = newValue }
    }

    public var background: MessageListBackground? {
        get { userBackground }
        set { userBackground = newValue }
    }

    public var defaultBubbleAppearance: MessageBubbleAppearance? {
        get { userDefaultBubbleAppearance }
        set { userDefaultBubbleAppearance = newValue }
    }

    public var ownBubbleAppearance: MessageBubbleAppearance? {
        get { userOwnBubbleAppearance }
        set { userOwnBubbleAppearance = newValue }
    }

    public var incomingBubbleAppearance: MessageBubbleAppearance? {
        get { userIncomingBubbleAppearance }
        set { userIncomingBubbleAppearance = newValue }
    }

    public var leftBubbleAppearance: MessageBubbleAppearance? {
        get { userLeftBubbleAppearance }
        set { userLeftBubbleAppearance = newValue }
    }

    public var rightBubbleAppearance: MessageBubbleAppearance? {
        get { userRightBubbleAppearance }
        set { userRightBubbleAppearance = newValue }
    }

    public var bubbleMaxWidthRatio: CGFloat {
        get { userBubbleMaxWidthRatio ?? Self.defaultBubbleMaxWidthRatio }
        set { userBubbleMaxWidthRatio = newValue }
    }

    public var messageExclusionMatchers: [MessageMatcher] {
        get { userMessageExclusionMatchers ?? [] }
        set { userMessageExclusionMatchers = newValue }
    }

    public mutating func addMessageExclusion(_ matcher: @escaping MessageMatcher) {
        messageExclusionMatchers.append(matcher)
    }

    public mutating func excludeMessagesByType(_ types: MessageType...) {
        messageExclusionMatchers.append { message in
            return types.contains(message.messageType)
        }
    }

    public mutating func excludeCustomMessagesByBusinessID(_ businessID: String) {
        messageExclusionMatchers.append { message in
            guard case .custom(let payload) = message.messagePayload,
                  let data = payload.customData.data(using: .utf8),
                  let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
            else {
                return false
            }
            return json["businessID"] as? String == businessID
        }
    }

    public mutating func clearMessageExclusions() {
        userMessageExclusionMatchers = nil
    }
}
