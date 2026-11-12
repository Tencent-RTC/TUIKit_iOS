import AtomicXCore
import Combine
import SnapKit
import UIKit

final class InviteMemberSheet: UIView {

    struct Pick {
        let userID: String
        let displayName: String
    }

    var onInvite: (([Pick]) -> Void)?
    var onClose: (() -> Void)?

    private enum Source {
        case friends
        case groupMembers
    }

    fileprivate struct Row {
        let userID: String
        let displayName: String
        let avatarURL: String?
        let showsFriendTag: Bool
        let busyStatus: CallParticipantStatus?
    }

    private let header = LightSheetHeader(title: CallKitResources.text("callkit.invite.title"))
    private let tableView = UITableView()
    private let emptyLabel = UILabel()
    private var rows: [Row] = []
    private var picked = Set<String>()
    private var isSubmitting = false
    private let source: Source
    private var cancellables = Set<AnyCancellable>()
    private var memberStore: GroupMemberStore?

    override init(frame: CGRect) {
        let call = CallStore.shared.state.value.activeCall
        source = call.chatGroupId.isEmpty ? .friends : .groupMembers
        super.init(frame: frame)
        setupViews()
        loadRows()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func setupViews() {
        backgroundColor = .white

        header.onAction = { [weak self] in self?.handleActionTap() }
        addSubview(header)
        header.snp.makeConstraints { make in
            make.top.leading.trailing.equalToSuperview()
        }

        tableView.dataSource = self
        tableView.delegate = self
        tableView.rowHeight = 52
        tableView.separatorInset = .zero
        tableView.separatorColor = CallKitTheme.sheetLine
        tableView.tableFooterView = UIView()
        tableView.register(InviteRowCell.self, forCellReuseIdentifier: "InviteRowCell")
        tableView.backgroundColor = .white

        emptyLabel.font = .systemFont(ofSize: 12)
        emptyLabel.textColor = CallKitTheme.sheetText3
        emptyLabel.textAlignment = .center

        [tableView, emptyLabel].forEach { addSubview($0) }
        tableView.snp.makeConstraints { make in
            make.top.equalTo(header.snp.bottom)
            make.leading.trailing.equalToSuperview()
            make.bottom.equalTo(safeAreaLayoutGuide.snp.bottom)
            make.height.equalTo(0)
        }
        emptyLabel.snp.makeConstraints { make in
            make.top.equalTo(header.snp.bottom).offset(18)
            make.leading.trailing.equalToSuperview()
            make.bottom.equalTo(safeAreaLayoutGuide.snp.bottom).offset(-12)
        }

        syncAction()
    }

    private func loadRows() {
        switch source {
        case .friends:
            emptyLabel.text = CallKitResources.text("callkit.invite.empty_friends")
            ContactStore.shared.state
                .subscribe(StatePublisherSelector { $0.friendList.map { "\($0.userID)|\($0.nickname ?? "")" }.joined(separator: ",") })
                .removeDuplicates()
                .receive(on: RunLoop.main)
                .sink { [weak self] _ in self?.reloadFriendRows() }
                .store(in: &cancellables)
            ContactStore.shared.loadFriends { result in
                if case .failure(let error) = result {
                    CallKitLog.warning("loadFriends failed: code=\(error.code) message=\(error.message)")
                }
            }
            reloadFriendRows()
        case .groupMembers:
            emptyLabel.text = CallKitResources.text("callkit.invite.empty_members")
            let groupID = CallStore.shared.state.value.activeCall.chatGroupId
            let store = GroupMemberStore.create(groupID: groupID)
            memberStore = store
            store.state
                .subscribe(StatePublisherSelector { $0.memberList.map(\.userID).joined(separator: ",") })
                .removeDuplicates()
                .receive(on: RunLoop.main)
                .sink { [weak self] _ in self?.reloadGroupRows() }
                .store(in: &cancellables)
            store.loadMembers { result in
                if case .failure(let error) = result {
                    CallKitLog.warning("loadMembers failed: code=\(error.code) message=\(error.message)")
                }
            }
            reloadGroupRows()
        }

        CallStore.shared.state
            .subscribe(StatePublisherSelector { $0.allParticipants.map { "\($0.id):\($0.status.rawValue)" }.joined(separator: ",") })
            .removeDuplicates()
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in
                guard let self else { return }
                switch self.source {
                case .friends: self.reloadFriendRows()
                case .groupMembers: self.reloadGroupRows()
                }
            }
            .store(in: &cancellables)
    }

    private func busyMap() -> [String: CallParticipantStatus] {
        Dictionary(uniqueKeysWithValues: CallStore.shared.state.value.allParticipants.map { ($0.id, $0.status) })
    }

    private func reloadFriendRows() {
        let busy = busyMap()
        rows = ContactStore.shared.state.value.friendList.map { info in
            Row(userID: info.userID,
                displayName: info.nickname?.isEmpty == false ? info.nickname! : info.userID,
                avatarURL: info.avatarURL,
                showsFriendTag: true,
                busyStatus: busy[info.userID])
        }
        finishLoad()
    }

    private func reloadGroupRows() {
        guard let memberStore else { return }
        let selfID = LoginStore.shared.state.value.loginUserInfo?.userID ?? ""
        let busy = busyMap()
        rows = memberStore.state.value.memberList.filter { $0.userID != selfID }.map { member in
            let name = [member.nameCard, member.nickname].compactMap { $0 }.first { !$0.isEmpty } ?? member.userID
            return Row(userID: member.userID,
                       displayName: name,
                       avatarURL: member.avatarURL,
                       showsFriendTag: false,
                       busyStatus: busy[member.userID])
        }
        finishLoad()
    }

    private func finishLoad() {
        emptyLabel.isHidden = !rows.isEmpty
        tableView.isHidden = rows.isEmpty
        let height = min(rows.count, 6) * 52
        tableView.snp.updateConstraints { make in
            make.height.equalTo(height)
        }
        tableView.reloadData()
    }

    private func syncAction() {
        let hasPicks = !picked.isEmpty
        header.setActionTitle(CallKitResources.text(hasPicks ? "callkit.invite.confirm" : "callkit.invite.cancel"),
                              isCancel: !hasPicks)
    }

    private func handleActionTap() {
        guard !isSubmitting else { return }
        guard !picked.isEmpty else {
            onClose?()
            return
        }
        isSubmitting = true
        header.setActionEnabled(false)

        let available = max(0, 9 - CallStore.shared.state.value.allParticipants.count)
        let selected = rows.filter { picked.contains($0.userID) }
        if selected.count > available {
            CallKitToast.show(CallKitResources.text("callkit.invite.limit"))
        }
        onInvite?(selected.prefix(available).map { Pick(userID: $0.userID, displayName: $0.displayName) })
    }

    private func avatar(for urlString: String?, into imageView: UIImageView, tag: String) {
        imageView.image = CallKitResources.image(named: "callkit_default_avatar")
        CallKitAvatarLoader.image(from: urlString) { [weak imageView] image in
            guard let image, let imageView, imageView.accessibilityHint == tag else { return }
            imageView.image = image
        }
    }
}

private final class InviteRowCell: UITableViewCell {

    fileprivate let avatarImageView = UIImageView()
    private let nameLabel = UILabel()
    private let tagLabel = UILabel()
    private let tagContainer = UIView()
    private let checkLabel = CallKitCheckLabel(tint: CallKitTheme.brand)

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        selectionStyle = .none
        backgroundColor = .white

        avatarImageView.layer.cornerRadius = 17
        avatarImageView.clipsToBounds = true
        avatarImageView.contentMode = .scaleAspectFill

        nameLabel.font = .systemFont(ofSize: 15)
        nameLabel.lineBreakMode = .byTruncatingTail
        nameLabel.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)

        tagLabel.font = .systemFont(ofSize: 10)
        tagLabel.text = CallKitResources.text("callkit.invite.friend_tag")
        tagContainer.layer.cornerRadius = 8
        tagContainer.addSubview(tagLabel)
        tagLabel.snp.makeConstraints { make in
            make.edges.equalToSuperview().inset(UIEdgeInsets(top: 1, left: 7, bottom: 1, right: 7))
        }

        [avatarImageView, nameLabel, tagContainer, checkLabel].forEach { contentView.addSubview($0) }
        avatarImageView.snp.makeConstraints { make in
            make.leading.equalToSuperview().offset(16)
            make.centerY.equalToSuperview()
            make.size.equalTo(34)
        }
        nameLabel.snp.makeConstraints { make in
            make.leading.equalTo(avatarImageView.snp.trailing).offset(10)
            make.centerY.equalToSuperview()
        }
        tagContainer.snp.makeConstraints { make in
            make.leading.equalTo(nameLabel.snp.trailing).offset(8)
            make.centerY.equalToSuperview()
        }
        checkLabel.snp.makeConstraints { make in
            make.trailing.equalToSuperview().offset(-16)
            make.centerY.equalToSuperview()
            make.leading.greaterThanOrEqualTo(tagContainer.snp.trailing).offset(8)
        }
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func prepareForReuse() {
        super.prepareForReuse()
        avatarImageView.accessibilityHint = nil
    }

    func configure(row: InviteMemberSheet.Row, isPicked: Bool) {
        nameLabel.text = row.displayName
        tagContainer.isHidden = !row.showsFriendTag
        let busy = row.busyStatus != nil
        nameLabel.textColor = busy ? CallKitTheme.sheetText3 : CallKitTheme.sheetText
        tagLabel.textColor = busy ? CallKitTheme.sheetText3 : CallKitTheme.brand
        tagContainer.backgroundColor = busy ? CallKitTheme.sheetTagBackground : CallKitTheme.brand.withAlphaComponent(0.18)
        avatarImageView.alpha = busy ? 0.5 : 1
        checkLabel.isHidden = !busy && !isPicked
        checkLabel.textColor = busy ? CallKitTheme.sheetText3 : CallKitTheme.brand
    }
}

extension InviteMemberSheet: UITableViewDataSource, UITableViewDelegate {

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        rows.count
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "InviteRowCell", for: indexPath)
        guard let inviteCell = cell as? InviteRowCell else { return cell }
        let row = rows[indexPath.row]
        inviteCell.configure(row: row, isPicked: picked.contains(row.userID))
        inviteCell.avatarImageView.accessibilityHint = row.userID
        avatar(for: row.avatarURL, into: inviteCell.avatarImageView, tag: row.userID)
        return inviteCell
    }

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        let row = rows[indexPath.row]
        if let status = row.busyStatus {
            let key = status == .accept ? "callkit.invite.in_call" : "callkit.invite.waiting"
            CallKitToast.show(String(format: CallKitResources.text(key), row.displayName))
            return
        }
        if picked.remove(row.userID) == nil {
            picked.insert(row.userID)
        }
        tableView.reloadRows(at: [indexPath], with: .none)
        syncAction()
    }
}
