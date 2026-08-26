import AtomicXCore
import SnapKit
import UIKit

protocol ConversationActionConfigProtocol {
    var isSupportDelete: Bool { get }
    var isSupportMute: Bool { get }
    var isSupportPin: Bool { get }
    var isSupportMarkUnread: Bool { get }
    var isSupportClearHistory: Bool { get }
    var actionCustomizer: ConversationActionCustomizer? { get }
}

extension ConversationActionConfigProtocol {
    var actionCustomizer: ConversationActionCustomizer? { nil }
}

struct ChatConversationActionConfig: ConversationActionConfigProtocol {
    var isSupportDelete: Bool {
        if let userIsSupportDelete = userIsSupportDelete {
            return userIsSupportDelete
        } else {
            let config = AppBuilderConfig.shared
            return config.conversationActionList.contains(.delete)
        }
    }

    var isSupportMute: Bool {
        if let userIsSupportMute = userIsSupportMute {
            return userIsSupportMute
        } else {
            let config = AppBuilderConfig.shared
            return config.conversationActionList.contains(.mute)
        }
    }

    var isSupportPin: Bool {
        if let userIsSupportPin = userIsSupportPin {
            return userIsSupportPin
        } else {
            let config = AppBuilderConfig.shared
            return config.conversationActionList.contains(.pin)
        }
    }

    var isSupportMarkUnread: Bool {
        if let userIsSupportMarkUnread = userIsSupportMarkUnread {
            return userIsSupportMarkUnread
        } else {
            let config = AppBuilderConfig.shared
            return config.conversationActionList.contains(.markUnread)
        }
    }

    var isSupportClearHistory: Bool {
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

    var actionCustomizer: ConversationActionCustomizer? {
        return userActionCustomizer
    }

    private let userIsSupportClearHistory: Bool?

    private let userActionCustomizer: ConversationActionCustomizer?

    init() {
        self.userIsSupportDelete = nil
        self.userIsSupportMute = nil
        self.userIsSupportPin = nil
        self.userIsSupportMarkUnread = nil
        self.userIsSupportClearHistory = nil
        self.userActionCustomizer = nil
    }

    init(
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

typealias ConversationActionCustomizer = (CustomEditor<ConversationCustomAction>) -> Void

struct ConversationCustomAction: CustomItem {
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

    init(title: String, action: @escaping (ConversationInfo) -> Void) {
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
