import AtomicXCore
import Combine
import SnapKit
import UIKit

enum ContactListItemIDs {
    static let newContacts = "contactList.newContacts"
    static let groupApplications = "contactList.groupApplications"
    static let myGroups = "contactList.myGroups"
    static let blacklist = "contactList.blacklist"
}

final class ContactListViewImpl: RTCBaseView {
    private static let itemTitleFontSize: CGFloat = 18

    private let onContactClick: (ContactInfo) -> Void

    private let onGroupClick: (GroupInfo) -> Void

    private let config: ContactListConfigProtocol

    private let viewModel = ContactListViewModel()

    private var cancellables = Set<AnyCancellable>()

    private var allContacts: [ContactInfo] = []

    private var searchQuery = ""

    private lazy var listView: AZOrderedListView = {
        let listView = AZOrderedListView(showIndexBar: true) { [weak self] item in
            guard let contact = item.extraData as? ContactInfo else { return }
            self?.onContactClick(contact)
        }
        listView.itemTitleFontSize = Self.itemTitleFontSize
        return listView
    }()

    private let searchBar = ContactSearchBarView()

    private let headerView = ContactNavigationHeaderView()

    init(onContactClick: @escaping (ContactInfo) -> Void,
         onGroupClick: @escaping (GroupInfo) -> Void,
         config: ContactListConfigProtocol = ChatContactListConfig()) {
        self.onContactClick = onContactClick
        self.onGroupClick = onGroupClick
        self.config = config
        super.init(frame: .zero)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    public override func constructViewHierarchy() {
        addSubview(searchBar)
        addSubview(listView)
    }

    public override func activateConstraints() {
        searchBar.snp.makeConstraints { make in
            make.top.leading.trailing.equalToSuperview()
        }
        listView.snp.makeConstraints { make in
            if config.showSearchBar {
                make.top.equalTo(searchBar.snp.bottom)
            } else {
                make.top.equalToSuperview()
            }
            make.leading.trailing.bottom.equalToSuperview()
        }
        searchBar.isHidden = !config.showSearchBar
    }

    public override func bindInteraction() {
        listView.headerView = headerView
        searchBar.onQueryChange = { [weak self] query in
            self?.searchQuery = query
            self?.renderFriendList()
        }
        listView.onUserInteraction = { [weak self] in
            self?.searchBar.hideKeyboard()
        }
        headerView.setItems(buildHeaderItems())
        bindViewModel()
        viewModel.loadData()
    }

    public override func setupViewStyle() {
        backgroundColor = TUIChatKitTheme.colors.bgColorOperate
    }

    private func buildHeaderItems() -> [ContactCustomItem] {
        var defaults: [ContactCustomItem] = []
        if config.showNewContacts {
            defaults.append(ContactCustomItem(
                ID: ContactListItemIDs.newContacts,
                title: LocalizedChatString("ContactsNewFriends"),
                iconName: "contact_new_contacts",
                badgeCount: viewModel.$friendApplicationUnreadCount.eraseToAnyPublisher(),
                onClick: { [weak self] in self?.presentFriendApplications() }
            ))
        }
        if config.showGroupApplications {
            defaults.append(ContactCustomItem(
                ID: ContactListItemIDs.groupApplications,
                title: LocalizedChatString("ContactsGroupApplications"),
                iconName: "contact_group_notification",
                badgeCount: viewModel.$groupApplicationUnreadCount.eraseToAnyPublisher(),
                onClick: { [weak self] in self?.presentGroupApplications() }
            ))
        }
        if config.showMyGroups {
            defaults.append(ContactCustomItem(
                ID: ContactListItemIDs.myGroups,
                title: LocalizedChatString("ContactsGroupChats"),
                iconName: "contact_my_group",
                onClick: { [weak self] in self?.presentGroupList() }
            ))
        }
        if config.showBlacklist {
            defaults.append(ContactCustomItem(
                ID: ContactListItemIDs.blacklist,
                title: LocalizedChatString("ContactsBlackList"),
                iconName: "contact_blacklist",
                onClick: { [weak self] in self?.presentBlackList() }
            ))
        }
        guard let customizer = config.itemCustomizer else { return defaults }
        let editor = CustomEditor(items: defaults)
        customizer(editor)
        return editor.build()
    }

    private func bindViewModel() {
        viewModel.$friendList
            .receive(on: DispatchQueue.main)
            .sink { [weak self] list in
                self?.allContacts = list
                self?.renderFriendList()
            }
            .store(in: &cancellables)
    }

    private func renderFriendList() {
        let isSearching = !searchQuery.trimmingCharacters(in: .whitespaces).isEmpty
        listView.isHeaderHidden = isSearching
        let filtered = allContacts.filter { contact in
            matchesSearchQuery(contact, query: searchQuery)
        }
        let items = filtered.map { contact in
            AZOrderedListItem(
                userID: contact.userID,
                avatarURL: contact.avatarURL,
                title: ContactDisplayNameFormatter.name(for: contact),
                extraData: contact
            )
        }
        listView.setItems(items)
    }

    private func matchesSearchQuery(_ contact: ContactInfo, query: String) -> Bool {
        let keyword = query.trimmingCharacters(in: .whitespaces)
        if keyword.isEmpty {
            return true
        }
        let candidates = [
            ContactDisplayNameFormatter.name(for: contact),
            contact.userID,
            contact.nickname,
            contact.friendRemark,
        ]
        var seen = Set<String>()
        return candidates.compactMap { $0 }.filter { !$0.isEmpty }.contains { value in
            if !seen.insert(value).inserted {
                return false
            }
            return value.range(of: keyword, options: .caseInsensitive) != nil
        }
    }

    private func presentFriendApplications() {
        present(FriendApplicationListViewController())
    }

    private func presentGroupApplications() {
        present(GroupApplicationListViewController())
    }

    private func presentGroupList() {
        let controller = GroupListViewController { [weak self] item in
            guard let group = item.extraData as? GroupInfo else { return }
            self?.onGroupClick(group)
        }
        controller.hidesBottomBarWhenPushed = true
        if let navigationController = findViewController()?.navigationController {
            navigationController.pushViewController(controller, animated: true)
        } else {
            present(controller)
        }
    }

    private func presentBlackList() {
        let controller = BlackListViewController { [weak self] item in
            guard let contact = item.extraData as? ContactInfo else { return }
            self?.onContactClick(contact)
        }
        controller.hidesBottomBarWhenPushed = true
        if let navigationController = findViewController()?.navigationController {
            navigationController.pushViewController(controller, animated: true)
        } else {
            present(controller)
        }
    }

    private func present(_ controller: UIViewController) {
        controller.modalPresentationStyle = .fullScreen
        findViewController()?.present(controller, animated: true)
    }

    private func findViewController() -> UIViewController? {
        var responder: UIResponder? = self
        while let next = responder?.next {
            if let viewController = next as? UIViewController {
                return viewController
            }
            responder = next
        }
        return nil
    }
}
