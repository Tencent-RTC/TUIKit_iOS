import AtomicXCore
import SnapKit
import UIKit

public struct NavigationInfo {
    public let conversation: ConversationInfo
    public let locateMessage: MessageInfo?

    public init(conversation: ConversationInfo, locateMessage: MessageInfo? = nil) {
        self.conversation = conversation
        self.locateMessage = locateMessage
    }
}

public final class ConversationsPage: UIViewController {
    private static let headerVerticalPadding: CGFloat = CGFloat(SpacingScheme.iconIconSpacing)

    private static let horizontalPadding: CGFloat = CGFloat(SpacingScheme.bubbleSpacing)

    private static let addButtonSize: CGFloat = 24

    private static let searchBarHeight: CGFloat = 36

    private static let searchBarVerticalPadding: CGFloat = CGFloat(SpacingScheme.smallSpacing)

    private static let titleFontSize: CGFloat = 17

    private let onConversationClick: ((NavigationInfo) -> Void)?

    private let config: ConversationActionConfigProtocol

    private let headerView = UIView()

    private let titleLabel = UILabel()

    private let addButton = UIButton(type: .system)

    private lazy var searchEntryBar = SearchEntryBarView(onTapItem: { [weak self] result in
        self?.handleSearchResult(result)
    })

    private lazy var conversationListView = ConversationListView(
        onConversationClick: { [weak self] conversation in
            self?.onConversationClick?(NavigationInfo(conversation: conversation))
        },
        config: config
    )

    // MARK: - Init

    public init(
        config: ConversationActionConfigProtocol = ChatConversationActionConfig(),
        onConversationClick: ((NavigationInfo) -> Void)? = nil
    ) {
        self.config = config
        self.onConversationClick = onConversationClick
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    // MARK: - Lifecycle

    public override func viewDidLoad() {
        super.viewDidLoad()
        TUIChatKitLayoutDirection.install()
        constructViewHierarchy()
        activateConstraints()
        bindInteraction()
        setupViewStyle()
        ContactStore.shared.loadFriends(completion: nil)
    }

    // MARK: - Search Result Handling

    private func constructViewHierarchy() {
        view.addSubview(headerView)
        headerView.addSubview(titleLabel)
        headerView.addSubview(addButton)
        view.addSubview(searchEntryBar)
        view.addSubview(conversationListView)
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
        searchEntryBar.snp.makeConstraints { make in
            make.top.equalTo(headerView.snp.bottom).offset(Self.searchBarVerticalPadding)
            make.leading.trailing.equalToSuperview()
            make.height.equalTo(Self.searchBarHeight)
        }
        conversationListView.snp.makeConstraints { make in
            make.top.equalTo(searchEntryBar.snp.bottom).offset(Self.searchBarVerticalPadding)
            make.leading.trailing.bottom.equalToSuperview()
        }
    }

    private func bindInteraction() {
        addButton.addTarget(self, action: #selector(handleAddTapped), for: .touchUpInside)
    }

    private func setupViewStyle() {
        let colors = TUIChatKitTheme.colors
        view.backgroundColor = colors.bgColorOperate

        titleLabel.text = LocalizedChatString("TabChats")
        titleLabel.font = .systemFont(ofSize: Self.titleFontSize, weight: .bold)
        titleLabel.textColor = colors.textColorPrimary
        titleLabel.textAlignment = .center

        addButton.setImage(AtomicXChatResources.image(named: "contact_add_circle"), for: .normal)
        addButton.tintColor = colors.textColorPrimary
        addButton.isHidden = !AppBuilderConfig.shared.enableCreateConversation
    }

    @objc private func handleAddTapped() {
        let menu = BubbleMenuViewController(
            anchorView: addButton,
            items: [
                BubbleMenuViewController.Item(
                    icon: AtomicXChatResources.image(named: "contact_add_friend"),
                    title: LocalizedChatString("ChatsNewChatText"),
                    action: { [weak self] in self?.presentStartConversation() }
                ),
                BubbleMenuViewController.Item(
                    icon: AtomicXChatResources.image(named: "contact_add_group"),
                    title: LocalizedChatString("ChatsNewGroupText"),
                    action: { [weak self] in self?.presentUserPicker() }
                ),
            ]
        )
        present(menu, animated: false)
    }

    private func presentStartConversation() {
        let picker = CreateC2CConversationViewController(onUserSelected: { [weak self] user in
            guard let self = self else { return }
            let conversation = self.makeConversation(fromUser: user)
            self.openChatRemovingIntermediatePages(NavigationInfo(conversation: conversation))
        })
        picker.hidesBottomBarWhenPushed = true
        navigationController?.pushViewController(picker, animated: true)
    }

    private func presentUserPicker() {
        let picker = CreateGroupConversationViewController(onComplete: { [weak self] createdGroupID, groupName, conversationId in
            guard let self = self,
                  let groupID = createdGroupID,
                  let name = groupName,
                  let convId = conversationId else { return }
            let conversation = self.makeConversation(groupID: groupID, groupName: name, conversationId: convId)
            self.openChatRemovingIntermediatePages(NavigationInfo(conversation: conversation))
        })
        picker.hidesBottomBarWhenPushed = true
        navigationController?.pushViewController(picker, animated: true)
    }

    private func openChatRemovingIntermediatePages(_ info: NavigationInfo) {
        onConversationClick?(info)
        guard let navigationController = navigationController else { return }
        let stack = navigationController.viewControllers.filter {
            !($0 is CreateC2CConversationViewController)
                && !($0 is CreateGroupConversationViewController)
        }
        if stack.count != navigationController.viewControllers.count {
            navigationController.setViewControllers(stack, animated: false)
        }
    }

    private func makeConversation(fromUser user: AZOrderedListItem) -> ConversationInfo {
        var conversation = ConversationInfo(conversationID: ChatUtil.getC2CConversationID(user.userID))
        conversation.type = .c2c
        conversation.title = user.title ?? user.userID
        conversation.avatarURL = user.avatarURL
        return conversation
    }

    private func makeConversation(groupID: String, groupName: String, conversationId: String) -> ConversationInfo {
        var conversation = ConversationInfo(conversationID: conversationId)
        conversation.type = .group
        conversation.title = groupName
        conversation.avatarURL = nil
        return conversation
    }

    private func handleSearchResult(_ result: Any) {
        if let friendInfo = result as? FriendSearchInfo {
            navigateToFriend(friendInfo)
        } else if let groupInfo = result as? GroupSearchInfo {
            navigateToGroup(groupInfo)
        } else if let dict = result as? [String: Any] {
            navigateFromDictionary(dict)
        }
    }

    private func navigateToFriend(_ friendInfo: FriendSearchInfo) {
        let conversationID = ChatUtil.getC2CConversationID(friendInfo.userID)
        var conversation = ConversationInfo(conversationID: conversationID)
        conversation.type = .c2c
        conversation.title = friendInfo.friendRemark ?? friendInfo.userInfo?.nickname ?? friendInfo.userID
        conversation.avatarURL = friendInfo.userInfo?.avatarURL
        onConversationClick?(NavigationInfo(conversation: conversation))
    }

    private func navigateToGroup(_ groupInfo: GroupSearchInfo) {
        let conversationID = ChatUtil.getGroupConversationID(groupInfo.groupID)
        var conversation = ConversationInfo(conversationID: conversationID)
        conversation.type = .group
        conversation.title = groupInfo.groupName
        conversation.avatarURL = groupInfo.groupAvatarURL
        onConversationClick?(NavigationInfo(conversation: conversation))
    }

    private func navigateFromDictionary(_ dict: [String: Any]) {
        guard let conversationID = dict["conversationID"] as? String else { return }
        var conversation = ConversationInfo(conversationID: conversationID)
        conversation.type = conversationID.hasPrefix("c2c_") ? .c2c : .group
        conversation.title = dict["conversationName"] as? String
        conversation.avatarURL = dict["conversationAvatar"] as? String
        if let messageInfo = dict["message"] as? MessageInfo {
            onConversationClick?(NavigationInfo(conversation: conversation, locateMessage: messageInfo))
        } else {
            onConversationClick?(NavigationInfo(conversation: conversation))
        }
    }
}
