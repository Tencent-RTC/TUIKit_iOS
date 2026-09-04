import UIKit
import SnapKit
import AtomicXCore

public typealias MessageMatcher = (MessageInfo) -> Bool

public protocol MessageListConfigProtocol {
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
    var messageExclusionMatchers: [MessageMatcher] { get }
    var background: MessageListBackground? { get }
    var defaultBubbleAppearance: MessageBubbleAppearance? { get }
    var ownBubbleAppearance: MessageBubbleAppearance? { get }
    var incomingBubbleAppearance: MessageBubbleAppearance? { get }
    var leftBubbleAppearance: MessageBubbleAppearance? { get }
    var rightBubbleAppearance: MessageBubbleAppearance? { get }
}

extension MessageListConfigProtocol {
    public var isSupportQuote: Bool { true }
    public var enableTyping: Bool { true }
    public var messageExclusionMatchers: [MessageMatcher] { [] }
    public var background: MessageListBackground? { nil }
    public var defaultBubbleAppearance: MessageBubbleAppearance? { nil }
    public var ownBubbleAppearance: MessageBubbleAppearance? { nil }
    public var incomingBubbleAppearance: MessageBubbleAppearance? { nil }
    public var leftBubbleAppearance: MessageBubbleAppearance? { nil }
    public var rightBubbleAppearance: MessageBubbleAppearance? { nil }

    public func resolvedBubbleAppearance(isSelf: Bool, isLeft: Bool) -> MessageBubbleAppearance? {
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

public protocol MessageActionConfigProtocol {
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

extension MessageActionConfigProtocol {
    public var isSupportQuote: Bool { true }
    public var actionCustomizer: MessageActionCustomizer? { nil }
}

extension ChatMessageListConfig: MessageListConfigProtocol, MessageActionConfigProtocol {
    public var alignment: MessageAlignment {
        return userAlignment ?? AppBuilderConfig.shared.messageAlignment
    }

    public var isShowTimeMessage: Bool {
        return userIsShowTimeMessage ?? true
    }

    public var isShowLeftAvatar: Bool {
        return userIsShowLeftAvatar ?? true
    }

    public var isShowLeftNickname: Bool {
        return userIsShowLeftNickname ?? true
    }

    public var isShowRightAvatar: Bool {
        return userIsShowRightAvatar ?? false
    }

    public var isShowRightNickname: Bool {
        return userIsShowRightNickname ?? true
    }

    public var isShowTimeInBubble: Bool {
        return userIsShowTimeInBubble ?? true
    }

    public var cellSpacing: CGFloat {
        return userCellSpacing ?? Self.defaultCellSpacing
    }

    public var isShowSystemMessage: Bool {
        return userIsShowSystemMessage ?? true
    }

    public var isShowUnsupportMessage: Bool {
        return userIsShowUnsupportMessage ?? true
    }

    public var isSupportCopy: Bool {
        if let userIsSupportCopy = userIsSupportCopy {
            return userIsSupportCopy
        } else {
            let config = AppBuilderConfig.shared
            return config.messageActionList.contains(.copy)
        }
    }

    public var isSupportDelete: Bool {
        if let userIsSupportDelete = userIsSupportDelete {
            return userIsSupportDelete
        } else {
            let config = AppBuilderConfig.shared
            return config.messageActionList.contains(.delete)
        }
    }

    public var isSupportRecall: Bool {
        if let userIsSupportRecall = userIsSupportRecall {
            return userIsSupportRecall
        } else {
            let config = AppBuilderConfig.shared
            return config.messageActionList.contains(.recall)
        }
    }

    public var isSupportForward: Bool {
        if let userIsSupportForward = userIsSupportForward {
            return userIsSupportForward
        } else {
            return AppBuilderConfig.shared.messageActionList.contains(.forward)
        }
    }

    public var isSupportQuote: Bool {
        if let userIsSupportQuote = userIsSupportQuote {
            return userIsSupportQuote
        } else {
            return AppBuilderConfig.shared.messageActionList.contains(.quote)
        }
    }

    public var isSupportMultiSelect: Bool {
        return userIsSupportMultiSelect ?? true
    }

    public var isSupportConvertToText: Bool {
        return userIsSupportConvertToText ?? true
    }

    public var isSupportTranslate: Bool {
        return userIsSupportTranslate ?? true
    }

    public var isSupportListenFromHere: Bool {
        return userIsSupportListenFromHere ?? true
    }

    public var actionCustomizer: MessageActionCustomizer? {
        return userActionCustomizer
    }

    public var horizontalPadding: CGFloat {
        return userHorizontalPadding ?? Self.defaultHorizontalPadding
    }

    public var avatarSpacing: CGFloat {
        return userAvatarSpacing ?? Self.defaultAvatarSpacing
    }

    public var isSupportReaction: Bool {
        return userIsSupportReaction ?? true
    }

    public var enableTyping: Bool {
        return userEnableTyping ?? true
    }

    public var background: MessageListBackground? {
        return userBackground
    }

    public var defaultBubbleAppearance: MessageBubbleAppearance? {
        return userDefaultBubbleAppearance
    }

    public var ownBubbleAppearance: MessageBubbleAppearance? {
        return userOwnBubbleAppearance
    }

    public var incomingBubbleAppearance: MessageBubbleAppearance? {
        return userIncomingBubbleAppearance
    }

    public var leftBubbleAppearance: MessageBubbleAppearance? {
        return userLeftBubbleAppearance
    }

    public var rightBubbleAppearance: MessageBubbleAppearance? {
        return userRightBubbleAppearance
    }

    public var messageExclusionMatchers: [MessageMatcher] {
        return exclusionMatchers
    }

    public mutating func addMessageExclusion(_ matcher: @escaping MessageMatcher) {
        exclusionMatchers.append(matcher)
    }

    public mutating func excludeMessagesByType(_ types: MessageType...) {
        exclusionMatchers.append { message in
            return types.contains(message.messageType)
        }
    }

    public mutating func excludeCustomMessagesByBusinessID(_ businessID: String) {
        exclusionMatchers.append { message in
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
        exclusionMatchers.removeAll()
    }
}

public final class MessageListView: UIView {
    static let blankAreaClickNotification = NSNotification.Name("MessageListBlankAreaClick")

    public static func registerCustomMessageCell(businessID: String,
                                                 summaryProvider: @escaping (CustomMessagePayload) -> String?,
                                                 makeContentView: @escaping () -> MessageContentView) {
        MessageCellRegistry.shared.registerCustomMessageCell(
            businessID: businessID,
            summaryProvider: summaryProvider,
            makeContentView: makeContentView
        )
    }

    var onMultiSelectModeChange: ((Bool) -> Void)? {
        get { impl.onMultiSelectModeChange }
        set { impl.onMultiSelectModeChange = newValue }
    }

    private let impl: MessageListViewImpl

    init(conversationID: String,
         config: (MessageListConfigProtocol & MessageActionConfigProtocol) = ChatMessageListConfig(),
         locateMessage: MessageInfo? = nil,
         onUserClick: ((String) -> Void)? = nil) {
        impl = MessageListViewImpl(
            conversationID: conversationID,
            config: config,
            locateMessage: locateMessage,
            onUserClick: onUserClick
        )
        super.init(frame: .zero)
        addSubview(impl)
        impl.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func hostVisibilityDidChange(_ isVisible: Bool) {
        impl.hostVisibilityDidChange(isVisible)
    }

    func applyChatBackgroundImage(uri: String?) {
        impl.applyChatBackgroundImage(uri: uri)
    }

    func exitMultiSelectMode() {
        impl.exitMultiSelectMode()
    }
}

public struct MessageContentContext {
    let config: MessageListConfigProtocol
    public let isLeft: Bool
    public let isSelf: Bool
    var showsReadReceipt: Bool = true
    public var isGroupChat: Bool = false
    public var isMultiSelectMode: Bool = false
    var detailTimeText: String? = nil
    weak var messageListStore: MessageListStore?

    var onMediaTap: ((MessageInfo) -> Void)? = nil

    var onMergedMessageTap: ((MessageInfo) -> Void)? = nil
}

public protocol MessageContentView: UIView {

    func bind(message: MessageInfo, context: MessageContentContext)
}
