import TUIRoomKit
import UIKit
import SnapKit
import Combine
import AtomicXCore

public final class RoomQuickStartView: UIView {

    public weak var routerContext: RouterContext?

    private var isPushing = false
    private static let roomNotFoundCode = 100004
    private static let displayNameMaxLength = 10
    private var cancellableSet = Set<AnyCancellable>()

    private let navBar = UIView()
    private let navBarContent = UIView()
    private let navBackButton = UIButton(type: .custom)
    private let navBackIcon = UIImageView()
    private let navTitleLabel = UILabel()

    private let scrollView = UIScrollView()
    private let contentView = UIView()

    private let nameCard = UIStackView()
    private let nameInput = UILabel()

    private let mediaCard = UIStackView()
    private let microphoneSwitch = UISwitch()
    private let speakerSwitch = UISwitch()
    private let cameraSwitch = UISwitch()

    private let submitButton = UIButton(type: .custom)
    private let enteringView = RoomLoadingView()

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

        configureCard(nameCard)
        configureCard(mediaCard)
        addRow(to: nameCard, title: .quickStartMeetingName, content: nameInput, trailingAligned: false)
        addRow(to: mediaCard, title: .preMicOn, content: microphoneSwitch, trailingAligned: true)
        addRow(to: mediaCard, title: .preSpeakerOn, content: speakerSwitch, trailingAligned: true)
        addRow(to: mediaCard, title: .preCameraOn, content: cameraSwitch, trailingAligned: true)
        contentView.addSubview(nameCard)
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
        nameCard.snp.makeConstraints {
            $0.top.equalToSuperview().offset(12)
            $0.leading.equalToSuperview().offset(16)
            $0.trailing.equalToSuperview().offset(-16)
        }
        mediaCard.snp.makeConstraints {
            $0.top.equalTo(nameCard.snp.bottom).offset(12)
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
        navTitleLabel.text = .quickStartNavTitle
        
        nameInput.font = .systemFont(ofSize: 15)
        nameInput.textColor = UIColor.roomKitFgSecondary
        nameInput.textAlignment = .right

        submitButton.layer.cornerRadius = 12
        submitButton.layer.masksToBounds = true
        submitButton.titleLabel?.font = .systemFont(ofSize: 15)
        submitButton.setTitle(.quickStartNavTitle, for: .normal)
        submitButton.snp.makeConstraints { $0.height.equalTo(48) }

        for control in [microphoneSwitch, speakerSwitch, cameraSwitch] {
            control.applyRoomKitStyle()
        }

        applyTheme()
    }

    private func setupBindings() {
        submitButton.addTarget(self, action: #selector(handleSubmitTap), for: .touchUpInside)

        microphoneSwitch.isOn = true
        cameraSwitch.isOn = true
        speakerSwitch.isOn = true

        LoginStore.shared.state
            .subscribe(StatePublisherSelector(projector: { state in
                guard state.loginStatus == .logined, let profile = state.loginUserInfo else { return "" }
                if let nickname = profile.nickname, !nickname.isEmpty { return String(nickname.prefix(Self.displayNameMaxLength)) }
                return String(profile.userID.prefix(Self.displayNameMaxLength))
            }))
            .receive(on: RunLoop.main)
            .sink { [weak self] name in
                guard let self, self.nameInput.text?.isEmpty != false else { return }
                self.nameInput.text = String(format: NSLocalizedString("app.quick_start.title_placeholder", comment: ""), name)
            }
            .store(in: &cancellableSet)
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

    private func applyTheme() {
        backgroundColor = UIColor.roomKitBgCanvas
        submitButton.backgroundColor = UIColor.roomKitAccent
        submitButton.setTitleColor(UIColor.roomKitFgOnAccent, for: .normal)
    }

    @objc private func handleSubmitTap() {
        startMeeting(
            roomName: nameInput.text?.trimmingCharacters(in: .whitespacesAndNewlines) ?? "",
            isMicrophoneOn: microphoneSwitch.isOn,
            isSpeakerOn: speakerSwitch.isOn,
            isCameraOn: cameraSwitch.isOn
        )
    }

    private func startMeeting(roomName: String, isMicrophoneOn: Bool, isSpeakerOn: Bool, isCameraOn: Bool) {
        guard !isPushing else { return }
        isPushing = true
        enteringView.setShown(true)
        generateUnusedRoomID { [weak self] roomID in
            guard let self else { return }
            let finalName = roomName.isEmpty ? roomID : roomName
            var options = CreateRoomOptions()
            options.roomName = finalName
            self.routerContext?.push(
                MeetingViewController(
                    roomID: roomID,
                    behavior: .createAndJoinRoom(options: options),
                    config: RoomConnectConfig(
                        autoEnableMicrophone: isMicrophoneOn,
                        autoEnableCamera: isCameraOn,
                        autoEnableSpeaker: isSpeakerOn
                    )
                ),
                animated: true
            )
        }
    }

    private func generateUnusedRoomID(remainingAttempts: Int = 5, onReady: @escaping (String) -> Void) {
        let candidate = String(Int.random(in: 100_000...999_999))
        RoomStore.shared.getRoomInfo(roomID: candidate) { result in
            DispatchQueue.main.async {
                switch result {
                case .success:
                    if remainingAttempts > 0 {
                        self.generateUnusedRoomID(remainingAttempts: remainingAttempts - 1, onReady: onReady)
                    } else {
                        onReady(Self.fallbackRoomID(base: candidate))
                    }
                case .failure(let error):
                    if error.code == Self.roomNotFoundCode {
                        onReady(candidate)
                    } else {
                        onReady(Self.fallbackRoomID(base: candidate))
                    }
                }
            }
        }
    }

    private static func fallbackRoomID(base: String) -> String {
        let millis = Int64(Date().timeIntervalSince1970 * 1000)
        return "\(base)-\(String(millis).prefix(6))"
    }
}

extension RoomQuickStartView {

    @objc private func handleBlankTap() {
        endEditing(true)
    }
}

extension String {
    fileprivate static var quickStartNavTitle: String { NSLocalizedString("app.quick_start.nav_title", comment: "") }
    fileprivate static var quickStartMeetingName: String { NSLocalizedString("app.quick_start.meeting_name", comment: "") }
    fileprivate static var preMicOn: String { NSLocalizedString("app.pre.mic_on", comment: "") }
    fileprivate static var preSpeakerOn: String { NSLocalizedString("app.pre.speaker_on", comment: "") }
    fileprivate static var preCameraOn: String { NSLocalizedString("app.pre.camera_on", comment: "") }
}

extension RoomQuickStartView {

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
