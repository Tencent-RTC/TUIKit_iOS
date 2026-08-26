import AtomicXCore
import Combine
import SnapKit
import UIKit

func chatSettingMemberDisplayName(_ member: GroupMember) -> String {
    if let nameCard = member.nameCard, !nameCard.isEmpty {
        return nameCard
    } else if let friendRemark = member.friendRemark, !friendRemark.isEmpty {
        return friendRemark
    } else if let nickname = member.nickname, !nickname.isEmpty {
        return nickname
    } else {
        return member.userID
    }
}

func chatSettingContactDisplayName(_ contact: ContactInfo) -> String {
    if let friendRemark = contact.friendRemark, !friendRemark.isEmpty {
        return friendRemark
    } else if let nickname = contact.nickname, !nickname.isEmpty {
        return nickname
    } else {
        return contact.userID
    }
}

public final class GroupChatSettingViewController: ChatSettingBaseViewController {
    private static let headerAvatarSize = ChatAvatarSize.l

    private static let headerSpacing: CGFloat = CGFloat(SpacingScheme.bubbleSpacing)

    private static let headerHorizontalPadding: CGFloat = CGFloat(SpacingScheme.bubbleSpacing)

    private static let headerVerticalPadding: CGFloat = CGFloat(SpacingScheme.iconIconSpacing)

    private static let headerIDFontSize: CGFloat = 13

    private static let headerIDTopSpacing: CGFloat = CGFloat(SpacingScheme.iconTextSpacing)

    private static let memberGridColumns = 5

    private static let memberGridMaxCount = 10

    private static let memberGridItemWidth: CGFloat = 40

    private static let memberGridAvatarSize = ChatAvatarSize.m

    private static let memberGridRowSpacing: CGFloat = CGFloat(SpacingScheme.iconIconSpacing)

    private static let memberGridHorizontalPadding: CGFloat = CGFloat(SpacingScheme.bubbleSpacing)

    private static let memberGridBottomPadding: CGFloat = CGFloat(SpacingScheme.iconIconSpacing)

    private static let memberGridNameTopSpacing: CGFloat = 3

    private static let memberSymbolFontSize: CGFloat = 22

    private static let memberSymbolCornerRadius: CGFloat = CGFloat(RadiusScheme.tipsRadius)

    private static let presetAvatarCount: Int = 24

    private static let avatarPickerColumnCount: Int = 4

    private static let noticeMaxInputLength: Int = 300

    private static let toastDuration: TimeInterval = 2

    private let groupID: String

    private let groupStore: GroupStore

    private let memberStore: GroupMemberStore

    private let conversationStore: ConversationListStore

    private let onSendMessageClick: (() -> Void)?

    private let onGroupDelete: (() -> Void)?

    private let onGroupMemberClick: ((String) -> Void)?

    private var groupName: String = ""

    private var avatar: String = ""

    private var notice: String = ""

    private var groupType: GroupType = .work

    private var memberCount: Int = 0

    private var currentUserRole: GroupMemberRole = .member

    private var selfNameCard: String?

    private var joinGroupApprovalType: GroupJoinOption = .forbid

    private var inviteToGroupApprovalType: GroupInviteOption = .forbid

    private var allMembers: [GroupMember] = []

    private var currentUserID: String = ""

    private var isNotDisturb: Bool = false

    private var isPinned: Bool = false

    private var chatBackgroundURI: String?

    private var cancellables = Set<AnyCancellable>()

    private let scrollView = UIScrollView()

    private let stackView = UIStackView()

    private let headerView = UIView()

    private let avatarButton = UIButton(type: .custom)

    private let headerAvatarView = ChatAvatarView(size: .l, isRound: false)

    private let nameLabel = UILabel()

    private let groupIDLabel = UILabel()

    private let headerTextStack = UIStackView()

    private let memberSection = UIStackView()

    private lazy var memberHeaderRow = ChatSettingRowView(
        title: LocalizedChatString("GroupMember"),
        accessory: .arrow
    )

    private let gridContainer = UIView()

    private let gridRow1 = UIStackView()

    private let gridRow2 = UIStackView()

    private let settingsSection = UIStackView()

    private lazy var noticeRow = ChatSettingRowView(title: LocalizedChatString("GroupNotice"), accessory: .none)

    private lazy var manageRow = ChatSettingRowView(title: LocalizedChatString("GroupProfileManage"), accessory: .arrow)

    private lazy var typeRow = ChatSettingRowView(title: LocalizedChatString("GroupProfileType"), accessory: .none)

    private lazy var joinRow = ChatSettingRowView(title: LocalizedChatString("GroupProfileJoinType"), accessory: .none)

    private lazy var inviteRow = ChatSettingRowView(title: LocalizedChatString("GroupProfileInviteType"), accessory: .none)

    private lazy var aliasRow = ChatSettingRowView(title: LocalizedChatString("GroupProfileAlias"), accessory: .none)

    private let switchSection = UIStackView()

    private lazy var doNotDisturbRow = ChatSettingToggleRowView(title: LocalizedChatString("ProfileMessageDoNotDisturb"))

    private lazy var pinRow = ChatSettingToggleRowView(title: LocalizedChatString("ProfileStickyonTop"))

    private lazy var backgroundRow = ChatSettingRowView(title: LocalizedChatString("ChatBackgroundSetting"), accessory: .arrow)

    private let actionSection = UIStackView()

    private let actionSpacer = makeChatSettingSectionSpacer()

    private var conversationID: String {
        return ChatUtil.getGroupConversationID(groupID)
    }

    private var headerDisplayName: String {
        return groupName.isEmpty ? groupID : groupName
    }

    private var showAddMemberButton: Bool {
        return canPerformAction(.addGroupMember) && inviteToGroupApprovalType != .forbid
    }

    private var showRemoveMemberButton: Bool {
        return canPerformAction(.removeGroupMember)
    }

    private var groupTypeDisplayName: String {
        switch groupType {
        case .work: return LocalizedChatString("CreatGroupType_Work")
        case .publicGroup: return LocalizedChatString("PublicGroup")
        case .meeting: return LocalizedChatString("MeetingGroup")
        case .community: return LocalizedChatString("Community")
        case .avChatRoom: return LocalizedChatString("LiveGroup")
        }
    }

    public init(
        groupID: String,
        onSendMessageClick: (() -> Void)? = nil,
        onGroupDelete: (() -> Void)? = nil,
        onGroupMemberClick: ((String) -> Void)? = nil
    ) {
        self.groupID = groupID
        self.groupStore = GroupStore.shared
        self.memberStore = GroupMemberStore.create(groupID: groupID)
        self.conversationStore = ConversationListStore.create()
        self.onSendMessageClick = onSendMessageClick
        self.onGroupDelete = onGroupDelete
        self.onGroupMemberClick = onGroupMemberClick
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    public override func viewDidLoad() {
        super.viewDidLoad()
        setNavTitle(LocalizedChatString("GroupChatInfoTitle"))
        constructViewHierarchy()
        activateConstraints()
        setupViewStyle()
        bindInteraction()
        subscribeStores()
        currentUserID = LoginStore.shared.state.value.loginUserInfo?.userID ?? ""
        chatBackgroundURI = ChatBackgroundStore.shared.imageURI(forConversationID: conversationID)
        fetchInitialInfo()
        ContactStore.shared.loadFriends(completion: nil)
        refreshUI()
    }

    // MARK: - Actions

    func openMemberDetail(userID: String) {
        if let onGroupMemberClick = onGroupMemberClick {
            onGroupMemberClick(userID)
        } else {
            UserProfileRouter.open(userID: userID, from: self)
        }
    }

    // MARK: - Helpers

    private func constructViewHierarchy() {
        view.addSubview(scrollView)
        scrollView.addSubview(stackView)

        headerView.addSubview(headerAvatarView)
        headerView.addSubview(avatarButton)
        headerTextStack.addArrangedSubview(nameLabel)
        headerTextStack.addArrangedSubview(groupIDLabel)
        headerView.addSubview(headerTextStack)

        gridContainer.addSubview(gridRow1)
        gridContainer.addSubview(gridRow2)
        memberSection.addArrangedSubview(memberHeaderRow)
        memberSection.addArrangedSubview(gridContainer)

        stackView.addArrangedSubview(headerView)
        stackView.addArrangedSubview(makeChatSettingSectionSpacer())
        stackView.addArrangedSubview(memberSection)
        stackView.addArrangedSubview(makeChatSettingSectionSpacer())
        stackView.addArrangedSubview(settingsSection)
        stackView.addArrangedSubview(makeChatSettingSectionSpacer())
        stackView.addArrangedSubview(aliasRow)
        stackView.addArrangedSubview(makeChatSettingSectionSpacer())
        stackView.addArrangedSubview(switchSection)
        stackView.addArrangedSubview(makeChatSettingSectionSpacer())
        stackView.addArrangedSubview(backgroundRow)
        stackView.addArrangedSubview(actionSpacer)
        stackView.addArrangedSubview(actionSection)
    }

    private func activateConstraints() {
        scrollView.snp.makeConstraints { make in
            make.top.equalTo(contentTopItem)
            make.leading.trailing.bottom.equalToSuperview()
        }
        stackView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
            make.width.equalToSuperview()
        }
        headerAvatarView.snp.makeConstraints { make in
            make.leading.equalToSuperview().offset(Self.headerHorizontalPadding)
            make.centerY.equalToSuperview()
            make.width.height.equalTo(Self.headerAvatarSize.size)
        }
        avatarButton.snp.makeConstraints { make in
            make.edges.equalTo(headerAvatarView)
        }
        headerTextStack.snp.makeConstraints { make in
            make.leading.equalTo(headerAvatarView.snp.trailing).offset(Self.headerSpacing)
            make.trailing.lessThanOrEqualToSuperview().offset(-Self.headerHorizontalPadding)
            make.centerY.equalToSuperview()
            make.top.greaterThanOrEqualToSuperview().offset(Self.headerVerticalPadding)
            make.bottom.lessThanOrEqualToSuperview().offset(-Self.headerVerticalPadding)
        }
        gridRow1.snp.makeConstraints { make in
            make.top.leading.trailing.equalToSuperview()
        }
        gridRow2.snp.makeConstraints { make in
            make.top.equalTo(gridRow1.snp.bottom).offset(Self.memberGridRowSpacing)
            make.leading.trailing.bottom.equalToSuperview()
        }
    }

    private func setupViewStyle() {
        let colors = ChatUIKitTheme.colors
        view.backgroundColor = colors.bgColorTopBar
        scrollView.backgroundColor = colors.bgColorTopBar
        stackView.axis = .vertical
        stackView.spacing = 0
        headerView.backgroundColor = colors.bgColorOperate
        headerTextStack.axis = .vertical
        headerTextStack.spacing = Self.headerIDTopSpacing
        headerTextStack.alignment = .leading
        nameLabel.font = FontScheme.body4Regular
        nameLabel.textColor = colors.textColorPrimary
        nameLabel.lineBreakMode = .byTruncatingTail
        nameLabel.isUserInteractionEnabled = true
        groupIDLabel.font = .systemFont(ofSize: Self.headerIDFontSize)
        groupIDLabel.textColor = colors.textColorTertiary
        groupIDLabel.lineBreakMode = .byTruncatingTail
        groupIDLabel.isUserInteractionEnabled = true
        memberSection.axis = .vertical
        memberSection.spacing = 0
        memberSection.backgroundColor = colors.bgColorOperate
        gridContainer.backgroundColor = colors.bgColorOperate
        gridContainer.layoutMargins = UIEdgeInsets(
            top: 0,
            left: Self.memberGridHorizontalPadding,
            bottom: Self.memberGridBottomPadding,
            right: Self.memberGridHorizontalPadding
        )
        for row in [gridRow1, gridRow2] {
            row.axis = .horizontal
            row.distribution = .fillEqually
            row.alignment = .top
            row.spacing = 0
        }
        settingsSection.axis = .vertical
        settingsSection.spacing = 0
        settingsSection.backgroundColor = colors.bgColorOperate
        switchSection.axis = .vertical
        switchSection.spacing = 0
        switchSection.backgroundColor = colors.bgColorOperate
        actionSection.axis = .vertical
        actionSection.spacing = 0
        actionSection.backgroundColor = colors.bgColorOperate
    }

    private func bindInteraction() {
        avatarButton.addTarget(self, action: #selector(handleAvatarTapped), for: .touchUpInside)
        nameLabel.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(handleNameTapped)))
        groupIDLabel.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(handleGroupIDTapped)))
        memberHeaderRow.addTarget(self, action: #selector(handleMemberListTapped), for: .touchUpInside)
        noticeRow.addTarget(self, action: #selector(handleNoticeTapped), for: .touchUpInside)
        manageRow.addTarget(self, action: #selector(handleManageTapped), for: .touchUpInside)
        joinRow.addTarget(self, action: #selector(handleJoinTapped), for: .touchUpInside)
        inviteRow.addTarget(self, action: #selector(handleInviteTapped), for: .touchUpInside)
        aliasRow.addTarget(self, action: #selector(handleAliasTapped), for: .touchUpInside)
        backgroundRow.addTarget(self, action: #selector(handleBackgroundTapped), for: .touchUpInside)
        doNotDisturbRow.onToggle = { [weak self] value in
            guard let self = self else { return }
            let opt: ReceiveMessageOption = value ? .notNotify : .receive
            self.conversationStore.setReceiveMessageOpt(conversationID: self.conversationID, opt: opt, completion: nil)
        }
        pinRow.onToggle = { [weak self] value in
            guard let self = self else { return }
            self.conversationStore.pinConversation(conversationID: self.conversationID, pin: value, completion: nil)
        }
    }

    private func subscribeStores() {
        groupStore.state
            .subscribe(StatePublisherSelector(keyPath: \GroupState.joinedGroupList))
            .receive(on: DispatchQueue.main)
            .sink { [weak self] joinedGroupList in
                guard let self = self else { return }
                if let groupInfo = joinedGroupList.first(where: { $0.groupID == self.groupID }) {
                    self.applyGroupInfo(groupInfo)
                }
            }
            .store(in: &cancellables)
        memberStore.state
            .subscribe(StatePublisherSelector(keyPath: \GroupMemberState.memberList))
            .receive(on: DispatchQueue.main)
            .sink { [weak self] memberList in
                self?.applyMemberList(memberList)
            }
            .store(in: &cancellables)
        conversationStore.state
            .subscribe(StatePublisherSelector(keyPath: \ConversationListState.conversationList))
            .receive(on: DispatchQueue.main)
            .sink { [weak self] conversationList in
                guard let self = self else { return }
                if let info = conversationList.first(where: { $0.conversationID == self.conversationID }) {
                    self.isNotDisturb = info.receiveOption != .receive
                    self.isPinned = info.isPinned
                    self.refreshUI()
                }
            }
            .store(in: &cancellables)
    }

    private func fetchInitialInfo() {
        groupStore.getGroupInfo(
            groupID: groupID,
            completion: GroupSettingGroupInfoHandler(
                onSuccess: { [weak self] groupInfo in
                    DispatchQueue.main.async {
                        self?.applyGroupInfo(groupInfo)
                    }
                },
                onFailure: { _, _ in }
            )
        )
        conversationStore.getConversationInfo(
            conversationID: conversationID,
            completion: GroupSettingConversationInfoHandler(
                onSuccess: { [weak self] info in
                    DispatchQueue.main.async {
                        guard let self = self else { return }
                        self.isNotDisturb = info.receiveOption != .receive
                        self.isPinned = info.isPinned
                        self.refreshUI()
                    }
                },
                onFailure: { _, _ in }
            )
        )
        memberStore.loadMembers(roleList: [.all], completion: nil)
        groupStore.loadJoinedGroups(completion: nil)
    }

    private func applyGroupInfo(_ groupInfo: GroupInfo) {
        groupName = groupInfo.groupName ?? ""
        avatar = groupInfo.avatarURL ?? ""
        notice = groupInfo.notification ?? ""
        groupType = groupInfo.groupType ?? .work
        memberCount = groupInfo.memberCount ?? 0
        currentUserRole = groupInfo.selfRole ?? currentUserRole
        joinGroupApprovalType = groupInfo.joinOption ?? .forbid
        inviteToGroupApprovalType = groupInfo.inviteOption ?? .forbid
        refreshUI()
    }

    private func applyMemberList(_ memberList: [GroupMember]) {
        allMembers = memberList
        memberCount = memberList.isEmpty ? memberCount : memberList.count
        if let selfMember = memberList.first(where: { $0.userID == currentUserID }) {
            selfNameCard = selfMember.nameCard
            currentUserRole = selfMember.role
        }
        refreshUI()
    }

    private func canPerformAction(_ permission: GroupPermission) -> Bool {
        return GroupPermissionManager.hasPermission(
            groupType: groupType,
            memberRole: currentUserRole,
            permission: permission
        )
    }

    private func refreshUI() {
        headerAvatarView.configure(avatarURL: avatar, fallbackName: headerDisplayName)
        nameLabel.text = headerDisplayName
        groupIDLabel.text = "\(LocalizedChatString("GroupID")): \(groupID)"
        memberHeaderRow.update(value: "\(memberCount)", accessory: .arrow)
        rebuildMemberGrid()
        rebuildSettingsSection()
        rebuildSwitchSection()
        rebuildActionSection()
        let aliasValue: String
        if let nameCard = selfNameCard, !nameCard.isEmpty {
            aliasValue = nameCard
        } else {
            aliasValue = LocalizedChatString("Unsetted")
        }
        aliasRow.update(
            value: aliasValue,
            accessory: canPerformAction(.setGroupRemark) ? .edit : .none
        )
        aliasRow.isEnabled = canPerformAction(.setGroupRemark)
        doNotDisturbRow.setOn(isNotDisturb)
        pinRow.setOn(isPinned)
        backgroundRow.update(
            value: chatBackgroundURI == nil
                ? LocalizedChatString("ChatBackgroundDefault")
                : LocalizedChatString("ChatBackgroundCustom"),
            accessory: .arrow
        )
    }

    private func rebuildMemberGrid() {
        gridRow1.arrangedSubviews.forEach { $0.removeFromSuperview() }
        gridRow2.arrangedSubviews.forEach { $0.removeFromSuperview() }

        let buttonCount = (showAddMemberButton ? 1 : 0) + (showRemoveMemberButton ? 1 : 0)
        let previewMembers = Array(allMembers.prefix(max(0, Self.memberGridMaxCount - buttonCount)))
        var items: [UIView] = previewMembers.map { makeMemberGridItem($0) }
        if showAddMemberButton {
            items.append(makeSymbolGridItem("+", action: #selector(handleAddMemberTapped)))
        }
        if showRemoveMemberButton {
            items.append(makeSymbolGridItem("−", action: #selector(handleRemoveMemberTapped)))
        }
        for (index, item) in items.enumerated() {
            let slot = UIView()
            slot.addSubview(item)
            item.snp.makeConstraints { make in
                make.top.centerX.equalToSuperview()
                make.bottom.lessThanOrEqualToSuperview()
                make.width.equalTo(Self.memberGridItemWidth)
            }
            if index < Self.memberGridColumns {
                gridRow1.addArrangedSubview(slot)
            } else {
                gridRow2.addArrangedSubview(slot)
            }
        }
        let firstRowCount = min(items.count, Self.memberGridColumns)
        for _ in 0 ..< (Self.memberGridColumns - firstRowCount) {
            gridRow1.addArrangedSubview(UIView())
        }
        let secondRowCount = max(0, items.count - Self.memberGridColumns)
        if secondRowCount > 0 {
            gridRow2.isHidden = false
            for _ in 0 ..< (Self.memberGridColumns - secondRowCount) {
                gridRow2.addArrangedSubview(UIView())
            }
        } else {
            gridRow2.isHidden = true
        }
    }

    private func gridDisplayName(for member: GroupMember) -> String {
        if let nameCard = member.nameCard, !nameCard.isEmpty { return nameCard }
        if let nickname = member.nickname, !nickname.isEmpty { return nickname }
        return member.userID
    }

    private func makeMemberGridItem(_ member: GroupMember) -> UIView {
        let container = UIControl()
        let avatarView = ChatAvatarView(size: Self.memberGridAvatarSize, isRound: false)
        avatarView.configure(avatarURL: member.avatarURL, fallbackName: gridDisplayName(for: member))
        avatarView.isUserInteractionEnabled = false
        let nameLabel = UILabel()
        nameLabel.text = gridDisplayName(for: member)
        nameLabel.font = FontScheme.caption3Regular
        nameLabel.textColor = ChatUIKitTheme.colors.textColorPrimary
        nameLabel.textAlignment = .center
        nameLabel.lineBreakMode = .byTruncatingTail
        container.addSubview(avatarView)
        container.addSubview(nameLabel)
        avatarView.snp.makeConstraints { make in
            make.top.centerX.equalToSuperview()
            make.width.height.equalTo(Self.memberGridAvatarSize.size)
        }
        nameLabel.snp.makeConstraints { make in
            make.top.equalTo(avatarView.snp.bottom).offset(Self.memberGridNameTopSpacing)
            make.leading.trailing.bottom.equalToSuperview()
        }
        container.tag = allMembers.firstIndex(where: { $0.userID == member.userID }) ?? 0
        container.addTarget(self, action: #selector(handleMemberItemTapped(_:)), for: .touchUpInside)
        return container
    }

    private func makeSymbolGridItem(_ symbol: String, action: Selector) -> UIView {
        let container = UIControl()
        let symbolBox = UILabel()
        symbolBox.text = symbol
        symbolBox.font = .systemFont(ofSize: Self.memberSymbolFontSize)
        symbolBox.textColor = ChatUIKitTheme.colors.textColorSecondary
        symbolBox.textAlignment = .center
        symbolBox.backgroundColor = ChatUIKitTheme.colors.bgColorInput
        symbolBox.layer.cornerRadius = Self.memberSymbolCornerRadius
        symbolBox.layer.masksToBounds = true
        symbolBox.isUserInteractionEnabled = false
        let placeholderLabel = UILabel()
        placeholderLabel.text = " "
        placeholderLabel.font = FontScheme.caption3Regular
        container.addSubview(symbolBox)
        container.addSubview(placeholderLabel)
        symbolBox.snp.makeConstraints { make in
            make.top.centerX.equalToSuperview()
            make.width.height.equalTo(Self.memberGridAvatarSize.size)
        }
        placeholderLabel.snp.makeConstraints { make in
            make.top.equalTo(symbolBox.snp.bottom).offset(Self.memberGridNameTopSpacing)
            make.leading.trailing.bottom.equalToSuperview()
        }
        container.addTarget(self, action: action, for: .touchUpInside)
        return container
    }

    private func rebuildSettingsSection() {
        settingsSection.arrangedSubviews.forEach { $0.removeFromSuperview() }
        let canEditNotice = canPerformAction(.setGroupNotice)
        let trimmedNotice = notice.trimmingCharacters(in: .whitespacesAndNewlines)
        noticeRow.update(
            value: trimmedNotice.isEmpty ? LocalizedChatString("GroupNoticeNull") : trimmedNotice,
            accessory: canEditNotice ? .edit : .none
        )
        noticeRow.isEnabled = canEditNotice
        settingsSection.addArrangedSubview(noticeRow)

        if canPerformAction(.setGroupManagement) {
            settingsSection.addArrangedSubview(makeChatSettingRowDivider())
            settingsSection.addArrangedSubview(manageRow)
        }

        settingsSection.addArrangedSubview(makeChatSettingRowDivider())
        typeRow.update(value: groupTypeDisplayName, accessory: .none)
        typeRow.isEnabled = false
        settingsSection.addArrangedSubview(typeRow)

        settingsSection.addArrangedSubview(makeChatSettingRowDivider())
        let canEditJoin = canPerformAction(.setJoinGroupApprovalType)
        joinRow.update(value: joinGroupDisplayName(joinGroupApprovalType), accessory: canEditJoin ? .arrow : .none)
        joinRow.isEnabled = canEditJoin
        settingsSection.addArrangedSubview(joinRow)

        settingsSection.addArrangedSubview(makeChatSettingRowDivider())
        let canEditInvite = canPerformAction(.setInviteToGroupApprovalType)
        inviteRow.update(value: inviteOptionDisplayName(inviteToGroupApprovalType), accessory: canEditInvite ? .arrow : .none)
        inviteRow.isEnabled = canEditInvite
        settingsSection.addArrangedSubview(inviteRow)
    }

    private func rebuildSwitchSection() {
        switchSection.arrangedSubviews.forEach { $0.removeFromSuperview() }
        let showDoNotDisturb = canPerformAction(.setDoNotDisturb)
        let showPin = canPerformAction(.pinGroup)
        if showDoNotDisturb {
            switchSection.addArrangedSubview(doNotDisturbRow)
        }
        if showDoNotDisturb && showPin {
            switchSection.addArrangedSubview(makeChatSettingRowDivider())
        }
        if showPin {
            switchSection.addArrangedSubview(pinRow)
        }
        switchSection.isHidden = !showDoNotDisturb && !showPin
    }

    private func rebuildActionSection() {
        actionSection.arrangedSubviews.forEach { $0.removeFromSuperview() }
        let colors = ChatUIKitTheme.colors
        var rows: [UIView] = []
        if canPerformAction(.transferOwner) {
            rows.append(makeActionRow(
                titleKey: "GroupTransferOwner",
                textColor: colors.textColorLink,
                action: #selector(handleTransferTapped)
            ))
        }
        if canPerformAction(.clearHistoryMessages) {
            rows.append(makeActionRow(
                titleKey: "ClearAllChatHistory",
                textColor: colors.textColorError,
                action: #selector(handleClearHistoryTapped)
            ))
        }
        if canPerformAction(.deleteAndQuit) {
            rows.append(makeActionRow(
                titleKey: "GroupProfileDeleteAndExit",
                textColor: colors.textColorError,
                action: #selector(handleQuitTapped)
            ))
        }
        if canPerformAction(.dismissGroup) {
            rows.append(makeActionRow(
                titleKey: "GroupProfileDissolve",
                textColor: colors.textColorError,
                action: #selector(handleDismissTapped)
            ))
        }
        for (index, row) in rows.enumerated() {
            if index > 0 {
                actionSection.addArrangedSubview(makeChatSettingRowDivider())
            }
            actionSection.addArrangedSubview(row)
        }
        actionSection.isHidden = rows.isEmpty
        actionSpacer.isHidden = rows.isEmpty
    }

    private func makeActionRow(titleKey: String, textColor: UIColor, action: Selector) -> ChatSettingActionRowView {
        let row = ChatSettingActionRowView(title: LocalizedChatString(titleKey), textColor: textColor)
        row.addTarget(self, action: action, for: .touchUpInside)
        return row
    }

    private func inviteOptionDisplayName(_ option: GroupInviteOption) -> String {
        switch option {
        case .forbid: return LocalizedChatString("GroupProfileInviteDisable")
        case .auth: return LocalizedChatString("GroupProfileAdminApprove")
        case .any: return LocalizedChatString("GroupProfileAutoApproval")
        }
    }

    private func joinGroupDisplayName(_ option: GroupJoinOption) -> String {
        switch option {
        case .forbid: return LocalizedChatString("GroupProfileJoinDisable")
        case .auth: return LocalizedChatString("GroupProfileAdminApprove")
        case .any: return LocalizedChatString("GroupProfileAutoApproval")
        }
    }

    @objc private func handleAvatarTapped() {
        guard canPerformAction(.setGroupAvatar) else { return }
        let picker = AvatarPickerSheetController(
            title: LocalizedChatString("ChooseAvatar"),
            imageUrlList: (1 ... Self.presetAvatarCount).map {
                "https://im.sdk.qcloud.com/download/tuikit-resource/group-avatar/group_avatar_\($0).png"
            },
            columnCount: Self.avatarPickerColumnCount,
            onImageSelected: { [weak self] selectedImageUrl in
                self?.updateGroupProfile(name: nil, notice: nil, avatar: selectedImageUrl)
            }
        )
        present(picker, animated: true)
    }

    @objc private func handleNameTapped() {
        guard canPerformAction(.setGroupName) else { return }
        let dialog = TextInputDialogViewController(
            title: LocalizedChatString("GroupProfileEditGroupName"),
            initialText: groupName
        ) { [weak self] text in
            guard !text.isEmpty else { return }
            self?.updateGroupProfile(name: text, notice: nil, avatar: nil)
        }
        present(dialog, animated: true)
    }

    @objc private func handleGroupIDTapped() {
        UIPasteboard.general.string = groupID
        WindowToastManager.shared.show(LocalizedChatString("Copied"), type: .success, duration: Self.toastDuration)
    }

    @objc private func handleMemberListTapped() {
        guard canPerformAction(.getGroupMemberList) else { return }
        let memberListPage = GroupMemberListViewController(
            groupStore: groupStore,
            memberStore: memberStore,
            onGroupMemberClick: onGroupMemberClick
        )
        pushOrPresent(memberListPage)
    }

    @objc private func handleMemberItemTapped(_ sender: UIControl) {
        let member = allMembers[sender.tag]
        guard canPerformAction(.getGroupMemberInfo), member.userID != currentUserID else { return }
        openMemberDetail(userID: member.userID)
    }

    @objc private func handleAddMemberTapped() {
        let picker = GroupMemberPickerViewController(
            mode: .addMember(memberStore: memberStore)
        )
        pushOrPresent(picker)
    }

    @objc private func handleRemoveMemberTapped() {
        let picker = GroupMemberPickerViewController(
            mode: .removeMember(memberStore: memberStore, currentUserRole: currentUserRole)
        )
        pushOrPresent(picker)
    }

    @objc private func handleNoticeTapped() {
        guard canPerformAction(.setGroupNotice) else { return }
        let currentNotice = notice
        let dialog = TextInputDialogViewController(
            title: LocalizedChatString("GroupNotice"),
            initialText: currentNotice,
            maxLength: Self.noticeMaxInputLength,
            multiline: true
        ) { [weak self] text in
            if text != currentNotice {
                self?.updateGroupProfile(name: nil, notice: text, avatar: nil)
            }
        }
        present(dialog, animated: true)
    }

    @objc private func handleManageTapped() {
        let managementPage = GroupManagementViewController(groupID: groupID, groupStore: groupStore, memberStore: memberStore)
        pushOrPresent(managementPage)
    }

    @objc private func handleJoinTapped() {
        presentPermissionActionSheet(isJoinOption: true)
    }

    @objc private func handleInviteTapped() {
        presentPermissionActionSheet(isJoinOption: false)
    }

    @objc private func handleAliasTapped() {
        guard canPerformAction(.setGroupRemark) else { return }
        let dialog = TextInputDialogViewController(
            title: LocalizedChatString("GroupEditNameCard"),
            initialText: selfNameCard ?? ""
        ) { [weak self] text in
            self?.memberStore.setSelfNameCard(nameCard: text, completion: nil)
        }
        present(dialog, animated: true)
    }

    @objc private func handleBackgroundTapped() {
        let picker = ChatBackgroundPickerViewController(conversationID: conversationID) { [weak self] uri in
            guard let self = self else { return }
            ChatBackgroundStore.shared.setImageURI(uri, forConversationID: self.conversationID)
            self.chatBackgroundURI = uri
            self.refreshUI()
        }
        present(picker, animated: true)
    }

    @objc private func handleTransferTapped() {
        let picker = GroupMemberPickerViewController(
            mode: .transferOwner(groupID: groupID, groupStore: groupStore, memberStore: memberStore)
        )
        pushOrPresent(picker)
    }

    @objc private func handleClearHistoryTapped() {
        let alert = UIAlertController(
            title: LocalizedChatString("ClearAllChatHistory"),
            message: LocalizedChatString("ClearAllChatHistoryTips"),
            preferredStyle: .alert
        )
        alert.addAction(UIAlertAction(title: LocalizedChatString("Clear"), style: .destructive) { [weak self] _ in
            guard let self = self else { return }
            self.conversationStore.clearConversationMessages(conversationID: self.conversationID, completion: nil)
        })
        alert.addAction(UIAlertAction(title: LocalizedChatString("Cancel"), style: .cancel))
        present(alert, animated: true)
    }

    @objc private func handleQuitTapped() {
        let alert = UIAlertController(
            title: LocalizedChatString("DeleteAndQuitConfirmTitle"),
            message: LocalizedChatString("DeleteAndQuitConfirmMessage"),
            preferredStyle: .alert
        )
        alert.addAction(UIAlertAction(title: LocalizedChatString("DeleteAndQuit"), style: .destructive) { [weak self] _ in
            self?.quitGroup()
        })
        alert.addAction(UIAlertAction(title: LocalizedChatString("Cancel"), style: .cancel))
        present(alert, animated: true)
    }

    @objc private func handleDismissTapped() {
        let alert = UIAlertController(
            title: LocalizedChatString("DismissGroupConfirmTitle"),
            message: LocalizedChatString("DismissGroupConfirmMessage"),
            preferredStyle: .alert
        )
        alert.addAction(UIAlertAction(title: LocalizedChatString("DismissGroup"), style: .destructive) { [weak self] _ in
            self?.dismissGroup()
        })
        alert.addAction(UIAlertAction(title: LocalizedChatString("Cancel"), style: .cancel))
        present(alert, animated: true)
    }

    private func presentPermissionActionSheet(isJoinOption: Bool) {
        let alert = UIAlertController(
            title: nil,
            message: nil,
            preferredStyle: .actionSheet
        )
        let forbidKey = isJoinOption ? "GroupProfileJoinDisable" : "GroupProfileInviteDisable"
        alert.addAction(UIAlertAction(title: LocalizedChatString(forbidKey), style: .default) { [weak self] _ in
            self?.setGroupPermission(.forbid, isJoinOption: isJoinOption)
        })
        alert.addAction(UIAlertAction(title: LocalizedChatString("GroupProfileAdminApprove"), style: .default) { [weak self] _ in
            self?.setGroupPermission(.auth, isJoinOption: isJoinOption)
        })
        alert.addAction(UIAlertAction(title: LocalizedChatString("GroupProfileAutoApproval"), style: .default) { [weak self] _ in
            self?.setGroupPermission(.any, isJoinOption: isJoinOption)
        })
        alert.addAction(UIAlertAction(title: LocalizedChatString("Cancel"), style: .cancel))
        present(alert, animated: true)
    }

    private func setGroupPermission(_ option: GroupJoinOption, isJoinOption: Bool) {
        if isJoinOption {
            groupStore.setJoinOption(groupID: groupID, option: option, completion: nil)
        } else {
            let inviteOption = GroupInviteOption(rawValue: option.rawValue) ?? .forbid
            groupStore.setInviteOption(groupID: groupID, option: inviteOption, completion: nil)
        }
    }

    private func updateGroupProfile(name: String?, notice: String?, avatar: String?) {
        var groupInfo = GroupInfo(groupID: groupID)
        groupInfo.groupName = name
        groupInfo.notification = notice
        groupInfo.avatarURL = avatar
        groupStore.updateProfile(groupInfo: groupInfo, completion: nil)
    }

    private func quitGroup() {
        groupStore.quitGroup(groupID: groupID) { [weak self] _ in
            DispatchQueue.main.async {
                self?.exitAfterGroupGone()
            }
        }
    }

    private func dismissGroup() {
        groupStore.dismissGroup(groupID: groupID) { [weak self] _ in
            DispatchQueue.main.async {
                self?.exitAfterGroupGone()
            }
        }
    }

    private func exitAfterGroupGone() {
        conversationStore.deleteConversation(conversationID: conversationID, completion: nil)
        if let onGroupDelete = onGroupDelete {
            onGroupDelete()
        } else if let navigationController = navigationController {
            navigationController.popViewController(animated: true)
        } else {
            dismiss(animated: true)
        }
    }
}

final class GroupSettingGroupInfoHandler: GetGroupInfoCompletionHandler {
    private let onSuccessBlock: (GroupInfo) -> Void

    private let onFailureBlock: (Int, String) -> Void

    init(onSuccess: @escaping (GroupInfo) -> Void, onFailure: @escaping (Int, String) -> Void) {
        self.onSuccessBlock = onSuccess
        self.onFailureBlock = onFailure
    }

    func onSuccess(groupInfo: GroupInfo) {
        onSuccessBlock(groupInfo)
    }

    func onFailure(code: Int, desc: String) {
        onFailureBlock(code, desc)
    }
}

final class GroupSettingConversationInfoHandler: GetConversationInfoCompletionHandler {
    private let onSuccessBlock: (ConversationInfo) -> Void

    private let onFailureBlock: (Int, String) -> Void

    init(onSuccess: @escaping (ConversationInfo) -> Void, onFailure: @escaping (Int, String) -> Void) {
        self.onSuccessBlock = onSuccess
        self.onFailureBlock = onFailure
    }

    func onSuccess(conversationInfo: ConversationInfo) {
        onSuccessBlock(conversationInfo)
    }

    func onFailure(code: Int, desc: String) {
        onFailureBlock(code, desc)
    }
}
