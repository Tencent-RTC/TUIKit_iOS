import AtomicXCore
import Combine
import SnapKit
import UIKit

final class GroupManagementViewController: ChatSettingBaseViewController {
    fileprivate static let horizontalPadding: CGFloat = CGFloat(SpacingScheme.bubbleSpacing)

    private static let sectionSpacerHeight: CGFloat = 10

    private static let adminTitleTopSpacing: CGFloat = CGFloat(SpacingScheme.bubbleSpacing)

    private static let adminTitleBottomSpacing: CGFloat = CGFloat(SpacingScheme.bubbleSpacing)

    private static let adminRowVerticalPadding: CGFloat = CGFloat(SpacingScheme.iconIconSpacing)

    private static let adminItemWidth: CGFloat = 40

    private static let adminItemSpacing: CGFloat = 20

    private static let adminAvatarSize = ChatAvatarSize.m

    private static let adminNameTopMargin: CGFloat = 3

    private static let adminActionSymbolFontSize: CGFloat = 22

    private static let adminTileCornerRadius: CGFloat = CGFloat(RadiusScheme.tipsRadius)

    private static let adminActionBottomSpacerHeight: CGFloat = 20

    private static let descriptionPadding: CGFloat = CGFloat(SpacingScheme.bubbleSpacing)

    private static let descriptionTopPadding = CGFloat(SpacingScheme.iconTextSpacing)

    private static let addRowSpacing: CGFloat = CGFloat(SpacingScheme.smallSpacing)

    private static let addRowVerticalPadding: CGFloat = CGFloat(SpacingScheme.bubbleSpacing)

    private static let mutedRowHeight: CGFloat = 56

    fileprivate static let mutedAvatarSize = ChatAvatarSize.m

    fileprivate static let mutedNameSpacing: CGFloat = 13

    private let groupID: String

    private let groupStore: GroupStore

    private let memberStore: GroupMemberStore

    private var mutedMembers: [GroupMember] = []

    private var adminMembers: [GroupMember] = []

    private var isAllMuted: Bool = false

    private var groupType: GroupType = .work

    private var currentUserRole: GroupMemberRole = .member

    private var cancellables = Set<AnyCancellable>()

    private let headerStack = UIStackView()

    private let adminSectionSpacer = UIView()

    private let adminSection = UIView()

    private let adminTitleLabel = UILabel()

    private let adminScrollView = UIScrollView()

    private let adminRowStack = UIStackView()

    private let muteSectionSpacer = UIView()

    private lazy var muteAllRow = ChatSettingToggleRowView(title: LocalizedChatString("AllMembersMuted"))

    private let descriptionContainer = UIView()

    private let descriptionLabel = UILabel()

    private let addMutedRow = UIControl()

    private let addMutedPlusLabel = UILabel()

    private let addMutedLabel = UILabel()

    private let tableView = UITableView(frame: .zero, style: .plain)

    private var canManageAdmins: Bool {
        return GroupPermissionManager.hasPermission(
            groupType: groupType,
            memberRole: currentUserRole,
            permission: .setGroupMemberRole
        )
    }

    init(groupID: String, groupStore: GroupStore, memberStore: GroupMemberStore) {
        self.groupID = groupID
        self.groupStore = groupStore
        self.memberStore = memberStore
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        setNavTitle(LocalizedChatString("GroupProfileManage"))
        constructViewHierarchy()
        activateConstraints()
        setupViewStyle()
        bindInteraction()
        subscribeStores()
        memberStore.loadMembers(roleList: [.all], completion: nil)
    }

    private func constructViewHierarchy() {
        view.addSubview(headerStack)
        headerStack.addArrangedSubview(adminSectionSpacer)
        headerStack.addArrangedSubview(adminSection)
        adminSection.addSubview(adminTitleLabel)
        adminSection.addSubview(adminScrollView)
        adminScrollView.addSubview(adminRowStack)
        headerStack.addArrangedSubview(muteSectionSpacer)
        headerStack.addArrangedSubview(muteAllRow)
        descriptionContainer.addSubview(descriptionLabel)
        headerStack.addArrangedSubview(descriptionContainer)
        headerStack.addArrangedSubview(addMutedRow)
        addMutedRow.addSubview(addMutedPlusLabel)
        addMutedRow.addSubview(addMutedLabel)
        view.addSubview(tableView)
    }

    private func activateConstraints() {
        headerStack.snp.makeConstraints { make in
            make.top.equalTo(contentTopItem)
            make.leading.trailing.equalToSuperview()
        }
        adminSectionSpacer.snp.makeConstraints { make in
            make.height.equalTo(Self.sectionSpacerHeight)
        }
        adminTitleLabel.snp.makeConstraints { make in
            make.top.equalToSuperview().offset(Self.adminTitleTopSpacing)
            make.leading.equalToSuperview().offset(Self.horizontalPadding)
            make.trailing.lessThanOrEqualToSuperview().offset(-Self.horizontalPadding)
        }
        adminScrollView.snp.makeConstraints { make in
            make.top.equalTo(adminTitleLabel.snp.bottom).offset(Self.adminTitleBottomSpacing)
            make.leading.trailing.equalToSuperview()
            make.bottom.equalToSuperview()
            make.height.equalTo(adminRowStack).offset(Self.adminRowVerticalPadding * 2)
        }
        adminRowStack.snp.makeConstraints { make in
            make.edges.equalToSuperview().inset(UIEdgeInsets(
                top: Self.adminRowVerticalPadding,
                left: Self.horizontalPadding,
                bottom: Self.adminRowVerticalPadding,
                right: Self.horizontalPadding
            ))
        }
        muteSectionSpacer.snp.makeConstraints { make in
            make.height.equalTo(Self.sectionSpacerHeight)
        }
        descriptionLabel.snp.makeConstraints { make in
            make.edges.equalToSuperview().inset(UIEdgeInsets(
                top: Self.descriptionTopPadding,
                left: Self.horizontalPadding,
                bottom: Self.descriptionPadding,
                right: Self.horizontalPadding
            ))
        }
        addMutedPlusLabel.snp.makeConstraints { make in
            make.leading.equalToSuperview().offset(Self.horizontalPadding)
            make.centerY.equalToSuperview()
        }
        addMutedLabel.snp.makeConstraints { make in
            make.leading.equalTo(addMutedPlusLabel.snp.trailing).offset(Self.addRowSpacing)
            make.centerY.equalToSuperview()
            make.top.equalToSuperview().offset(Self.addRowVerticalPadding)
            make.bottom.equalToSuperview().offset(-Self.addRowVerticalPadding)
            make.trailing.lessThanOrEqualToSuperview().offset(-Self.horizontalPadding)
        }
        tableView.snp.makeConstraints { make in
            make.top.equalTo(headerStack.snp.bottom)
            make.leading.trailing.bottom.equalToSuperview()
        }
    }

    private func setupViewStyle() {
        let colors = ChatUIKitTheme.colors
        view.backgroundColor = colors.bgColorTopBar
        headerStack.axis = .vertical
        headerStack.spacing = 0
        adminSectionSpacer.backgroundColor = colors.bgColorTopBar
        adminSection.backgroundColor = colors.bgColorOperate
        muteSectionSpacer.backgroundColor = colors.bgColorTopBar
        muteAllRow.backgroundColor = colors.bgColorOperate
        descriptionContainer.backgroundColor = colors.bgColorOperate
        addMutedRow.backgroundColor = colors.bgColorOperate

        adminTitleLabel.text = LocalizedChatString("GroupManageAdmins")
        adminTitleLabel.font = FontScheme.caption1Regular
        adminTitleLabel.textColor = colors.textColorSecondary

        adminScrollView.showsHorizontalScrollIndicator = false
        adminScrollView.alwaysBounceVertical = false
        adminRowStack.axis = .horizontal
        adminRowStack.alignment = .top
        adminRowStack.spacing = Self.adminItemSpacing

        descriptionLabel.text = LocalizedChatString("AllMembersMutedDescription")
        descriptionLabel.font = FontScheme.caption2Regular
        descriptionLabel.textColor = colors.textColorTertiary
        descriptionLabel.numberOfLines = 0

        addMutedPlusLabel.text = "+"
        addMutedPlusLabel.font = FontScheme.body3Regular
        addMutedPlusLabel.textColor = colors.textColorLink
        addMutedLabel.text = LocalizedChatString("GroupManageSelectMuted")
        addMutedLabel.font = FontScheme.caption3Regular
        addMutedLabel.textColor = colors.textColorLink

        tableView.backgroundColor = colors.bgColorOperate
        tableView.separatorStyle = .none
        tableView.rowHeight = Self.mutedRowHeight
        tableView.register(MutedMemberCell.self, forCellReuseIdentifier: MutedMemberCell.reuseIdentifier)
        tableView.dataSource = self
        tableView.delegate = self
    }

    private func bindInteraction() {
        muteAllRow.onToggle = { [weak self] value in
            guard let self = self else { return }
            self.groupStore.muteAllMembers(groupID: self.groupID, isMuted: value, completion: nil)
        }
        addMutedRow.addTarget(self, action: #selector(handleAddMutedTapped), for: .touchUpInside)
    }

    private func subscribeStores() {
        groupStore.state
            .subscribe(StatePublisherSelector(keyPath: \GroupState.joinedGroupList))
            .receive(on: DispatchQueue.main)
            .sink { [weak self] joinedGroupList in
                guard let self = self,
                      let info = joinedGroupList.first(where: { $0.groupID == self.groupID }) else { return }
                self.isAllMuted = info.isAllMuted ?? false
                self.groupType = info.groupType ?? .work
                self.currentUserRole = info.selfRole ?? .member
                self.muteAllRow.setOn(self.isAllMuted)
                self.updateMuteSectionVisibility()
                self.updateAdminSectionVisibility()
            }
            .store(in: &cancellables)
        memberStore.state
            .subscribe(StatePublisherSelector(keyPath: \GroupMemberState.memberList))
            .receive(on: DispatchQueue.main)
            .sink { [weak self] memberList in
                guard let self = self else { return }
                self.mutedMembers = memberList.filter { $0.isMuted }
                self.adminMembers = memberList.filter { $0.role == .admin }
                self.tableView.reloadData()
                self.renderAdminItems()
            }
            .store(in: &cancellables)
    }

    private func updateAdminSectionVisibility() {
        let visible = canManageAdmins
        adminSectionSpacer.isHidden = !visible
        adminSection.isHidden = !visible
        if visible {
            renderAdminItems()
        }
    }

    private func updateMuteSectionVisibility() {
        addMutedRow.isHidden = isAllMuted
        tableView.isHidden = isAllMuted
    }

    private func renderAdminItems() {
        guard canManageAdmins else { return }
        adminRowStack.arrangedSubviews.forEach { $0.removeFromSuperview() }
        for (index, member) in adminMembers.enumerated() {
            adminRowStack.addArrangedSubview(makeAdminMemberItem(member, index: index))
        }
        adminRowStack.addArrangedSubview(makeAdminActionItem(isAdd: true))
        if !adminMembers.isEmpty {
            adminRowStack.addArrangedSubview(makeAdminActionItem(isAdd: false))
        }
    }

    private func makeAdminMemberItem(_ member: GroupMember, index: Int) -> UIView {
        let container = UIStackView()
        container.axis = .vertical
        container.alignment = .center
        container.spacing = Self.adminNameTopMargin
        container.tag = index

        let displayName = chatSettingMemberDisplayName(member)
        let avatarView = ChatAvatarView(size: Self.adminAvatarSize, isRound: false)
        avatarView.configure(avatarURL: member.avatarURL, fallbackName: displayName)
        avatarView.snp.makeConstraints { make in
            make.width.height.equalTo(Self.adminAvatarSize.size)
        }

        let nameLabel = UILabel()
        nameLabel.font = FontScheme.caption3Regular
        nameLabel.textColor = ChatUIKitTheme.colors.textColorPrimary
        nameLabel.textAlignment = .center
        nameLabel.lineBreakMode = .byTruncatingTail
        nameLabel.text = displayName

        container.addArrangedSubview(avatarView)
        container.addArrangedSubview(nameLabel)
        container.snp.makeConstraints { make in
            make.width.equalTo(Self.adminItemWidth)
        }
        container.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(handleAdminItemTapped(_:))))
        return container
    }

    private func makeAdminActionItem(isAdd: Bool) -> UIView {
        let container = UIStackView()
        container.axis = .vertical
        container.alignment = .center

        let tile = UIControl()
        tile.backgroundColor = ChatUIKitTheme.colors.bgColorInput
        tile.layer.cornerRadius = Self.adminTileCornerRadius
        tile.snp.makeConstraints { make in
            make.width.height.equalTo(Self.adminAvatarSize.size)
        }

        let symbolLabel = UILabel()
        symbolLabel.text = isAdd ? "+" : "−"
        symbolLabel.font = .systemFont(ofSize: Self.adminActionSymbolFontSize)
        symbolLabel.textColor = ChatUIKitTheme.colors.textColorSecondary
        symbolLabel.textAlignment = .center
        tile.addSubview(symbolLabel)
        symbolLabel.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }

        tile.addTarget(
            self,
            action: isAdd ? #selector(handleAddAdminTapped) : #selector(handleRemoveAdminTapped),
            for: .touchUpInside
        )

        let bottomSpacer = UIView()
        bottomSpacer.snp.makeConstraints { make in
            make.height.equalTo(Self.adminActionBottomSpacerHeight)
        }

        container.addArrangedSubview(tile)
        container.addArrangedSubview(bottomSpacer)
        container.snp.makeConstraints { make in
            make.width.equalTo(Self.adminItemWidth)
        }
        return container
    }

    @objc private func handleAdminItemTapped(_ gesture: UITapGestureRecognizer) {
        guard let index = gesture.view?.tag, index >= 0, index < adminMembers.count else { return }
        let member = adminMembers[index]
        presentActionSheet(
            actionTitle: LocalizedChatString("GroupManageRemoveAdmin"),
            anchorView: gesture.view
        ) { [weak self] in
            self?.memberStore.setMemberRole(userID: member.userID, role: .member, completion: nil)
        }
    }

    @objc private func handleAddAdminTapped() {
        pushOrPresent(GroupMemberPickerViewController(mode: .setAdmin(memberStore: memberStore)))
    }

    @objc private func handleRemoveAdminTapped() {
        pushOrPresent(GroupMemberPickerViewController(mode: .removeAdmin(memberStore: memberStore)))
    }

    @objc private func handleAddMutedTapped() {
        pushOrPresent(GroupMemberPickerViewController(mode: .muteMembers(memberStore: memberStore)))
    }

    private func presentUnmuteActionSheet(for member: GroupMember, anchorView: UIView?) {
        presentActionSheet(
            actionTitle: LocalizedChatString("GroupManageCancelMute"),
            anchorView: anchorView
        ) { [weak self] in
            self?.memberStore.muteMember(userID: member.userID, time: 0, completion: nil)
        }
    }

    private func presentActionSheet(actionTitle: String, anchorView: UIView?, action: @escaping () -> Void) {
        let alert = UIAlertController(title: nil, message: nil, preferredStyle: .actionSheet)
        alert.addAction(UIAlertAction(title: actionTitle, style: .default) { _ in action() })
        alert.addAction(UIAlertAction(title: LocalizedChatString("Cancel"), style: .cancel))
        if let popover = alert.popoverPresentationController {
            popover.sourceView = anchorView ?? view
            popover.sourceRect = anchorView?.bounds ?? view.bounds
        }
        present(alert, animated: true)
    }
}

extension GroupManagementViewController: UITableViewDataSource, UITableViewDelegate {

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return mutedMembers.count
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        guard let cell = tableView.dequeueReusableCell(
            withIdentifier: MutedMemberCell.reuseIdentifier,
            for: indexPath
        ) as? MutedMemberCell else {
            return UITableViewCell()
        }
        let member = mutedMembers[indexPath.row]
        cell.configure(member: member)
        cell.onLongPress = { [weak self] in
            self?.presentUnmuteActionSheet(for: member, anchorView: cell)
        }
        return cell
    }
}

private final class MutedMemberCell: UITableViewCell {
    static let reuseIdentifier = "MutedMemberCell"

    var onLongPress: (() -> Void)?

    private let avatarView = ChatAvatarView(
        size: GroupManagementViewController.mutedAvatarSize,
        isRound: false
    )

    private let nameLabel = UILabel()

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        selectionStyle = .none
        contentView.addSubview(avatarView)
        contentView.addSubview(nameLabel)
        avatarView.snp.makeConstraints { make in
            make.leading.equalToSuperview().offset(GroupManagementViewController.horizontalPadding)
            make.centerY.equalToSuperview()
            make.width.height.equalTo(GroupManagementViewController.mutedAvatarSize.size)
        }
        nameLabel.snp.makeConstraints { make in
            make.leading.equalTo(avatarView.snp.trailing).offset(GroupManagementViewController.mutedNameSpacing)
            make.centerY.equalToSuperview()
            make.trailing.lessThanOrEqualToSuperview().offset(-GroupManagementViewController.horizontalPadding)
        }
        let colors = ChatUIKitTheme.colors
        backgroundColor = colors.bgColorOperate
        contentView.backgroundColor = colors.bgColorOperate
        nameLabel.font = FontScheme.caption2Regular
        nameLabel.textColor = colors.textColorPrimary
        nameLabel.lineBreakMode = .byTruncatingTail
        let longPress = UILongPressGestureRecognizer(target: self, action: #selector(handleLongPress(_:)))
        contentView.addGestureRecognizer(longPress)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func configure(member: GroupMember) {
        let displayName = chatSettingMemberDisplayName(member)
        nameLabel.text = displayName
        avatarView.configure(avatarURL: member.avatarURL, fallbackName: displayName)
    }

    @objc private func handleLongPress(_ gesture: UILongPressGestureRecognizer) {
        guard gesture.state == .began else { return }
        onLongPress?()
    }
}
