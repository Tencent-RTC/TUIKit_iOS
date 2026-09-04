import AtomicXCore
import Combine
import SnapKit
import UIKit

final class GroupMemberPickerViewController: ChatSettingBaseViewController {
    enum Mode {
        case addMember(memberStore: GroupMemberStore)
        case removeMember(memberStore: GroupMemberStore, currentUserRole: GroupMemberRole)
        case transferOwner(groupID: String, groupStore: GroupStore, memberStore: GroupMemberStore)
        case muteMembers(memberStore: GroupMemberStore)
        case setAdmin(memberStore: GroupMemberStore)
        case removeAdmin(memberStore: GroupMemberStore)
    }

    private static let muteDurationSeconds: Int64 = 7 * 24 * 60 * 60

    private let mode: Mode

    private var currentUserID: String = ""

    private var allMembers: [GroupMember] = []

    private var friendList: [ContactInfo] = []

    private var currentSelection: [UserPickerItem] = []

    private var cancellables = Set<AnyCancellable>()

    private let pickerView = UserPickerView()

    private let cancelButton = UIButton(type: .custom)

    private let confirmButton = UIButton(type: .custom)

    private var usesNavConfirm: Bool {
        switch mode {
        case .addMember, .removeMember, .transferOwner, .muteMembers, .setAdmin, .removeAdmin:
            return true
        default:
            return false
        }
    }

    init(mode: Mode) {
        self.mode = mode
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        constructViewHierarchy()
        activateConstraints()
        setupViewStyle()
        currentUserID = LoginStore.shared.state.value.loginUserInfo?.userID ?? ""
        pickerView.onSelectionChanged = { [weak self] selectedItems in
            self?.handleSelectionChanged(selectedItems)
        }
        if usesNavConfirm {
            setupNavActions()
        }
        switch mode {
        case .addMember(let memberStore):
            setNavTitle(LocalizedChatString("GroupAddMembers"))
            subscribeFriendList()
            subscribeMemberList(memberStore)
            memberStore.loadMembers(roleList: [.all], completion: nil)
            ContactStore.shared.loadFriends(completion: nil)
        case .removeMember(let memberStore, _):
            setNavTitle(LocalizedChatString("GroupRemoveMembers"))
            subscribeMemberList(memberStore)
            memberStore.loadMembers(roleList: [.all], completion: nil)
        case .transferOwner(_, _, let memberStore):
            setNavTitle(LocalizedChatString("GroupTransferOwner"))
            subscribeMemberList(memberStore)
            memberStore.loadMembers(roleList: [.all], completion: nil)
        case .muteMembers(let memberStore):
            setNavTitle(LocalizedChatString("GroupManageSelectMuted"))
            subscribeMemberList(memberStore)
            memberStore.loadMembers(roleList: [.all], completion: nil)
        case .setAdmin(let memberStore):
            setNavTitle(LocalizedChatString("GroupManageSelectAdmin"))
            subscribeMemberList(memberStore)
            memberStore.loadMembers(roleList: [.all], completion: nil)
        case .removeAdmin(let memberStore):
            setNavTitle(LocalizedChatString("GroupManageRemoveAdmin"))
            subscribeMemberList(memberStore)
            memberStore.loadMembers(roleList: [.all], completion: nil)
        }
        refreshPicker()
        updateConfirmButton()
    }

    private func constructViewHierarchy() {
        view.addSubview(pickerView)
    }

    private func activateConstraints() {
        pickerView.snp.makeConstraints { make in
            make.top.equalTo(contentTopItem)
            make.leading.trailing.bottom.equalToSuperview()
        }
    }

    private func setupViewStyle() {
        view.backgroundColor = TUIChatKitTheme.colors.bgColorOperate
    }

    private func setupNavActions() {
        let colors = TUIChatKitTheme.colors
        setNavBackHidden(true)
        cancelButton.setTitle(LocalizedChatString("Cancel"), for: .normal)
        cancelButton.titleLabel?.font = FontScheme.caption1Regular
        cancelButton.setTitleColor(colors.textColorLink, for: .normal)
        cancelButton.addTarget(self, action: #selector(handleCancel), for: .touchUpInside)
        setNavLeadingView(cancelButton)
        confirmButton.setTitle(LocalizedChatString("Confirm"), for: .normal)
        confirmButton.titleLabel?.font = FontScheme.caption1Regular
        confirmButton.addTarget(self, action: #selector(handleConfirm), for: .touchUpInside)
        setNavTrailingView(confirmButton)
    }

    private func subscribeFriendList() {
        ContactStore.shared.state
            .subscribe(StatePublisherSelector(keyPath: \ContactState.friendList))
            .receive(on: DispatchQueue.main)
            .sink { [weak self] friendList in
                self?.friendList = friendList
                self?.refreshPicker()
            }
            .store(in: &cancellables)
    }

    private func subscribeMemberList(_ memberStore: GroupMemberStore) {
        memberStore.state
            .subscribe(StatePublisherSelector(keyPath: \GroupMemberState.memberList))
            .receive(on: DispatchQueue.main)
            .sink { [weak self] memberList in
                self?.allMembers = memberList
                self?.refreshPicker()
            }
            .store(in: &cancellables)
    }

    private func refreshPicker() {
        switch mode {
        case .addMember:
            let memberIDs = Set(allMembers.map { $0.userID })
            let items = friendList.compactMap { contact -> UserPickerItem? in
                guard !memberIDs.contains(contact.userID) else { return nil }
                return UserPickerItem(
                    userID: contact.userID,
                    avatarURL: contact.avatarURL,
                    title: chatSettingContactDisplayName(contact)
                )
            }
            pickerView.configure(userList: items, maxCount: 0)
        case .removeMember(_, let currentUserRole):
            let items = allMembers.compactMap { member -> UserPickerItem? in
                guard Self.canRemove(memberRole: member.role, currentUserRole: currentUserRole) else { return nil }
                let subtitle = member.role == .admin ? LocalizedChatString("MembersRoleAdmin") : nil
                return UserPickerItem(
                    userID: member.userID,
                    avatarURL: member.avatarURL,
                    title: chatSettingMemberDisplayName(member),
                    subtitle: subtitle
                )
            }
            pickerView.configure(userList: items, maxCount: 0)
        case .transferOwner:
            let items = allMembers.compactMap { member -> UserPickerItem? in
                if member.userID == currentUserID { return nil }
                let subtitle = member.role == .admin ? LocalizedChatString("MembersRoleAdmin") : nil
                return UserPickerItem(
                    userID: member.userID,
                    avatarURL: member.avatarURL,
                    title: chatSettingMemberDisplayName(member),
                    subtitle: subtitle
                )
            }
            pickerView.configure(userList: items, maxCount: 1)
        case .muteMembers:
            let items = allMembers.compactMap { member -> UserPickerItem? in
                if member.role == .owner || member.isMuted { return nil }
                let subtitle = member.role == .admin ? LocalizedChatString("MembersRoleAdmin") : nil
                return UserPickerItem(
                    userID: member.userID,
                    avatarURL: member.avatarURL,
                    title: chatSettingMemberDisplayName(member),
                    subtitle: subtitle
                )
            }
            pickerView.configure(userList: items, maxCount: 0)
        case .setAdmin:
            let items = allMembers.compactMap { member -> UserPickerItem? in
                guard member.role == .member else { return nil }
                return UserPickerItem(
                    userID: member.userID,
                    avatarURL: member.avatarURL,
                    title: chatSettingMemberDisplayName(member)
                )
            }
            pickerView.configure(userList: items, maxCount: 0)
        case .removeAdmin:
            let items = allMembers.compactMap { member -> UserPickerItem? in
                guard member.role == .admin else { return nil }
                return UserPickerItem(
                    userID: member.userID,
                    avatarURL: member.avatarURL,
                    title: chatSettingMemberDisplayName(member),
                    subtitle: LocalizedChatString("MembersRoleAdmin")
                )
            }
            pickerView.configure(userList: items, maxCount: 0)
        }
    }

    private static func canRemove(memberRole: GroupMemberRole, currentUserRole: GroupMemberRole) -> Bool {
        switch currentUserRole {
        case .owner:
            return memberRole != .owner
        case .admin:
            return memberRole == .member
        default:
            return false
        }
    }

    private func handleSelectionChanged(_ selectedItems: [UserPickerItem]) {
        currentSelection = selectedItems
        updateConfirmButton()
    }

    private func updateConfirmButton() {
        guard usesNavConfirm else { return }
        let colors = TUIChatKitTheme.colors
        let hasSelection = !currentSelection.isEmpty
        confirmButton.setTitleColor(hasSelection ? colors.textColorLink : colors.textColorDisable, for: .normal)
    }

    @objc private func handleCancel() {
        closePage()
    }

    @objc private func handleConfirm() {
        let selectedIDs = currentSelection.map { $0.userID }
        guard !selectedIDs.isEmpty else { return }
        switch mode {
        case .addMember(let memberStore):
            memberStore.addMember(userIDList: selectedIDs, completion: nil)
        case .removeMember(let memberStore, _):
            memberStore.deleteMember(userIDList: selectedIDs, completion: nil)
        case .transferOwner(let groupID, let groupStore, _):
            presentTransferOwnerConfirmation(groupID: groupID, groupStore: groupStore, newOwnerID: selectedIDs[0])
            return
        case .muteMembers(let memberStore):
            for userID in selectedIDs {
                memberStore.muteMember(userID: userID, time: Self.muteDurationSeconds, completion: nil)
            }
        case .setAdmin(let memberStore):
            for userID in selectedIDs {
                memberStore.setMemberRole(userID: userID, role: .admin, completion: nil)
            }
        case .removeAdmin(let memberStore):
            for userID in selectedIDs {
                memberStore.setMemberRole(userID: userID, role: .member, completion: nil)
            }
        }
        closePage()
    }

    private func presentTransferOwnerConfirmation(groupID: String, groupStore: GroupStore, newOwnerID: String) {
        let alert = UIAlertController(
            title: LocalizedChatString("GroupTransferOwnerConfirmTips"),
            message: nil,
            preferredStyle: .alert
        )
        alert.addAction(UIAlertAction(title: LocalizedChatString("Confirm"), style: .destructive) { [weak self] _ in
            groupStore.changeOwner(groupID: groupID, newOwnerID: newOwnerID, completion: nil)
            self?.closePage()
        })
        alert.addAction(UIAlertAction(title: LocalizedChatString("Cancel"), style: .cancel))
        present(alert, animated: true)
    }

    private func closePage() {
        if let navigationController = navigationController {
            navigationController.popViewController(animated: true)
        } else {
            dismiss(animated: true)
        }
    }
}
