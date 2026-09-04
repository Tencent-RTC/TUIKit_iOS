import UIKit
import SnapKit
import AtomicXCore

final class MentionMemberPickerViewController: UIViewController {
    private static let headerBarHeight: CGFloat = 56

    private static let navButtonHorizontalInset: CGFloat = 10

    private static let separatorHeight: CGFloat = 0.5

    private static let atAllRowHeight: CGFloat = 56

    private static let atAllCheckboxSize: CGFloat = 16

    private static let atAllCheckboxLeadingInset: CGFloat = CGFloat(SpacingScheme.bubbleSpacing)

    private static let atAllAvatarLeadingGap: CGFloat = 10

    private static let atAllLabelLeadingGap: CGFloat = 13

    private static let atAllLabelTrailingInset: CGFloat = 26

    private let groupID: String

    private let atPosition: Int

    private let onMembersSelected: ([MentionInfo], Int) -> Void

    private let memberStore: GroupMemberStore

    private var members: [GroupMember] = []

    private var selectedMemberIDs: Set<String> = []

    private var isAtAllSelected = false

    private var isLoading = false

    private var isLoadingMore = false

    private var hasMoreData = true

    private let headerBar = UIView()

    private let cancelButton = UIButton(type: .system)

    private let titleLabel = UILabel()

    private let confirmButton = UIButton(type: .system)

    private let atAllRow = UIControl()

    private let atAllCheckbox = SelectionCheckBox()

    private let atAllAvatar = ChatAvatarView(size: .m, isRound: false)

    private let atAllLabel = UILabel()

    private let separatorView = UIView()

    private let loadingIndicator = UIActivityIndicatorView(style: .medium)

    private let pickerView = UserPickerView()

    // MARK: - Init

    init(groupID: String,
         atPosition: Int,
         onMembersSelected: @escaping ([MentionInfo], Int) -> Void) {
        self.groupID = groupID
        self.atPosition = atPosition
        self.onMembersSelected = onMembersSelected
        self.memberStore = GroupMemberStore.create(groupID: groupID)
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    // MARK: - Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()
        constructViewHierarchy()
        activateConstraints()
        bindInteraction()
        setupViewStyle()
        loadMembers()
    }

    // MARK: - Display Name (nameCard > nickname > userID)

    static func displayName(for member: GroupMember) -> String {
        if let nameCard = member.nameCard, !nameCard.isEmpty { return nameCard }
        if let nickname = member.nickname, !nickname.isEmpty { return nickname }
        return member.userID
    }

    private func constructViewHierarchy() {
        view.addSubview(headerBar)
        headerBar.addSubview(cancelButton)
        headerBar.addSubview(titleLabel)
        headerBar.addSubview(confirmButton)
        view.addSubview(separatorView)
        view.addSubview(atAllRow)
        atAllRow.addSubview(atAllCheckbox)
        atAllRow.addSubview(atAllAvatar)
        atAllRow.addSubview(atAllLabel)
        view.addSubview(pickerView)
        view.addSubview(loadingIndicator)
    }

    private func activateConstraints() {
        headerBar.snp.makeConstraints { make in
            make.top.equalTo(view.safeAreaLayoutGuide)
            make.leading.trailing.equalToSuperview()
            make.height.equalTo(Self.headerBarHeight)
        }
        cancelButton.snp.makeConstraints { make in
            make.leading.equalToSuperview().offset(Self.navButtonHorizontalInset)
            make.centerY.equalToSuperview()
        }
        confirmButton.snp.makeConstraints { make in
            make.trailing.equalToSuperview().offset(-Self.navButtonHorizontalInset)
            make.centerY.equalToSuperview()
        }
        titleLabel.snp.makeConstraints { make in
            make.center.equalToSuperview()
        }
        separatorView.snp.makeConstraints { make in
            make.top.equalTo(headerBar.snp.bottom)
            make.leading.trailing.equalToSuperview()
            make.height.equalTo(Self.separatorHeight)
        }
        atAllRow.snp.makeConstraints { make in
            make.top.equalTo(separatorView.snp.bottom)
            make.leading.trailing.equalToSuperview()
            make.height.equalTo(Self.atAllRowHeight)
        }
        atAllCheckbox.snp.makeConstraints { make in
            make.leading.equalToSuperview().offset(Self.atAllCheckboxLeadingInset)
            make.centerY.equalToSuperview()
            make.width.height.equalTo(Self.atAllCheckboxSize)
        }
        atAllAvatar.snp.makeConstraints { make in
            make.leading.equalTo(atAllCheckbox.snp.trailing).offset(Self.atAllAvatarLeadingGap)
            make.centerY.equalToSuperview()
            make.width.height.equalTo(ChatAvatarSize.m.size)
        }
        atAllLabel.snp.makeConstraints { make in
            make.leading.equalTo(atAllAvatar.snp.trailing).offset(Self.atAllLabelLeadingGap)
            make.centerY.equalToSuperview()
            make.trailing.lessThanOrEqualToSuperview().offset(-Self.atAllLabelTrailingInset)
        }
        pickerView.snp.makeConstraints { make in
            make.top.equalTo(atAllRow.snp.bottom)
            make.leading.trailing.bottom.equalToSuperview()
        }
        loadingIndicator.snp.makeConstraints { make in
            make.center.equalTo(pickerView)
        }
    }

    private func bindInteraction() {
        cancelButton.addTarget(self, action: #selector(handleCancel), for: .touchUpInside)
        confirmButton.addTarget(self, action: #selector(handleConfirm), for: .touchUpInside)
        atAllRow.addTarget(self, action: #selector(handleAtAll), for: .touchUpInside)
        pickerView.onSelectionChanged = { [weak self] selection in
            self?.selectedMemberIDs = Set(selection.map { $0.userID })
        }
        pickerView.onReachEnd = { [weak self] in
            self?.loadMoreMembers()
        }
    }

    private func setupViewStyle() {
        let colors = TUIChatKitTheme.colors
        view.backgroundColor = colors.bgColorInput
        headerBar.backgroundColor = colors.bgColorOperate
        atAllRow.backgroundColor = colors.bgColorOperate
        separatorView.backgroundColor = colors.strokeColorPrimary

        titleLabel.text = LocalizedChatString("MentionSelectMember")
        titleLabel.font = FontScheme.caption1Bold
        titleLabel.textColor = colors.textColorPrimary

        cancelButton.setTitle(LocalizedChatString("Cancel"), for: .normal)
        cancelButton.setTitleColor(colors.textColorLink, for: .normal)
        cancelButton.titleLabel?.font = FontScheme.caption1Regular

        confirmButton.setTitle(LocalizedChatString("Confirm"), for: .normal)
        confirmButton.setTitleColor(colors.textColorLink, for: .normal)
        confirmButton.titleLabel?.font = FontScheme.caption1Regular

        atAllAvatar.configure(avatarURL: nil, fallbackName: LocalizedChatString("MentionAll"))
        atAllLabel.text = "@\(LocalizedChatString("MentionAll"))"
        atAllLabel.font = FontScheme.caption2Regular
        atAllLabel.textColor = colors.textColorPrimary
    }

    private func loadMembers() {
        guard !isLoading else { return }
        isLoading = true
        loadingIndicator.startAnimating()
        memberStore.loadMembers(roleList: [.all]) { [weak self] result in
            DispatchQueue.main.async {
                guard let self = self else { return }
                self.isLoading = false
                self.loadingIndicator.stopAnimating()
                if case .success = result {
                    self.refreshMembersFromState()
                }
            }
        }
    }

    private func loadMoreMembers() {
        guard !isLoadingMore, hasMoreData else { return }
        isLoadingMore = true
        memberStore.loadMoreMembers { [weak self] result in
            DispatchQueue.main.async {
                guard let self = self else { return }
                self.isLoadingMore = false
                switch result {
                case .success:
                    self.refreshMembersFromState()
                case .failure:
                    self.hasMoreData = false
                }
            }
        }
    }

    private func refreshMembersFromState() {
        let newMembers = memberStore.state.value.memberList
        if newMembers.count == members.count {
            hasMoreData = false
        }
        members = newMembers
        pickerView.configure(
            userList: members.map {
                UserPickerItem(userID: $0.userID, avatarURL: $0.avatarURL, title: Self.displayName(for: $0))
            },
            maxCount: 0
        )
    }

    @objc private func handleCancel() {
        dismiss(animated: true)
    }

    @objc private func handleConfirm() {
        var mentionInfos: [MentionInfo] = []
        if isAtAllSelected {
            mentionInfos.append(MentionInfo.create(
                userID: MentionInfo.atAllUserID,
                displayName: LocalizedChatString("MentionAll"),
                atPosition: atPosition
            ))
        }
        mentionInfos.append(contentsOf: members
            .filter { selectedMemberIDs.contains($0.userID) }
            .map { member in
                MentionInfo.create(
                    userID: member.userID,
                    displayName: Self.displayName(for: member),
                    atPosition: atPosition
                )
            })
        onMembersSelected(mentionInfos, atPosition)
        dismiss(animated: true)
    }

    @objc private func handleAtAll() {
        isAtAllSelected.toggle()
        atAllCheckbox.isChecked = isAtAllSelected
    }
}
