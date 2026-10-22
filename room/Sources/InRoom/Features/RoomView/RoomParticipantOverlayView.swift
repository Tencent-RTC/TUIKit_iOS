import UIKit
import SnapKit
import AtomicXCore

final class RoomParticipantOverlayView: UIView {

    private var role: ParticipantRole?
    private var isLocal = false
    private var isCameraOn = false

    private let avatar = RoomAvatar()
    private let flipButton = UIButton(type: .custom)
    private let screenStatusLabel = UILabel()
    private let footer = UIView()
    private let footerStack = UIStackView()
    private let microphone = UIImageView()
    private let micLevel = RoomMicLevelView()
    private let nameLabel = UILabel()
    private let localBadge = UIView()
    private let localBadgeLabel = UILabel()
    private let roleBadge = UIView()
    private let roleBadgeIcon = UIImageView()
    private let speakingBorder = UIView()

    private let netMark: UIView = {
        let row = UIStackView()
        row.axis = .horizontal
        row.alignment = .bottom
        row.spacing = 2
        row.isUserInteractionEnabled = false
        return row
    }()

    private let netBars: [UIView] = RoomParticipantOverlayView.makeNetBars()

    override init(frame: CGRect) {
        super.init(frame: frame)
        isUserInteractionEnabled = true
        setupViews()
        setupConstraints()
        setupStyles()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func didMoveToWindow() {
        super.didMoveToWindow()
        if window != nil {
            applyTheme()
            updateBadges()
        }
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        footer.layer.cornerRadius = footer.bounds.height / 2
        localBadge.layer.cornerRadius = localBadge.bounds.height / 2
        roleBadge.layer.cornerRadius = roleBadge.bounds.height / 2
        updateBadges()
    }

    private func setupViews() {
        microphone.addSubview(micLevel)
        footerStack.addArrangedSubview(microphone)
        footerStack.addArrangedSubview(roleBadge)
        footerStack.addArrangedSubview(nameLabel)
        footerStack.addArrangedSubview(localBadge)
        footer.addSubview(footerStack)
        localBadge.addSubview(localBadgeLabel)
        roleBadge.addSubview(roleBadgeIcon)

        addSubview(avatar)
        addSubview(screenStatusLabel)
        addSubview(footer)
        addSubview(speakingBorder)
        addSubview(flipButton)
        addSubview(netMark)
    }

    override func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
        let hit = super.hitTest(point, with: event)
        return hit === self ? nil : hit
    }

    private func setupConstraints() {
        avatar.snp.makeConstraints {
            $0.center.equalToSuperview()
            $0.size.equalTo(40)
        }
        screenStatusLabel.snp.makeConstraints {
            $0.center.equalToSuperview()
            $0.leading.trailing.equalToSuperview().inset(16)
        }
        footer.snp.makeConstraints {
            $0.leading.equalToSuperview().offset(6)
            $0.bottom.equalToSuperview().offset(-6)
            $0.trailing.lessThanOrEqualToSuperview().offset(-6)
        }
        footerStack.snp.makeConstraints {
            $0.edges.equalToSuperview().inset(UIEdgeInsets(top: 2, left: 4, bottom: 2, right: 6))
        }
        microphone.snp.makeConstraints { $0.size.equalTo(12) }
        let cavity = RoomMicLevelView.cavityFrame(inIconBox: CGRect(x: 0, y: 0, width: 12, height: 12))
        micLevel.snp.makeConstraints {
            $0.leading.equalToSuperview().offset(cavity.minX)
            $0.top.equalToSuperview().offset(cavity.minY)
            $0.size.equalTo(cavity.size)
        }
        localBadge.snp.makeConstraints {
            $0.height.equalTo(16)
            $0.width.greaterThanOrEqualTo(16)
        }
        roleBadge.snp.makeConstraints {
            $0.size.equalTo(Self.ROLE_MARK_SIZE)
        }
        flipButton.snp.makeConstraints {
            $0.top.leading.equalToSuperview().offset(8)
            $0.size.equalTo(Self.FLIP_SIZE)
        }
        localBadgeLabel.snp.makeConstraints {
            $0.leading.trailing.equalToSuperview().inset(4)
            $0.centerY.equalToSuperview()
        }
        roleBadgeIcon.snp.makeConstraints {
            $0.center.equalToSuperview()
            $0.size.equalTo(Self.adminIconSize)
        }
        roleBadgeIcon.setContentCompressionResistancePriority(.required, for: .horizontal)
        speakingBorder.snp.makeConstraints { $0.edges.equalToSuperview() }

        netMark.snp.makeConstraints {
            $0.top.trailing.equalToSuperview().inset(8)
        }
    }

    private func setupStyles() {
        screenStatusLabel.font = .systemFont(ofSize: 14)
        screenStatusLabel.textAlignment = .center
        screenStatusLabel.numberOfLines = 0
        screenStatusLabel.isHidden = true

        footer.layer.masksToBounds = true
        footerStack.axis = .horizontal
        footerStack.alignment = .center
        footerStack.spacing = 4

        nameLabel.font = .systemFont(ofSize: 10)
        nameLabel.lineBreakMode = .byTruncatingTail
        nameLabel.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)

        localBadgeLabel.text = .roomViewMe
        for badge in [localBadge, roleBadge] {
            badge.isHidden = true
            badge.layer.masksToBounds = true
            badge.setContentCompressionResistancePriority(.required, for: .horizontal)
        }
        localBadgeLabel.font = .systemFont(ofSize: 10, weight: .medium)
        localBadgeLabel.textAlignment = .center
        roleBadgeIcon.contentMode = .scaleAspectFit

        flipButton.setImage(RoomKitResources.image(named: "roomkit_icon_flip_camera_roomview"), for: .normal)
        flipButton.backgroundColor = UIColor.roomKitBgOnMedia
        flipButton.layer.cornerRadius = Self.FLIP_SIZE / 2
        flipButton.imageEdgeInsets = UIEdgeInsets(top: 6, left: 6, bottom: 6, right: 6)
        flipButton.isHidden = true
        flipButton.accessibilityLabel = .roomViewFlipCamera
        flipButton.addTarget(self, action: #selector(handleFlipTap), for: .touchUpInside)
        flipButton.addTarget(self, action: #selector(handleFlipPressBegin), for: [.touchDown, .touchDownRepeat])
        flipButton.addTarget(self, action: #selector(handleFlipPressEnd), for: [.touchUpInside, .touchUpOutside, .touchCancel])

        speakingBorder.isHidden = true
        speakingBorder.backgroundColor = .clear
        speakingBorder.layer.cornerRadius = RoomVideoFlowLayout.cornerRadius
        speakingBorder.layer.borderWidth = 2

        netBars.forEach { (netMark as? UIStackView)?.addArrangedSubview($0) }
        for (index, bar) in netBars.enumerated() {
            bar.backgroundColor = UIColor.roomKitDanger
            bar.layer.cornerRadius = 1
            bar.snp.makeConstraints {
                $0.width.equalTo(3)
                $0.height.equalTo(Self.netBarHeights[index])
            }
        }
        netMark.isHidden = true
        netMark.accessibilityLabel = .roomViewNetworkQuality

        applyTheme()
    }

    private func applyTheme() {
        screenStatusLabel.textColor = UIColor.roomKitFgOnMedia
        footer.backgroundColor = UIColor.roomKitBgOnMedia
        nameLabel.textColor = UIColor.roomKitFgOnMedia
        localBadgeLabel.textColor = UIColor.roomKitFgOnMedia
        speakingBorder.layer.borderColor = UIColor.roomKitSuccessBorder.cgColor
    }

    private func updateBadges() {
        let hasPrivilegedRole = role != nil && role != .generalUser
        localBadge.isHidden = !(isLocal && bounds.width >= RoomParticipantOverlayView.localBadgeMinWidth)
        roleBadge.isHidden = !(hasPrivilegedRole && bounds.width >= RoomParticipantOverlayView.roleBadgeMinWidth)
        localBadge.backgroundColor = UIColor.roomKitBgPressOnMedia
        flipButton.isHidden = !(isLocal && isCameraOn)
        if role == .owner {
            roleBadge.backgroundColor = UIColor.roomKitAccent
            roleBadge.accessibilityLabel = .roomViewOwner
        } else {
            roleBadge.backgroundColor = UIColor.roomKitWarning
            roleBadge.accessibilityLabel = .roomViewAdmin
        }
        let iconSize = role == .owner ? Self.ownerIconSize : Self.adminIconSize
        let iconName = role == .owner ? "roomkit_icon_host_role_roomview" : "roomkit_icon_role_user_roomview"
        roleBadgeIcon.image = RoomKitResources.image(named: iconName)
        roleBadgeIcon.snp.updateConstraints { $0.size.equalTo(iconSize) }
    }
}

// MARK: - public methods

extension RoomParticipantOverlayView {

    func reset() {
        isLocal = false
        isCameraOn = false
        role = nil
        flipButton.isHidden = true
        avatar.url = nil
        avatar.text = nil
        avatar.isHidden = false
        nameLabel.text = nil
        screenStatusLabel.text = nil
        screenStatusLabel.isHidden = true
        microphone.image = nil
        micLevel.isHidden = true
        micLevel.reset()
        microphone.accessibilityLabel = nil
        speakingBorder.isHidden = true
        localBadge.isHidden = true
        roleBadge.isHidden = true
        roleBadgeIcon.image = nil
        roleBadge.accessibilityLabel = nil
    }

    func bind(participant: RoomParticipant,
              streamType: VideoStreamType,
              isLocal: Bool,
              volume: Int,
              hasVideoStream: Bool,
              networkQuality: NetworkQuality? = nil) {
        self.isLocal = isLocal
        role = participant.role
        updateNetworkMark(networkQuality)
        isCameraOn = participant.cameraStatus == .on
        let isMicrophoneOn = participant.microphoneStatus == .on
        speakingBorder.isHidden = !(isMicrophoneOn && volume > 0)
        updateParticipantInfo(participant)
        updateMicrophone(participant.microphoneStatus)
        micLevel.setVolume(isMicrophoneOn ? volume : 0)
        updateBadges()
        updatePlaceholder(streamType: streamType, hasVideoStream: hasVideoStream)
    }
}

// MARK: - private methods

extension RoomParticipantOverlayView {

    fileprivate static let localBadgeMinWidth: CGFloat = 96
    fileprivate static let roleBadgeMinWidth: CGFloat = 112
    fileprivate static let FLIP_SIZE: CGFloat = 28
    fileprivate static let ROLE_MARK_SIZE: CGFloat = 16
    fileprivate static let ownerIconSize: CGFloat = 12
    fileprivate static let adminIconSize: CGFloat = 11
    fileprivate static let netBarHeights: [CGFloat] = [4, 8, 12]

    private static func makeNetBars() -> [UIView] {
        netBarHeights.enumerated().map { index, _ in
            let bar = UIView()
            bar.alpha = index == 0 ? 1 : 0.18
            return bar
        }
    }

    private func updateParticipantInfo(_ participant: RoomParticipant) {
        let name = participant.displayName
        avatar.text = name
        avatar.url = participant.avatarURL
        nameLabel.text = name
    }

    private func updateMicrophone(_ status: DeviceStatus) {
        let isOn = status == .on
        micLevel.isHidden = !isOn
        microphone.image = RoomKitResources.image(named: isOn ? "roomkit_icon_microphone_on_roomview" : "roomkit_icon_microphone_off_roomview")
        microphone.accessibilityLabel = isOn ? .roomViewMicOnHint : .roomViewMicOffHint
    }

    private func updateNetworkMark(_ quality: NetworkQuality?) {
        guard let quality else {
            netMark.isHidden = true
            return
        }
        switch quality {
        case .bad, .veryBad, .down:
            netMark.isHidden = false
        case .excellent, .good, .poor, .unknown:
            netMark.isHidden = true
        @unknown default:
            netMark.isHidden = true
        }
    }

    private func updatePlaceholder(streamType: VideoStreamType, hasVideoStream: Bool) {
        let isScreenShare = streamType == .screen
        avatar.isHidden = isScreenShare || hasVideoStream
        screenStatusLabel.isHidden = !(isLocal && isScreenShare && !hasVideoStream)
        screenStatusLabel.text = .roomViewSharingScreen
    }

    @objc private func handleFlipTap() {
        DeviceStore.shared.switchCamera(isFront: !DeviceStore.shared.state.value.isFrontCamera)
    }

    @objc private func handleFlipPressBegin() {
        UIView.animate(withDuration: 0.1) { self.flipButton.transform = CGAffineTransform(scaleX: 0.96, y: 0.96) }
    }

    @objc private func handleFlipPressEnd() {
        UIView.animate(withDuration: 0.1) { self.flipButton.transform = .identity }
    }
}

extension String {
    fileprivate static var roomViewMe: String { RoomKitResources.localizedString("roomkit.room_view.me") }
    fileprivate static var roomViewOwner: String { RoomKitResources.localizedString("roomkit.room_view.owner") }
    fileprivate static var roomViewAdmin: String { RoomKitResources.localizedString("roomkit.room_view.admin") }
    fileprivate static var roomViewMicOnHint: String { RoomKitResources.localizedString("roomkit.room_view.mic_on_hint") }
    fileprivate static var roomViewMicOffHint: String { RoomKitResources.localizedString("roomkit.room_view.mic_off_hint") }
    fileprivate static var roomViewSharingScreen: String { RoomKitResources.localizedString("roomkit.room_view.sharing_screen") }
    fileprivate static var roomViewFlipCamera: String { RoomKitResources.localizedString("roomkit.room_view.flip_camera") }
    fileprivate static var roomViewNetworkQuality: String { RoomKitResources.localizedString("roomkit.room_view.network_quality") }
}
