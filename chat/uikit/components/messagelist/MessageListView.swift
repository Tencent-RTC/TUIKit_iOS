import Foundation
import UIKit
import SnapKit
import AtomicXCore

public final class MessageListView: UIView {
    static let blankAreaClickNotification = NSNotification.Name("MessageListBlankAreaClick")
    private let impl: MessageListViewImpl

    /// 添加或更新本地展示占位；相同会话和占位 ID 的更新保留原位置。
    public static func addPlaceholder(conversationID: String, info: MessagePlaceholderInfo) {
        MessageListPlaceholderStore.shared.upsert(conversationID: conversationID, info: info)
    }

    /// 删除本地展示占位，不撤回消息或取消发送任务。
    public static func removePlaceholder(conversationID: String, placeholderID: String) {
        MessageListPlaceholderStore.shared.remove(conversationID: conversationID, placeholderID: placeholderID)
    }

    public static func registerCustomMessageCell(businessID: String,
                                                 summaryProvider: @escaping (CustomMessagePayload) -> String?,
                                                 makeContentView: @escaping () -> MessageContentView) {
        MessageCellRegistry.shared.registerCustomMessageCell(
            businessID: businessID,
            summaryProvider: summaryProvider,
            makeContentView: makeContentView
        )
    }

    /// 注册自定义消息摘要匹配器，返回非 nil 即命中（用于会话列表与引用预览）。
    public static func registerCustomMessageSummary(matcher: @escaping (CustomMessagePayload) -> String?) {
        CustomMessageSummaryRegistry.shared.registerMatcher(matcher)
    }

    init(conversationID: String,
         config: ChatMessageListConfig = ChatMessageListConfig(),
         locateMessage: MessageInfo? = nil,
         chatbotController: ChatbotConversationController? = nil,
         onUserClick: ((String) -> Void)? = nil,
         onMultiSelectModeChange: ((Bool) -> Void)? = nil) {
        impl = MessageListViewImpl(
            conversationID: conversationID,
            config: config,
            locateMessage: locateMessage,
            chatbotController: chatbotController,
            onUserClick: onUserClick,
            onMultiSelectModeChange: onMultiSelectModeChange
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

public typealias MessageActionCustomizer = (CustomEditor<MessageActionMenuAction>) -> Void

public struct MessageActionMenuAction: CustomItem {
    public var ID: String = ""
    public let iconName: String
    public let systemIconFallback: String
    public let label: String
    public var isDangerous: Bool = false
    public var isReactionEntry: Bool = false
    public let handler: (MessageInfo, MessageActionStore) -> Void
    public init(ID: String = "",
                iconName: String,
                systemIconFallback: String,
                label: String,
                isDangerous: Bool = false,
                isReactionEntry: Bool = false,
                handler: @escaping (MessageInfo, MessageActionStore) -> Void) {
        self.ID = ID
        self.iconName = iconName
        self.systemIconFallback = systemIconFallback
        self.label = label
        self.isDangerous = isDangerous
        self.isReactionEntry = isReactionEntry
        self.handler = handler
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
