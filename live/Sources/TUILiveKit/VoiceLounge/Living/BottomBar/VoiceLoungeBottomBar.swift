import Combine
import SnapKit
import UIKit

final class VoiceLoungeBottomBar: UIView {
    var onComment: (() -> Void)?
    var onGift: (() -> Void)?
    var onAudioEffects: (() -> Void)?
    var onBackgroundMusic: (() -> Void)?

    let role: VoiceLoungeRole
    private let liveID: String
    private let seatStore: VoiceLoungeSeatStore
    private let livingActions: VoiceLoungeLivingActions
    private var cancellables = Set<AnyCancellable>()
    private lazy var coGuestManagePanel = VoiceLoungeCoGuestManagePanel(store: seatStore)
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
        imageName: .audioEffectsIcon, iconSize: 20.5, title: .audioEffects)
    private let hostMoreButton = BottomBarActionButton(imageName: "livekit_living_more", iconSize: 27, title: .more)
    private var hostActionButtons: [BottomBarActionButton] {
        [hostMuteButton, hostMusicButton, hostAudioButton, hostMoreButton]
    }

    private let inputPill = UIControl()
    private let inputPlaceholder = LiveText.voiceLounge(.body, tone: .tertiary)
    private let audienceMuteButton: BottomBarCircleButton
    private let audienceAudioButton: BottomBarCircleButton
    private let audienceCoMicButton: BottomBarCircleButton
    private let audienceGiftButton: BottomBarCircleButton
    private var audienceMuteWidth: Constraint?
    private var audienceMuteSpacing: Constraint?

    init(liveID: String, seatStore: VoiceLoungeSeatStore, livingActions: VoiceLoungeLivingActions) {
        self.role = seatStore.role
        self.liveID = liveID
        self.seatStore = seatStore
        self.livingActions = livingActions
        hostCoMicButton = BottomBarButton(icon: .coMic, titleKey: "tuilivekit.voiceroom.room.comic")
        audienceMuteButton = BottomBarCircleButton(icon: .mute)
        audienceAudioButton = BottomBarCircleButton(icon: .audioEffects)
        audienceCoMicButton = BottomBarCircleButton(icon: .coMic)
        audienceGiftButton = BottomBarCircleButton(icon: .gift)
        super.init(frame: .zero)
        setupViews()
        setupConstraints()
        setupStyles()
        setupBindings()
    }

    @available(*, unavailable) required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    private func setupViews() {
        switch role {
        case .host:
            addSubview(hostCoMicButton)
            [hostMuteButton, hostMusicButton, hostAudioButton, hostMoreButton].forEach(addSubview)
        case .audience:
            addSubview(inputPill)
            inputPill.addSubview(inputPlaceholder)
            [audienceMuteButton, audienceAudioButton, audienceCoMicButton, audienceGiftButton].forEach(addSubview)
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
            audienceCoMicButton.snp.makeConstraints { make in
                make.trailing.equalTo(audienceGiftButton.snp.leading).offset(-8)
                make.centerY.equalToSuperview()
                make.size.equalTo(36)
            }
            audienceAudioButton.snp.makeConstraints { make in
                make.trailing.equalTo(audienceCoMicButton.snp.leading).offset(-8)
                make.centerY.equalToSuperview()
                make.size.equalTo(36)
            }
            audienceMuteButton.snp.makeConstraints { make in
                audienceMuteSpacing = make.trailing.equalTo(audienceAudioButton.snp.leading).constraint
                make.centerY.equalToSuperview()
                make.height.equalTo(36)
                audienceMuteWidth = make.width.equalTo(0).constraint
            }
            inputPill.snp.makeConstraints { make in
                make.leading.equalToSuperview().inset(12)
                make.trailing.equalTo(audienceMuteButton.snp.leading).offset(-10)
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
            audienceMuteButton.onTap = { [weak self] in self?.toggleAudienceMute() }
            audienceAudioButton.onTap = { [weak self] in self?.onAudioEffects?() }
            audienceCoMicButton.onTap = { [weak self] in self?.showCoMic() }
            audienceGiftButton.onTap = { [weak self] in self?.onGift?() }
            seatStore.changes.sink { [weak self] in self?.syncAudienceCoMic() }.store(in: &cancellables)
            seatStore.coGuest.changes.sink { [weak self] in self?.syncAudienceCoMic() }.store(in: &cancellables)
            syncAudienceCoMic()
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

    private var panels: [BottomSheetView] { role == .host ? [coGuestManagePanel, morePanel] : [] }

    private func showCoMic() {
        switch role {
        case .host: coGuestManagePanel.show(skin: seatStore.skin)
        case .audience: tapAudienceCoMic()
        }
    }

    private func tapAudienceCoMic() {
        let coGuest = seatStore.coGuest
        switch coGuest.guestStatus {
        case .idle: coGuest.apply(seatIndex: seatStore.audienceFadedSeatIndex ?? -1)
        case .applying: seatStore.promptCancelApplication()
        case .onSeat: seatStore.promptLeave()
        }
    }

    private func toggleAudienceMute() {
        guard seatStore.toggleSelfMicrophone() else {
            LiveToast.show(.microphoneLocked)
            return
        }
    }

    private func syncAudienceCoMic() {
        guard role == .audience else { return }
        let onSeat = seatStore.coGuest.guestStatus == .onSeat
        audienceMuteButton.isHidden = !onSeat
        audienceMuteButton.setMuted(seatStore.isSelfMicOff)
        audienceMuteWidth?.update(offset: onSeat ? 36 : 0)
        audienceMuteSpacing?.update(offset: onSeat ? -8 : 0)
        audienceCoMicButton.setLeaveBadgeVisible(onSeat)
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

        iconImageView.image = LiveKitResources.image(named: .coMicIcon)

        titleLabel.text = LiveKitResources.localizedString(titleKey)
        titleLabel.applyBottomBarShadow()
        titleLabel.isUserInteractionEnabled = false
        addSubview(titleLabel)

        snp.makeConstraints { make in
            make.width.equalTo(46)
            make.height.equalTo(46)
        }
        iconImageView.snp.makeConstraints { make in
            make.centerY.equalTo(snp.top).offset(13.5)
            make.centerX.equalToSuperview()
            make.size.equalTo(28)
        }
        titleLabel.snp.makeConstraints { make in
            make.leading.trailing.equalToSuperview()
            make.top.equalToSuperview().offset(30)
            make.height.equalTo(16)
        }
        badgeView.snp.makeConstraints { make in
            make.size.equalTo(8)
            make.centerX.equalTo(iconImageView.snp.trailing).offset(-2)
            make.centerY.equalTo(iconImageView.snp.top).offset(5)
        }
        addTarget(self, action: #selector(tap), for: .touchUpInside)
    }

    func setBadgeVisible(_ visible: Bool) { badgeView.isHidden = !visible }

    @available(*, unavailable) required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    @objc private func tap() { onTap?() }
}

private final class BottomBarCircleButton: UIControl {
    enum Icon { case mute, audioEffects, coMic, like, gift }

    var onTap: (() -> Void)?

    private static let micBoxSize: CGFloat = 28
    private static let audioIconSize: CGFloat = 20
    private static let audioIconOpticalOffset: CGFloat = 1
    private static let badgeScale = micBoxSize / 24

    private let icon: Icon
    private let iconView = UIImageView()
    private let micGlyph = GradientGlyphView(path: GradientGlyphView.micPath, lineWidth: 1.6)
    private let gradientIcon = GradientImageView(imageName: .audioEffectsIcon)
    private let leaveBadge = CoMicLeaveBadgeView(radius: 3.6 * badgeScale)

    init(icon: Icon) {
        self.icon = icon
        super.init(frame: .zero)
        setupViews()
        setupConstraints()
        setupStyles()
        setupBindings()
    }

    @available(*, unavailable) required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    func setMuted(_ muted: Bool) {
        micGlyph.path = muted ? GradientGlyphView.micSlashPath : GradientGlyphView.micPath
        accessibilityLabel = muted ? .unmute : .mute
    }

    func setLeaveBadgeVisible(_ visible: Bool) { leaveBadge.isHidden = !visible }

    private var imageSpec: (name: String, size: CGFloat) {
        switch icon {
        case .mute, .audioEffects, .coMic: return (.coMicIcon, Self.micBoxSize)
        case .like: return ("livekit_voiceroom_like", 26)
        case .gift: return ("livekit_voiceroom_gift", 30)
        }
    }

    private func setupViews() {
        switch icon {
        case .mute: addSubview(micGlyph)
        case .audioEffects: addSubview(gradientIcon)
        case .coMic:
            addSubview(iconView)
            addSubview(leaveBadge)
        case .like, .gift: addSubview(iconView)
        }
    }

    private func setupConstraints() {
        switch icon {
        case .mute:
            micGlyph.snp.makeConstraints { make in
                make.center.equalToSuperview()
                make.size.equalTo(Self.micBoxSize)
            }
        case .audioEffects:
            gradientIcon.snp.makeConstraints { make in
                make.centerX.equalToSuperview().offset(-Self.audioIconOpticalOffset)
                make.centerY.equalToSuperview().offset(-Self.audioIconOpticalOffset)
                make.size.equalTo(Self.audioIconSize)
            }
        case .coMic, .like, .gift:
            iconView.snp.makeConstraints { make in
                make.center.equalToSuperview()
                make.size.equalTo(imageSpec.size)
            }
        }
        guard icon == .coMic else { return }
        leaveBadge.snp.makeConstraints { make in
            make.centerX.equalTo(iconView.snp.centerX).offset(7 * Self.badgeScale)
            make.centerY.equalTo(iconView.snp.centerY).offset(7 * Self.badgeScale)
            make.size.equalTo(leaveBadge.side)
        }
    }

    private func setupStyles() {
        backgroundColor = BottomBarStyle.circleBackground
        layer.borderWidth = 1
        layer.borderColor = BottomBarStyle.circleBorder.cgColor
        layer.shadowColor = UIColor.black.cgColor
        layer.shadowOpacity = 0.28
        layer.shadowOffset = CGSize(width: 0, height: 8)
        layer.shadowRadius = 12
        clipsToBounds = false
        iconView.contentMode = .scaleAspectFit
        iconView.isUserInteractionEnabled = false
        iconView.image = icon == .mute || icon == .audioEffects ? nil : LiveKitResources.image(named: imageSpec.name)
        leaveBadge.isHidden = true
        if icon == .mute { accessibilityLabel = .mute }
        if icon == .audioEffects { accessibilityLabel = .audioEffects }
        guard icon == .gift else { return }
        iconView.layer.shadowColor = BottomBarStyle.giftGlow.cgColor
        iconView.layer.shadowOpacity = 0.42
        iconView.layer.shadowOffset = CGSize(width: 0, height: 3)
        iconView.layer.shadowRadius = 3
    }

    private func setupBindings() { addTarget(self, action: #selector(tap), for: .touchUpInside) }

    override var isHighlighted: Bool {
        didSet { transform = isHighlighted ? CGAffineTransform(scaleX: 0.92, y: 0.92) : .identity }
    }

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

private final class GradientGlyphView: UIView {
    var path: UIBezierPath { didSet { setNeedsLayout() } }

    private let lineWidth: CGFloat
    private let gradientLayer = CAGradientLayer()
    private let maskLayer = CAShapeLayer()

    init(path: UIBezierPath, lineWidth: CGFloat) {
        self.path = path
        self.lineWidth = lineWidth
        super.init(frame: .zero)
        setupViews()
        setupStyles()
    }

    @available(*, unavailable) required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    private func setupViews() {
        gradientLayer.mask = maskLayer
        layer.addSublayer(gradientLayer)
    }

    private func setupStyles() {
        isUserInteractionEnabled = false
        gradientLayer.colors = BottomBarStyle.glyphGradient.map(\.cgColor)
        gradientLayer.locations = [0, 0.48, 1]
        gradientLayer.startPoint = .zero
        gradientLayer.endPoint = CGPoint(x: 1, y: 1)
        maskLayer.fillColor = UIColor.clear.cgColor
        maskLayer.strokeColor = UIColor.black.cgColor
        maskLayer.lineCap = .round
        maskLayer.lineJoin = .round
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        let scale = bounds.width / 24
        let scaled = path.copy() as? UIBezierPath ?? UIBezierPath()
        scaled.apply(CGAffineTransform(scaleX: scale, y: scale))
        gradientLayer.frame = bounds
        maskLayer.frame = bounds
        maskLayer.lineWidth = lineWidth * scale
        maskLayer.path = scaled.cgPath
    }

    static var micPath: UIBezierPath {
        let path = UIBezierPath(roundedRect: CGRect(x: 9, y: 3, width: 6, height: 11), cornerRadius: 3)
        path.move(to: CGPoint(x: 6, y: 11))
        path.addArc(withCenter: CGPoint(x: 12, y: 11), radius: 6, startAngle: .pi, endAngle: 0, clockwise: false)
        path.move(to: CGPoint(x: 12, y: 17))
        path.addLine(to: CGPoint(x: 12, y: 21))
        path.move(to: CGPoint(x: 8.5, y: 21))
        path.addLine(to: CGPoint(x: 15.5, y: 21))
        return path
    }

    static var micSlashPath: UIBezierPath {
        let path = micPath
        path.move(to: CGPoint(x: 3.5, y: 3.5))
        path.addLine(to: CGPoint(x: 20.5, y: 20.5))
        return path
    }
}

private final class GradientImageView: UIView {
    private let gradientLayer = CAGradientLayer()
    private let maskLayer = CALayer()

    init(imageName: String) {
        super.init(frame: .zero)
        isUserInteractionEnabled = false
        gradientLayer.colors = BottomBarStyle.glyphGradient.map(\.cgColor)
        gradientLayer.locations = [0, 0.48, 1]
        gradientLayer.startPoint = .zero
        gradientLayer.endPoint = CGPoint(x: 1, y: 1)
        maskLayer.contents = LiveKitResources.image(named: imageName)?.cgImage
        maskLayer.contentsGravity = .resizeAspect
        gradientLayer.mask = maskLayer
        layer.addSublayer(gradientLayer)
    }

    @available(*, unavailable) required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    override func layoutSubviews() {
        super.layoutSubviews()
        gradientLayer.frame = bounds
        maskLayer.frame = bounds
    }
}

private final class CoMicLeaveBadgeView: UIView {
    let side: CGFloat

    private let radius: CGFloat
    private let cutoutLayer = CAShapeLayer()
    private let ringGlyph: GradientGlyphView

    init(radius: CGFloat) {
        self.radius = radius
        side = ceil(radius * 2 + 2)
        let unit = 24 / side
        let ring = UIBezierPath(
            arcCenter: CGPoint(x: 12, y: 12), radius: radius * unit, startAngle: 0, endAngle: .pi * 2, clockwise: true)
        let arm = 1.4 * unit * radius / 3.6
        ring.move(to: CGPoint(x: 12 - arm, y: 12 - arm))
        ring.addLine(to: CGPoint(x: 12 + arm, y: 12 + arm))
        ring.move(to: CGPoint(x: 12 + arm, y: 12 - arm))
        ring.addLine(to: CGPoint(x: 12 - arm, y: 12 + arm))
        ringGlyph = GradientGlyphView(path: ring, lineWidth: 1.3 * unit * radius / 3.6)
        super.init(frame: .zero)
        setupViews()
        setupConstraints()
        setupStyles()
    }

    @available(*, unavailable) required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    private func setupViews() {
        layer.addSublayer(cutoutLayer)
        addSubview(ringGlyph)
    }

    private func setupConstraints() { ringGlyph.snp.makeConstraints { make in make.edges.equalToSuperview() } }

    private func setupStyles() {
        isUserInteractionEnabled = false
        cutoutLayer.fillColor = BottomBarStyle.badgeCutout.cgColor
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        let center = CGPoint(x: bounds.midX, y: bounds.midY)
        cutoutLayer.frame = bounds
        cutoutLayer.path =
            UIBezierPath(arcCenter: center, radius: radius + 0.6, startAngle: 0, endAngle: .pi * 2, clockwise: true)
            .cgPath
    }
}

private enum BottomBarStyle {
    static let circleBackground = UIColor(red: 10 / 255, green: 10 / 255, blue: 15 / 255, alpha: 0.34)
    static let circleBorder = UIColor.white.withAlphaComponent(0.08)
    static let giftGlow = UIColor(red: 1, green: 20 / 255, blue: 139 / 255, alpha: 1)
    static let badgeCutout = UIColor(red: 12 / 255, green: 13 / 255, blue: 18 / 255, alpha: 1)
    static let glyphGradient: [UIColor] = [
        UIColor(red: 1, green: 122 / 255, blue: 198 / 255, alpha: 1),
        UIColor(red: 192 / 255, green: 101 / 255, blue: 240 / 255, alpha: 1),
        UIColor(red: 77 / 255, green: 212 / 255, blue: 243 / 255, alpha: 1),
    ]
}

private extension String {
    static let coMicIcon = "livekit_voiceroom_comic"
    static let audioEffectsIcon = "livekit_living_setting_audio"
    static let micOn = "livekit_coguest_seat_mic"
    static let micOff = "livekit_coguest_seat_muted"

    static var mute: String { LiveKitResources.localizedString("tuilivekit.voiceroom.living.mute") }
    static var unmute: String { LiveKitResources.localizedString("tuilivekit.voiceroom.living.unmute") }
    static var backgroundMusic: String { LiveKitResources.localizedString("tuilivekit.voiceroom.living.bgm") }
    static var audioEffects: String { LiveKitResources.localizedString("tuilivekit.voiceroom.prepare.more_audio") }
    static var more: String { LiveKitResources.localizedString("tuilivekit.voiceroom.room.more") }
    static var microphoneLocked: String {
        LiveKitResources.localizedString("tuilivekit.player.coguest.microphone_locked")
    }

    static var inputPlaceholder: String {
        LiveKitResources.localizedString("tuilivekit.voiceroom.room.input_placeholder")
    }
}
