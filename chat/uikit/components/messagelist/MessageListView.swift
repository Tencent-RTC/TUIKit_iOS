import Foundation
import UIKit
import SnapKit
import AtomicXCore

public final class MessageListView: UIView {
    static let blankAreaClickNotification = NSNotification.Name("MessageListBlankAreaClick")
    private let impl: MessageListViewImpl

    init(conversationID: String,
         config: ChatMessageListConfig = ChatMessageListConfig(),
         locateMessage: MessageInfo? = nil,
         chatbotController: ChatbotConversationController? = nil,
         onUserClick: ((String) -> Void)? = nil,
         onMultiSelectModeChange: ((Bool) -> Void)? = nil) {
        impl = MessageListViewImpl(conversationID: conversationID,config:
                                    config,locateMessage: locateMessage,
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
    public let config: ChatMessageListConfig
    public let isLeft: Bool
    public let isSelf: Bool
    public var showsReadReceipt: Bool = true
    public var isGroupChat: Bool = false
    public var isMultiSelectMode: Bool = false
    public var detailTimeText: String? = nil
    public weak var messageListStore: MessageListStore?
    public var onMediaTap: ((MessageInfo) -> Void)? = nil
    public var onMergedMessageTap: ((MessageInfo) -> Void)? = nil
}

public protocol MessageContentView: UIView {
    func bind(message: MessageInfo, context: MessageContentContext)
}
