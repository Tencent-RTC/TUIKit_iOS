import Combine
import SnapKit
import UIKit

final class VoiceLoungeBottomBar: UIView {
    var onComment: (() -> Void)?
    var onLike: (() -> Void)?
    var onGift: (() -> Void)?
    var onAudioEffects: (() -> Void)?
    var onBackgroundMusic: (() -> Void)?

    let role: VoiceLoungeRole
    private let liveID: String
    private let seatStore: VoiceLoungeSeatStore
    private let livingActions: VoiceLoungeLivingActions
    private var cancellables = Set<AnyCancellable>()
    private lazy var coGuestManagePanel = VoiceLoungeCoGuestManagePanel(liveID: liveID, coGuest: seatStore.coGuest)
    private lazy var coGuestPanel = VoiceLoungeCoGuestPanel(liveID: liveID, coGuest: seatStore.coGuest)
    private lazy var morePanel: VoiceLoungeLivingMorePanel = {
        let panel = VoiceLoungeLivingMorePanel(settings: seatStore.settings, livingActions: livingActions)
        panel.onComment = { [weak self] in self?.onComment?() }
        return panel
    }()

    private let hostCoMicButton: BottomBarButton
    private let hostMuteButton = BottomBarActionButton(
        imageName: .micOn, iconSize: 26, iconCenterOffset: -0.5, title: .mute)
    private let hostMusicButton = BottomBarActionButton(
        imageName: "livekit_living_setting_music", iconSize: 22, title: .backgroundMusic)
    private let hostAudioButton = BottomBarActionButton(
        imageName: "livekit_living_setting_audio", iconSize: 20.5, title: .audioEffects)
    private let hostMoreButton = BottomBarActionButton(imageName: "livekit_living_more", iconSize: 27, title: .more)
    private var hostActionButtons: [BottomBarActionButton] {
        [hostMuteButton, hostMusicButton, hostAudioButton, hostMoreButton]
    }

    private let inputPill = UIControl()
    private let inputPlaceholder = LiveText.voiceLounge(.body, tone: .tertiary)
    private let audienceCoMicButton: BottomBarCircleButton
    private let audienceLikeButton: BottomBarCircleButton
    private let audienceGiftButton: BottomBarCircleButton

    init(liveID: String, seatStore: VoiceLoungeSeatStore, livingActions: VoiceLoungeLivingActions) {
        self.role = seatStore.role
        self.liveID = liveID
        self.seatStore = seatStore
        self.livingActions = livingActions
        hostCoMicButton = BottomBarButton(icon: .coMic, titleKey: "tuilivekit.voiceroom.room.comic")
        audienceCoMicButton = BottomBarCircleButton(icon: .coMic)
        audienceLikeButton = BottomBarCircleButton(icon: .like)
        audienceGiftButton = BottomBarCircleButton(icon: .gift)
        super.init(frame: .zero)
        setupViews()
        setupConstraints()
        setupStyles()
        setupBindings()
    }

    @available(*, unavailable) required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    func likeButtonCenter(in view: UIView) -> CGPoint {
        audienceLikeButton.convert(
            CGPoint(x: audienceLikeButton.bounds.midX, y: audienceLikeButton.bounds.midY), to: view)
    }

    private func setupViews() {
        switch role {
        case .host:
            addSubview(hostCoMicButton)
            [hostMuteButton, hostMusicButton, hostAudioButton, hostMoreButton].forEach(addSubview)
        case .audience:
            addSubview(inputPill)
            inputPill.addSubview(inputPlaceholder)
            [audienceCoMicButton, audienceLikeButton, audienceGiftButton].forEach(addSubview)
        }
    }

    private func setupConstraints() {
        switch role {
        case .host:
            hostCoMicButton.snp.makeConstraints { make in
                make.leading.equalToSuperview().offset(12)
                make.centerY.equalToSuperview()
                make.top.greaterThanOrEqualToSuperview()
                make.bottom.lessThanOrEqualToSuperview()
            }
            let titles: [String] = [.mute, .unmute, .backgroundMusic, .audioEffects, .more]
            let slotWidth = titles.map(BottomBarActionButton.fittingWidth(for:)).max() ?? 34
            hostMoreButton.snp.makeConstraints { make in
                make.trailing.equalToSuperview().inset(12)
                make.centerY.equalTo(hostCoMicButton)
            }
            hostAudioButton.snp.makeConstraints { make in
                make.trailing.equalTo(hostMoreButton.snp.leading).offset(-12)
                make.centerY.equalTo(hostMoreButton)
            }
            hostMusicButton.snp.makeConstraints { make in
                make.trailing.equalTo(hostAudioButton.snp.leading).offset(-12)
                make.centerY.equalTo(hostMoreButton)
            }
            hostMuteButton.snp.makeConstraints { make in
                make.trailing.equalTo(hostMusicButton.snp.leading).offset(-12)
                make.leading.greaterThanOrEqualTo(hostCoMicButton.snp.trailing).offset(12)
                make.centerY.equalTo(hostMoreButton)
            }
            hostActionButtons.forEach { button in
                button.snp.makeConstraints { make in make.width.equalTo(slotWidth).priority(.high) }
            }
        case .audience:
            audienceGiftButton.snp.makeConstraints { make in
                make.trailing.equalToSuperview().inset(12)
                make.centerY.equalToSuperview()
                make.size.equalTo(36)
            }
            audienceLikeButton.snp.makeConstraints { make in
                make.trailing.equalTo(audienceGiftButton.snp.leading).offset(-8)
                make.centerY.equalToSuperview()
                make.size.equalTo(36)
            }
            audienceCoMicButton.snp.makeConstraints { make in
                make.trailing.equalTo(audienceLikeButton.snp.leading).offset(-8)
                make.centerY.equalToSuperview()
                make.size.equalTo(36)
            }
            inputPill.snp.makeConstraints { make in
                make.leading.equalToSuperview().inset(12)
                make.trailing.equalTo(audienceCoMicButton.snp.leading).offset(-10)
                make.centerY.equalToSuperview()
                make.height.equalTo(36)
            }
            inputPlaceholder.snp.makeConstraints { make in
                make.leading.trailing.equalToSuperview().inset(14)
                make.centerY.equalToSuperview()
            }
        }
    }

    private func setupStyles() {
        guard role == .audience else { return }
        inputPill.backgroundColor = UIColor.black.withAlphaComponent(0.3)
        inputPill.layer.cornerRadius = 18
        inputPlaceholder.text = .inputPlaceholder
        inputPlaceholder.isUserInteractionEnabled = false
    }

    private func setupBindings() {
        switch role {
        case .host:
            hostCoMicButton.onTap = { [weak self] in self?.showCoMic() }
            hostMuteButton.onTap = { [weak self] in
                self?.livingActions.toggleMute()
                self?.syncMuteIcon()
            }
            hostMusicButton.onTap = { [weak self] in self?.onBackgroundMusic?() }
            hostAudioButton.onTap = { [weak self] in self?.onAudioEffects?() }
            hostMoreButton.onTap = { [weak self] in self?.showHostTools() }
        case .audience:
            inputPill.addTarget(self, action: #selector(tapInput), for: .touchUpInside)
            audienceCoMicButton.onTap = { [weak self] in self?.showCoMic() }
            audienceLikeButton.onTap = { [weak self] in self?.onLike?() }
            audienceGiftButton.onTap = { [weak self] in self?.onGift?() }
        }
        guard role == .host else { return }
        seatStore.coGuest.changes.sink { [weak self] in
            guard let self else { return }
            self.hostCoMicButton.setBadgeVisible(!self.seatStore.coGuest.applicants.isEmpty)
        }.store(in: &cancellables)
        seatStore.changes.sink { [weak self] in self?.syncMuteIcon() }.store(in: &cancellables)
        syncMuteIcon()
    }

    private func syncMuteIcon() {
        guard role == .host else { return }
        let muted = livingActions.isMuted()
        hostMuteButton.setImage(named: muted ? .micOff : .micOn)
        hostMuteButton.setTitle(muted ? .unmute : .mute)
    }

    override func didMoveToWindow() {
        super.didMoveToWindow()
        guard let window else {
            panels.forEach { $0.removeFromSuperview() }
            return
        }
        panels.forEach { panel in
            guard panel.superview !== window else { return }
            panel.removeFromSuperview()
            window.addSubview(panel)
            panel.snp.remakeConstraints { make in make.edges.equalToSuperview() }
        }
    }

    private var panels: [BottomSheetView] { role == .host ? [coGuestManagePanel, morePanel] : [coGuestPanel] }

    private func showCoMic() {
        let skin = seatStore.skin
        switch role {
        case .host: coGuestManagePanel.show(skin: skin)
        case .audience: coGuestPanel.show(preferredSeatIndex: seatStore.audienceFadedSeatIndex, skin: skin)
        }
    }

    private func showHostTools() { morePanel.show() }
}

extension VoiceLoungeBottomBar { @objc private func tapInput() { onComment?() } }

private final class BottomBarButton: UIControl {
    enum Icon { case coMic }

    var onTap: (() -> Void)?

    private let iconImageView = UIImageView()
    private let titleLabel = LiveText(.control, tone: .secondary, alignment: .center)
    private let badgeView = UIView()

    init(icon: Icon, titleKey: String) {
        super.init(frame: .zero)

        iconImageView.contentMode = .scaleAspectFit
        iconImageView.isUserInteractionEnabled = false
        addSubview(iconImageView)

        badgeView.backgroundColor = VoiceLoungeColor.rose
        badgeView.layer.cornerRadius = 4
        badgeView.isHidden = true
        badgeView.isUserInteractionEnabled = false
        addSubview(badgeView)

        iconImageView.image = LiveKitResources.image(named: "livekit_living_coguest")

        titleLabel.text = LiveKitResources.localizedString(titleKey)
        titleLabel.applyBottomBarShadow()
        titleLabel.isUserInteractionEnabled = false
        addSubview(titleLabel)

        snp.makeConstraints { make in
            make.width.equalTo(46)
            make.height.equalTo(46)
        }
        iconImageView.snp.makeConstraints { make in
            make.top.equalToSuperview().offset(-6)
            make.centerX.equalToSuperview()
            make.width.equalTo(46)
            make.height.equalTo(38)
        }
        titleLabel.snp.makeConstraints { make in
            make.leading.trailing.equalToSuperview()
            make.top.equalToSuperview().offset(30)
            make.height.equalTo(16)
        }
        badgeView.snp.makeConstraints { make in
            make.size.equalTo(8)
            make.centerX.equalTo(iconImageView.snp.leading).offset(38)
            make.centerY.equalTo(iconImageView.snp.top).offset(9)
        }
        addTarget(self, action: #selector(tap), for: .touchUpInside)
    }

    func setBadgeVisible(_ visible: Bool) { badgeView.isHidden = !visible }

    @available(*, unavailable) required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    @objc private func tap() { onTap?() }
}

private final class BottomBarCircleButton: UIControl {
    enum Icon { case coMic, like, gift }

    var onTap: (() -> Void)?

    private let iconView = UIImageView()

    init(icon: Icon) {
        super.init(frame: .zero)
        iconView.contentMode = .scaleAspectFit
        iconView.isUserInteractionEnabled = false
        addSubview(iconView)
        switch icon {
        case .coMic:
            backgroundColor = UIColor.black.withAlphaComponent(0.3)
            iconView.image = LiveKitResources.image(named: "livekit_coguest_idle")
            iconView.snp.makeConstraints {
                $0.center.equalToSuperview()
                $0.size.equalTo(24)
            }
        case .like, .gift:
            iconView.image = LiveKitResources.image(
                named: icon == .like ? "livekit_player_like" : "livekit_player_gift")
            iconView.snp.makeConstraints { $0.edges.equalToSuperview() }
        }
        addTarget(self, action: #selector(tap), for: .touchUpInside)
    }

    @available(*, unavailable) required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    override func layoutSubviews() {
        super.layoutSubviews()
        layer.cornerRadius = bounds.width / 2
    }

    @objc private func tap() { onTap?() }
}

private final class BottomBarActionButton: UIControl {
    var onTap: (() -> Void)?

    private static let iconCenterY: CGFloat = 13.5
    private let iconView = UIImageView()
    private let titleLabel = LiveText(.control, tone: .secondary, alignment: .center)

    static func fittingWidth(for title: String) -> CGFloat {
        let label = LiveText(.control, tone: .secondary, alignment: .center)
        label.text = title
        return max(34, ceil(label.intrinsicContentSize.width))
    }

    init(imageName: String, iconSize: CGFloat, iconCenterOffset: CGFloat = 0, title: String) {
        super.init(frame: .zero)
        iconView.contentMode = .scaleAspectFit
        iconView.isUserInteractionEnabled = false
        addSubview(iconView)

        titleLabel.adjustsFontSizeToFitWidth = true
        titleLabel.minimumScaleFactor = 0.75
        titleLabel.applyBottomBarShadow()
        titleLabel.isUserInteractionEnabled = false
        addSubview(titleLabel)

        snp.makeConstraints { make in
            make.width.greaterThanOrEqualTo(34)
            make.height.equalTo(46)
        }
        iconView.snp.makeConstraints { make in
            make.centerY.equalTo(snp.top).offset(Self.iconCenterY + iconCenterOffset)
            make.centerX.equalToSuperview()
            make.size.equalTo(iconSize)
        }
        titleLabel.snp.makeConstraints { make in
            make.leading.trailing.equalToSuperview()
            make.top.equalToSuperview().offset(30)
            make.height.equalTo(16)
        }
        isAccessibilityElement = true
        accessibilityTraits = .button
        setImage(named: imageName)
        setTitle(title)
        addTarget(self, action: #selector(tap), for: .touchUpInside)
    }

    @available(*, unavailable) required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    func setImage(named name: String) { iconView.image = LiveKitResources.image(named: name) }

    func setTitle(_ title: String) {
        titleLabel.text = title
        accessibilityLabel = title
    }

    @objc private func tap() { onTap?() }
}

private extension UILabel {
    func applyBottomBarShadow() {
        layer.shadowColor = UIColor.black.withAlphaComponent(0.35).cgColor
        layer.shadowOffset = CGSize(width: 0, height: 1)
        layer.shadowRadius = 2
        layer.shadowOpacity = 1
    }
}

private extension String {
    static let micOn = "livekit_coguest_seat_mic"
    static let micOff = "livekit_coguest_seat_muted"

    static var mute: String { LiveKitResources.localizedString("tuilivekit.voiceroom.living.mute") }
    static var unmute: String { LiveKitResources.localizedString("tuilivekit.voiceroom.living.unmute") }
    static var backgroundMusic: String { LiveKitResources.localizedString("tuilivekit.voiceroom.living.bgm") }
    static var audioEffects: String { LiveKitResources.localizedString("tuilivekit.voiceroom.prepare.more_audio") }
    static var more: String { LiveKitResources.localizedString("tuilivekit.voiceroom.room.more") }

    static var inputPlaceholder: String {
        LiveKitResources.localizedString("tuilivekit.voiceroom.room.input_placeholder")
    }
}
