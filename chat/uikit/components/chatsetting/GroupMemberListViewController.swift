import AtomicXCore
import Combine
import SnapKit
import UIKit

final class GroupMemberListViewController: ChatSettingBaseViewController {
    fileprivate static let rowHeight: CGFloat = 60

    fileprivate static let horizontalPadding: CGFloat = CGFloat(SpacingScheme.bubbleSpacing)

    fileprivate static let avatarSize = ChatAvatarSize.m

    fileprivate static let avatarNameSpacing: CGFloat = CGFloat(SpacingScheme.iconIconSpacing)

    fileprivate static let roleTagLeadingSpacing: CGFloat = CGFloat(SpacingScheme.smallSpacing)

    fileprivate static let roleTagHorizontalPadding: CGFloat = CGFloat(SpacingScheme.smallSpacing)

    fileprivate static let roleTagVerticalPadding: CGFloat = 2

    fileprivate static let roleTagCornerRadius: CGFloat = 3

    private let groupStore: GroupStore

    private let memberStore: GroupMemberStore

    private let onGroupMemberClick: ((String) -> Void)?

    private var allMembers: [GroupMember] = []

    private var currentUserRole: GroupMemberRole = .member

    private var currentUserID: String = ""

    private var cancellables = Set<AnyCancellable>()

    private let tableView = UITableView(frame: .zero, style: .plain)

    init(
        groupStore: GroupStore,
        memberStore: GroupMemberStore,
        onGroupMemberClick: ((String) -> Void)? = nil
    ) {
        self.groupStore = groupStore
        self.memberStore = memberStore
        self.onGroupMemberClick = onGroupMemberClick
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        setNavTitle(String(format: LocalizedChatString("GroupMemberCountFormat"), 0))
        view.addSubview(tableView)
        tableView.snp.makeConstraints { make in
            make.top.equalTo(contentTopItem)
            make.leading.trailing.bottom.equalToSuperview()
        }
        tableView.backgroundColor = TUIChatKitTheme.colors.bgColorOperate
        tableView.separatorStyle = .none
        tableView.rowHeight = Self.rowHeight
        tableView.register(GroupMemberListCell.self, forCellReuseIdentifier: GroupMemberListCell.reuseIdentifier)
        tableView.dataSource = self
        tableView.delegate = self
        currentUserID = LoginStore.shared.state.value.loginUserInfo?.userID ?? ""
        subscribeStores()
        memberStore.loadMembers(roleList: [.all], completion: nil)
        ContactStore.shared.loadFriends(completion: nil)
    }

    // MARK: - Permission（对齐 Android GroupMemberActionPolicy）

    private func subscribeStores() {
        memberStore.state
            .subscribe(StatePublisherSelector(keyPath: \GroupMemberState.memberList))
            .receive(on: DispatchQueue.main)
            .sink { [weak self] memberList in
                guard let self = self else { return }
                self.allMembers = memberList
                if let selfMember = memberList.first(where: { $0.userID == self.currentUserID }) {
                    self.currentUserRole = selfMember.role
                }
                self.setNavTitle(String(format: LocalizedChatString("GroupMemberCountFormat"), memberList.count))
                self.tableView.reloadData()
            }
            .store(in: &cancellables)
        groupStore.state
            .subscribe(StatePublisherSelector(keyPath: \GroupState.joinedGroupList))
            .receive(on: DispatchQueue.main)
            .sink { [weak self] joinedGroupList in
                guard let self = self else { return }
                if let info = joinedGroupList.first(where: { $0.groupID == self.memberStore.groupID }) {
                    self.currentUserRole = info.selfRole ?? self.currentUserRole
                    self.tableView.reloadData()
                }
            }
            .store(in: &cancellables)
    }

    private func hasActionPermission(for member: GroupMember) -> Bool {
        switch currentUserRole {
        case .owner:
            return member.role != .owner
        case .admin:
            return member.role == .member
        default:
            return false
        }
    }

    private func canSetAdmin(for member: GroupMember) -> Bool {
        return currentUserRole == .owner && member.role == .member
    }

    private func canRemoveAdmin(for member: GroupMember) -> Bool {
        return currentUserRole == .owner && member.role == .admin
    }

    private func canRemoveMember(_ member: GroupMember) -> Bool {
        switch currentUserRole {
        case .owner:
            return member.role != .owner
        case .admin:
            return member.role == .member
        default:
            return false
        }
    }

    private func handleMemberTap(_ member: GroupMember) {
        if member.userID == currentUserID {
            return
        }
        if hasActionPermission(for: member) {
            presentMemberActionSheet(member)
        } else {
            openMemberDetail(member)
        }
    }

    private func openMemberDetail(_ member: GroupMember) {
        if let onGroupMemberClick = onGroupMemberClick {
            onGroupMemberClick(member.userID)
        } else {
            UserProfileRouter.open(userID: member.userID, from: self)
        }
    }

    private func presentMemberActionSheet(_ member: GroupMember) {
        let alert = UIAlertController(
            title: nil,
            message: nil,
            preferredStyle: .actionSheet
        )
        alert.addAction(UIAlertAction(title: LocalizedChatString("GroupMemberDetail"), style: .default) { [weak self] _ in
            self?.openMemberDetail(member)
        })
        if canRemoveMember(member) {
            alert.addAction(UIAlertAction(title: LocalizedChatString("RemoveMember"), style: .default) { [weak self] _ in
                self?.memberStore.deleteMember(userIDList: [member.userID], completion: nil)
            })
        }
        if canSetAdmin(for: member) {
            alert.addAction(UIAlertAction(title: LocalizedChatString("SetAsAdmin"), style: .default) { [weak self] _ in
                self?.memberStore.setMemberRole(userID: member.userID, role: .admin, completion: nil)
            })
        }
        if canRemoveAdmin(for: member) {
            alert.addAction(UIAlertAction(title: LocalizedChatString("CancelAdmin"), style: .default) { [weak self] _ in
                self?.memberStore.setMemberRole(userID: member.userID, role: .member, completion: nil)
            })
        }
        alert.addAction(UIAlertAction(title: LocalizedChatString("Cancel"), style: .cancel))
        present(alert, animated: true)
    }
}

extension GroupMemberListViewController: UITableViewDataSource, UITableViewDelegate {

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return allMembers.count
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        guard let cell = tableView.dequeueReusableCell(
            withIdentifier: GroupMemberListCell.reuseIdentifier,
            for: indexPath
        ) as? GroupMemberListCell else {
            return UITableViewCell()
        }
        cell.configure(member: allMembers[indexPath.row])
        return cell
    }

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: false)
        handleMemberTap(allMembers[indexPath.row])
    }
}

// MARK: - Cell

private final class GroupMemberListCell: UITableViewCell {
    static let reuseIdentifier = "GroupMemberListCell"

    private let avatarView: ChatAvatarView = {
        let size = GroupMemberListViewController.avatarSize
        let radius: CGFloat
        switch AppBuilderConfig.shared.avatarShape {
        case .circular:
            radius = size.size / 2
        case .rounded:
            radius = size.roundedRectCornerRadius
        case .square:
            radius = 0
        }
        return ChatAvatarView(cornerRadius: radius, fontSize: size.placeholderFontSize)
    }()

    private let nameLabel = UILabel()

    private let roleTagLabel = UILabel()

    private let roleTagContainer = UIView()

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        selectionStyle = .none
        constructViewHierarchy()
        activateConstraints()
        setupViewStyle()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func configure(member: GroupMember) {
        let displayName = chatSettingMemberDisplayName(member)
        nameLabel.text = displayName
        avatarView.configure(avatarURL: member.avatarURL, fallbackName: displayName)
        switch member.role {
        case .owner:
            roleTagLabel.text = LocalizedChatString("GroupOwnerLabel")
            roleTagContainer.isHidden = false
        case .admin:
            roleTagLabel.text = LocalizedChatString("AdminLabel")
            roleTagContainer.isHidden = false
        default:
            roleTagContainer.isHidden = true
        }
    }

    private func constructViewHierarchy() {
        contentView.addSubview(avatarView)
        contentView.addSubview(nameLabel)
        roleTagContainer.addSubview(roleTagLabel)
        contentView.addSubview(roleTagContainer)
    }

    private func activateConstraints() {
        avatarView.snp.makeConstraints { make in
            make.leading.equalToSuperview().offset(GroupMemberListViewController.horizontalPadding)
            make.centerY.equalToSuperview()
            make.width.height.equalTo(GroupMemberListViewController.avatarSize.size)
        }
        nameLabel.snp.makeConstraints { make in
            make.leading.equalTo(avatarView.snp.trailing).offset(GroupMemberListViewController.avatarNameSpacing)
            make.centerY.equalToSuperview()
        }
        roleTagContainer.snp.makeConstraints { make in
            make.leading.equalTo(nameLabel.snp.trailing).offset(GroupMemberListViewController.roleTagLeadingSpacing)
            make.centerY.equalToSuperview()
            make.trailing.lessThanOrEqualToSuperview().offset(-GroupMemberListViewController.horizontalPadding)
        }
        roleTagLabel.snp.makeConstraints { make in
            make.edges.equalToSuperview().inset(UIEdgeInsets(
                top: GroupMemberListViewController.roleTagVerticalPadding,
                left: GroupMemberListViewController.roleTagHorizontalPadding,
                bottom: GroupMemberListViewController.roleTagVerticalPadding,
                right: GroupMemberListViewController.roleTagHorizontalPadding
            ))
        }
        nameLabel.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
    }

    private func setupViewStyle() {
        let colors = TUIChatKitTheme.colors
        backgroundColor = colors.bgColorOperate
        contentView.backgroundColor = colors.bgColorOperate
        nameLabel.font = FontScheme.body4Regular
        nameLabel.textColor = colors.textColorPrimary
        nameLabel.lineBreakMode = .byTruncatingTail
        roleTagLabel.font = FontScheme.caption4Regular
        roleTagLabel.textColor = colors.textColorLink
        roleTagContainer.backgroundColor = colors.buttonColorPrimaryDisabled
        roleTagContainer.layer.cornerRadius = GroupMemberListViewController.roleTagCornerRadius
        roleTagContainer.layer.masksToBounds = true
    }
}
