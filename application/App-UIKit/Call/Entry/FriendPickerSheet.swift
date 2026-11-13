import AtomicXCore
import Combine
import Kingfisher
import SnapKit
import UIKit

/// G1 friend-picker bottom sheet: multi-select friends from `ContactStore.friendList` and merge
/// them into the callee ID list. Mirrors `openFriendPicker` in the design demo:
/// manually typed IDs are kept, selected friends append after them, the top-right action
/// reads "cancel" (red) when nothing is selected and "confirm" (brand) otherwise.
final class FriendPickerSheet: NSObject {

    private let state = CallEntryState.shared
    private var cancellables = Set<AnyCancellable>()

    private var friends: [ContactInfo] = []
    private var pickedIDs: Set<String> = []
    private var sheet: CallAccessSheet?
    private let tableView = UITableView(frame: .zero, style: .plain)
    private let emptyLabel = UILabel()
    private var tableHeightConstraint: Constraint?

    func present(in host: UIView, onDone: @escaping () -> Void) {
        pickedIDs = Set(state.userIDs)

        let sheet = CallAccessSheet(title: CallAccessText.friendPickerTitle, actionTitle: CallAccessText.sheetCancel, isCancelAction: true) { [weak self] in
            guard let self else { return }
            // Demo: when the merged list exceeds the limit the sheet stays open.
            if self.confirmSelection() {
                self.sheet?.dismiss()
            }
        }
        self.sheet = sheet
        sheet.onDismiss = onDone
        sheet.setContent(makeContent())
        sheet.present(in: host)
        loadFriends()
    }

    private func makeContent() -> UIView {
        let container = UIView()

        // .friend-pick-empty：12px text-3，padding 18 0 6
        emptyLabel.text = CallAccessText.friendPickerEmpty
        emptyLabel.font = .systemFont(ofSize: 12)
        emptyLabel.textColor = CallAccessTheme.text3
        emptyLabel.textAlignment = .center
        emptyLabel.isHidden = true

        tableView.register(FriendPickerCell.self, forCellReuseIdentifier: FriendPickerCell.reuseID)
        tableView.dataSource = self
        tableView.delegate = self
        tableView.rowHeight = 52
        tableView.separatorStyle = .none
        tableView.tableFooterView = UIView()

        container.addSubview(tableView)
        container.addSubview(emptyLabel)
        tableView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
            tableHeightConstraint = make.height.equalTo(Self.emptyHeight).constraint
        }
        emptyLabel.snp.makeConstraints { make in
            make.center.equalToSuperview()
        }
        return container
    }

    private func loadFriends() {
        ContactStore.shared.state
            .subscribe()
            .receive(on: DispatchQueue.main)
            .sink { [weak self] contactState in
                self?.friends = contactState.friendList
                self?.reload()
            }
            .store(in: &cancellables)
        ContactStore.shared.loadFriends { [weak self] result in
            if case .failure(let error) = result {
                CallAccessToast.show(String(format: CallAccessText.callFailed, "\(error.code) \(error.message)"))
                self?.reload()
            }
        }
    }

    private func reload() {
        emptyLabel.isHidden = !friends.isEmpty
        // html 无最小高度：内容多高就多高（空态只留 empty 文案的紧凑高度）
        tableHeightConstraint?.update(offset: friends.isEmpty ? Self.emptyHeight : CGFloat(friends.count) * Self.rowHeight)
        tableView.reloadData()
        syncAction()
    }

    private func syncAction() {
        let manualIDs = state.userIDs.filter { id in !friends.contains { $0.userID == id } }
        let pickedFriends = friends.filter { pickedIDs.contains($0.userID) }
        let hasSelection = !pickedFriends.isEmpty || !manualIDs.isEmpty
        sheet?.setAction(title: hasSelection ? CallAccessText.sheetConfirm : CallAccessText.sheetCancel,
                         isCancel: !hasSelection)
    }

    private static let rowHeight: CGFloat = 52
    private static let emptyHeight: CGFloat = 42

    /// Merges the manual IDs and picked friends into `state.userIDs`. Returns false when the
    /// merged list exceeds the limit (demo keeps the sheet open in that case).
    @discardableResult
    private func confirmSelection() -> Bool {
        // Manual (typed) IDs stay in front, friends follow contact order (demo behavior).
        let manualIDs = state.userIDs.filter { id in !friends.contains { $0.userID == id } }
        let selectedFriends = friends.filter { pickedIDs.contains($0.userID) }.map(\.userID)
        var next = manualIDs
        for id in selectedFriends where !next.contains(where: { $0.lowercased() == id.lowercased() }) {
            next.append(id)
        }
        if next.count > CallEntryState.maxCalleeIDs {
            CallAccessToast.show(CallAccessText.callTooMany)
            return false
        }
        state.userIDs = next
        return true
    }
}

extension FriendPickerSheet: UITableViewDataSource, UITableViewDelegate {

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        friends.count
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: FriendPickerCell.reuseID, for: indexPath) as! FriendPickerCell
        let friend = friends[indexPath.row]
        let name = friend.friendRemark?.isEmpty == false ? friend.friendRemark!
            : (friend.nickname?.isEmpty == false ? friend.nickname! : friend.userID)
        cell.configure(name: name,
                       avatarURL: friend.avatarURL,
                       isSelected: pickedIDs.contains(friend.userID),
                       showsSeparator: indexPath.row > 0)
        return cell
    }

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: false)
        let friend = friends[indexPath.row]
        if pickedIDs.contains(friend.userID) {
            pickedIDs.remove(friend.userID)
        } else {
            let manualCount = state.userIDs.filter { id in !friends.contains { $0.userID == id } }.count
            if manualCount + pickedIDs.count >= CallEntryState.maxCalleeIDs {
                CallAccessToast.show(CallAccessText.callTooMany)
                return
            }
            pickedIDs.insert(friend.userID)
        }
        tableView.reloadRows(at: [indexPath], with: .none)
        syncAction()
    }
}

/// `.friend-pick-row`: 34pt avatar + single-line name + friend tag + trailing check;
/// a selected row tints the name brand and semibold (.opt-row.on).
private final class FriendPickerCell: UITableViewCell {

    static let reuseID = "FriendPickerCell"

    private let avatarImageView = UIImageView()
    private let nameLabel = UILabel()
    private let tagLabel = UILabel()
    private let checkLabel = UILabel()
    private let separator = UIView()

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        selectionStyle = .none

        avatarImageView.layer.cornerRadius = 17
        avatarImageView.clipsToBounds = true
        avatarImageView.backgroundColor = CallAccessTheme.brandSoft
        avatarImageView.contentMode = .scaleAspectFill

        nameLabel.font = .systemFont(ofSize: 15)
        nameLabel.textColor = CallAccessTheme.text
        nameLabel.lineBreakMode = .byTruncatingTail

        // .friend-pick-tag: brand-soft capsule, 10px
        tagLabel.text = CallAccessText.entryFriends
        tagLabel.font = .systemFont(ofSize: 10)
        tagLabel.textColor = CallAccessTheme.brand
        tagLabel.backgroundColor = CallAccessTheme.brandSoft
        tagLabel.textAlignment = .center
        tagLabel.layer.cornerRadius = 9
        tagLabel.clipsToBounds = true
        tagLabel.snp.makeConstraints { make in
            make.height.equalTo(18)
            make.width.greaterThanOrEqualTo(34)
        }

        checkLabel.text = "✓"
        checkLabel.font = .systemFont(ofSize: 15, weight: .bold)
        checkLabel.textColor = CallAccessTheme.brand

        separator.backgroundColor = CallAccessTheme.line

        [avatarImageView, nameLabel, tagLabel, checkLabel, separator].forEach { contentView.addSubview($0) }
        avatarImageView.snp.makeConstraints { make in
            make.leading.equalToSuperview()
            make.centerY.equalToSuperview()
            make.size.equalTo(34)
        }
        nameLabel.snp.makeConstraints { make in
            make.leading.equalTo(avatarImageView.snp.trailing).offset(10)
            make.centerY.equalToSuperview()
        }
        nameLabel.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        tagLabel.snp.makeConstraints { make in
            make.leading.equalTo(nameLabel.snp.trailing).offset(6)
            make.centerY.equalToSuperview()
            make.trailing.lessThanOrEqualTo(checkLabel.snp.leading).offset(-8)
        }
        tagLabel.setContentHuggingPriority(.required, for: .horizontal)
        checkLabel.snp.makeConstraints { make in
            // .friend-pick-row: 12pt trailing inset so the check does not hug the panel edge
            make.trailing.equalToSuperview().offset(-12)
            make.centerY.equalToSuperview()
        }
        separator.snp.makeConstraints { make in
            make.leading.trailing.bottom.equalToSuperview()
            make.height.equalTo(CallAccessTheme.hairline)
        }
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func configure(name: String, avatarURL: String?, isSelected: Bool, showsSeparator: Bool) {
        nameLabel.text = name
        nameLabel.textColor = isSelected ? CallAccessTheme.brand : CallAccessTheme.text
        nameLabel.font = .systemFont(ofSize: 15, weight: isSelected ? .semibold : .regular)
        checkLabel.isHidden = !isSelected
        separator.isHidden = !showsSeparator
        if let avatarURL, let url = URL(string: avatarURL), !avatarURL.isEmpty {
            avatarImageView.kf.setImage(with: url)
        } else {
            avatarImageView.image = nil
        }
    }
}
