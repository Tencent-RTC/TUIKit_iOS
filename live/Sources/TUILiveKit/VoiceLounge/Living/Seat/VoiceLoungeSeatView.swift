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

    private let ringView = UIView()
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
    private var index = 0
    private var appliedAvatarURL: String?
    private var failedAvatarURL: String?

    init(avatarSize: CGFloat, emptyTitle: String, showsName: Bool = true, nameGap: CGFloat = defaultNameGap) {
        self.avatarSize = avatarSize
        self.emptyTitle = emptyTitle
        self.showsName = showsName
        self.nameGap = nameGap
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
            make.height.equalTo(18)
        }
    }

    private func setupStyles() {
        ringView.layer.borderColor = VoiceLoungeSeatStyle.speakingRing.cgColor
        ringView.layer.borderWidth = 2
        ringView.isUserInteractionEnabled = false
        ringView.isHidden = true
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
        pillLabel.font = .systemFont(ofSize: 13, weight: .medium)
        pillLabel.textAlignment = .center
        pillLabel.layer.cornerRadius = 9
        pillLabel.layer.masksToBounds = true
        pillLabel.isUserInteractionEnabled = false
        pillLabel.isHidden = true
    }

    private func setupBindings() { addTarget(self, action: #selector(handleTap), for: .touchUpInside) }

    override func layoutSubviews() {
        super.layoutSubviews()
        avatarContainer.layer.cornerRadius = avatarSize / 2
        emptyRing.layer.cornerRadius = avatarSize / 2
        ringView.layer.cornerRadius = (avatarSize + 8) / 2
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
        avatarContainer.alpha = faded ? 0.5 : 1
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
        updateRing(onSeat && !seat.isMuted && seat.isSpeaking ? .speaking : .idle)
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
        ringView.layer.removeAnimation(forKey: "pulse")
        ringView.layer.opacity = 1
        switch state {
        case .idle: ringView.isHidden = true
        case .speaking:
            ringView.isHidden = false
            ringView.layer.borderColor = VoiceLoungeSeatStyle.speakingRing.cgColor
            let pulse = CABasicAnimation(keyPath: "opacity")
            pulse.fromValue = 1
            pulse.toValue = 0.25
            pulse.duration = 0.7
            pulse.autoreverses = true
            pulse.repeatCount = .infinity
            ringView.layer.add(pulse, forKey: "pulse")
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
    static let speakingRing = LiveTheme.Color.brandCyan
    static let focusAvatar: CGFloat = 64
    static let guestAvatar: CGFloat = 52
    static let adminBadge = UIColor(red: 0.27, green: 0.55, blue: 1.0, alpha: 0.95)
    static let pillNormal = UIColor(red: 0.42, green: 0.40, blue: 0.75, alpha: 0.45)
    static let pillHighlighted = UIColor(red: 0.45, green: 0.42, blue: 0.88, alpha: 0.9)
}

private final class SeatPillLabel: UILabel {
    var insets = UIEdgeInsets(top: 0, left: 8, bottom: 0, right: 8)

    override func drawText(in rect: CGRect) { super.drawText(in: rect.inset(by: insets)) }

    override var intrinsicContentSize: CGSize {
        let size = super.intrinsicContentSize
        return CGSize(width: size.width + insets.left + insets.right, height: size.height)
    }
}

private extension String {
    static var adminBadge: String { LiveKitResources.localizedString("tuilivekit.voiceroom.seat.admin_badge") }
}
