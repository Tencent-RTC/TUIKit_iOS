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
        self.alignment = alignment
        self.isShowTimeMessage = isShowTimeMessage
        self.isShowLeftAvatar = isShowLeftAvatar
        self.isShowLeftNickname = isShowLeftNickname
        self.isShowRightAvatar = isShowRightAvatar
        self.isShowRightNickname = isShowRightNickname
        self.isShowTimeInBubble = isShowTimeInBubble
        self.cellSpacing = cellSpacing
        self.isShowSystemMessage = isShowSystemMessage
        self.isShowUnsupportMessage = isShowUnsupportMessage
        self.isSupportCopy = isSupportCopy
        self.isSupportDelete = isSupportDelete
        self.isSupportRecall = isSupportRecall
        self.isSupportForward = isSupportForward
        self.isSupportQuote = isSupportQuote
        self.isSupportMultiSelect = isSupportMultiSelect
        self.isSupportConvertToText = isSupportConvertToText
        self.isSupportTranslate = isSupportTranslate
        self.isSupportListenFromHere = isSupportListenFromHere
        self.actionCustomizer = actionCustomizer
        self.horizontalPadding = horizontalPadding
        self.avatarSpacing = avatarSpacing
        self.isSupportReaction = isSupportReaction
        self.enableTyping = enableTyping
        self.background = background
        self.defaultBubbleAppearance = defaultBubbleAppearance
        self.ownBubbleAppearance = ownBubbleAppearance
        self.incomingBubbleAppearance = incomingBubbleAppearance
        self.leftBubbleAppearance = leftBubbleAppearance
        self.rightBubbleAppearance = rightBubbleAppearance
        self.bubbleMaxWidthRatio = bubbleMaxWidthRatio
        self.enableChatbotReplyPlaceholder = enableChatbotReplyPlaceholder
        self.streamingMaxCharactersPerSecond = streamingMaxCharactersPerSecond
    }
}

public typealias MessageMatcher = (MessageInfo) -> Bool

extension ChatMessageListConfig {
    var _enableChatbotReplyPlaceholder: Bool {
        enableChatbotReplyPlaceholder ?? true
    }

    /// 流式文字每秒最多显示的 UTF-16 单位数，0 表示不限速。
    var _streamingMaxCharactersPerSecond: Double {
        streamingMaxCharactersPerSecond ?? 0
    }

    var _alignment: MessageAlignment {
        alignment ?? AppBuilderConfig.shared.messageAlignment
    }

    var _isShowTimeMessage: Bool {
        isShowTimeMessage ?? true
    }

    var _isShowLeftAvatar: Bool {
        isShowLeftAvatar ?? true
    }

    var _isShowLeftNickname: Bool {
        isShowLeftNickname ?? true
    }

    var _isShowRightAvatar: Bool {
        isShowRightAvatar ?? false
    }

    var _isShowRightNickname: Bool {
        isShowRightNickname ?? true
    }

    var _isShowTimeInBubble: Bool {
        isShowTimeInBubble ?? true
    }

    var _cellSpacing: CGFloat {
        cellSpacing ?? Self.defaultCellSpacing
    }

    var _isShowSystemMessage: Bool {
        isShowSystemMessage ?? true
    }

    var _isShowUnsupportMessage: Bool {
        isShowUnsupportMessage ?? true
    }

    var _horizontalPadding: CGFloat {
        horizontalPadding ?? Self.defaultHorizontalPadding
    }

    var _avatarSpacing: CGFloat {
        avatarSpacing ?? Self.defaultAvatarSpacing
    }

    var _isSupportReaction: Bool {
        isSupportReaction ?? true
    }

    var _enableTyping: Bool {
        enableTyping ?? true
    }

    var _background: MessageListBackground? {
        background
    }

    var _defaultBubbleAppearance: MessageBubbleAppearance? {
        defaultBubbleAppearance
    }

    var _ownBubbleAppearance: MessageBubbleAppearance? {
        ownBubbleAppearance
    }

    var _incomingBubbleAppearance: MessageBubbleAppearance? {
        incomingBubbleAppearance
    }

    var _leftBubbleAppearance: MessageBubbleAppearance? {
        leftBubbleAppearance
    }

    var _rightBubbleAppearance: MessageBubbleAppearance? {
        rightBubbleAppearance
    }

    func resolvedBubbleAppearance(isSelf: Bool, isLeft: Bool) -> MessageBubbleAppearance? {
        let slot: MessageBubbleAppearance?
        switch _alignment {
        case .left:
            slot = _leftBubbleAppearance
        case .right:
            slot = _rightBubbleAppearance
        case .twoSided:
            slot = isSelf ? _ownBubbleAppearance : _incomingBubbleAppearance
        }
        guard let slot = slot else { return _defaultBubbleAppearance }
        return slot.merged(over: _defaultBubbleAppearance)
    }

    var _bubbleMaxWidthRatio: CGFloat {
        bubbleMaxWidthRatio ?? Self.defaultBubbleMaxWidthRatio
    }

    var _messageExclusionMatchers: [MessageMatcher] {
        messageExclusionMatchers ?? []
    }

    public mutating func addMessageExclusion(_ matcher: @escaping MessageMatcher) {
        messageExclusionMatchers = _messageExclusionMatchers + [matcher]
    }

    public mutating func excludeMessagesByType(_ types: MessageType...) {
        addMessageExclusion { message in
            return types.contains(message.messageType)
        }
    }

    public mutating func excludeCustomMessagesByBusinessID(_ businessID: String) {
        addMessageExclusion { message in
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
        messageExclusionMatchers = nil
    }
    
}
