import UIKit
import Combine
import SnapKit
import AtomicXCore

final class MessageReadReceiptViewController: UIViewController, SystemNavigationBarPage {
    fileprivate static let backIconPointSize: CGFloat = 18

    fileprivate static let contentHorizontalInset = CGFloat(SpacingScheme.contentSpacing)

    fileprivate static let dividerHeight: CGFloat = 0.5

    fileprivate static let contentTopInset = CGFloat(SpacingScheme.bubbleSpacing)

    fileprivate static let tabSpacing = CGFloat(SpacingScheme.iconIconSpacing)

    fileprivate static let tabVerticalPadding = CGFloat(SpacingScheme.smallSpacing)

    fileprivate static let tabHorizontalPadding = CGFloat(SpacingScheme.iconIconSpacing)

    fileprivate static let tabCornerRadius = CGFloat(RadiusScheme.superLargeRadius)

    fileprivate static let listTopSpacing = CGFloat(SpacingScheme.iconIconSpacing)

    fileprivate static let rowAvatarSize: CGFloat = 36

    fileprivate static let rowNameSpacing = CGFloat(SpacingScheme.iconIconSpacing)

    fileprivate static let rowHorizontalInset = CGFloat(SpacingScheme.iconTextSpacing)

    fileprivate static let rowVerticalInset = CGFloat(SpacingScheme.smallSpacing)

    fileprivate static let receiptMemberPageCount = 20

    fileprivate static let loadMoreThresholdRows = 5

    private let message: MessageInfo

    private let actionStore: MessageActionStore

    private let onUserClick: ((String) -> Void)?

    private var cancellables = Set<AnyCancellable>()

    private let dividerView = UIView()

    private let tabStack = UIStackView()

    private let readTabButton = UIButton(type: .system)

    private let unreadTabButton = UIButton(type: .system)

    private let tableView = UITableView()

    private var readMembers: [GroupMember] = []

    private var unreadMembers: [GroupMember] = []

    private var hasMoreReadMembers = false

    private var hasMoreUnreadMembers = false

    private var isLoadingMoreRead = false

    private var isLoadingMoreUnread = false

    private var selectedReadTab: Bool

    private var displayedMembers: [GroupMember] {
        selectedReadTab ? readMembers : unreadMembers
    }

    init(message: MessageInfo,
         actionStore: MessageActionStore,
         onUserClick: ((String) -> Void)? = nil) {
        self.message = message
        self.actionStore = actionStore
        self.onUserClick = onUserClick
        self.selectedReadTab = (message.readReceiptInfo?.readCount ?? 0) > 0
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        title = LocalizedChatString("MessageReadDetail")
        view.backgroundColor = ChatUIKitTheme.colors.bgColorOperate
        setupNavigationBar()
        setupTabRow()
        setupTableView()
        subscribeState()
        loadInitialData()
        refreshTabState()
    }

    private func setupNavigationBar() {
        let backIcon = AtomicXChatResources.image(named: "contact_info_back")?
            .withRenderingMode(.alwaysTemplate)
            ?? UIImage(systemName: "chevron.left")?
            .withConfiguration(UIImage.SymbolConfiguration(pointSize: Self.backIconPointSize, weight: .semibold))
        navigationItem.leftBarButtonItem = UIBarButtonItem(
            image: backIcon,
            style: .plain,
            target: self,
            action: #selector(handleClose)
        )
        navigationItem.leftBarButtonItem?.tintColor = ChatUIKitTheme.colors.textColorPrimary
    }

    private func setupTabRow() {
        tabStack.axis = .horizontal
        tabStack.distribution = .fillEqually
        tabStack.spacing = Self.tabSpacing
        view.addSubview(tabStack)
        tabStack.addArrangedSubview(readTabButton)
        tabStack.addArrangedSubview(unreadTabButton)
        for button in [readTabButton, unreadTabButton] {
            button.titleLabel?.font = FontScheme.caption2Regular
            button.layer.cornerRadius = Self.tabCornerRadius
            button.layer.masksToBounds = true
            button.contentEdgeInsets = UIEdgeInsets(
                top: Self.tabVerticalPadding,
                left: Self.tabHorizontalPadding,
                bottom: Self.tabVerticalPadding,
                right: Self.tabHorizontalPadding
            )
        }
        readTabButton.addTarget(self, action: #selector(handleReadTabTap), for: .touchUpInside)
        unreadTabButton.addTarget(self, action: #selector(handleUnreadTabTap), for: .touchUpInside)
        dividerView.backgroundColor = ChatUIKitTheme.colors.strokeColorSecondary
        view.addSubview(dividerView)
        dividerView.snp.makeConstraints { make in
            make.top.equalTo(view.safeAreaLayoutGuide)
            make.leading.trailing.equalToSuperview()
            make.height.equalTo(Self.dividerHeight)
        }
        tabStack.snp.makeConstraints { make in
            make.top.equalTo(dividerView.snp.bottom).offset(Self.contentTopInset)
            make.leading.equalToSuperview().offset(Self.contentHorizontalInset)
            make.trailing.equalToSuperview().offset(-Self.contentHorizontalInset)
        }
    }

    private func setupTableView() {
        tableView.backgroundColor = .clear
        tableView.separatorStyle = .none
        tableView.dataSource = self
        tableView.delegate = self
        tableView.register(ReceiptMemberCell.self, forCellReuseIdentifier: ReceiptMemberCell.reuseID)
        view.addSubview(tableView)
        tableView.snp.makeConstraints { make in
            make.top.equalTo(tabStack.snp.bottom).offset(Self.listTopSpacing)
            make.leading.trailing.bottom.equalToSuperview()
        }
    }

    private func subscribeState() {
        actionStore.state
            .subscribe(StatePublisherSelector(keyPath: \MessageActionState.readMemberList))
            .receive(on: DispatchQueue.main)
            .sink { [weak self] members in
                self?.readMembers = Self.distinctMembers(members)
                self?.refreshTabState()
            }
            .store(in: &cancellables)
        actionStore.state
            .subscribe(StatePublisherSelector(keyPath: \MessageActionState.unreadMemberList))
            .receive(on: DispatchQueue.main)
            .sink { [weak self] members in
                self?.unreadMembers = Self.distinctMembers(members)
                self?.refreshTabState()
            }
            .store(in: &cancellables)
        actionStore.state
            .subscribe(StatePublisherSelector(keyPath: \MessageActionState.hasMoreReadMembers))
            .receive(on: DispatchQueue.main)
            .sink { [weak self] value in self?.hasMoreReadMembers = value }
            .store(in: &cancellables)
        actionStore.state
            .subscribe(StatePublisherSelector(keyPath: \MessageActionState.hasMoreUnreadMembers))
            .receive(on: DispatchQueue.main)
            .sink { [weak self] value in self?.hasMoreUnreadMembers = value }
            .store(in: &cancellables)
    }

    private static func distinctMembers(_ members: [GroupMember]) -> [GroupMember] {
        var seen = Set<String>()
        return members.filter { member in
            guard !member.userID.isEmpty, !seen.contains(member.userID) else { return false }
            seen.insert(member.userID)
            return true
        }
    }

    private func loadInitialData() {
        actionStore.loadReadMembers(count: Self.receiptMemberPageCount) { _ in }
        actionStore.loadUnreadMembers(count: Self.receiptMemberPageCount) { _ in }
    }

    private func maybeLoadMore() {
        let members = displayedMembers
        guard !members.isEmpty else { return }
        let lastVisibleRow = tableView.indexPathsForVisibleRows?.map(\.row).max() ?? -1
        guard lastVisibleRow >= members.count - Self.loadMoreThresholdRows else { return }
        if selectedReadTab {
            guard hasMoreReadMembers, !isLoadingMoreRead else { return }
            isLoadingMoreRead = true
            actionStore.loadMoreMembers(isRead: true) { [weak self] _ in
                self?.isLoadingMoreRead = false
            }
        } else {
            guard hasMoreUnreadMembers, !isLoadingMoreUnread else { return }
            isLoadingMoreUnread = true
            actionStore.loadMoreMembers(isRead: false) { [weak self] _ in
                self?.isLoadingMoreUnread = false
            }
        }
    }

    private func refreshTabState() {
        let colors = ChatUIKitTheme.colors
        readTabButton.setTitle("\(LocalizedChatString("MessageReadC2CRead")) (\(readMembers.count))", for: .normal)
        unreadTabButton.setTitle("\(LocalizedChatString("MessageReadC2CUnRead")) (\(unreadMembers.count))", for: .normal)
        readTabButton.backgroundColor = selectedReadTab ? colors.bgColorAvatar : colors.bgColorDefault
        unreadTabButton.backgroundColor = selectedReadTab ? colors.bgColorDefault : colors.bgColorAvatar
        readTabButton.setTitleColor(selectedReadTab ? colors.textColorPrimary : colors.textColorSecondary, for: .normal)
        unreadTabButton.setTitleColor(selectedReadTab ? colors.textColorSecondary : colors.textColorPrimary, for: .normal)
        tableView.reloadData()
    }

    @objc private func handleReadTabTap() {
        guard !selectedReadTab else { return }
        selectedReadTab = true
        refreshTabState()
    }

    @objc private func handleUnreadTabTap() {
        guard selectedReadTab else { return }
        selectedReadTab = false
        refreshTabState()
    }

    @objc private func handleClose() {
        closePage()
    }
}

// MARK: - UITableViewDataSource & UITableViewDelegate

extension MessageReadReceiptViewController: UITableViewDataSource, UITableViewDelegate {
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return displayedMembers.count
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: ReceiptMemberCell.reuseID, for: indexPath) as! ReceiptMemberCell
        cell.configure(member: displayedMembers[indexPath.row])
        return cell
    }

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: false)
        onUserClick?(displayedMembers[indexPath.row].userID)
    }

    func scrollViewDidScroll(_ scrollView: UIScrollView) {
        maybeLoadMore()
    }
}

// MARK: - Member Cell

private final class ReceiptMemberCell: UITableViewCell {
    static let reuseID = "ReceiptMemberCell"

    private let avatarView = ChatAvatarView(size: .m, isRound: false)

    private let nameLabel = UILabel()

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        selectionStyle = .none
        backgroundColor = .clear
        contentView.addSubview(avatarView)
        contentView.addSubview(nameLabel)
        avatarView.snp.makeConstraints { make in
            make.leading.equalToSuperview().offset(MessageReadReceiptViewController.contentHorizontalInset + MessageReadReceiptViewController.rowHorizontalInset)
            make.top.equalToSuperview().offset(MessageReadReceiptViewController.rowVerticalInset)
            make.bottom.equalToSuperview().offset(-MessageReadReceiptViewController.rowVerticalInset)
            make.width.height.equalTo(MessageReadReceiptViewController.rowAvatarSize)
        }
        nameLabel.snp.makeConstraints { make in
            make.leading.equalTo(avatarView.snp.trailing).offset(MessageReadReceiptViewController.rowNameSpacing)
            make.centerY.equalTo(avatarView)
            make.trailing.lessThanOrEqualToSuperview().offset(-(MessageReadReceiptViewController.contentHorizontalInset + MessageReadReceiptViewController.rowHorizontalInset))
        }
        nameLabel.font = FontScheme.caption2Regular
        nameLabel.textColor = ChatUIKitTheme.colors.textColorPrimary
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func configure(member: GroupMember) {
        let name = MessageReadReceiptHelper.displayName(for: member)
        nameLabel.text = name
        avatarView.configure(avatarURL: member.avatarURL, fallbackName: name)
    }
}
