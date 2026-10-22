import TUIRoomKit
import UIKit
import SnapKit
import AtomicXCore

public final class RoomJoinView: UIView {

    public weak var routerContext: RouterContext?
    
    private var isPushing = false

    private let navBar = RoomNavigationBar()

    private let scrollView = UIScrollView()
    private let contentView = UIView()

    private let roomCard = UIStackView()
    private let roomIDInput = UITextField()

    private let mediaCard = UIStackView()
    private let microphoneSwitch = UISwitch()
    private let speakerSwitch = UISwitch()
    private let cameraSwitch = UISwitch()
    private var micPermissionHint: UIView?
    private var cameraPermissionHint: UIView?
    private var faultSheet: RoomDeviceFaultSheet?

    private let submitButton = UIButton(type: .custom)

    public init() {
        super.init(frame: .zero)
        setupViews()
        setupConstraints()
        setupStyles()
        setupBindings()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override public func didMoveToWindow() {
        super.didMoveToWindow()
        guard window != nil else { return }
        applyTheme()
        updatePermissionHints()
        isPushing = false
    }

    private func setupViews() {
        addSubview(navBar)

        scrollView.alwaysBounceVertical = true
        scrollView.keyboardDismissMode = .onDrag
        scrollView.addSubview(contentView)
        addSubview(scrollView)

        configureCard(roomCard)
        configureCard(mediaCard)
        addRow(to: roomCard, title: .joinRoomId, content: roomIDInput, trailingAligned: false)
        addRow(to: mediaCard, title: .preMicOn, content: microphoneSwitch, trailingAligned: true)
        micPermissionHint = addPermissionHint(to: mediaCard, text: .preMicPermissionDenied)
        addRow(to: mediaCard, title: .preSpeakerOn, content: speakerSwitch, trailingAligned: true)
        addRow(to: mediaCard, title: .preCameraOn, content: cameraSwitch, trailingAligned: true)
        cameraPermissionHint = addPermissionHint(to: mediaCard, text: .preCameraPermissionDenied)
        contentView.addSubview(roomCard)
        contentView.addSubview(mediaCard)

        addSubview(submitButton)
    }

    private func setupConstraints() {
        navBar.snp.makeConstraints {
            $0.top.leading.trailing.equalToSuperview()
            $0.bottom.equalTo(safeAreaLayoutGuide.snp.top).offset(52)
        }

        scrollView.snp.makeConstraints {
            $0.top.equalTo(navBar.snp.bottom)
            $0.leading.trailing.equalToSuperview()
            $0.bottom.equalTo(submitButton.snp.top).offset(-8)
        }
        contentView.snp.makeConstraints {
            $0.edges.equalTo(scrollView.contentLayoutGuide)
            $0.width.equalTo(scrollView.frameLayoutGuide)
        }
        roomCard.snp.makeConstraints {
            $0.top.equalToSuperview().offset(12)
            $0.leading.equalToSuperview().offset(16)
            $0.trailing.equalToSuperview().offset(-16)
        }
        mediaCard.snp.makeConstraints {
            $0.top.equalTo(roomCard.snp.bottom).offset(12)
            $0.leading.equalToSuperview().offset(16)
            $0.trailing.equalToSuperview().offset(-16)
            $0.bottom.lessThanOrEqualToSuperview().offset(-16)
        }

        submitButton.snp.makeConstraints {
            $0.leading.equalToSuperview().offset(16)
            $0.trailing.equalToSuperview().offset(-16)
            $0.bottom.equalTo(safeAreaLayoutGuide).offset(-20)
        }
    }

    private func setupStyles() {
        navBar.navigationTitle = .joinNavTitle

        roomIDInput.keyboardType = .numberPad
        roomIDInput.returnKeyType = .done
        roomIDInput.autocorrectionType = .no
        roomIDInput.autocapitalizationType = .none
        roomIDInput.placeholder = .joinRoomIdPlaceholder
        applyFieldStyle(roomIDInput)

        submitButton.layer.cornerRadius = 12
        submitButton.layer.masksToBounds = true
        submitButton.titleLabel?.font = .systemFont(ofSize: 15)
        submitButton.setTitle(.joinNavTitle, for: .normal)
        submitButton.snp.makeConstraints { $0.height.equalTo(48) }

        for control in [microphoneSwitch, speakerSwitch, cameraSwitch] {
            control.applyRoomKitStyle()
        }

        applyTheme()
    }

    private func setupBindings() {
        navBar.onBack = { [weak self] in
            self?.routerContext?.pop(animated: true)
        }
        submitButton.addTarget(self, action: #selector(handleSubmitTap), for: .touchUpInside)
        roomIDInput.delegate = self

        NotificationCenter.default.addObserver(self, selector: #selector(handleDidBecomeActive),
                                               name: UIApplication.didBecomeActiveNotification, object: nil)

        microphoneSwitch.isOn = !RoomLocalMediaUtils.isPermissionDenied(.microphone)
        speakerSwitch.isOn = true
        cameraSwitch.isOn = !RoomLocalMediaUtils.isPermissionDenied(.camera)
        microphoneSwitch.addTarget(self, action: #selector(handleMicrophoneSwitchChanged), for: .valueChanged)
        cameraSwitch.addTarget(self, action: #selector(handleCameraSwitchChanged), for: .valueChanged)

        let tap = UITapGestureRecognizer(target: self, action: #selector(handleBlankTap))
        tap.cancelsTouchesInView = false
        addGestureRecognizer(tap)
    }

    private func configureCard(_ card: UIStackView) {
        card.axis = .vertical
        card.distribution = .fill
        card.isLayoutMarginsRelativeArrangement = true
        card.layoutMargins = UIEdgeInsets(top: 4, left: 16, bottom: 4, right: 16)
        card.backgroundColor = UIColor.roomKitBgSurface
        card.layer.cornerRadius = 12
        card.layer.masksToBounds = true
    }

    private func addRow(to card: UIStackView, title: String, content: UIView, trailingAligned: Bool) {
        let row = UIView()
        let titleLabel = UILabel()
        titleLabel.text = title
        titleLabel.font = .systemFont(ofSize: 15)
        titleLabel.textColor = UIColor.roomKitFgPrimary
        titleLabel.setContentHuggingPriority(.required, for: .horizontal)
        titleLabel.setContentCompressionResistancePriority(.required, for: .horizontal)
        row.addSubview(titleLabel)
        row.addSubview(content)

        row.snp.makeConstraints { $0.height.greaterThanOrEqualTo(56) }
        titleLabel.snp.makeConstraints {
            $0.leading.equalToSuperview()
            $0.centerY.equalToSuperview()
            if RoomKitResources.language != .english { $0.width.equalTo(88) }
        }
        if trailingAligned {
            content.snp.makeConstraints {
                $0.trailing.equalToSuperview().offset(content is UISwitch ? -5.5 : 0)
                $0.centerY.equalToSuperview()
            }
        } else {
            content.snp.makeConstraints {
                $0.leading.equalTo(titleLabel.snp.trailing).offset(16)
                $0.trailing.equalToSuperview()
                $0.centerY.equalToSuperview()
                $0.height.equalTo(32)
            }
        }
        card.addArrangedSubview(row)
    }

    @discardableResult
    private func addPermissionHint(to card: UIStackView, text: String) -> UIView {
        let row = UIView()
        let icon = UIImageView(image: RoomKitResources.image(named: "roomkit_icon_permission_warning"))
        let label = UILabel()
        let button = UIButton(type: .system)
        row.addSubview(icon)
        row.addSubview(label)
        row.addSubview(button)
        row.isHidden = true
        row.snp.makeConstraints { $0.height.equalTo(28) }
        icon.snp.makeConstraints {
            $0.leading.equalToSuperview()
            $0.centerY.equalToSuperview()
            $0.size.equalTo(12)
        }
        label.text = text
        label.font = .systemFont(ofSize: 11)
        label.textColor = UIColor.roomKitFgTertiary
        label.snp.makeConstraints {
            $0.leading.equalTo(icon.snp.trailing).offset(4)
            $0.centerY.equalToSuperview()
            $0.trailing.lessThanOrEqualTo(button.snp.leading)
        }
        button.setTitle(.preGoEnable, for: .normal)
        button.setTitleColor(UIColor.roomKitAccent, for: .normal)
        button.titleLabel?.font = .systemFont(ofSize: 13)
        button.addTarget(self, action: #selector(handleOpenSettings), for: .touchUpInside)
        button.snp.makeConstraints {
            $0.trailing.equalToSuperview()
            $0.centerY.equalToSuperview()
        }
        card.addArrangedSubview(row)
        return row
    }

    private func updatePermissionHints() {
        micPermissionHint?.isHidden = !RoomLocalMediaUtils.isPermissionDenied(.microphone)
        cameraPermissionHint?.isHidden = !RoomLocalMediaUtils.isPermissionDenied(.camera)
    }

    @objc private func handleMicrophoneSwitchChanged() {
        toggleSwitch(microphoneSwitch, kind: .microphone)
    }

    @objc private func handleCameraSwitchChanged() {
        toggleSwitch(cameraSwitch, kind: .camera)
    }

    private func toggleSwitch(_ control: UISwitch, kind: RoomDeviceKind) {
        guard control.isOn else { return }
        control.setOn(false, animated: true)
        guard RoomLocalMediaUtils.isPermissionDenied(kind) else {
            control.setOn(true, animated: true)
            return
        }
        RoomLocalMediaUtils.requestPermission(kind) { [weak self] granted in
            guard let self else { return }
            control.setOn(granted, animated: true)
            self.updatePermissionHints()
            if !granted { self.showFaultSheet(kind) }
        }
    }

    private func showFaultSheet(_ kind: RoomDeviceKind) {
        guard faultSheet == nil else { return }
        let sheet = RoomDeviceFaultSheet(kind: kind)
        sheet.onPrimary = { [weak self] in
            self?.faultSheet = nil
            RoomLocalMediaUtils.openSystemSettings()
        }
        sheet.onDismiss = { [weak self] in self?.faultSheet = nil }
        faultSheet = sheet
        sheet.show(in: self)
    }

    @objc private func handleOpenSettings() {
        RoomLocalMediaUtils.openSystemSettings()
    }

    @objc private func handleDidBecomeActive() {
        updatePermissionHints()
    }

    private func applyFieldStyle(_ field: UITextField) {
        field.font = .systemFont(ofSize: 15)
        field.textColor = UIColor.roomKitFgSecondary
        field.textAlignment = .right
        field.attributedPlaceholder = NSAttributedString(
            string: field.placeholder ?? "",
            attributes: [.foregroundColor: UIColor.roomKitFgTertiary]
        )
    }

    private func applyTheme() {
        backgroundColor = UIColor.roomKitBgCanvas
        submitButton.backgroundColor = UIColor.roomKitAccent
        submitButton.setTitleColor(UIColor.roomKitFgOnAccent, for: .normal)
    }

    @objc private func handleSubmitTap() {
        joinWithCurrentInput()
    }

    private func joinWithCurrentInput() {
        let roomID = roomIDInput.text?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        guard !roomID.isEmpty else {
            RoomToast.show(.joinInvalidRoomId)
            return
        }
        guard !isPushing else { return }
        isPushing = true
        endEditing(true)
        routerContext?.push(
            MeetingViewController(
                roomID: roomID,
                behavior: .join,
                config: RoomConnectConfig(
                    autoEnableMicrophone: microphoneSwitch.isOn,
                    autoEnableCamera: cameraSwitch.isOn,
                    autoEnableSpeaker: speakerSwitch.isOn
                )
            ),
            animated: true
        )
    }
}

extension RoomJoinView {

    @objc private func handleBlankTap() {
        endEditing(true)
    }
}

extension RoomJoinView: UITextFieldDelegate {

    public func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        textField.resignFirstResponder()
        joinWithCurrentInput()
        return true
    }
}

extension String {
    fileprivate static var joinNavTitle: String { RoomKitResources.localizedString("roomkit.join.nav_title") }
    fileprivate static var joinRoomId: String { RoomKitResources.localizedString("roomkit.join.room_id") }
    fileprivate static var joinRoomIdPlaceholder: String { RoomKitResources.localizedString("roomkit.join.room_id_placeholder") }
    fileprivate static var joinInvalidRoomId: String { RoomKitResources.localizedString("roomkit.join.invalid_room_id") }
    fileprivate static var preMicOn: String { RoomKitResources.localizedString("roomkit.pre.mic_on") }
    fileprivate static var preSpeakerOn: String { RoomKitResources.localizedString("roomkit.pre.speaker_on") }
    fileprivate static var preCameraOn: String { RoomKitResources.localizedString("roomkit.pre.camera_on") }
    fileprivate static var preMicPermissionDenied: String { RoomKitResources.localizedString("roomkit.pre.mic_permission_denied") }
    fileprivate static var preCameraPermissionDenied: String { RoomKitResources.localizedString("roomkit.pre.camera_permission_denied") }
    fileprivate static var preGoEnable: String { RoomKitResources.localizedString("roomkit.pre.go_enable") }
}
