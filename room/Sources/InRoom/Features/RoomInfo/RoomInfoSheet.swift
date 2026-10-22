import UIKit
import SnapKit
import Combine
import AtomicXCore

final class RoomInfoSheet: UIView {

    var onDismiss: (() -> Void)?

    private let roomID: String
    private var cancellableSet = Set<AnyCancellable>()
    private var copiedStates: [ObjectIdentifier: CopiedState] = [:]

    private weak var popup: RoomPopup?


    private let nameLabel = UILabel()
    private let divider = UIView()

    private let hostRow = UIView()
    private let hostLabel = UILabel()
    private let hostValueLabel = UILabel()

    private let idRow = UIView()
    private let idLabel = UILabel()
    private let idValueLabel = UILabel()
    private let idCopyButton = UIButton(type: .custom)

    private let passwordRow = UIView()
    private let passwordLabel = UILabel()
    private let passwordValueLabel = UILabel()
    private let passwordCopyButton = UIButton(type: .custom)

    private let bodyStack = UIStackView()
    private let inviteButton = UIButton(type: .custom)

    private var invitationText = ""
    private var didSetup = false

    init(roomID: String) {
        self.roomID = roomID
        super.init(frame: .zero)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    deinit {
        copiedStates.values.forEach { $0.workItem.cancel() }
        copiedStates.removeAll()
    }

    override func didMoveToSuperview() {
        super.didMoveToSuperview()
        guard !didSetup, superview != nil else { return }
        didSetup = true
        setupViews()
        setupConstraints()
        setupStyles()
        setupBindings()
        applyTheme()
    }

    override func didMoveToWindow() {
        super.didMoveToWindow()
        if window != nil {
            applyTheme()
        }
    }

    override var intrinsicContentSize: CGSize {
        guard didSetup else { return CGSize(width: UIView.noIntrinsicMetric, height: Self.FALLBACK_HEIGHT) }
        let fitting = CGSize(width: UIView.layoutFittingCompressedSize.width, height: 0)
        let height = Self.TOP_INSET
            + nameLabel.systemLayoutSizeFitting(fitting).height
            + Self.DIVIDER_TOP_SPACING
            + Self.DIVIDER_HEIGHT
            + Self.BODY_TOP_SPACING
            + bodyStack.systemLayoutSizeFitting(fitting).height
            + Self.INVITE_TOP_SPACING
            + Self.INVITE_HEIGHT
            + Self.BOTTOM_INSET
        return CGSize(width: UIView.noIntrinsicMetric, height: height)
    }

    private func setupViews() {
        addSubview(nameLabel)
        addSubview(divider)
        addSubview(bodyStack)
        addSubview(inviteButton)

        buildRow(hostRow, label: hostLabel, value: hostValueLabel, copyButton: nil)
        buildRow(idRow, label: idLabel, value: idValueLabel, copyButton: idCopyButton)
        buildRow(passwordRow, label: passwordLabel, value: passwordValueLabel, copyButton: passwordCopyButton)

        bodyStack.axis = .vertical
        bodyStack.spacing = 0
        bodyStack.alignment = .fill
        passwordRow.isHidden = true
        [hostRow, idRow, passwordRow].forEach { bodyStack.addArrangedSubview($0) }
    }

    private func setupConstraints() {
        nameLabel.snp.makeConstraints {
            $0.top.equalToSuperview().offset(Self.TOP_INSET)
            $0.leading.trailing.equalToSuperview().inset(Self.EDGE_INSET)
        }

        divider.snp.makeConstraints {
            $0.top.equalTo(nameLabel.snp.bottom).offset(Self.DIVIDER_TOP_SPACING)
            $0.leading.trailing.equalToSuperview().inset(Self.EDGE_INSET)
            $0.height.equalTo(Self.DIVIDER_HEIGHT)
        }

        bodyStack.snp.makeConstraints {
            $0.top.equalTo(divider.snp.bottom).offset(Self.BODY_TOP_SPACING)
            $0.leading.trailing.equalToSuperview().inset(Self.EDGE_INSET)
        }

        inviteButton.snp.makeConstraints {
            $0.top.equalTo(bodyStack.snp.bottom).offset(Self.INVITE_TOP_SPACING)
            $0.leading.trailing.equalToSuperview().inset(Self.EDGE_INSET)
            $0.height.equalTo(Self.INVITE_HEIGHT)
            $0.bottom.equalToSuperview().offset(-Self.BOTTOM_INSET)
        }
    }


    private func setupStyles() {
        nameLabel.font = .systemFont(ofSize: 16, weight: .medium)
        nameLabel.textColor = UIColor.roomKitFgPrimary
        nameLabel.textAlignment = .center
        nameLabel.lineBreakMode = .byTruncatingTail

        for label in [hostLabel, idLabel, passwordLabel] {
            label.font = .systemFont(ofSize: 15)
            label.textColor = UIColor.roomKitFgSecondary
        }
        for label in [hostValueLabel, idValueLabel, passwordValueLabel] {
            label.font = .systemFont(ofSize: 15)
            label.textColor = UIColor.roomKitFgPrimary
            label.lineBreakMode = .byTruncatingTail
        }

        hostLabel.text = .roomViewOwner
        idLabel.text = .roomInfoRoomId
        passwordLabel.text = .roomInfoPassword

        configureCopyButton(idCopyButton, action: #selector(handleIdCopyTap))
        configureCopyButton(passwordCopyButton, action: #selector(handlePasswordCopyTap))

        inviteButton.layer.cornerRadius = 8
        inviteButton.setTitle(.roomInfoInvitation, for: .normal)
        inviteButton.titleLabel?.font = .systemFont(ofSize: 15)
        inviteButton.setTitleColor(UIColor.roomKitFgOnAccent, for: .normal)
        inviteButton.addTarget(self, action: #selector(handleInviteTap), for: .touchUpInside)

        applyTheme()
    }

    private func setupBindings() {
        RoomStore.shared.state
            .subscribe(StatePublisherSelector(keyPath: \RoomState.currentRoom))
            .receive(on: RunLoop.main)
            .sink { [weak self] room in
                guard let self, let room, room.roomID == self.roomID else { return }
                self.render(room: room)
            }
            .store(in: &cancellableSet)
    }

    // MARK: - private methods

    private func render(room: RoomInfo) {
        nameLabel.text = room.roomName
        hostValueLabel.text = room.roomOwner.userName.isEmpty ? room.roomOwner.userID : room.roomOwner.userName
        idValueLabel.text = room.roomID
        let password = room.password ?? ""
        passwordRow.isHidden = password.isEmpty
        passwordValueLabel.text = password
        invalidateIntrinsicContentSize()
        invitationText = buildInvitation(room: room)
    }

    private func buildInvitation(room: RoomInfo) -> String {
        var lines = [room.roomName, String(format: .roomInfoInvitationRoomId, room.roomID)]
        let password = room.password ?? ""
        if !password.isEmpty {
            lines.append(String(format: .roomInfoInvitationPassword, password))
        }
        return lines.joined(separator: "\n")
    }

    private func buildRow(_ row: UIView, label: UILabel, value: UILabel, copyButton: UIButton?) {
        row.addSubview(label)
        row.addSubview(value)
        row.snp.makeConstraints { $0.height.equalTo(Self.ROW_HEIGHT) }

        label.snp.makeConstraints {
            $0.leading.equalToSuperview()
            $0.centerY.equalToSuperview()
        }
        value.snp.makeConstraints {
            $0.leading.equalTo(label.snp.trailing).offset(Self.COLUMN_GAP)
            $0.centerY.equalToSuperview()
        }
        label.setContentHuggingPriority(.required, for: .horizontal)
        label.setContentCompressionResistancePriority(.required, for: .horizontal)
        value.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)

        guard let copyButton else {
            value.snp.makeConstraints { $0.trailing.equalToSuperview() }
            return
        }
        row.addSubview(copyButton)
        value.snp.makeConstraints { $0.trailing.equalTo(copyButton.snp.leading).offset(-Self.COLUMN_GAP) }
        copyButton.snp.makeConstraints {
            $0.trailing.equalToSuperview()
            $0.centerY.equalToSuperview()
            $0.size.equalTo(Self.COPY_SIZE)
        }
    }

    private func configureCopyButton(_ button: UIButton, action: Selector) {
        button.setImage(Self.copyImage, for: .normal)
        button.imageView?.contentMode = .scaleAspectFit
        button.layer.cornerRadius = Self.COPY_RADIUS
        button.layer.masksToBounds = true
        button.addTarget(self, action: action, for: .touchUpInside)
    }

    private func copyToPasteboard(_ text: String) {
        UIPasteboard.general.string = text
    }

    private func copy(_ text: String, from button: UIButton) {
        copyToPasteboard(text)
        markCopied(on: button) {
            $0.setImage(Self.copyImage, for: .normal)
            $0.backgroundColor = .clear
        }
        button.setImage(Self.copiedImage, for: .normal)
        button.backgroundColor = UIColor.roomKitSuccessSoft
    }

    @objc private func handleIdCopyTap() {
        copy(idValueLabel.text ?? "", from: idCopyButton)
    }

    @objc private func handlePasswordCopyTap() {
        copy(passwordValueLabel.text ?? "", from: passwordCopyButton)
    }

    @objc private func handleInviteTap() {
        copyToPasteboard(invitationText)
        markCopied(on: inviteButton) {
            $0.setTitle(.roomInfoInvitation, for: .normal)
            $0.setTitleColor(UIColor.roomKitFgOnAccent, for: .normal)
            $0.backgroundColor = UIColor.roomKitAccent
        }
        inviteButton.setTitle(.commonCopied, for: .normal)
        inviteButton.setTitleColor(UIColor.roomKitSuccessText, for: .normal)
        inviteButton.backgroundColor = UIColor.roomKitSuccessSoft
    }

    private func markCopied<Target: UIView>(on target: Target, restore: @escaping (Target) -> Void) {
        let key = ObjectIdentifier(target)
        copiedStates[key]?.workItem.cancel()
        let workItem = DispatchWorkItem { [weak self, weak target] in
            guard let target else { return }
            restore(target)
            self?.copiedStates[ObjectIdentifier(target)] = nil
        }
        copiedStates[key] = CopiedState(workItem: workItem)
        DispatchQueue.main.asyncAfter(deadline: .now() + Self.COPIED_DURATION, execute: workItem)
    }

    private func applyTheme() {
        divider.backgroundColor = UIColor.roomKitInfoLine
        inviteButton.backgroundColor = UIColor.roomKitAccent
    }
}

private struct CopiedState {

    let workItem: DispatchWorkItem
}

// MARK: - private constants

private extension RoomInfoSheet {
    static let ROW_HEIGHT: CGFloat = 42
    static let COLUMN_GAP: CGFloat = 16
    static let EDGE_INSET: CGFloat = 20
    static let TOP_INSET: CGFloat = 8
    static let DIVIDER_TOP_SPACING: CGFloat = 16
    static let BODY_TOP_SPACING: CGFloat = 8
    static let INVITE_TOP_SPACING: CGFloat = 16
    static let INVITE_HEIGHT: CGFloat = 44
    static let BOTTOM_INSET: CGFloat = 14
    static let FALLBACK_HEIGHT: CGFloat = 268
    static let COPY_SIZE = CGSize(width: 22, height: 22)
    static let COPY_RADIUS: CGFloat = 8
    static let DIVIDER_HEIGHT: CGFloat = 1
    static let COPIED_DURATION: TimeInterval = 2
    static let copyImage = RoomKitResources.image(named: "roomkit_icon_copy_accent")
    static let copiedImage = RoomKitResources.image(named: "roomkit_icon_check_success")
}

// MARK: - public methods

extension RoomInfoSheet {

    func show(in host: UIView) {
        guard popup == nil else { return }
        let popup = RoomPopup()
        popup.contentView.addSubview(self)
        snp.makeConstraints { $0.edges.equalToSuperview() }
        popup.onDismiss = { [weak self] _ in
            self?.popup = nil
            self?.onDismiss?()
        }
        self.popup = popup
        popup.show(in: host)
    }

    func dismiss(completion: (() -> Void)? = nil) {
        guard let popup else {
            completion?()
            return
        }
        popup.dismiss(completion: completion)
    }
}

// MARK: - localized strings

private extension String {
    static var roomViewOwner: String { RoomKitResources.localizedString("roomkit.room_view.owner") }
    static var roomInfoRoomId: String { RoomKitResources.localizedString("roomkit.room_info.room_id") }
    static var roomInfoPassword: String { RoomKitResources.localizedString("roomkit.room_info.password") }
    static var roomInfoInvitation: String { RoomKitResources.localizedString("roomkit.room_info.invitation") }
    static var roomInfoInvitationRoomId: String { RoomKitResources.localizedString("roomkit.room_info.invitation_room_id") }
    static var roomInfoInvitationPassword: String { RoomKitResources.localizedString("roomkit.room_info.invitation_password") }
    static var commonCopied: String { RoomKitResources.localizedString("roomkit.common.copied") }
}
