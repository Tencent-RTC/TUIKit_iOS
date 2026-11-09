import UIKit
import SnapKit
import Combine
import AtomicXCore

final class RoomParticipantActionPopup: UIView {

    private weak var popup: RoomPopup?
    private let roomID: String
    private let participantStore: RoomParticipantStore
    private weak var presenter: UIViewController?

    private let container = UIView()
    private let stack = UIStackView()
    private var cancellableSet = Set<AnyCancellable>()
    private var targetUserID: String = ""
    private var renderedTarget: RoomParticipant?
    private var renderedLocalRole: ParticipantRole?
    private var renderedChatMuted = false

    init(roomID: String) {
        self.roomID = roomID
        participantStore = RoomParticipantStore.create(roomID: roomID)
        super.init(frame: .zero)
        setupViews()
        setupConstraints()
        setupStyles()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func setupViews() {
        addSubview(container)
        container.addSubview(stack)
    }

    private func setupConstraints() {
        container.snp.makeConstraints {
            $0.edges.equalToSuperview()
        }
        stack.snp.makeConstraints {
            $0.top.equalToSuperview().offset(4)
            $0.leading.equalToSuperview().offset(16)
            $0.trailing.equalToSuperview().offset(-16)
            $0.bottom.equalToSuperview().offset(-24)
        }
    }

    private func setupStyles() {
        stack.axis = .vertical
        stack.spacing = 0
    }

    func show(target: RoomParticipant, in host: UIView) {
        targetUserID = target.userID
        guard isTargetManageable() else { return }
        updateActions()
        presenter = Self.viewController(from: host)

        let popup = RoomPopup()
        popup.contentView.addSubview(self)
        self.snp.makeConstraints { $0.edges.equalToSuperview() }
        popup.onDismiss = { [weak self] _ in self?.cancellableSet.removeAll() }
        self.popup = popup
        popup.show(in: host)
        observeParticipants()
    }

    private func observeParticipants() {
        let state = participantStore.state
        Publishers.CombineLatest3(
            state.subscribe(StatePublisherSelector(keyPath: \RoomParticipantState.participantList)),
            state.subscribe(StatePublisherSelector(keyPath: \RoomParticipantState.localParticipant)),
            state.subscribe(StatePublisherSelector(keyPath: \RoomParticipantState.messageDisabledUserList))
        )
        .receive(on: RunLoop.main)
        .sink { [weak self] _ in
            guard let self else { return }
            if self.isTargetManageable() {
                self.updateActions()
            } else {
                self.dismissPopup()
            }
        }
        .store(in: &cancellableSet)
    }

    private func isTargetManageable() -> Bool {
        let state = participantStore.state.value
        guard let local = state.localParticipant,
              let target = state.participantList.first(where: { $0.userID == targetUserID }) else { return false }
        return target.userID == local.userID || local.role.canManage(target.role)
    }

    private func updateActions() {
        let state = participantStore.state.value
        guard let local = state.localParticipant,
              let target = state.participantList.first(where: { $0.userID == targetUserID }) else { return }
        let chatMuted = state.messageDisabledUserList.contains { $0.userID == target.userID }
        if target == renderedTarget, local.role == renderedLocalRole, chatMuted == renderedChatMuted { return }
        renderedTarget = target
        renderedLocalRole = local.role
        renderedChatMuted = chatMuted
        stack.arrangedSubviews.forEach {
            stack.removeArrangedSubview($0)
            $0.removeFromSuperview()
        }
        if target.userID == local.userID {
            addSelfActions(target: target)
        } else {
            addManageActions(target: target, local: local)
        }
    }

    private func dismissPopup() {
        cancellableSet.removeAll()
        popup?.dismiss()
    }

    private func addSelfActions(target: RoomParticipant) {
        let microphoneOn = target.microphoneStatus == .on
        let cameraOn = target.cameraStatus == .on
        addAction(
            icon: microphoneOn ? "roomkit_icon_microphone" : "roomkit_icon_microphone_off",
            label: microphoneOn ? .participantsMicClose : .participantsMicOpen
        ) { [weak self] in
            self?.toggleSelfMicrophone(microphoneOn: microphoneOn)
        }
        addAction(
            icon: cameraOn ? "roomkit_icon_camera" : "roomkit_icon_camera_off",
            label: cameraOn ? .participantsCamClose : .participantsCamOpen
        ) { [weak self] in
            self?.toggleSelfCamera(cameraOn: cameraOn)
        }
        addAction(icon: "roomkit_icon_rename", label: .participantsRename) { [weak self] in
            self?.showRenameDialog(target: target)
        }
    }

    private func addManageActions(target: RoomParticipant, local: RoomParticipant) {
        let isOwner = local.role == .owner
        let displayName = target.displayName
        addAction(icon: "roomkit_icon_rename", label: .participantsRename) { [weak self] in
            self?.showRenameDialog(target: target)
        }
        if isOwner {
            addAction(icon: "roomkit_icon_transfer_owner", label: .participantsTransferOwner) { [weak self] in
                self?.showTransferOwnerDialog(target: target)
            }
            if target.role == .generalUser {
                addAction(icon: "roomkit_icon_set_admin", label: .participantsSetAdmin) { [weak self] in
                    self?.participantStore.setAdmin(userID: target.userID) { result in
                        if case .success = result { RoomToast.show(RoomKitResources.localizedFormat("roomkit.participants.set_admin_done", displayName)) }
                        if case .failure(let error) = result { ErrorLocalized.showError(code: error.code, message: error.message) }
                    }
                }
            }
            if target.role == .admin {
                addAction(icon: "roomkit_icon_revoke_admin", label: .participantsRevokeAdmin) { [weak self] in
                    self?.participantStore.revokeAdmin(userID: target.userID) { result in
                        if case .success = result { RoomToast.show(RoomKitResources.localizedFormat("roomkit.participants.revoke_admin_done", displayName)) }
                        if case .failure(let error) = result { ErrorLocalized.showError(code: error.code, message: error.message) }
                    }
                }
            }
            addDivider()
        }
        addMediaActions(target: target)
        addDivider()
        addAction(icon: "roomkit_icon_kick_danger", label: .participantsKick, danger: true) { [weak self] in
            self?.showKickDialog(target: target)
        }
    }

    private func addMediaActions(target: RoomParticipant) {
        let microphoneOn = target.microphoneStatus == .on
        let cameraOn = target.cameraStatus == .on
        let chatMuted = participantStore.state.value.messageDisabledUserList.contains { $0.userID == target.userID }
        addAction(
            icon: microphoneOn ? "roomkit_icon_microphone" : "roomkit_icon_microphone_off",
            label: microphoneOn ? .participantsAudioDisable : .participantsAudioAllow
        ) { [weak self] in
            self?.toggleParticipantDevice(target: target, deviceType: .microphone, on: microphoneOn)
        }
        addAction(
            icon: cameraOn ? "roomkit_icon_camera" : "roomkit_icon_camera_off",
            label: cameraOn ? .participantsVideoDisable : .participantsVideoAllow
        ) { [weak self] in
            self?.toggleParticipantDevice(target: target, deviceType: .camera, on: cameraOn)
        }
        addAction(
            icon: chatMuted ? "roomkit_icon_chat" : "roomkit_icon_chat_off",
            label: chatMuted ? .participantsChatUnmute : .participantsChatMute
        ) { [weak self] in
            self?.toggleParticipantChat(target: target, chatMuted: chatMuted)
        }
    }

    private func addAction(
        icon: String,
        label: String,
        danger: Bool = false,
        onClick: @escaping () -> Void
    ) {
        let row = RoomParticipantActionRow(icon: icon, label: label, danger: danger)
        row.onTap = { [weak self] in
            self?.dismissPopup()
            onClick()
        }
        stack.addArrangedSubview(row)
    }

    private func addDivider() {
        let divider = UIView()
        divider.backgroundColor = UIColor.roomKitBorder
        stack.addArrangedSubview(divider)
        divider.snp.makeConstraints {
            $0.height.equalTo(1)
        }
        stack.setCustomSpacing(10, after: divider)
        if let last = stack.arrangedSubviews.dropLast().last {
            stack.setCustomSpacing(10, after: last)
        }
    }

    private func toggleSelfMicrophone(microphoneOn: Bool) {
        if microphoneOn {
            participantStore.muteMicrophone()
        } else {
            RoomDevicePermission.requestMicrophonePermission { granted in
                guard granted else {
                    RoomToast.show(RoomKitResources.localizedString("roomkit.device.mic_no_permission"))
                    return
                }
                DeviceStore.shared.openLocalMicrophone { result in
                    switch result {
                    case .success:
                        self.participantStore.unmuteMicrophone { result in
                            if case .failure(let error) = result {
                                ErrorLocalized.showError(code: error.code, message: error.message)
                            }
                        }
                    case .failure(let error):
                        ErrorLocalized.showError(code: error.code, message: error.message)
                    }
                }
            }
        }
    }

    private func toggleSelfCamera(cameraOn: Bool) {
        if cameraOn {
            DeviceStore.shared.closeLocalCamera()
        } else {
            let selfRole = participantStore.state.value.localParticipant?.role
            let allCamDisabled = RoomStore.shared.state.value.currentRoom?.isAllCameraDisabled == true
            let roomDisabled = allCamDisabled && selfRole != nil && selfRole != .owner && selfRole != .admin
            if roomDisabled {
                RoomToast.show(RoomKitResources.localizedString("roomkit.device.all_cam_disabled"))
                return
            }
            RoomDevicePermission.requestCameraPermission { granted in
                guard granted else {
                    RoomToast.show(RoomKitResources.localizedString("roomkit.device.camera_no_permission"))
                    return
                }
                DeviceStore.shared.openLocalCamera(isFront: DeviceStore.shared.state.value.isFrontCamera) { result in
                    if case .failure(let error) = result {
                        ErrorLocalized.showError(code: error.code, message: error.message)
                    }
                }
            }
        }
    }

    private func toggleParticipantDevice(target: RoomParticipant, deviceType: DeviceType, on: Bool) {
        if on {
            participantStore.closeParticipantDevice(userID: target.userID, device: deviceType) { result in
                switch result {
                case .success:
                    let key = deviceType == .microphone
                        ? "roomkit.participants.mute_done"
                        : "roomkit.participants.cam_stop_done"
                    RoomToast.show(RoomKitResources.localizedFormat(key, target.displayName))
                case .failure(let error):
                    ErrorLocalized.showError(code: error.code, message: error.message)
                }
            }
        } else {
            participantStore.inviteToOpenDevice(userID: target.userID, device: deviceType, timeout: 30) { result in
                if case .failure(let error) = result { ErrorLocalized.showError(code: error.code, message: error.message) }
            }
        }
    }

    private func toggleParticipantChat(target: RoomParticipant, chatMuted: Bool) {
        participantStore.disableUserMessage(userID: target.userID, disable: !chatMuted) { result in
            switch result {
            case .success:
                let key = chatMuted
                    ? "roomkit.participants.unmute_chat_done"
                    : "roomkit.participants.mute_chat_done"
                RoomToast.show(RoomKitResources.localizedFormat(key, target.displayName))
            case .failure(let error):
                ErrorLocalized.showError(code: error.code, message: error.message)
            }
        }
    }

    private static func viewController(from view: UIView) -> UIViewController? {
        var responder: UIResponder? = view
        while let next = responder?.next {
            if let viewController = next as? UIViewController { return viewController }
            responder = next
        }
        return nil
    }

    private func showRenameDialog(target: RoomParticipant) {
        let input = RenameInputField()
        input.text = String(target.displayName.prefix(RenameInputField.maxLength))
        input.placeholder = .participantsRenamePlaceholder
        let store = participantStore
        let dialog = RoomDialog.Builder(in: presenter ?? UIViewController())
            .title(.participantsRename)
            .message(.participantsRenameDesc)
            .contentView(input)
            .primaryAction(.participantsConfirm) {
                let name = (input.text ?? "").trimmingCharacters(in: .whitespaces)
                guard !name.isEmpty else { return }
                store.updateParticipantNameCard(
                    userID: target.userID,
                    nameCard: name,
                    completion: nil
                )
            }
            .secondaryAction(.commonCancel)
            .show()
        dismissDialogWhenInvalid(dialog) { self.isTargetManageable() }
    }

    private func showTransferOwnerDialog(target: RoomParticipant) {
        let store = participantStore
        let dialog = RoomDialog.Builder(in: presenter ?? UIViewController())
            .title(.participantsTransferOwner)
            .message(RoomKitResources.localizedFormat("roomkit.participants.transfer_owner_message", target.displayName))
            .primaryAction(.participantsTransferOwnerConfirm) {
                store.transferOwner(userID: target.userID) { result in
                    if case .success = result {
                        RoomToast.show(RoomKitResources.localizedFormat("roomkit.participants.transfer_owner_done", target.displayName))
                    }
                }
            }
            .secondaryAction(.commonCancel)
            .show()
        dismissDialogWhenInvalid(dialog) { self.isLocalOwner() && self.isTargetManageable() }
    }

    private func showKickDialog(target: RoomParticipant) {
        let displayName = target.displayName
        let store = participantStore
        let dialog = RoomDialog.Builder(in: presenter ?? UIViewController())
            .title(.commonNotification)
            .message(RoomKitResources.localizedFormat("roomkit.participants.kick_message", displayName))
            .primaryAction(.participantsKickConfirm, variant: .danger) {
                store.kickUser(
                    userID: target.userID,
                    completion: { result in
                        if case .success = result {
                            RoomToast.show(RoomKitResources.localizedFormat("roomkit.participants.kick_done", displayName))
                        }
                    }
                )
            }
            .secondaryAction(.commonCancel)
            .show()
        dismissDialogWhenInvalid(dialog) { self.isTargetManageable() }
    }

    private func isLocalOwner() -> Bool {
        participantStore.state.value.localParticipant?.role == .owner
    }

    private func dismissDialogWhenInvalid(_ dialog: RoomDialog, isValid: @escaping () -> Bool) {
        let state = participantStore.state
        Publishers.CombineLatest(
            state.subscribe(StatePublisherSelector(keyPath: \RoomParticipantState.participantList)),
            state.subscribe(StatePublisherSelector(keyPath: \RoomParticipantState.localParticipant))
        )
        .receive(on: RunLoop.main)
        .sink { [weak dialog] _ in
            guard !isValid() else { return }
            dialog?.cancellables.removeAll()
            dialog?.dismissDialog()
        }
        .store(in: &dialog.cancellables)
        dialog.onDismiss = { [weak dialog] in dialog?.cancellables.removeAll() }
    }
}

final class RenameInputField: UITextField {

    static let maxLength = 10

    override init(frame: CGRect) {
        super.init(frame: frame)
        font = .systemFont(ofSize: 15)
        textColor = .roomKitFgPrimary
        backgroundColor = .roomKitBgSurface
        layer.cornerRadius = 12
        layer.borderWidth = 1
        layer.borderColor = UIColor.roomKitBorder.cgColor
        let spacer = UIView(frame: CGRect(x: 0, y: 0, width: 14, height: 44))
        leftView = spacer
        rightView = spacer
        leftViewMode = .always
        rightViewMode = .always
        inputAccessoryView = makeDoneToolbar()
        snp.makeConstraints { $0.height.equalTo(44) }
        addTarget(self, action: #selector(handleEditingChanged), for: .editingDidBegin)
        addTarget(self, action: #selector(handleEditingChanged), for: .editingDidEnd)
        addTarget(self, action: #selector(handleTextChanged), for: .editingChanged)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func didMoveToWindow() {
        super.didMoveToWindow()
        if window != nil {
            becomeFirstResponder()
        }
    }

    @objc private func handleEditingChanged() {
        layer.borderColor = (isFirstResponder ? UIColor.roomKitAccent : UIColor.roomKitBorder).cgColor
    }

    @objc private func handleTextChanged() {
        if let text, text.count > Self.maxLength {
            self.text = String(text.prefix(Self.maxLength))
        }
    }

    private func makeDoneToolbar() -> UIToolbar {
        let toolbar = UIToolbar()
        toolbar.sizeToFit()
        toolbar.items = [
            UIBarButtonItem(barButtonSystemItem: .flexibleSpace, target: nil, action: nil),
            UIBarButtonItem(barButtonSystemItem: .done, target: self, action: #selector(endEditingInput)),
        ]
        return toolbar
    }

    @objc private func endEditingInput() {
        resignFirstResponder()
    }
}

final class RoomParticipantActionRow: UIControl {

    var onTap: (() -> Void)?

    private let iconView = UIImageView()
    let label = UILabel()

    init(icon: String, label text: String, danger: Bool) {
        super.init(frame: .zero)
        iconView.image = RoomKitResources.image(named: icon)
        label.text = text
        label.font = .systemFont(ofSize: 13)
        label.textColor = danger ? UIColor.roomKitDanger : UIColor.roomKitFgPrimary

        addSubview(iconView)
        addSubview(label)
        iconView.snp.makeConstraints {
            $0.leading.equalToSuperview().offset(12)
            $0.centerY.equalToSuperview()
            $0.size.equalTo(15)
        }
        label.snp.makeConstraints {
            $0.leading.equalTo(iconView.snp.trailing).offset(10)
            $0.centerY.equalToSuperview()
        }
        snp.makeConstraints { $0.height.equalTo(42).priority(.required) }
        addTarget(self, action: #selector(handleTap), for: .touchUpInside)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    @objc private func handleTap() {
        onTap?()
    }
}

extension ParticipantRole {

    func canManage(_ target: ParticipantRole) -> Bool {
        switch self {
        case .owner: return true
        case .admin: return target == .generalUser
        case .generalUser: return false
        }
    }
}

private extension String {
    static var commonCancel: String { RoomKitResources.localizedString("roomkit.common.cancel") }
    static var commonNotification: String { RoomKitResources.localizedString("roomkit.common.notification") }
    static var participantsRename: String { RoomKitResources.localizedString("roomkit.participants.rename") }
    static var participantsRenameDesc: String { RoomKitResources.localizedString("roomkit.participants.rename_desc") }
    static var participantsRenamePlaceholder: String { RoomKitResources.localizedString("roomkit.participants.rename_placeholder") }
    static var participantsConfirm: String { RoomKitResources.localizedString("roomkit.participants.confirm") }
    static var participantsTransferOwner: String { RoomKitResources.localizedString("roomkit.participants.transfer_owner") }
    static var participantsTransferOwnerConfirm: String { RoomKitResources.localizedString("roomkit.participants.transfer_owner_confirm") }
    static var participantsMicClose: String { RoomKitResources.localizedString("roomkit.participants.mic_close") }
    static var participantsMicOpen: String { RoomKitResources.localizedString("roomkit.participants.mic_open") }
    static var participantsCamClose: String { RoomKitResources.localizedString("roomkit.participants.cam_close") }
    static var participantsCamOpen: String { RoomKitResources.localizedString("roomkit.participants.cam_open") }
    static var participantsAudioDisable: String { RoomKitResources.localizedString("roomkit.participants.audio_disable") }
    static var participantsAudioAllow: String { RoomKitResources.localizedString("roomkit.participants.audio_allow") }
    static var participantsVideoDisable: String { RoomKitResources.localizedString("roomkit.participants.video_disable") }
    static var participantsVideoAllow: String { RoomKitResources.localizedString("roomkit.participants.video_allow") }
    static var participantsChatMute: String { RoomKitResources.localizedString("roomkit.participants.chat_mute") }
    static var participantsChatUnmute: String { RoomKitResources.localizedString("roomkit.participants.chat_unmute") }
    static var participantsSetAdmin: String { RoomKitResources.localizedString("roomkit.participants.set_admin") }
    static var participantsRevokeAdmin: String { RoomKitResources.localizedString("roomkit.participants.revoke_admin") }
    static var participantsKick: String { RoomKitResources.localizedString("roomkit.participants.kick") }
    static var participantsKickConfirm: String { RoomKitResources.localizedString("roomkit.participants.kick_confirm") }
}
