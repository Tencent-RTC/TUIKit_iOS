import UIKit
import SnapKit
import AtomicXCore

final class GroupCallMemberPickerViewController: UIViewController {
    private static let headerBarHeight: CGFloat = 56

    private static let navButtonHorizontalInset: CGFloat = CGFloat(SpacingScheme.bubbleSpacing)

    private static let rowHeight: CGFloat = 56

    private let groupID: String

    private let onConfirm: ([String]) -> Void

    private let memberStore: GroupMemberStore

    private var members: [GroupMember] = []

    private var selectedMemberIDs: Set<String> = []

    private var isLoading = false

    private var isLoadingMore = false

    private var hasMoreData = true

    private let headerBar = UIView()

    private let cancelButton = UIButton(type: .system)

    private let titleLabel = UILabel()

    private let confirmButton = UIButton(type: .system)

    private let loadingIndicator = UIActivityIndicatorView(style: .medium)

    private lazy var tableView: UITableView = {
        let table = UITableView(frame: .zero, style: .plain)
        table.separatorStyle = .none
        table.rowHeight = Self.rowHeight
        table.register(MentionMemberCell.self, forCellReuseIdentifier: MentionMemberCell.reuseIdentifier)
        table.dataSource = self
        table.delegate = self
        return table
    }()

    // MARK: - Init

    init(groupID: String, onConfirm: @escaping ([String]) -> Void) {
        self.groupID = groupID
        self.onConfirm = onConfirm
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

    // MARK: - Actions

    private func constructViewHierarchy() {
        view.addSubview(headerBar)
        headerBar.addSubview(cancelButton)
        headerBar.addSubview(titleLabel)
        headerBar.addSubview(confirmButton)
        view.addSubview(tableView)
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
        tableView.snp.makeConstraints { make in
            make.top.equalTo(headerBar.snp.bottom)
            make.leading.trailing.bottom.equalToSuperview()
        }
        loadingIndicator.snp.makeConstraints { make in
            make.center.equalTo(tableView)
        }
    }

    private func bindInteraction() {
        cancelButton.addTarget(self, action: #selector(handleCancel), for: .touchUpInside)
        confirmButton.addTarget(self, action: #selector(handleConfirm), for: .touchUpInside)
    }

    private func setupViewStyle() {
        let colors = ChatUIKitTheme.colors
        view.backgroundColor = colors.bgColorOperate
        headerBar.backgroundColor = colors.bgColorOperate
        tableView.backgroundColor = colors.bgColorOperate

        titleLabel.text = LocalizedChatString("MentionSelectMember")
        titleLabel.font = FontScheme.caption1Medium
        titleLabel.textColor = colors.textColorPrimary

        cancelButton.setTitle(LocalizedChatString("Cancel"), for: .normal)
        cancelButton.setTitleColor(colors.textColorLink, for: .normal)
        cancelButton.titleLabel?.font = FontScheme.caption1Regular

        confirmButton.setTitle(LocalizedChatString("Confirm"), for: .normal)
        confirmButton.titleLabel?.font = FontScheme.caption1Regular
        updateConfirmButtonState()
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
        tableView.reloadData()
    }

    @objc private func handleCancel() {
        dismiss(animated: true)
    }

    @objc private func handleConfirm() {
        let userIDs = members
            .filter { selectedMemberIDs.contains($0.userID) }
            .map { $0.userID }
        guard !userIDs.isEmpty else { return }
        onConfirm(userIDs)
        dismiss(animated: true)
    }

    private func toggleSelection(_ userID: String) {
        if selectedMemberIDs.contains(userID) {
            selectedMemberIDs.remove(userID)
        } else {
            selectedMemberIDs.insert(userID)
        }
        updateConfirmButtonState()
    }

    private func updateConfirmButtonState() {
        let colors = ChatUIKitTheme.colors
        let enabled = !selectedMemberIDs.isEmpty
        confirmButton.isEnabled = enabled
        confirmButton.setTitleColor(enabled ? colors.textColorLink : colors.textColorTertiary, for: .normal)
    }
}

// MARK: - UITableViewDataSource / Delegate

extension GroupCallMemberPickerViewController: UITableViewDataSource, UITableViewDelegate {

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return members.count
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        guard let cell = tableView.dequeueReusableCell(
            withIdentifier: MentionMemberCell.reuseIdentifier,
            for: indexPath
        ) as? MentionMemberCell else {
            return UITableViewCell()
        }
        let member = members[indexPath.row]
        let name = MentionMemberPickerViewController.displayName(for: member)
        cell.configure(
            name: name,
            avatarURL: member.avatarURL,
            isSelected: selectedMemberIDs.contains(member.userID)
        )
        return cell
    }

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: false)
        let member = members[indexPath.row]
        toggleSelection(member.userID)
        tableView.reloadRows(at: [indexPath], with: .none)
    }

    func tableView(_ tableView: UITableView, willDisplay cell: UITableViewCell, forRowAt indexPath: IndexPath) {
        guard indexPath.row >= members.count - 1 else { return }
        loadMoreMembers()
    }
}
