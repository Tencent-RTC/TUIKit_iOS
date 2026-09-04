import UIKit
import SnapKit
import Combine
import AtomicXCore

final class ForwardTargetSelectorViewController: UIViewController {
    private static let conversationRowHeight: CGFloat = 60

    private static let topBarHeight: CGFloat = 56

    private static let contactEntryHeight: CGFloat = 56

    private static let contentHorizontalInset = CGFloat(SpacingScheme.bubbleSpacing)

    private static let arrowIconSize: CGFloat = 16

    private static let sectionLabelVerticalInset = CGFloat(SpacingScheme.smallSpacing)

    private static let loadMoreThreshold: CGFloat = 60

    private static let c2cIDPrefixLength = 4

    private let onConfirm: ([String]) -> Void

    private let conversationStore = ConversationListStore.create()

    private let contactStore = ContactStore.shared

    private var cancellables = Set<AnyCancellable>()

    private var conversations: [ConversationInfo] = []

    private var friendList: [ContactInfo] = []

    private var selectedConversationIDs = LinkedHashSet<String>()

    private lazy var topBar = buildTopBar()

    private lazy var contactEntry = buildContactEntry()

    private lazy var sectionLabel = buildSectionLabel()

    private lazy var tableView: UITableView = {
        let table = UITableView(frame: .zero, style: .plain)
        table.separatorStyle = .none
        table.rowHeight = Self.conversationRowHeight
        table.dataSource = self
        table.delegate = self
        table.register(ForwardConversationCell.self, forCellReuseIdentifier: ForwardConversationCell.reuseIdentifier)
        return table
    }()

    private lazy var bottomBar = ForwardBottomBar()

    init(onConfirm: @escaping ([String]) -> Void) {
        self.onConfirm = onConfirm
        super.init(nibName: nil, bundle: nil)
        modalPresentationStyle = .fullScreen
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        bindState()
        loadData()
    }

    // MARK: - Actions

    private func setupUI() {
        let colors = TUIChatKitTheme.colors
        view.backgroundColor = colors.bgColorOperate

        view.addSubview(topBar)
        view.addSubview(contactEntry)
        view.addSubview(sectionLabel)
        view.addSubview(tableView)
        view.addSubview(bottomBar)

        topBar.snp.makeConstraints { make in
            make.top.equalTo(view.safeAreaLayoutGuide)
            make.leading.trailing.equalToSuperview()
            make.height.equalTo(Self.topBarHeight)
        }

        contactEntry.snp.makeConstraints { make in
            make.top.equalTo(topBar.snp.bottom)
            make.leading.trailing.equalToSuperview()
            make.height.equalTo(Self.contactEntryHeight)
        }

        sectionLabel.snp.makeConstraints { make in
            make.top.equalTo(contactEntry.snp.bottom)
            make.leading.trailing.equalToSuperview()
        }

        bottomBar.snp.makeConstraints { make in
            make.leading.trailing.equalToSuperview()
            make.bottom.equalTo(view.safeAreaLayoutGuide)
        }

        tableView.snp.makeConstraints { make in
            make.top.equalTo(sectionLabel.snp.bottom)
            make.leading.trailing.equalToSuperview()
            make.bottom.equalTo(bottomBar.snp.top)
        }
        tableView.backgroundColor = colors.bgColorOperate

        bottomBar.onConfirm = { [weak self] in
            guard let self = self else { return }
            let ids = Array(self.selectedConversationIDs)
            guard !ids.isEmpty else { return }
            self.closePage {
                self.onConfirm(ids)
            }
        }
        refreshBottomBar()
    }

    private func bindState() {
        conversationStore.state
            .subscribe(StatePublisherSelector(keyPath: \ConversationListState.conversationList))
            .receive(on: DispatchQueue.main)
            .sink { [weak self] list in
                self?.conversations = list
                self?.tableView.reloadData()
            }
            .store(in: &cancellables)

        contactStore.state
            .subscribe(StatePublisherSelector(keyPath: \ContactState.friendList))
            .receive(on: DispatchQueue.main)
            .sink { [weak self] list in
                self?.friendList = list
            }
            .store(in: &cancellables)
    }

    private func loadData() {
        conversationStore.loadConversations(option: nil, completion: nil)
        contactStore.loadFriends(completion: nil)
    }

    private func toggleConversation(_ conversationID: String) {
        if selectedConversationIDs.contains(conversationID) {
            selectedConversationIDs.remove(conversationID)
        } else {
            selectedConversationIDs.insert(conversationID)
        }
        tableView.reloadData()
        refreshBottomBar()
    }

    private func refreshBottomBar() {
        let allSelected = collectAllSelectedItems()
        bottomBar.configure(items: allSelected)
    }

    private func collectAllSelectedItems() -> [ForwardBottomBarItem] {
        var items: [ForwardBottomBarItem] = []
        for id in selectedConversationIDs {
            if let conv = conversations.first(where: { $0.conversationID == id }) {
                items.append(ForwardBottomBarItem(
                    key: id,
                    avatarURL: conv.avatarURL ?? "",
                    fallbackName: conv.title ?? conv.conversationID
                ))
            } else {
                let userID = id.hasPrefix("c2c_") ? String(id.dropFirst(Self.c2cIDPrefixLength)) : id
                if let contact = friendList.first(where: { $0.userID == userID }) {
                    items.append(ForwardBottomBarItem(
                        key: id,
                        avatarURL: contact.avatarURL ?? "",
                        fallbackName: contact.nickname ?? contact.userID
                    ))
                } else {
                    items.append(ForwardBottomBarItem(key: id, avatarURL: "", fallbackName: userID))
                }
            }
        }
        return items
    }

    private func buildTopBar() -> UIView {
        let colors = TUIChatKitTheme.colors
        let bar = UIView()
        bar.backgroundColor = colors.bgColorOperate

        let cancelButton = UIButton(type: .system)
        cancelButton.setTitle(LocalizedChatString("Cancel"), for: .normal)
        cancelButton.setTitleColor(colors.textColorLink, for: .normal)
        cancelButton.titleLabel?.font = FontScheme.caption1Regular
        cancelButton.addTarget(self, action: #selector(handleCancelTapped), for: .touchUpInside)
        bar.addSubview(cancelButton)
        cancelButton.snp.makeConstraints { make in
            make.leading.equalToSuperview().offset(Self.contentHorizontalInset)
            make.centerY.equalToSuperview()
        }

        let titleLabel = UILabel()
        titleLabel.text = LocalizedChatString("Forward")
        titleLabel.font = FontScheme.caption1Bold
        titleLabel.textColor = colors.textColorPrimary
        titleLabel.textAlignment = .center
        bar.addSubview(titleLabel)
        titleLabel.snp.makeConstraints { make in
            make.center.equalToSuperview()
        }

        return bar
    }

    private func buildContactEntry() -> UIView {
        let colors = TUIChatKitTheme.colors
        let container = UIView()
        container.backgroundColor = colors.bgColorOperate
        let tapGesture = UITapGestureRecognizer(target: self, action: #selector(handleContactEntryTapped))
        container.addGestureRecognizer(tapGesture)

        let titleLabel = UILabel()
        titleLabel.text = LocalizedChatString("RelayTargetSelectFromContacts")
        titleLabel.font = FontScheme.caption1Regular
        titleLabel.textColor = colors.textColorPrimary
        container.addSubview(titleLabel)
        titleLabel.snp.makeConstraints { make in
            make.leading.equalToSuperview().offset(Self.contentHorizontalInset)
            make.centerY.equalToSuperview()
        }

        let arrowImage = UIImageView()
        arrowImage.image = UIImage(systemName: "chevron.right")?.withRenderingMode(.alwaysTemplate)
        arrowImage.tintColor = colors.textColorSecondary
        arrowImage.contentMode = .scaleAspectFit
        container.addSubview(arrowImage)
        arrowImage.snp.makeConstraints { make in
            make.trailing.equalToSuperview().offset(-Self.contentHorizontalInset)
            make.centerY.equalToSuperview()
            make.width.height.equalTo(Self.arrowIconSize)
        }

        return container
    }

    private func buildSectionLabel() -> UIView {
        let colors = TUIChatKitTheme.colors
        let label = UILabel()
        label.text = LocalizedChatString("RelayRecentMessages")
        label.font = FontScheme.caption3Regular
        label.textColor = colors.textColorSecondary
        label.backgroundColor = colors.bgColorInput
        let container = UIView()
        container.backgroundColor = colors.bgColorInput
        container.addSubview(label)
        label.snp.makeConstraints { make in
            make.leading.equalToSuperview().offset(Self.contentHorizontalInset)
            make.trailing.equalToSuperview().offset(-Self.contentHorizontalInset)
            make.top.equalToSuperview().offset(Self.sectionLabelVerticalInset)
            make.bottom.equalToSuperview().offset(-Self.sectionLabelVerticalInset)
        }
        return container
    }

    @objc private func handleCancelTapped() {
        closePage()
    }

    @objc private func handleContactEntryTapped() {
        guard !friendList.isEmpty else { return }
        let preSelected = collectPreSelectedUserIDs()
        let picker = ForwardContactPickerViewController(
            contacts: friendList,
            preSelectedUserIDs: preSelected
        ) { [weak self] returnedContacts in
            self?.applyContactPickerResult(returnedContacts, preSelected: preSelected)
        }
        navigationController?.pushViewController(picker, animated: true)
    }

    private func collectPreSelectedUserIDs() -> Set<String> {
        var ids = Set<String>()
        for id in selectedConversationIDs {
            if id.hasPrefix("c2c_") {
                ids.insert(String(id.dropFirst(Self.c2cIDPrefixLength)))
            }
        }
        return ids
    }

    private func applyContactPickerResult(_ returnedContacts: [ContactInfo], preSelected: Set<String>) {
        let returnedUserIDs = Set(returnedContacts.map { $0.userID })

        for userID in preSelected where !returnedUserIDs.contains(userID) {
            selectedConversationIDs.remove("c2c_\(userID)")
        }

        for contact in returnedContacts {
            let c2cID = "c2c_\(contact.userID)"
            if !selectedConversationIDs.contains(c2cID) {
                selectedConversationIDs.insert(c2cID)
            }
        }

        tableView.reloadData()
        refreshBottomBar()
    }
}

// MARK: - UITableViewDataSource & Delegate

extension ForwardTargetSelectorViewController: UITableViewDataSource, UITableViewDelegate {

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return conversations.count
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        guard let cell = tableView.dequeueReusableCell(
            withIdentifier: ForwardConversationCell.reuseIdentifier,
            for: indexPath
        ) as? ForwardConversationCell else {
            return UITableViewCell()
        }
        let conversation = conversations[indexPath.row]
        let isSelected = selectedConversationIDs.contains(conversation.conversationID)
        cell.configure(conversation: conversation, isSelected: isSelected)
        return cell
    }

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: false)
        guard indexPath.row < conversations.count else { return }
        toggleConversation(conversations[indexPath.row].conversationID)
    }

    func scrollViewDidScroll(_ scrollView: UIScrollView) {
        let distanceFromBottom = scrollView.contentSize.height - (scrollView.contentOffset.y + scrollView.bounds.height)
        if distanceFromBottom <= Self.loadMoreThreshold {
            conversationStore.loadMoreConversations(completion: nil)
        }
    }
}

// MARK: - LinkedHashSet

private struct LinkedHashSet<Element: Hashable> {
    var count: Int { array.count }

    var isEmpty: Bool { array.isEmpty }

    private var array: [Element] = []

    private var set: Set<Element> = []

    func contains(_ element: Element) -> Bool { set.contains(element) }

    mutating func insert(_ element: Element) {
        guard !set.contains(element) else { return }
        array.append(element)
        set.insert(element)
    }

    mutating func remove(_ element: Element) {
        guard set.contains(element) else { return }
        set.remove(element)
        array.removeAll { $0 == element }
    }
}

extension LinkedHashSet: Sequence {
    func makeIterator() -> IndexingIterator<[Element]> {
        return array.makeIterator()
    }
}
