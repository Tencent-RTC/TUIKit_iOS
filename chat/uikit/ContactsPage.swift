import AtomicXCore
import SnapKit
import UIKit

public final class ContactsPage: UIViewController {
    private static let headerVerticalPadding: CGFloat = CGFloat(SpacingScheme.iconIconSpacing)

    private static let horizontalPadding: CGFloat = CGFloat(SpacingScheme.bubbleSpacing)

    private static let addButtonSize: CGFloat = 24

    private static let titleFontSize: CGFloat = 17

    private let onContactClick: ((AZOrderedListItem) -> Void)?

    private let onGroupClick: ((AZOrderedListItem) -> Void)?

    private let headerView = UIView()

    private let titleLabel = UILabel()

    private let addButton = UIButton(type: .system)

    private lazy var contactListView = ContactListView(
        onContactClick: { [weak self] user in self?.onContactClick?(user) },
        onGroupClick: { [weak self] group in self?.onGroupClick?(group) }
    )

    // MARK: - Init

    public init(
        onContactClick: ((AZOrderedListItem) -> Void)? = nil,
        onGroupClick: ((AZOrderedListItem) -> Void)? = nil
    ) {
        self.onContactClick = onContactClick
        self.onGroupClick = onGroupClick
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    // MARK: - Lifecycle

    public override func viewDidLoad() {
        super.viewDidLoad()
        ChatUIKitLayoutDirection.install()
        constructViewHierarchy()
        activateConstraints()
        bindInteraction()
        setupViewStyle()
    }

    // MARK: - Actions

    private func constructViewHierarchy() {
        view.addSubview(headerView)
        headerView.addSubview(titleLabel)
        headerView.addSubview(addButton)
        view.addSubview(contactListView)
    }

    private func activateConstraints() {
        headerView.snp.makeConstraints { make in
            make.top.equalTo(view.safeAreaLayoutGuide)
            make.leading.trailing.equalToSuperview()
        }
        titleLabel.snp.makeConstraints { make in
            make.centerX.equalToSuperview()
            make.leading.greaterThanOrEqualToSuperview().offset(Self.horizontalPadding + Self.addButtonSize)
            make.trailing.lessThanOrEqualTo(addButton.snp.leading).offset(-Self.horizontalPadding)
            make.top.equalToSuperview().offset(Self.headerVerticalPadding)
            make.bottom.equalToSuperview().offset(-Self.headerVerticalPadding)
        }
        addButton.snp.makeConstraints { make in
            make.trailing.equalToSuperview().offset(-Self.horizontalPadding)
            make.centerY.equalTo(titleLabel)
            make.width.height.equalTo(Self.addButtonSize)
        }
        contactListView.snp.makeConstraints { make in
            make.top.equalTo(headerView.snp.bottom)
            make.leading.trailing.bottom.equalToSuperview()
        }
    }

    private func bindInteraction() {
        addButton.addTarget(self, action: #selector(handleAddTapped), for: .touchUpInside)
    }

    private func setupViewStyle() {
        let colors = ChatUIKitTheme.colors
        view.backgroundColor = colors.bgColorOperate
        headerView.backgroundColor = colors.bgColorOperate

        titleLabel.text = LocalizedChatString("ContactsPageTitle")
        titleLabel.font = .systemFont(ofSize: Self.titleFontSize, weight: .bold)
        titleLabel.textColor = colors.textColorPrimary
        titleLabel.textAlignment = .center

        addButton.setImage(AtomicXChatResources.image(named: "contact_add_circle"), for: .normal)
        addButton.tintColor = colors.textColorPrimary
    }

    @objc private func handleAddTapped() {
        let menu = BubbleMenuViewController(
            anchorView: addButton,
            items: [
                BubbleMenuViewController.Item(
                    icon: AtomicXChatResources.image(named: "contact_add_friend"),
                    title: LocalizedChatString("ContactsAddFriends"),
                    action: { [weak self] in self?.presentAddFriend() }
                ),
                BubbleMenuViewController.Item(
                    icon: AtomicXChatResources.image(named: "contact_add_group"),
                    title: LocalizedChatString("ContactsJoinGroup"),
                    action: { [weak self] in self?.presentJoinGroup() }
                ),
            ]
        )
        present(menu, animated: false)
    }

    private func presentAddFriend() {
        let addFriend = AddFriendViewController()
        addFriend.hidesBottomBarWhenPushed = true
        navigationController?.pushViewController(addFriend, animated: true)
    }

    private func presentJoinGroup() {
        let joinGroup = JoinGroupViewController()
        joinGroup.onEnterGroupChat = { [weak self] group in
            let item = AZOrderedListItem(
                userID: group.groupID,
                avatarURL: group.avatarURL,
                title: ContactDisplayFormatter.name(for: group)
            )
            self?.onGroupClick?(item)
        }
        joinGroup.hidesBottomBarWhenPushed = true
        navigationController?.pushViewController(joinGroup, animated: true)
    }
}
