import AtomicXCore
import Kingfisher
import SnapKit
import UIKit

private let groupCreateTipsMessageDelay: TimeInterval = 0.5

final class ConfigGroupInfoViewController: UIViewController {
    private static let horizontalPadding: CGFloat = CGFloat(SpacingScheme.bubbleSpacing)

    private static let rowHeight: CGFloat = 48

    private static let sectionTitleFontSize: CGFloat = 16

    private static let sectionTitleTopPadding: CGFloat = CGFloat(SpacingScheme.iconIconSpacing)

    private static let sectionTitleBottomPadding: CGFloat = CGFloat(SpacingScheme.smallSpacing)

    private static let sectionBottomPadding: CGFloat = CGFloat(SpacingScheme.bubbleSpacing)

    private static let dividerHeight: CGFloat = 0.5

    private static let descTopPadding: CGFloat = CGFloat(SpacingScheme.smallSpacing)

    private static let descLineHeightMultiple: CGFloat = 1.25

    private static let avatarItemSize: CGFloat = 48

    private static let avatarItemSpacing: CGFloat = CGFloat(SpacingScheme.contentSpacing)

    private static let avatarGridRows = 2

    private static let memberAvatarSize: CGFloat = 40

    private static let memberAvatarSpacing: CGFloat = CGFloat(SpacingScheme.iconIconSpacing)

    private static let createButtonWidth: CGFloat = 76

    private static let createButtonHeight: CGFloat = 30

    private static let createButtonCornerRadius: CGFloat = 6

    private static let bottomBarTopPadding: CGFloat = CGFloat(SpacingScheme.iconIconSpacing)

    private static let bottomBarBottomPadding: CGFloat = CGFloat(SpacingScheme.contentSpacing)

    private static let toastBottomOffset: CGFloat = 200

    private static let groupNamePreviewCount = 3

    private static let presetAvatarCount = 24

    private static let backButtonSymbolPointSize: CGFloat = 18

    private static let rowContentSpacing: CGFloat = CGFloat(SpacingScheme.smallSpacing)

    private static let memberAvatarCornerRadius: CGFloat = CGFloat(RadiusScheme.tipsRadius)

    private static let memberAvatarFontSize: CGFloat = 16

    private static let createErrorToastDuration: TimeInterval = 3

    private static let validationErrorToastDuration: TimeInterval = 2

    private var avatarURLList: [String] {
        (1 ... Self.presetAvatarCount).map { "https://im.sdk.qcloud.com/download/tuikit-resource/group-avatar/group_avatar_\($0).png" }
    }

    private var members: [UserPickerItem]

    private let onComplete: (String?, String?, String?) -> Void

    private let onBack: () -> Void

    private var groupType: GroupTypeSelection = .work

    private var selectedAvatar: String?

    private let scrollView = UIScrollView()

    private let contentStack = UIStackView()

    private let groupNameField = UITextField()

    private let groupIDField = UITextField()

    private let groupTypeValueLabel = UILabel()

    private let groupTypeDescLabel = UILabel()

    private var avatarItems: [GroupAvatarGridItem] = []

    private let avatarColumnsStack = UIStackView()

    private let membersStack = UIStackView()

    private let bottomBar = UIView()

    private let createButton = UIButton(type: .custom)

    // MARK: - Init

    init(members: [UserPickerItem],
         onComplete: @escaping (String?, String?, String?) -> Void,
         onBack: @escaping () -> Void) {
        self.members = members
        self.onComplete = onComplete
        self.onBack = onBack
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    // MARK: - Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()
        setupInitialData()
        constructViewHierarchy()
        activateConstraints()
        setupNavigationBar()
        setupViewStyle()
        refreshGroupTypeDisplay()
        refreshMembers()
        refreshCreateButtonState()
    }

    // MARK: - Create Group

    private func constructViewHierarchy() {
        view.addSubview(scrollView)
        view.addSubview(bottomBar)
        bottomBar.addSubview(createButton)
        scrollView.addSubview(contentStack)

        contentStack.addArrangedSubview(makeEditableRow(title: LocalizedChatString("ConfigGroupNameLabel"),
                                                        field: groupNameField,
                                                        hint: ""))
        contentStack.addArrangedSubview(makeDivider())
        contentStack.addArrangedSubview(makeEditableRow(title: LocalizedChatString("ConfigGroupIDLabel"),
                                                        field: groupIDField,
                                                        hint: LocalizedChatString("ConfigGroupIDOptionalHint")))
        contentStack.addArrangedSubview(makeDivider())
        contentStack.addArrangedSubview(makeGroupTypeRow())
        contentStack.addArrangedSubview(makeDescContainer())
        contentStack.addArrangedSubview(makeAvatarSection())
        contentStack.addArrangedSubview(makeMembersSection())
    }

    private func activateConstraints() {
        bottomBar.snp.makeConstraints { make in
            make.leading.trailing.bottom.equalToSuperview()
        }
        createButton.snp.makeConstraints { make in
            make.trailing.equalToSuperview().offset(-Self.horizontalPadding)
            make.top.equalToSuperview().offset(Self.bottomBarTopPadding)
            make.bottom.equalTo(bottomBar.safeAreaLayoutGuide).offset(-Self.bottomBarBottomPadding)
            make.width.equalTo(Self.createButtonWidth)
            make.height.equalTo(Self.createButtonHeight)
        }
        scrollView.snp.makeConstraints { make in
            make.top.leading.trailing.equalToSuperview()
            make.bottom.equalTo(bottomBar.snp.top)
        }
        contentStack.snp.makeConstraints { make in
            make.edges.equalTo(scrollView.contentLayoutGuide)
            make.width.equalTo(scrollView.frameLayoutGuide)
        }
    }

    private func setupNavigationBar() {
        let colors = ChatUIKitTheme.colors
        title = LocalizedChatString("CreateGroupTitle")
        navigationItem.leftBarButtonItem = UIBarButtonItem(
            image: AtomicXChatResources.image(named: "contact_info_back")?
                .withRenderingMode(.alwaysTemplate)
                ?? UIImage(systemName: "chevron.left")?
                .withConfiguration(UIImage.SymbolConfiguration(pointSize: Self.backButtonSymbolPointSize, weight: .semibold)),
            style: .plain,
            target: self,
            action: #selector(handleCancel)
        )
        navigationItem.leftBarButtonItem?.tintColor = colors.textColorPrimary
    }

    private func setupViewStyle() {
        let colors = ChatUIKitTheme.colors
        view.backgroundColor = colors.bgColorOperate
        bottomBar.backgroundColor = colors.bgColorOperate
        contentStack.axis = .vertical
        contentStack.spacing = 0
        contentStack.alignment = .fill

        createButton.setTitle(LocalizedChatString("CreateFinish"), for: .normal)
        createButton.setTitleColor(colors.textColorButton, for: .normal)
        createButton.titleLabel?.font = FontScheme.caption1Regular
        createButton.layer.cornerRadius = Self.createButtonCornerRadius
        createButton.layer.masksToBounds = true

        groupNameField.addTarget(self, action: #selector(handleGroupNameChanged), for: .editingChanged)
        createButton.addTarget(self, action: #selector(handleCreate), for: .touchUpInside)
        scrollView.keyboardDismissMode = .onDrag
        let tapGesture = UITapGestureRecognizer(target: self, action: #selector(handleBackgroundTapped))
        tapGesture.cancelsTouchesInView = false
        scrollView.addGestureRecognizer(tapGesture)
    }

    @objc private func handleBackgroundTapped() {
        view.endEditing(true)
    }

    private func setupInitialData() {
        groupNameField.text = Self.makeDefaultGroupName(from: members)
    }

    private static func makeDefaultGroupName(from members: [UserPickerItem]) -> String {
        let names = members.map { $0.title.trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty }
        let preview = names.prefix(Self.groupNamePreviewCount)
            .joined(separator: LocalizedChatString("ConfigGroupNameSeparator"))
        let remaining = names.count - Self.groupNamePreviewCount
        if remaining > 0 {
            return preview + String(format: LocalizedChatString("ConfigGroupNameSuffix"), remaining)
        }
        return preview
    }

    private func makeEditableRow(title: String, field: UITextField, hint: String) -> UIView {
        let colors = ChatUIKitTheme.colors
        let row = UIView()
        row.backgroundColor = colors.bgColorTopBar

        let titleLabel = UILabel()
        titleLabel.text = title
        titleLabel.font = FontScheme.caption1Regular
        titleLabel.textColor = colors.textColorPrimary
        titleLabel.setContentHuggingPriority(.required, for: .horizontal)

        field.placeholder = hint.isEmpty ? nil : hint
        field.font = FontScheme.caption1Regular
        field.textColor = colors.textColorPrimary
        field.textAlignment = LanguageHelper.isRTL ? .left : .right
        field.autocapitalizationType = .none
        field.autocorrectionType = .no
        field.returnKeyType = .done
        field.delegate = self
        field.attributedPlaceholder = hint.isEmpty ? nil : NSAttributedString(
            string: hint,
            attributes: [.foregroundColor: colors.textColorSecondary]
        )

        row.addSubview(titleLabel)
        row.addSubview(field)
        row.snp.makeConstraints { make in
            make.height.equalTo(Self.rowHeight)
        }
        titleLabel.snp.makeConstraints { make in
            make.leading.equalToSuperview().offset(Self.horizontalPadding)
            make.centerY.equalToSuperview()
        }
        field.snp.makeConstraints { make in
            make.leading.equalTo(titleLabel.snp.trailing).offset(Self.rowContentSpacing)
            make.trailing.equalToSuperview().offset(-Self.horizontalPadding)
            make.centerY.equalToSuperview()
        }
        return row
    }

    private func makeDivider() -> UIView {
        let divider = UIView()
        divider.backgroundColor = ChatUIKitTheme.colors.strokeColorPrimary
        divider.snp.makeConstraints { make in
            make.height.equalTo(Self.dividerHeight)
        }
        return divider
    }

    private func makeGroupTypeRow() -> UIView {
        let colors = ChatUIKitTheme.colors
        let row = UIControl()
        row.backgroundColor = colors.bgColorTopBar
        row.addTarget(self, action: #selector(handleSelectGroupType), for: .touchUpInside)

        let titleLabel = UILabel()
        titleLabel.text = LocalizedChatString("CreatGroupType")
        titleLabel.font = FontScheme.caption1Regular
        titleLabel.textColor = colors.textColorPrimary

        let chevronLabel = UILabel()
        chevronLabel.text = LanguageHelper.isRTL ? "‹" : "›"
        chevronLabel.font = FontScheme.body3Regular
        chevronLabel.textColor = colors.textColorSecondary

        groupTypeValueLabel.font = FontScheme.caption1Regular
        groupTypeValueLabel.textColor = colors.textColorPrimary
        groupTypeValueLabel.lineBreakMode = .byTruncatingTail

        row.addSubview(titleLabel)
        row.addSubview(groupTypeValueLabel)
        row.addSubview(chevronLabel)
        row.snp.makeConstraints { make in
            make.height.equalTo(Self.rowHeight)
        }
        titleLabel.snp.makeConstraints { make in
            make.leading.equalToSuperview().offset(Self.horizontalPadding)
            make.centerY.equalToSuperview()
        }
        chevronLabel.snp.makeConstraints { make in
            make.trailing.equalToSuperview().offset(-Self.horizontalPadding)
            make.centerY.equalToSuperview()
        }
        groupTypeValueLabel.snp.makeConstraints { make in
            make.leading.greaterThanOrEqualTo(titleLabel.snp.trailing).offset(Self.rowContentSpacing)
            make.trailing.equalTo(chevronLabel.snp.leading).offset(-Self.rowContentSpacing)
            make.centerY.equalToSuperview()
        }
        return row
    }

    private func makeDescContainer() -> UIView {
        let container = UIView()
        groupTypeDescLabel.font = FontScheme.caption3Regular
        groupTypeDescLabel.textColor = ChatUIKitTheme.colors.textColorSecondary
        groupTypeDescLabel.numberOfLines = 0
        container.addSubview(groupTypeDescLabel)
        groupTypeDescLabel.snp.makeConstraints { make in
            make.top.equalToSuperview().offset(Self.descTopPadding)
            make.leading.equalToSuperview().offset(Self.horizontalPadding)
            make.trailing.equalToSuperview().offset(-Self.horizontalPadding)
            make.bottom.equalToSuperview()
        }
        return container
    }

    private func makeAvatarSection() -> UIView {
        let colors = ChatUIKitTheme.colors
        let container = UIView()
        container.backgroundColor = colors.bgColorTopBar

        let titleLabel = UILabel()
        titleLabel.text = LocalizedChatString("CreatGroupAvatar")
        titleLabel.font = .systemFont(ofSize: Self.sectionTitleFontSize, weight: .semibold)
        titleLabel.textColor = colors.textColorPrimary

        let scrollView = UIScrollView()
        scrollView.showsHorizontalScrollIndicator = false
        scrollView.alwaysBounceHorizontal = true
        scrollView.clipsToBounds = false

        avatarColumnsStack.axis = .horizontal
        avatarColumnsStack.spacing = Self.avatarItemSpacing
        avatarColumnsStack.alignment = .top

        container.addSubview(titleLabel)
        container.addSubview(scrollView)
        scrollView.addSubview(avatarColumnsStack)
        titleLabel.snp.makeConstraints { make in
            make.top.equalToSuperview().offset(Self.sectionTitleTopPadding)
            make.leading.equalToSuperview().offset(Self.horizontalPadding)
            make.trailing.equalToSuperview().offset(-Self.horizontalPadding)
        }
        scrollView.snp.makeConstraints { make in
            make.top.equalTo(titleLabel.snp.bottom).offset(Self.sectionTitleBottomPadding)
            make.leading.trailing.equalToSuperview()
            make.bottom.equalToSuperview().offset(-Self.sectionBottomPadding)
            make.height.equalTo(Self.avatarItemSize * CGFloat(Self.avatarGridRows) + Self.avatarItemSpacing)
        }
        avatarColumnsStack.snp.makeConstraints { make in
            make.edges.equalToSuperview().inset(UIEdgeInsets(top: 0, left: Self.horizontalPadding, bottom: 0, right: Self.horizontalPadding))
            make.height.equalToSuperview()
        }

        buildAvatarGrid()
        return container
    }

    private func buildAvatarGrid() {
        let candidates: [String?] = [nil] + avatarURLList.map { Optional($0) }
        let currentGroupName = groupNameField.text ?? ""
        let fallbackName = currentGroupName.isEmpty ? LocalizedChatString("ConfigGroupNameLabel") : currentGroupName
        let columns = stride(from: 0, to: candidates.count, by: Self.avatarGridRows).map {
            Array(candidates[$0 ..< min($0 + Self.avatarGridRows, candidates.count)])
        }
        for columnItems in columns {
            let columnStack = UIStackView()
            columnStack.axis = .vertical
            columnStack.spacing = Self.avatarItemSpacing
            for url in columnItems {
                let item = GroupAvatarGridItem(url: url, fallbackName: fallbackName) { [weak self] selectedURL in
                    self?.selectAvatar(selectedURL)
                }
                item.snp.makeConstraints { make in
                    make.width.height.equalTo(Self.avatarItemSize)
                }
                avatarItems.append(item)
                columnStack.addArrangedSubview(item)
            }
            avatarColumnsStack.addArrangedSubview(columnStack)
        }
        refreshAvatarSelection()
    }

    private func selectAvatar(_ url: String?) {
        selectedAvatar = url
        refreshAvatarSelection()
    }

    private func refreshAvatarSelection() {
        for item in avatarItems {
            item.setSelected(item.url == selectedAvatar)
        }
    }

    private func makeMembersSection() -> UIView {
        let colors = ChatUIKitTheme.colors
        let container = UIView()
        container.backgroundColor = colors.bgColorTopBar

        let titleLabel = UILabel()
        titleLabel.text = LocalizedChatString("CreateMemebers")
        titleLabel.font = .systemFont(ofSize: Self.sectionTitleFontSize, weight: .semibold)
        titleLabel.textColor = colors.textColorPrimary

        let scrollView = UIScrollView()
        scrollView.showsHorizontalScrollIndicator = false

        membersStack.axis = .horizontal
        membersStack.spacing = Self.memberAvatarSpacing
        membersStack.alignment = .center

        container.addSubview(titleLabel)
        container.addSubview(scrollView)
        scrollView.addSubview(membersStack)
        titleLabel.snp.makeConstraints { make in
            make.top.equalToSuperview().offset(Self.sectionTitleTopPadding)
            make.leading.equalToSuperview().offset(Self.horizontalPadding)
            make.trailing.equalToSuperview().offset(-Self.horizontalPadding)
        }
        scrollView.snp.makeConstraints { make in
            make.top.equalTo(titleLabel.snp.bottom).offset(Self.sectionTitleBottomPadding)
            make.leading.trailing.equalToSuperview()
            make.bottom.equalToSuperview().offset(-Self.sectionBottomPadding)
            make.height.equalTo(Self.memberAvatarSize)
        }
        membersStack.snp.makeConstraints { make in
            make.edges.equalToSuperview().inset(UIEdgeInsets(top: 0, left: Self.horizontalPadding, bottom: 0, right: Self.horizontalPadding))
            make.height.equalToSuperview()
        }
        return container
    }

    private func refreshGroupTypeDisplay() {
        groupTypeValueLabel.text = groupType.displayName
        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.lineHeightMultiple = Self.descLineHeightMultiple
        groupTypeDescLabel.attributedText = NSAttributedString(
            string: groupType.typeDescription,
            attributes: [.paragraphStyle: paragraphStyle]
        )
    }

    private func refreshMembers() {
        membersStack.arrangedSubviews.forEach { $0.removeFromSuperview() }
        for member in members {
            let avatar = ChatAvatarView(cornerRadius: Self.memberAvatarCornerRadius, fontSize: Self.memberAvatarFontSize)
            avatar.configure(avatarURL: member.avatarURL, fallbackName: member.title)
            avatar.snp.makeConstraints { make in
                make.width.height.equalTo(Self.memberAvatarSize)
            }
            membersStack.addArrangedSubview(avatar)
        }
    }

    private func refreshCreateButtonState() {
        let colors = ChatUIKitTheme.colors
        let nameEmpty = (groupNameField.text ?? "").isEmpty
        let enabled = !nameEmpty && !members.isEmpty
        createButton.isEnabled = enabled
        createButton.backgroundColor = enabled ? colors.textColorLink : colors.textColorDisable
    }

    @objc private func handleGroupNameChanged() {
        refreshCreateButtonState()
    }

    @objc private func handleSelectGroupType() {
        let selector = ChooseGroupTypeViewController(selected: groupType) { [weak self] type in
            self?.groupType = type
            self?.refreshGroupTypeDisplay()
        }
        navigationController?.pushViewController(selector, animated: true)
    }

    @objc private func handleCancel() {
        onBack()
    }

    @objc private func handleCreate() {
        let groupID = groupIDField.text ?? ""
        guard validateGroupID(groupID) else { return }

        var params = GroupCreateParams(groupName: groupNameField.text ?? "")
        params.groupType = groupType.coreType
        params.groupID = groupID.isEmpty ? nil : groupID
        params.avatarURL = selectedAvatar
        params.memberList = members.map { $0.userID }

        GroupStore.shared.createGroup(
            params: params,
            completion: CreateGroupHandler(
                onSuccess: { [weak self] createdGroupID in
                    DispatchQueue.main.async {
                        self?.handleCreateSuccess(createdGroupID)
                    }
                },
                onFailure: { [weak self] code, _ in
                    DispatchQueue.main.async {
                        guard let self = self else { return }
                        WindowToastManager.shared.show(Self.createGroupErrorText(code: code), type: .error, duration: Self.createErrorToastDuration, position: .bottom(Self.toastBottomOffset))
                    }
                }
            )
        )
    }

    private func validateGroupID(_ groupID: String) -> Bool {
        guard !groupID.isEmpty else { return true }
        let isCommunity = groupType == .community
        let hasCommunityPrefix = groupID.hasPrefix("@TGS#_")
        let hasGroupPrefix = groupID.hasPrefix("@TGS#")
        if isCommunity && !hasCommunityPrefix {
            WindowToastManager.shared.show(LocalizedChatString("TUICommunityCreateTipsMessageRuleError"), type: .error, duration: Self.validationErrorToastDuration, position: .bottom(Self.toastBottomOffset))
            return false
        }
        if !isCommunity && hasGroupPrefix {
            WindowToastManager.shared.show(LocalizedChatString("TUIGroupCreateTipsMessageRuleError"), type: .error, duration: Self.validationErrorToastDuration, position: .bottom(Self.toastBottomOffset))
            return false
        }
        return true
    }

    private static func createGroupErrorText(code: Int) -> String {
        switch code {
        case 10021, 10025:
            return LocalizedChatString("GroupCreateErrorGroupIDUsed")
        default:
            return LocalizedChatString("GroupCreateFailed")
        }
    }

    private func handleCreateSuccess(_ createdGroupID: String) {
        let groupName = groupNameField.text ?? ""
        let conversationId = createdGroupID.isEmpty ? nil : "group_\(createdGroupID)"
        onComplete(createdGroupID.isEmpty ? nil : createdGroupID, groupName.isEmpty ? nil : groupName, conversationId)
        dismiss(animated: true)
        let type = groupType.rawValue
        DispatchQueue.main.asyncAfter(deadline: .now() + groupCreateTipsMessageDelay) {
            Self.sendGroupCreateTipsMessage(groupID: createdGroupID, groupType: type)
        }
    }

    private static func sendGroupCreateTipsMessage(groupID: String, groupType: String) {
        guard !groupID.isEmpty else { return }
        let showName = LoginStore.shared.state.value.loginUserInfo?.userID ?? "用户"
        let isCommunity = groupType == "Community"
        let content = isCommunity
            ? LocalizedChatString("TUICommunityCreateTipsMessage")
            : LocalizedChatString("TUIGroupCreateTipsMessage")
        let dic: [String: Any] = [
            "version": 1,
            "businessID": "group_create",
            "opUser": showName,
            "content": content,
            "cmd": isCommunity ? 1 : 0
        ]
        let customData = ChatUtil.dictionary2JsonData(dic)
            .flatMap { String(data: $0, encoding: .utf8) } ?? ""
        let payload = CustomSendMessagePayload(customData: customData)
        let messageInputState = MessageInputStore.create(conversationID: "group_\(groupID)")
        messageInputState.sendMessage(payload: .custom(payload), option: nil, completion: nil)
    }
}

extension ConfigGroupInfoViewController: UITextFieldDelegate {

    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        textField.resignFirstResponder()
        return true
    }
}

// MARK: - Group Type

private enum GroupTypeSelection: String, CaseIterable {
    case work = "Work"
    case publicGroup = "Public"
    case meeting = "Meeting"
    case community = "Community"

    var displayName: String {
        switch self {
        case .work: return LocalizedChatString("CreatGroupType_Work")
        case .publicGroup: return LocalizedChatString("CreatGroupType_Public")
        case .meeting: return LocalizedChatString("CreatGroupType_Meeting")
        case .community: return LocalizedChatString("CreatGroupType_Community")
        }
    }

    var typeDescription: String {
        switch self {
        case .work: return LocalizedChatString("CreatGroupType_Work_Desc")
        case .publicGroup: return LocalizedChatString("CreatGroupType_Public_Desc")
        case .meeting: return LocalizedChatString("CreatGroupType_Meeting_Desc")
        case .community: return LocalizedChatString("CreatGroupType_Community_Desc")
        }
    }

    var iconName: String {
        switch self {
        case .work: return "group_type_work"
        case .publicGroup: return "group_type_public"
        case .meeting: return "group_type_meeting"
        case .community: return "group_type_community"
        }
    }

    var coreType: AtomicXCore.GroupType {
        switch self {
        case .work: return .work
        case .publicGroup: return .publicGroup
        case .meeting: return .meeting
        case .community: return .community
        }
    }
}

// MARK: - Choose Group Type

private final class ChooseGroupTypeViewController: UIViewController {
    private static let cardSpacing: CGFloat = CGFloat(SpacingScheme.iconIconSpacing)

    private static let containerPadding: CGFloat = CGFloat(SpacingScheme.bubbleSpacing)

    private static let cardCornerRadius: CGFloat = CGFloat(RadiusScheme.alertRadius)

    private static let cardPadding: CGFloat = CGFloat(SpacingScheme.bubbleSpacing)

    private static let cardSelectedStrokeWidth: CGFloat = 1.5

    private static let typeIconSize: CGFloat = 40

    private static let typeIconTitleGap: CGFloat = 10

    private static let descTopMargin: CGFloat = 10

    private static let descFontSize: CGFloat = 13

    private static let descLineHeightMultiple: CGFloat = 1.3

    private static let titleFontSize: CGFloat = 16

    private static let backButtonSymbolPointSize: CGFloat = 18

    private var selected: GroupTypeSelection

    private let onSelect: (GroupTypeSelection) -> Void

    private let contentStack = UIStackView()

    init(selected: GroupTypeSelection, onSelect: @escaping (GroupTypeSelection) -> Void) {
        self.selected = selected
        self.onSelect = onSelect
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        let colors = ChatUIKitTheme.colors
        view.backgroundColor = colors.bgColorTopBar
        title = LocalizedChatString("ConfigSelectGroupTypeTitle")
        navigationItem.leftBarButtonItem = UIBarButtonItem(
            image: AtomicXChatResources.image(named: "contact_info_back")?
                .withRenderingMode(.alwaysTemplate)
                ?? UIImage(systemName: "chevron.left")?
                .withConfiguration(UIImage.SymbolConfiguration(pointSize: Self.backButtonSymbolPointSize, weight: .semibold)),
            style: .plain,
            target: self,
            action: #selector(handleBack)
        )
        navigationItem.leftBarButtonItem?.tintColor = colors.textColorPrimary

        let scrollView = UIScrollView()
        view.addSubview(scrollView)
        scrollView.addSubview(contentStack)
        scrollView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }
        contentStack.axis = .vertical
        contentStack.spacing = Self.cardSpacing
        contentStack.snp.makeConstraints { make in
            make.top.equalTo(scrollView.contentLayoutGuide).offset(Self.cardSpacing)
            make.leading.trailing.equalTo(scrollView.frameLayoutGuide).inset(Self.containerPadding)
            make.bottom.equalTo(scrollView.contentLayoutGuide).offset(-Self.cardSpacing)
        }

        for type in GroupTypeSelection.allCases {
            contentStack.addArrangedSubview(makeOption(type))
        }
    }

    private func makeOption(_ type: GroupTypeSelection) -> UIView {
        let colors = ChatUIKitTheme.colors
        let isSelected = type == selected

        let card = GroupTypeOptionControl(type: type) { [weak self] selectedType in
            self?.onSelect(selectedType)
            self?.navigationController?.popViewController(animated: true)
        }
        card.backgroundColor = colors.bgColorOperate
        card.layer.cornerRadius = Self.cardCornerRadius
        card.layer.borderWidth = isSelected ? Self.cardSelectedStrokeWidth : 0
        card.layer.borderColor = colors.textColorLink.cgColor

        let iconView = UIImageView(image: AtomicXChatResources.image(named: type.iconName))
        iconView.contentMode = .scaleAspectFit

        let titleLabel = UILabel()
        titleLabel.text = type.displayName
        titleLabel.font = .systemFont(ofSize: Self.titleFontSize, weight: .semibold)
        titleLabel.textColor = colors.textColorPrimary

        let descLabel = UILabel()
        descLabel.font = .systemFont(ofSize: Self.descFontSize)
        descLabel.textColor = colors.textColorSecondary
        descLabel.numberOfLines = 0
        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.lineHeightMultiple = Self.descLineHeightMultiple
        descLabel.attributedText = NSAttributedString(
            string: type.typeDescription,
            attributes: [.paragraphStyle: paragraphStyle]
        )

        card.addSubview(iconView)
        card.addSubview(titleLabel)
        card.addSubview(descLabel)
        iconView.snp.makeConstraints { make in
            make.top.equalToSuperview().offset(Self.cardPadding)
            make.leading.equalToSuperview().offset(Self.cardPadding)
            make.width.height.equalTo(Self.typeIconSize)
        }
        titleLabel.snp.makeConstraints { make in
            make.centerY.equalTo(iconView)
            make.leading.equalTo(iconView.snp.trailing).offset(Self.typeIconTitleGap)
            make.trailing.lessThanOrEqualToSuperview().offset(-Self.cardPadding)
        }
        descLabel.snp.makeConstraints { make in
            make.top.equalTo(iconView.snp.bottom).offset(Self.descTopMargin)
            make.leading.equalToSuperview().offset(Self.cardPadding)
            make.trailing.equalToSuperview().offset(-Self.cardPadding)
            make.bottom.equalToSuperview().offset(-Self.cardPadding)
        }
        return card
    }

    @objc private func handleBack() {
        navigationController?.popViewController(animated: true)
    }
}

private final class GroupTypeOptionControl: UIControl {
    private let type: GroupTypeSelection

    private let handler: (GroupTypeSelection) -> Void

    init(type: GroupTypeSelection, handler: @escaping (GroupTypeSelection) -> Void) {
        self.type = type
        self.handler = handler
        super.init(frame: .zero)
        addTarget(self, action: #selector(handleTap), for: .touchUpInside)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    @objc private func handleTap() {
        handler(type)
    }
}

// MARK: - Group Avatar Grid Item

private final class GroupAvatarGridItem: UIControl {
    private static let avatarCornerRadius: CGFloat = CGFloat(RadiusScheme.smallRadius)

    private static let avatarFontSize: CGFloat = 18

    private static let selectedBorderWidth: CGFloat = 2

    let url: String?

    private let onTap: (String?) -> Void

    private let avatarView: ChatAvatarView

    init(url: String?, fallbackName: String, onTap: @escaping (String?) -> Void) {
        self.url = url
        self.onTap = onTap
        avatarView = ChatAvatarView(cornerRadius: Self.avatarCornerRadius, fontSize: Self.avatarFontSize)
        super.init(frame: .zero)
        avatarView.isUserInteractionEnabled = false
        if let url = url {
            avatarView.configure(avatarURL: url, fallbackName: fallbackName)
        } else {
            avatarView.configure(avatarURL: nil, fallbackName: fallbackName)
        }
        addSubview(avatarView)
        avatarView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }
        layer.cornerRadius = Self.avatarCornerRadius
        layer.masksToBounds = true
        addTarget(self, action: #selector(handleTap), for: .touchUpInside)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func setSelected(_ selected: Bool) {
        layer.borderWidth = selected ? Self.selectedBorderWidth : 0
        layer.borderColor = ChatUIKitTheme.colors.textColorLink.cgColor
    }

    @objc private func handleTap() {
        onTap(url)
    }
}

// MARK: - Create Group Handler

private final class CreateGroupHandler: CreateGroupCompletionHandler {
    private let onSuccessBlock: (String) -> Void

    private let onFailureBlock: (Int, String) -> Void

    init(onSuccess: @escaping (String) -> Void, onFailure: @escaping (Int, String) -> Void) {
        self.onSuccessBlock = onSuccess
        self.onFailureBlock = onFailure
    }

    func onSuccess(groupID: String) {
        onSuccessBlock(groupID)
    }

    func onFailure(code: Int, desc: String) {
        onFailureBlock(code, desc)
    }
}
