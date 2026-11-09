import TUIRoomKit
import UIKit
import SnapKit
import AtomicXCore

public final class RoomJoinView: UIView {

    public weak var routerContext: RouterContext?

    private var isPushing = false

    private let navBar = UIView()
    private let navBarContent = UIView()
    private let navBackButton = UIButton(type: .custom)
    private let navBackIcon = UIImageView()
    private let navTitleLabel = UILabel()

    private let scrollView = UIScrollView()
    private let contentView = UIView()

    private let roomCard = UIStackView()
    private let roomIDInput = UITextField()

    private let mediaCard = UIStackView()
    private let microphoneSwitch = UISwitch()
    private let speakerSwitch = UISwitch()
    private let cameraSwitch = UISwitch()
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
        isPushing = false
    }

    private func setupViews() {
        addSubview(navBar)
        navBar.addSubview(navBarContent)
        navBackButton.addSubview(navBackIcon)
        navBarContent.addSubview(navBackButton)
        navBarContent.addSubview(navTitleLabel)
        navBackButton.addTarget(self, action: #selector(handleNavBarBack), for: .touchUpInside)
        navBackButton.addTarget(self, action: #selector(handleNavBarBackHighlight), for: [.touchDown, .touchDragEnter])
        navBackButton.addTarget(self, action: #selector(handleNavBarBackUnhighlight),
                                for: [.touchUpInside, .touchUpOutside, .touchCancel, .touchDragExit])

        scrollView.alwaysBounceVertical = true
        scrollView.keyboardDismissMode = .onDrag
        scrollView.addSubview(contentView)
        addSubview(scrollView)

        configureCard(roomCard)
        configureCard(mediaCard)
        addRow(to: roomCard, title: .joinRoomId, content: roomIDInput, trailingAligned: false)
        addRow(to: mediaCard, title: .preMicOn, content: microphoneSwitch, trailingAligned: true)
        addRow(to: mediaCard, title: .preSpeakerOn, content: speakerSwitch, trailingAligned: true)
        addRow(to: mediaCard, title: .preCameraOn, content: cameraSwitch, trailingAligned: true)
        contentView.addSubview(roomCard)
        contentView.addSubview(mediaCard)

        addSubview(submitButton)
    }

    private func setupConstraints() {
        navBar.snp.makeConstraints {
            $0.top.leading.trailing.equalToSuperview()
            $0.bottom.equalTo(safeAreaLayoutGuide.snp.top).offset(52)
        }
        navBarContent.snp.makeConstraints {
            $0.leading.trailing.bottom.equalToSuperview()
            $0.height.equalTo(52)
        }
        navBackButton.snp.makeConstraints {
            $0.leading.equalToSuperview().offset(8)
            $0.centerY.equalToSuperview()
            $0.size.equalTo(40)
        }
        navBackIcon.snp.makeConstraints {
            $0.center.equalToSuperview()
            $0.size.equalTo(22)
        }
        navTitleLabel.snp.makeConstraints {
            $0.center.equalToSuperview()
            $0.leading.greaterThanOrEqualToSuperview().offset(72)
            $0.trailing.lessThanOrEqualToSuperview().offset(-72)
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

        navBar.backgroundColor = UIColor.roomKitBgSurface
        navBackButton.layer.cornerRadius = 20
        navBackIcon.isUserInteractionEnabled = false
        navBackIcon.image = UIImage(named: "roomkit_icon_back")
        navBackButton.accessibilityLabel = NSLocalizedString("app.common.back", comment: "")
        navTitleLabel.font = .systemFont(ofSize: 17, weight: .semibold)
        navTitleLabel.textAlignment = .center
        navTitleLabel.textColor = UIColor.roomKitFgPrimary
        navTitleLabel.text = .joinNavTitle
        
        roomIDInput.keyboardType = .asciiCapable
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
        submitButton.addTarget(self, action: #selector(handleSubmitTap), for: .touchUpInside)
        roomIDInput.delegate = self

        microphoneSwitch.isOn = true
        cameraSwitch.isOn = true
        speakerSwitch.isOn = true

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
    fileprivate static var joinNavTitle: String { NSLocalizedString("app.join.nav_title", comment: "") }
    fileprivate static var joinRoomId: String { NSLocalizedString("app.join.room_id", comment: "") }
    fileprivate static var joinRoomIdPlaceholder: String { NSLocalizedString("app.join.room_id_placeholder", comment: "") }
    fileprivate static var joinInvalidRoomId: String { NSLocalizedString("app.join.invalid_room_id", comment: "") }
    fileprivate static var preMicOn: String { NSLocalizedString("app.pre.mic_on", comment: "") }
    fileprivate static var preSpeakerOn: String { NSLocalizedString("app.pre.speaker_on", comment: "") }
    fileprivate static var preCameraOn: String { NSLocalizedString("app.pre.camera_on", comment: "") }
}

extension RoomJoinView {

    @objc private func handleNavBarBack() {
        routerContext?.pop(animated: true)
    }

    @objc private func handleNavBarBackHighlight() {
        navBackButton.alpha = 0.72
    }

    @objc private func handleNavBarBackUnhighlight() {
        navBackButton.alpha = 1
    }
}
