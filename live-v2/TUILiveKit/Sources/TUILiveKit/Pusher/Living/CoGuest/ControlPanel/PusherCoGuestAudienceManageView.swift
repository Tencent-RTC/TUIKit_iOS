import AtomicXCore
import SnapKit
import UIKit

/// Drawer opened by tapping a connected guest's video: mute and disconnect.
final class PusherCoGuestAudienceManageView: BottomSheetView {
    weak var actionHandler: PusherCoGuestActionHandling?

    private enum Metrics {
        static let additionalBottomSpacing: CGFloat = 12
        static let designPanelHeight: CGFloat = 170 + additionalBottomSpacing
        static let contentHeight: CGFloat = 136 + additionalBottomSpacing
        static let minimumPanelHeight: CGFloat = 150 + additionalBottomSpacing
    }

    private let titleLabel = LiveText(.dialogTitle, alignment: .center)
    private let actionStack = UIStackView()
    private let microphoneControl = PusherCoGuestAudienceManageItemControl()
    private let disconnectControl = PusherCoGuestAudienceManageItemControl()
    private var selectedUserID: String?
    private var isAwaitingActionCompletion = false
    private var didObservePendingAction = false

    override var sheetHeight: CGFloat {
        max(Metrics.minimumPanelHeight, Metrics.contentHeight + safeAreaInsets.bottom)
    }

    override init(frame: CGRect) {
        super.init(frame: frame)
        configureUI()
    }

    override func safeAreaInsetsDidChange() {
        super.safeAreaInsetsDidChange()
        updateSheetHeight(animated: false)
    }

    func show(user: PusherCoGuestStore.User, isPending: Bool) {
        selectedUserID = user.userID
        isAwaitingActionCompletion = false
        didObservePendingAction = false
        render(user: user, isPending: isPending)
        present()
    }

    func bind(_ state: PusherCoGuestStore.State) {
        guard let selectedUserID else { return }
        guard let user = state.connected.first(where: { $0.userID == selectedUserID }) else {
            dismiss()
            return
        }
        let isPending = state.pendingUserIDs.contains(selectedUserID)
        if isAwaitingActionCompletion {
            didObservePendingAction = didObservePendingAction || isPending
            if didObservePendingAction, !isPending {
                dismiss()
                return
            }
        }
        render(user: user, isPending: isPending)
    }

    private func configureUI() {
        titleLabel.lineBreakMode = .byTruncatingTail
        contentView.addSubview(titleLabel)

        actionStack.axis = .horizontal
        actionStack.distribution = .equalSpacing
        actionStack.alignment = .fill
        [microphoneControl, disconnectControl].forEach(actionStack.addArrangedSubview)
        contentView.addSubview(actionStack)

        [(microphoneControl, 80), (disconnectControl, 80)].forEach { control, width in
            control.snp.makeConstraints { $0.width.equalTo(width) }
        }
        microphoneControl.addAction(UIAction { [weak self] _ in self?.perform { $0.toggleRemoteMicrophone(userID: $1) } }, for: .touchUpInside)
        disconnectControl.addAction(UIAction { [weak self] _ in self?.perform { $0.disconnect(userID: $1) } }, for: .touchUpInside)

        titleLabel.snp.makeConstraints { make in
            make.leading.trailing.equalToSuperview().inset(20)
            make.top.equalToSuperview().offset(27)
            make.height.equalTo(22)
        }
        actionStack.snp.makeConstraints { make in
            make.centerX.equalToSuperview()
            make.leading.greaterThanOrEqualToSuperview().offset(20)
            make.trailing.lessThanOrEqualToSuperview().offset(-20)
            make.width.equalTo(200).priority(.high)
            make.top.equalToSuperview().offset(70)
            make.height.equalTo(72)
        }
    }

    private func render(user: PusherCoGuestStore.User, isPending: Bool) {
        titleLabel.text = LiveKitResources.localizedFormat(
            "tuilivekit.pusher.coguest.manage_user",
            user.userName
        )
        let isMicrophoneOn = user.allowOpenMicrophone && user.microphoneStatus == .on
        let actions = [
            (microphoneControl, isMicrophoneOn ? "tuilivekit.pusher.coguest.mute_user" : "tuilivekit.pusher.coguest.unmute_user",
             isMicrophoneOn ? "livekit_coguest_action_mic" : "livekit_coguest_action_mic_off", PusherCoGuestManageStyle.deviceForeground),
            (disconnectControl, "tuilivekit.pusher.coguest.disconnect_user", "livekit_coguest_action_disconnect",
             PusherCoGuestManageStyle.disconnectForeground),
        ]
        actions.forEach { $0.bind(title: LiveKitResources.localizedString($1), assetName: $2, titleColor: $3) }

        [microphoneControl, disconnectControl].forEach {
            $0.isEnabled = !isPending
            $0.alpha = isPending ? 0.46 : 1
        }
    }

    private func perform(_ action: (PusherCoGuestActionHandling, String) -> Void) {
        guard let actionHandler, let selectedUserID else { return }
        isAwaitingActionCompletion = true
        didObservePendingAction = false
        action(actionHandler, selectedUserID)
        if !didObservePendingAction {
            isAwaitingActionCompletion = false
        }
    }

    override func sheetWillDismiss() {
        selectedUserID = nil
        isAwaitingActionCompletion = false
        didObservePendingAction = false
    }
}

private final class PusherCoGuestAudienceManageItemControl: UIControl {
    private let iconView = UIImageView()
    private let titleLabel = LiveText(.control, alignment: .center)

    override init(frame: CGRect) {
        super.init(frame: frame)
        iconView.contentMode = .scaleAspectFit
        titleLabel.lineBreakMode = .byTruncatingTail
        addSubview(iconView)
        addSubview(titleLabel)

        iconView.snp.makeConstraints { make in
            make.top.centerX.equalToSuperview()
            make.size.equalTo(44)
        }
        titleLabel.snp.makeConstraints { make in
            make.leading.trailing.equalToSuperview()
            make.top.equalTo(iconView.snp.bottom).offset(7)
            make.height.equalTo(16)
            make.bottom.lessThanOrEqualToSuperview()
        }
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func bind(title: String, assetName: String, titleColor: UIColor) {
        titleLabel.text = title
        titleLabel.textColor = titleColor
        iconView.image = LiveKitResources.image(named: assetName)
    }
}

// Styles owned by this component or feature. Values preserve the existing design.
private enum PusherCoGuestManageStyle {
    static let deviceForeground: UIColor = UIColor.white.withAlphaComponent(0.75)
    static let disconnectForeground: UIColor = UIColor(red: 1, green: 0.565, blue: 0.584, alpha: 1)
}
