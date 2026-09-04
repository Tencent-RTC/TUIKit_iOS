import AtomicXCore
import Combine
import SnapKit
import UIKit

public protocol ContactListConfigProtocol {
    var showNewContacts: Bool { get }
    var showGroupApplications: Bool { get }
    var showMyGroups: Bool { get }
    var showBlacklist: Bool { get }
    var showSearchBar: Bool { get }
    var itemCustomizer: ContactListItemCustomizer? { get }
}

public extension ContactListConfigProtocol {
    var showNewContacts: Bool { true }
    var showGroupApplications: Bool { true }
    var showMyGroups: Bool { true }
    var showBlacklist: Bool { true }
    var showSearchBar: Bool { true }
    var itemCustomizer: ContactListItemCustomizer? { nil }
}

public struct ChatContactListConfig: ContactListConfigProtocol {
    public var showNewContacts: Bool {
        return userShowNewContacts ?? true
    }

    public var showGroupApplications: Bool {
        return userShowGroupApplications ?? true
    }

    public var showMyGroups: Bool {
        return userShowMyGroups ?? true
    }

    public var showBlacklist: Bool {
        return userShowBlacklist ?? true
    }

    public var showSearchBar: Bool {
        return userShowSearchBar ?? true
    }

    public var itemCustomizer: ContactListItemCustomizer? {
        return userItemCustomizer
    }

    private let userShowNewContacts: Bool?

    private let userShowGroupApplications: Bool?

    private let userShowMyGroups: Bool?

    private let userShowBlacklist: Bool?

    private let userShowSearchBar: Bool?

    private let userItemCustomizer: ContactListItemCustomizer?

    public init() {
        self.userShowNewContacts = nil
        self.userShowGroupApplications = nil
        self.userShowMyGroups = nil
        self.userShowBlacklist = nil
        self.userShowSearchBar = nil
        self.userItemCustomizer = nil
    }

    public init(showNewContacts: Bool? = nil,
                showGroupApplications: Bool? = nil,
                showMyGroups: Bool? = nil,
                showBlacklist: Bool? = nil,
                showSearchBar: Bool? = nil,
                itemCustomizer: ContactListItemCustomizer? = nil) {
        self.userShowNewContacts = showNewContacts
        self.userShowGroupApplications = showGroupApplications
        self.userShowMyGroups = showMyGroups
        self.userShowBlacklist = showBlacklist
        self.userShowSearchBar = showSearchBar
        self.userItemCustomizer = itemCustomizer
    }
}

public typealias ContactListItemCustomizer = (CustomEditor<ContactCustomItem>) -> Void

public struct ContactCustomItem: CustomItem {
    public var ID: String

    public let title: String

    public let iconName: String

    public let badgeCount: AnyPublisher<Int, Never>?

    public let onClick: () -> Void

    public init(ID: String,
                title: String,
                iconName: String,
                badgeCount: AnyPublisher<Int, Never>? = nil,
                onClick: @escaping () -> Void) {
        self.ID = ID
        self.title = title
        self.iconName = iconName
        self.badgeCount = badgeCount
        self.onClick = onClick
    }
}

enum ContactDisplayFormatter {
    static func name(for contact: ContactInfo) -> String {
        if let remark = contact.friendRemark, !remark.isEmpty { return remark }
        if let nickname = contact.nickname, !nickname.isEmpty { return nickname }
        return contact.userID
    }

    static func name(for group: GroupInfo) -> String {
        if let groupName = group.groupName, !groupName.isEmpty { return groupName }
        return group.groupID
    }
}

final class ContactListView: UIView {
    private let impl: ContactListViewImpl

    init(onContactClick: @escaping (ContactInfo) -> Void,
         onGroupClick: @escaping (GroupInfo) -> Void,
         config: ContactListConfigProtocol = ChatContactListConfig()) {
        impl = ContactListViewImpl(onContactClick: onContactClick, onGroupClick: onGroupClick, config: config)
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
