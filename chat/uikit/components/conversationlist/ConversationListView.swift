import AtomicXCore
import SnapKit
import UIKit

public protocol ConversationActionConfigProtocol {
    var isSupportDelete: Bool { get }
    var isSupportMute: Bool { get }
    var isSupportPin: Bool { get }
    var isSupportMarkUnread: Bool { get }
    var isSupportClearHistory: Bool { get }
    var actionCustomizer: ConversationActionCustomizer? { get }
}

public extension ConversationActionConfigProtocol {
    var actionCustomizer: ConversationActionCustomizer? { nil }
}

public struct ChatConversationActionConfig: ConversationActionConfigProtocol {
    public var isSupportDelete: Bool {
        if let userIsSupportDelete = userIsSupportDelete {
            return userIsSupportDelete
        } else {
            let config = AppBuilderConfig.shared
            return config.conversationActionList.contains(.delete)
        }
    }

    public var isSupportMute: Bool {
        if let userIsSupportMute = userIsSupportMute {
            return userIsSupportMute
        } else {
            let config = AppBuilderConfig.shared
            return config.conversationActionList.contains(.mute)
        }
    }

    public var isSupportPin: Bool {
        if let userIsSupportPin = userIsSupportPin {
            return userIsSupportPin
        } else {
            let config = AppBuilderConfig.shared
            return config.conversationActionList.contains(.pin)
        }
    }

    public var isSupportMarkUnread: Bool {
        if let userIsSupportMarkUnread = userIsSupportMarkUnread {
            return userIsSupportMarkUnread
        } else {
            let config = AppBuilderConfig.shared
            return config.conversationActionList.contains(.markUnread)
        }
    }

    public var isSupportClearHistory: Bool {
        if let userIsSupportClearHistory = userIsSupportClearHistory {
            return userIsSupportClearHistory
        } else {
            let config = AppBuilderConfig.shared
            return config.conversationActionList.contains(.clearHistory)
        }
    }

    private let userIsSupportDelete: Bool?

    private let userIsSupportMute: Bool?

    private let userIsSupportPin: Bool?

    private let userIsSupportMarkUnread: Bool?

    public var actionCustomizer: ConversationActionCustomizer? {
        return userActionCustomizer
    }

    private let userIsSupportClearHistory: Bool?

    private let userActionCustomizer: ConversationActionCustomizer?

    public init() {
        self.userIsSupportDelete = nil
        self.userIsSupportMute = nil
        self.userIsSupportPin = nil
        self.userIsSupportMarkUnread = nil
        self.userIsSupportClearHistory = nil
        self.userActionCustomizer = nil
    }

    public init(
        isSupportDelete: Bool? = nil,
        isSupportMute: Bool? = nil,
        isSupportPin: Bool? = nil,
        isSupportMarkUnread: Bool? = nil,
        isSupportClearHistory: Bool? = nil,
        actionCustomizer: ConversationActionCustomizer? = nil
    ) {
        self.userIsSupportDelete = isSupportDelete
        self.userIsSupportMute = isSupportMute
        self.userIsSupportPin = isSupportPin
        self.userIsSupportMarkUnread = isSupportMarkUnread
        self.userIsSupportClearHistory = isSupportClearHistory
        self.userActionCustomizer = actionCustomizer
    }
}

public typealias ConversationActionCustomizer = (CustomEditor<ConversationCustomAction>) -> Void

public struct ConversationCustomAction: CustomItem {
    public var ID: String
    public let title: String
    public let dangerous: Bool
    public let action: (ConversationInfo) -> Void

    public init(ID: String, title: String, dangerous: Bool = false, action: @escaping (ConversationInfo) -> Void) {
        self.ID = ID
        self.title = title
        self.dangerous = dangerous
        self.action = action
    }

    public init(title: String, action: @escaping (ConversationInfo) -> Void) {
        self.init(ID: UUID().uuidString, title: title, dangerous: false, action: action)
    }
}

final class ConversationListView: UIView {
    private let impl: ConversationListViewImpl

    init(onConversationClick: @escaping (ConversationInfo) -> Void,
         config: ConversationActionConfigProtocol = ChatConversationActionConfig()) {
        impl = ConversationListViewImpl(onConversationClick: onConversationClick, config: config)
        super.init(frame: .zero)
        addSubview(impl)
        impl.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}
