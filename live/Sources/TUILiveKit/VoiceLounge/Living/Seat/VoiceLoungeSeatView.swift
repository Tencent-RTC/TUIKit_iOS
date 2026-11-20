import Kingfisher
import SnapKit
import UIKit

final class VoiceLoungeSeatView: UIControl {
    var onTap: ((Int) -> Void)?

    static func height(avatarSize: CGFloat, nameGap: CGFloat = defaultNameGap) -> CGFloat {
        avatarSize + 8 + nameGap + nameHeight
    }
    static let defaultNameGap: CGFloat = 2
    private static let nameHeight: CGFloat = 17

    var avatarAnchor: ConstraintItem { avatarContainer.snp.center }

    private let ringView = UIView()
    private let waveRings = [CAShapeLayer(), CAShapeLayer()]
    private let avatarContainer = UIView()
    private let avatarImageView = UIImageView()
    private let initialLabel = LiveText.voiceLounge(.body, tone: .primary, alignment: .center)
    private let emptyRing = UIView()
    private let dashLayer = CAShapeLayer()
    private let micIconView = UIImageView()
    private let lockIconLayer = CAShapeLayer()
    private let nameLabel = LiveText.voiceLounge(.control, tone: .secondary, alignment: .center)
    private let pillLabel = SeatPillLabel()
    private let adminBadge = SeatPillLabel()

    private let avatarSize: CGFloat
    private let emptyTitle: String
    private let showsName: Bool
    private let nameGap: CGFloat
    private let isCompact: Bool
    private let showsWave: Bool
    private var index = 0
    private var appliedAvatarURL: String?
    private var failedAvatarURL: String?
    private var wasFaded = false

    init(
        avatarSize: CGFloat, emptyTitle: String, showsName: Bool = true, nameGap: CGFloat = defaultNameGap,
        isCompact: Bool = false, showsWave: Bool = true
    ) {
        self.avatarSize = avatarSize
        self.emptyTitle = emptyTitle
        self.showsName = showsName
        self.nameGap = nameGap
        self.isCompact = isCompact
        self.showsWave = showsWave
        super.init(frame: .zero)
        setupViews()
        setupConstraints()
        setupStyles()
        setupBindings()
    }

    @available(*, unavailable) required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    private func setupViews() {
        addSubview(ringView)
        addSubview(emptyRing)
        emptyRing.layer.addSublayer(dashLayer)
        addSubview(avatarContainer)
        avatarContainer.addSubview(avatarImageView)
        avatarContainer.addSubview(initialLabel)
        emptyRing.addSubview(micIconView)
        emptyRing.layer.addSublayer(lockIconLayer)
        addSubview(nameLabel)
        addSubview(adminBadge)
        addSubview(pillLabel)
    }

    private func setupConstraints() {
        ringView.snp.makeConstraints { make in
            make.top.centerX.equalToSuperview()
            make.size.equalTo(avatarSize + 8)
        }
        emptyRing.snp.makeConstraints { make in
            make.center.equalTo(ringView)
            make.size.equalTo(avatarSize)
        }
        avatarContainer.snp.makeConstraints { make in
            make.center.equalTo(ringView)
            make.size.equalTo(avatarSize)
        }
        avatarImageView.snp.makeConstraints { make in make.edges.equalToSuperview() }
        initialLabel.snp.makeConstraints { make in make.edges.equalToSuperview() }
        if showsName {
            nameLabel.snp.makeConstraints { make in
                make.top.equalTo(ringView.snp.bottom).offset(nameGap)
                make.leading.trailing.equalToSuperview()
                make.height.equalTo(Self.nameHeight)
                make.bottom.equalToSuperview()
            }
        } else {
            ringView.snp.makeConstraints { $0.bottom.equalToSuperview() }
        }
        adminBadge.snp.makeConstraints { make in
            make.centerX.equalTo(avatarContainer)
            make.centerY.equalTo(avatarContainer.snp.bottom).offset(-1)
            make.height.equalTo(showsName ? 16 : 12)
            make.width.greaterThanOrEqualTo(showsName ? 30 : 24)
        }
        pillLabel.snp.makeConstraints { make in
            make.centerX.equalToSuperview()
            make.centerY.equalTo(showsName ? nameLabel.snp.centerY : ringView.snp.bottom)
            make.height.equalTo(pillHeight)
            make.width.lessThanOrEqualToSuperview()
        }
    }

    private func setupStyles() {
        ringView.isUserInteractionEnabled = false
        waveRings.forEach { ring in
            VoiceLoungeSeatStyle.styleWaveRing(ring)
            ringView.layer.addSublayer(ring)
        }
        emptyRing.isUserInteractionEnabled = false
        emptyRing.backgroundColor = VoiceLoungeSeatStyle.emptyFill
        dashLayer.fillColor = UIColor.clear.cgColor
        dashLayer.strokeColor = VoiceLoungeSeatStyle.emptyStroke.cgColor
        dashLayer.lineWidth = 1
        dashLayer.lineDashPattern = [3, 3]
        avatarContainer.backgroundColor = VoiceLoungeSeatStyle.seatBackground
        avatarContainer.clipsToBounds = true
        avatarContainer.isUserInteractionEnabled = false
        avatarImageView.contentMode = .scaleAspectFill
        avatarImageView.clipsToBounds = true
        initialLabel.isHidden = true
        micIconView.image = LiveKitResources.image(named: "livekit_coguest_seat_mic")?.withRenderingMode(
            .alwaysTemplate)
        micIconView.tintColor = VoiceLoungeSeatStyle.emptyStroke
        micIconView.contentMode = .scaleAspectFit
        lockIconLayer.strokeColor = VoiceLoungeSeatStyle.emptyStroke.cgColor
        lockIconLayer.fillColor = UIColor.clear.cgColor
        lockIconLayer.lineWidth = 1.6
        lockIconLayer.lineCap = .round
        lockIconLayer.lineJoin = .round
        lockIconLayer.isHidden = true
        nameLabel.numberOfLines = 1
        nameLabel.lineBreakMode = .byTruncatingMiddle
        nameLabel.isUserInteractionEnabled = false
        nameLabel.isHidden = !showsName
        adminBadge.insets = UIEdgeInsets(top: 0, left: 6, bottom: 0, right: 6)
        adminBadge.text = .adminBadge
        adminBadge.font = .systemFont(ofSize: showsName ? 10 : 8, weight: .bold)
        adminBadge.textColor = .white
        adminBadge.textAlignment = .center
        adminBadge.backgroundColor = VoiceLoungeSeatStyle.adminBadge
        adminBadge.layer.cornerRadius = showsName ? 7 : 6
        adminBadge.layer.masksToBounds = true
        adminBadge.layer.borderWidth = 1
        adminBadge.layer.borderColor = UIColor.black.withAlphaComponent(0.25).cgColor
        adminBadge.isUserInteractionEnabled = false
        adminBadge.isHidden = true
        pillLabel.font = .systemFont(ofSize: isCompact ? 10 : 13, weight: .medium)
        pillLabel.insets = isCompact ? UIEdgeInsets(top: 0, left: 5, bottom: 0, right: 5) : pillLabel.insets
        pillLabel.adjustsFontSizeToFitWidth = true
        pillLabel.minimumScaleFactor = 0.8
        pillLabel.textAlignment = .center
        pillLabel.layer.cornerRadius = pillHeight / 2
        pillLabel.layer.masksToBounds = true
        pillLabel.isUserInteractionEnabled = false
        pillLabel.isHidden = true
    }

    private var pillHeight: CGFloat { isCompact ? 16 : 18 }

    private func setupBindings() { addTarget(self, action: #selector(handleTap), for: .touchUpInside) }

    override func layoutSubviews() {
        super.layoutSubviews()
        avatarContainer.layer.cornerRadius = avatarSize / 2
        emptyRing.layer.cornerRadius = avatarSize / 2
        let ringSide = avatarSize + VoiceLoungeSeatStyle.waveRingOffset * 2
        let ringFrame = CGRect(
            x: (ringView.bounds.width - ringSide) / 2, y: (ringView.bounds.height - ringSide) / 2, width: ringSide,
            height: ringSide)
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        waveRings.forEach { ring in
            ring.frame = ringFrame
            ring.path = UIBezierPath(ovalIn: ring.bounds).cgPath
        }
        CATransaction.commit()
        dashLayer.frame = emptyRing.bounds
        dashLayer.path = UIBezierPath(ovalIn: emptyRing.bounds.insetBy(dx: 0.5, dy: 0.5)).cgPath
        let box = emptyRing.bounds
        let s = avatarSize / 24
        let micSide = avatarSize * 0.5
        micIconView.frame = CGRect(
            x: box.midX - micSide / 2, y: box.midY - micSide / 2, width: micSide, height: micSide)

        let lock = UIBezierPath(roundedRect: CGRect(x: 8, y: 11, width: 8, height: 7), cornerRadius: 1.5)
        let shackle = UIBezierPath()
        shackle.move(to: CGPoint(x: 9.8, y: 11))
        shackle.addLine(to: CGPoint(x: 9.8, y: 9))
        shackle.addArc(withCenter: CGPoint(x: 12, y: 9), radius: 2.2, startAngle: .pi, endAngle: 0, clockwise: true)
        shackle.addLine(to: CGPoint(x: 14.2, y: 11))
        lock.append(shackle)
        lock.apply(CGAffineTransform(scaleX: s, y: s))
        lockIconLayer.frame = box
        lockIconLayer.path = lock.cgPath
    }

    func configure(seat: VoiceLoungeSeat) {
        index = seat.index
        let faded = seat.state == .faded
        let occupied = seat.state == .occupied || faded
        let locked = seat.state == .locked

        avatarContainer.isHidden = !occupied
        applyFadeAlpha(faded: faded, shouldAnimate: wasFaded && !faded && occupied)
        wasFaded = faded
        emptyRing.isHidden = occupied
        avatarImageView.isHidden = !occupied
        initialLabel.isHidden = !occupied || (!seat.avatarURL.isEmpty && failedAvatarURL != seat.avatarURL)
        adminBadge.isHidden = !(seat.state == .occupied && seat.isAdmin)
        if let accent = seat.accentColor { adminBadge.backgroundColor = accent }
        micIconView.isHidden = occupied || locked
        lockIconLayer.isHidden = !locked

        let pill = faded ? seat.pillText : ""
        pillLabel.isHidden = pill.isEmpty
        if !pill.isEmpty {
            pillLabel.text = pill
            pillLabel.textColor = seat.isPillHighlighted ? .white : UIColor.white.withAlphaComponent(0.8)
            if let accent = seat.accentColor {
                pillLabel.backgroundColor = accent.withAlphaComponent(seat.isPillHighlighted ? 0.9 : 0.45)
            } else {
                pillLabel.backgroundColor =
                    seat.isPillHighlighted ? VoiceLoungeSeatStyle.pillHighlighted : VoiceLoungeSeatStyle.pillNormal
            }
        }

        if occupied {
            let showsMuteIcon = seat.state == .occupied && seat.isMuted
            if pill.isEmpty { setName(seat.name, muted: showsMuteIcon) } else { nameLabel.text = "" }
            if seat.avatarURL.isEmpty {
                avatarContainer.backgroundColor = Self.placeholderColor(for: seat.name)
                initialLabel.text = String(seat.name.prefix(1)).uppercased()
                avatarImageView.image = nil
                appliedAvatarURL = nil
            } else if appliedAvatarURL != seat.avatarURL {
                let url = seat.avatarURL
                let name = seat.name
                appliedAvatarURL = url
                failedAvatarURL = nil
                avatarContainer.backgroundColor = VoiceLoungeSeatStyle.seatBackground
                avatarImageView.image = nil
                avatarImageView.kf.setImage(with: URL(string: url)) { [weak self] result in
                    guard let self, case .failure = result, self.appliedAvatarURL == url else { return }
                    self.failedAvatarURL = url
                    self.avatarContainer.backgroundColor = Self.placeholderColor(for: name)
                    self.initialLabel.text = String(name.prefix(1)).uppercased()
                    self.initialLabel.isHidden = false
                }
            }
        } else {
            nameLabel.text = locked ? "" : emptyTitle
            avatarImageView.image = nil
            appliedAvatarURL = nil
        }

        let onSeat = seat.state == .occupied
        updateRing(showsWave && onSeat && !seat.isMuted && seat.isSpeaking ? .speaking : .idle)
    }
    private func applyFadeAlpha(faded: Bool, shouldAnimate: Bool) {
        let target: CGFloat = faded ? 0.5 : 1
        avatarContainer.layer.removeAnimation(forKey: "fadeAlpha")
        if shouldAnimate {
            let fade = CABasicAnimation(keyPath: "opacity")
            fade.fromValue = 0.5
            fade.toValue = 1
            fade.duration = 0.28
            fade.timingFunction = CAMediaTimingFunction(name: .easeOut)
            avatarContainer.layer.add(fade, forKey: "fadeAlpha")
        }
        avatarContainer.alpha = target
    }

    private func setName(_ name: String, muted: Bool) {
        guard muted, let icon = Self.muteIcon, let font = nameLabel.font else {
            nameLabel.text = name
            return
        }
        let side = font.pointSize
        let attachment = NSTextAttachment()
        attachment.image = icon
        attachment.bounds = CGRect(x: 0, y: (font.capHeight - side) / 2, width: side, height: side)
        let text = NSMutableAttributedString(attachment: attachment)
        text.append(NSAttributedString(string: " " + name))
        text.addAttributes(
            [.font: font, .foregroundColor: nameLabel.textColor ?? .white],
            range: NSRange(location: 0, length: text.length))
        nameLabel.attributedText = text
    }

    private static let muteIcon = LiveKitResources.image(named: "livekit_coguest_seat_muted")?.withTintColor(
        UIColor.white.withAlphaComponent(0.7), renderingMode: .alwaysOriginal)

    private enum RingState { case idle, speaking }
    private var ringState: RingState = .idle

    private func updateRing(_ state: RingState) {
        guard state != ringState else { return }
        ringState = state
        if state == .speaking {
            VoiceLoungeSeatStyle.startWave(on: waveRings)
        } else {
            VoiceLoungeSeatStyle.stopWave(on: waveRings)
        }
    }

    override func didMoveToWindow() {
        super.didMoveToWindow()
        guard window != nil, ringState == .speaking else { return }
        let state = ringState
        ringState = .idle
        updateRing(state)
    }

    private static func placeholderColor(for name: String) -> UIColor {
        let palette = VoiceLoungeColor.avatarPlaceholders
        let hash = abs(name.hashValue)
        return palette[hash % max(1, palette.count)]
    }
}

extension VoiceLoungeSeatView { @objc private func handleTap() { onTap?(index) } }

enum VoiceLoungeSeatStyle {
    static let seatBackground = VoiceLoungeColor.overlaySoft
    static let emptyStroke = UIColor.white.withAlphaComponent(0.4)
    static let emptyFill = UIColor.white.withAlphaComponent(0.04)
    static let waveRing = UIColor.white.withAlphaComponent(0.8)

    static let waveRingWidth: CGFloat = 2
    static let waveRingOffset: CGFloat = 2
    static let waveMaximumScale: CGFloat = 1.38
    static let waveDuration: CFTimeInterval = 1.4
    static let waveStaticOpacity: CGFloat = 0.58
    static let waveAnimationKey = "VoiceLoungeSpeakingWave"
    static let focusAvatar: CGFloat = 64
    static let guestAvatar: CGFloat = 52
    static let adminBadge = UIColor(red: 0.27, green: 0.55, blue: 1.0, alpha: 0.95)
    static let pillNormal = UIColor(red: 0.42, green: 0.40, blue: 0.75, alpha: 0.45)
    static let pillHighlighted = UIColor(red: 0.45, green: 0.42, blue: 0.88, alpha: 0.9)

    static func styleWaveRing(_ ring: CAShapeLayer) {
        ring.fillColor = UIColor.clear.cgColor
        ring.strokeColor = waveRing.cgColor
        ring.lineWidth = waveRingWidth
        ring.opacity = 0
    }

    static func startWave(on rings: [CAShapeLayer]) {
        rings.forEach { ring in
            ring.removeAnimation(forKey: waveAnimationKey)
            ring.opacity = 0
        }
        if UIAccessibility.isReduceMotionEnabled {
            rings.first?.opacity = Float(waveStaticOpacity)
            return
        }
        rings.enumerated().forEach { index, ring in
            let offset = waveDuration / Double(rings.count) * Double(index)
            ring.add(waveAnimation(timeOffset: offset), forKey: waveAnimationKey)
        }
    }

    static func stopWave(on rings: [CAShapeLayer]) {
        rings.forEach { ring in
            ring.removeAnimation(forKey: waveAnimationKey)
            ring.opacity = 0
        }
    }

    private static func waveAnimation(timeOffset: CFTimeInterval) -> CAAnimation {
        let opacity = CAKeyframeAnimation(keyPath: "opacity")
        opacity.values = [0, 0.62, 0.22, 0]
        opacity.keyTimes = [0, 0.14, 0.7, 1]
        let scale = CABasicAnimation(keyPath: "transform.scale")
        scale.fromValue = 1
        scale.toValue = waveMaximumScale
        let group = CAAnimationGroup()
        group.animations = [opacity, scale]
        group.duration = waveDuration
        group.timingFunction = CAMediaTimingFunction(controlPoints: 0.16, 0.5, 0.4, 1)
        group.repeatCount = .infinity
        group.timeOffset = timeOffset
        return group
    }
}

private final class SeatPillLabel: UILabel {
    var insets = UIEdgeInsets(top: 0, left: 8, bottom: 0, right: 8)

    override func drawText(in rect: CGRect) { super.drawText(in: rect.inset(by: insets)) }

    override func textRect(forBounds bounds: CGRect, limitedToNumberOfLines numberOfLines: Int) -> CGRect {
        super.textRect(forBounds: bounds.inset(by: insets), limitedToNumberOfLines: numberOfLines)
    }

    override var intrinsicContentSize: CGSize {
        let size = super.intrinsicContentSize
        return CGSize(width: size.width + insets.left + insets.right, height: size.height)
    }
}

private extension String {
    static var adminBadge: String { LiveKitResources.localizedString("tuilivekit.voiceroom.seat.admin_badge") }
}
