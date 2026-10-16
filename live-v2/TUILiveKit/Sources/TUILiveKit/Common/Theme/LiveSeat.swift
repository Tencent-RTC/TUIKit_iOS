import Kingfisher
import UIKit

/// Shared seat presentation. Entry-specific subclasses project SDK state into
/// these inputs; SDK lifecycle, role decisions and seat geometry stay outside.
class LiveSeat: UIView {
    private let emptyView: LiveSeatEmptyView
    private let noVideoView = LiveSeatNoVideoView()
    private let overlayView = LiveSeatOverlayView()

    init(emptyTitle: String) {
        emptyView = LiveSeatEmptyView(title: emptyTitle)
        super.init(frame: .zero)
        isUserInteractionEnabled = false
        clipsToBounds = true
        [noVideoView, overlayView, emptyView].forEach(addSubview)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    func updateContent(name: String, avatarURL: String, microphoneOn: Bool) {
        noVideoView.update(avatarURL: avatarURL)
        overlayView.update(name: name, microphoneOn: microphoneOn)
    }

    func updateVisibility(isEmpty: Bool, showsNoVideo: Bool, showsOverlay: Bool) {
        emptyView.isHidden = !isEmpty
        noVideoView.isHidden = isEmpty || !showsNoVideo
        overlayView.isHidden = isEmpty || !showsOverlay
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        [noVideoView, overlayView, emptyView].forEach { $0.frame = bounds }
    }
}

/// Placeholder widget for an unoccupied co-guest seat.
///
/// `AtomicLiveView` owns the geometry: it constrains this view to the full seat
/// region, and adjacent seat regions touch each other. The tinted fill is
/// therefore drawn on an inset content layer so that neighbouring empty seats
/// keep a transparent gutter that reveals the co-guest stage background.
private final class LiveSeatEmptyView: UIView {
    /// Half of the transparent gutter between two adjacent empty seats.
    ///
    /// Two neighbouring seats each inset by this amount, which restores the
    /// designed ~2pt gutter without needing to know the neighbouring seats.
    private static let contentInset: CGFloat = 1

    private let contentView = UIView()
    private let plusLabel = UILabel()
    private let invitationLabel = LiveText(.metadata, tone: .tertiary, alignment: .center)

    init(title: String) {
        super.init(frame: .zero)
        isUserInteractionEnabled = false
        backgroundColor = .clear

        plusLabel.text = "+"
        plusLabel.textAlignment = .center
        plusLabel.textColor = UIColor.white.withAlphaComponent(0.46)

        invitationLabel.text = title

        addSubview(contentView)
        contentView.addSubview(plusLabel)
        contentView.addSubview(invitationLabel)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        guard bounds.width > 0, bounds.height > 0 else { return }

        let inset = min(Self.contentInset, min(bounds.width, bounds.height) / 4)
        contentView.frame = bounds.insetBy(dx: inset, dy: inset)
        let contentBounds = contentView.bounds
        guard contentBounds.width > 0, contentBounds.height > 0 else { return }

        let isCompactSeat = min(contentBounds.width, contentBounds.height) <= 110
        contentView.backgroundColor = UIColor.white
            .withAlphaComponent(isCompactSeat ? 0.055 : 0.035)
        plusLabel.font = .systemFont(ofSize: isCompactSeat ? 29 : 26, weight: .ultraLight)

        let plusHeight: CGFloat = isCompactSeat ? 32 : 30
        let spacing: CGFloat = 3
        let invitationHeight: CGFloat = 14
        let showsInvitation = contentBounds.height >= plusHeight + spacing + invitationHeight
        invitationLabel.isHidden = !showsInvitation

        let contentHeight = showsInvitation
            ? plusHeight + spacing + invitationHeight
            : plusHeight
        let originY = max(0, (contentBounds.height - contentHeight) / 2)
        plusLabel.frame = CGRect(
            x: 0,
            y: originY,
            width: contentBounds.width,
            height: plusHeight
        )
        invitationLabel.frame = CGRect(
            x: 0,
            y: originY + plusHeight + spacing,
            width: contentBounds.width,
            height: invitationHeight
        )
    }
}

/// Fallback shown inside a single seat while its occupant has no video stream:
/// a gradient plus the user's avatar, sized against the seat's short edge.
private final class LiveSeatNoVideoView: UIView {
    private let occupiedGradient = CAGradientLayer()
    private let avatarView = UIImageView()
    private var avatarURL: String?

    init() {
        super.init(frame: .zero)
        clipsToBounds = true
        configureOccupiedSeat()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        occupiedGradient.frame = bounds

        let shortSide = min(bounds.width, bounds.height)
        let avatarSize: CGFloat
        if shortSide <= 110 {
            avatarSize = 42
        } else if shortSide <= 140 {
            avatarSize = 30
        } else if shortSide > 250 {
            avatarSize = 67
        } else {
            avatarSize = 63
        }
        avatarView.frame = CGRect(
            x: (bounds.width - avatarSize) / 2,
            y: (bounds.height - avatarSize) / 2,
            width: avatarSize,
            height: avatarSize
        )
        avatarView.layer.cornerRadius = avatarSize / 2
    }

    deinit {
        Task { @MainActor [avatarView] in
            avatarView.kf.cancelDownloadTask()
        }
    }

    private func configureOccupiedSeat() {
        occupiedGradient.colors = [
            LiveSeatNoVideoStyle.gradientStart.cgColor,
            LiveSeatNoVideoStyle.gradientEnd.cgColor,
        ]
        occupiedGradient.startPoint = CGPoint(x: 0, y: 0)
        occupiedGradient.endPoint = CGPoint(x: 1, y: 1)
        layer.addSublayer(occupiedGradient)

        avatarView.contentMode = .scaleAspectFill
        avatarView.clipsToBounds = true
        avatarView.image = LiveKitResources.image(named: "livekit_livelist_default_avatar")
        addSubview(avatarView)
    }

    func update(avatarURL: String) {
        guard self.avatarURL != avatarURL else { return }
        self.avatarURL = avatarURL
        avatarView.kf.cancelDownloadTask()

        avatarView.kf.setImage(with: URL(string: avatarURL), placeholder: LiveKitResources.image(named: "livekit_livelist_default_avatar"))
    }
}

// Styles owned by this component or feature. Values preserve the existing design.
private enum LiveSeatNoVideoStyle {
    static let gradientStart: UIColor = UIColor(red: 0.1, green: 0.18, blue: 0.27, alpha: 1)
    static let gradientEnd: UIColor = UIColor(red: 0.03, green: 0.06, blue: 0.12, alpha: 1)
}

/// Badge drawn on top of a connected guest's video: microphone status plus nickname.
private final class LiveSeatOverlayView: UIView {
    private let microphoneBadgeView = UIView()
    private let microphoneImageView = UIImageView()
    private let nameLabel = UILabel()
    private let nameShadingLayer = CAGradientLayer()

    init() {
        super.init(frame: .zero)
        isUserInteractionEnabled = false

        nameShadingLayer.colors = [
            UIColor.black.withAlphaComponent(0).cgColor,
            UIColor.black.withAlphaComponent(0.4).cgColor,
        ]
        nameShadingLayer.startPoint = CGPoint(x: 0.5, y: 0)
        nameShadingLayer.endPoint = CGPoint(x: 0.5, y: 1)
        layer.insertSublayer(nameShadingLayer, at: 0)

        microphoneImageView.contentMode = .scaleAspectFit
        microphoneBadgeView.backgroundColor = LiveSeatOverlayStyle.microphoneBadge
        microphoneBadgeView.clipsToBounds = true

        nameLabel.textColor = LiveSeatOverlayStyle.name
        nameLabel.font = LiveSeatOverlayTypography.nameFont
        nameLabel.textAlignment = .left
        nameLabel.lineBreakMode = .byTruncatingTail

        addSubview(microphoneBadgeView)
        microphoneBadgeView.addSubview(microphoneImageView)
        addSubview(nameLabel)
    }

    func update(name: String, microphoneOn: Bool) {
        nameLabel.text = name
        let microphoneIcon = microphoneOn
            ? "livekit_coguest_seat_mic"
            : "livekit_coguest_seat_muted"
        microphoneImageView.image = LiveKitResources.image(named: microphoneIcon)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        defer { CATransaction.commit() }
        let availableWidth = max(0, bounds.width - 12)
        guard availableWidth > 0, bounds.height >= 14 else {
            microphoneBadgeView.frame = .zero
            microphoneImageView.frame = .zero
            nameLabel.frame = .zero
            nameShadingLayer.frame = .zero
            return
        }
        // Keep the status badge at the same visual height as the nickname line.
        let lineHeight: CGFloat = 14
        let iconSize = lineHeight - 2
        microphoneBadgeView.frame = CGRect(x: 6, y: 6, width: min(iconSize + 8, availableWidth), height: lineHeight)
        microphoneBadgeView.layer.cornerRadius = lineHeight / 2
        microphoneImageView.frame = CGRect(
            x: (microphoneBadgeView.bounds.width - iconSize) / 2,
            y: 1,
            width: iconSize,
            height: iconSize
        )
        nameLabel.frame = CGRect(
            x: 4,
            y: max(0, bounds.height - lineHeight),
            width: max(0, bounds.width - 8),
            height: lineHeight
        )
        nameShadingLayer.frame = CGRect(
            x: 0,
            y: nameLabel.frame.minY,
            width: bounds.width,
            height: bounds.height - nameLabel.frame.minY
        )
    }
}

// Styles owned by this component or feature. Values preserve the existing design.
private enum LiveSeatOverlayStyle {
    static let microphoneBadge: UIColor = UIColor.black.withAlphaComponent(0.32)
    static let name: UIColor = UIColor.white.withAlphaComponent(0.8)
}

private enum LiveSeatOverlayTypography {
    static let nameFont: UIFont = UIFont.systemFont(ofSize: 10)
}
