import SnapKit
import UIKit

final class PusherAudienceManageView: BottomSheetView {
    var onToggleFollow: ((String) -> Void)?
    var onToggleMessagePermission: ((String) -> Void)?
    var onRemoveFromRoom: ((String) -> Void)?

    private enum Metrics {
        static let contentHeight: CGFloat = 191
    }

    private let actionStack = UIStackView()
    private let followItem = PusherSettingsItemView(
        title: LiveKitResources.localizedString("tuilivekit.pusher.audience.follow"),
        assetName: "livekit_pusher_audience_follow"
    )
    private let muteItem = PusherSettingsItemView(
        title: LiveKitResources.localizedString("tuilivekit.pusher.audience.mute"),
        assetName: "livekit_pusher_audience_mute"
    )
    private let removeItem = PusherSettingsItemView(
        title: LiveKitResources.localizedString("tuilivekit.pusher.audience.remove"),
        assetName: "livekit_pusher_audience_remove",
        iconSize: CGSize(width: 21, height: 21)
    )
    private var selectedUserID: String?

    override var sheetHeight: CGFloat {
        Metrics.contentHeight + safeAreaInsets.bottom
    }

    override init(frame: CGRect) {
        super.init(frame: frame)
        configureUI()
    }

    override func safeAreaInsetsDidChange() {
        super.safeAreaInsetsDidChange()
        updateSheetHeight(animated: false)
    }

    func show(user: PusherAudienceStore.User, state: PusherAudienceStore.State) {
        selectedUserID = user.userID
        render(user: user, state: state)
        present()
    }

    func bind(_ state: PusherAudienceStore.State) {
        guard let selectedUserID else { return }
        guard let user = state.users.first(where: { $0.userID == selectedUserID }) else {
            if !isHidden { dismiss() }
            return
        }
        render(user: user, state: state)
    }

    func completeAction(userID: String, action: PusherAudienceStore.Action, succeeded: Bool) {
        guard selectedUserID == userID, succeeded else { return }
        switch action {
        case .mute, .unmute, .remove:
            dismiss()
        case .follow, .unfollow:
            break
        }
    }

    override func sheetWillDismiss() {
        selectedUserID = nil
    }

    private func configureUI() {
        actionStack.axis = .horizontal
        actionStack.distribution = .fillEqually
        [followItem, muteItem, removeItem].forEach(actionStack.addArrangedSubview)
        contentView.addSubview(actionStack)

        followItem.addTarget(self, action: #selector(handleFollow), for: .touchUpInside)
        muteItem.addTarget(self, action: #selector(handleMute), for: .touchUpInside)
        removeItem.addTarget(self, action: #selector(handleRemove), for: .touchUpInside)

        actionStack.snp.makeConstraints { make in
            make.leading.trailing.equalToSuperview().inset(16)
            make.top.equalToSuperview().offset(75)
            make.height.equalTo(84)
        }
    }

    private func render(user: PusherAudienceStore.User, state: PusherAudienceStore.State) {
        sheetTitle = user.userName.isEmpty ? user.userID : user.userName

        let followStatus = state.followStatus(for: user.userID)
        followItem.setIcon(assetName: followStatus == .following
            ? "livekit_pusher_audience_followed"
            : "livekit_pusher_audience_follow")
        followItem.setTitle(LiveKitResources.localizedString(
            followStatus == .following
                ? "tuilivekit.pusher.audience.following"
                : "tuilivekit.pusher.audience.follow"
        ))

        let isMuted = state.mutedUserIDs.contains(user.userID)
        muteItem.setTitle(LiveKitResources.localizedString(
            isMuted
                ? "tuilivekit.pusher.audience.unmute"
                : "tuilivekit.pusher.audience.mute"
        ))

        let pendingAction = state.pendingActionByUserID[user.userID]
        let isPending = pendingAction != nil
        followItem.isEnabled = !isPending && followStatus != .unknown
        muteItem.isEnabled = !isPending
        removeItem.isEnabled = !isPending
        followItem.alpha = pendingAction == .follow || pendingAction == .unfollow ? 0.46 : 1
        muteItem.alpha = pendingAction == .mute || pendingAction == .unmute ? 0.46 : 1
        removeItem.alpha = pendingAction == .remove ? 0.46 : 1
    }

    @objc private func handleFollow() {
        perform(onToggleFollow)
    }

    @objc private func handleMute() {
        perform(onToggleMessagePermission)
    }

    @objc private func handleRemove() {
        perform(onRemoveFromRoom)
    }

    private func perform(_ action: ((String) -> Void)?) {
        if let selectedUserID { action?(selectedUserID) }
    }
}
