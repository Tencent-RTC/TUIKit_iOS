import UIKit
import SnapKit

final class RoomToolbarButton: UIControl {

    var icon: UIImage? {
        didSet {
            guard oldValue != icon else { return }
            applyIcon()
        }
    }

    var roomDisabledIcon: UIImage? {
        didSet {
            guard oldValue != roomDisabledIcon else { return }
            applyIcon()
        }
    }

    var badgeCount: Int? {
        didSet {
            guard oldValue != badgeCount else { return }
            applyBadge()
        }
    }

    var isActive: Bool = false {
        didSet {
            guard oldValue != isActive else { return }
            applyTheme()
        }
    }

    var hasFault: Bool = false {
        didSet {
            guard oldValue != hasFault else { return }
            applyBadgeVisibility()
            setNeedsLayout()
        }
    }

    var isRoomDisabled = false {
        didSet {
            guard oldValue != isRoomDisabled else { return }
            alpha = isRoomDisabled ? Self.roomDisabledAlpha : 1
            applyIcon()
            applyBadgeVisibility()
            setNeedsLayout()
        }
    }

    var micVolume: Int? {
        didSet {
            guard oldValue != micVolume else { return }
            if let micVolume {
                micLevelView.isHidden = false
                micLevelView.setVolume(micVolume)
            } else {
                micLevelView.isHidden = true
                micLevelView.reset()
            }
        }
    }

    private let iconView = UIImageView()
    private let micLevelView = RoomMicLevelView()
    private let badgeLabel = UILabel()
    private let faultBadge = UILabel()

    private static let roomDisabledAlpha: CGFloat = 0.45

    override var isHighlighted: Bool {
        didSet {
            guard oldValue != isHighlighted else { return }
            transform = isHighlighted
                ? CGAffineTransform(scaleX: 0.92, y: 0.92)
                : .identity
        }
    }

    init(icon: UIImage?) {
        self.icon = icon
        super.init(frame: .zero)

        iconView.isUserInteractionEnabled = false
        iconView.contentMode = .scaleAspectFit
        iconView.image = icon
        micLevelView.isHidden = true
        addSubview(micLevelView)
        addSubview(iconView)

        badgeLabel.font = .monospacedDigitSystemFont(ofSize: 10, weight: .semibold)
        badgeLabel.textAlignment = .left
        badgeLabel.isHidden = true
        badgeLabel.isUserInteractionEnabled = false
        addSubview(badgeLabel)

        faultBadge.text = "!"
        faultBadge.font = .systemFont(ofSize: 9, weight: .bold)
        faultBadge.textColor = .roomKitFgPrimary
        faultBadge.textAlignment = .center
        faultBadge.layer.cornerRadius = 7
        faultBadge.layer.borderWidth = 1.5
        faultBadge.layer.masksToBounds = true
        faultBadge.isHidden = true
        faultBadge.isUserInteractionEnabled = false
        addSubview(faultBadge)

        applyTheme()
        applyBadge()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func didMoveToWindow() {
        super.didMoveToWindow()
        if window != nil {
            applyTheme()
        }
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        layer.cornerRadius = min(bounds.width, bounds.height) / 2
        iconView.frame = CGRect(
            x: (bounds.width - 20) / 2,
            y: (bounds.height - 20) / 2,
            width: 20,
            height: 20
        )
        badgeLabel.sizeToFit()
        badgeLabel.frame = CGRect(
            x: bounds.midX + 8,
            y: bounds.midY - 6 - 12,
            width: max(badgeLabel.bounds.width, 6),
            height: 12
        )
        micLevelView.frame = RoomMicLevelView.cavityFrame(inIconBox: iconView.frame)
        faultBadge.frame = CGRect(x: iconView.frame.maxX + 8 - 14, y: iconView.frame.minY - 6, width: 14, height: 14)
    }

    private func applyTheme() {
        if isActive {
            backgroundColor = UIColor.roomKitBgHoverStrong
        } else {
            backgroundColor = UIColor.roomKitBgHover
        }
        badgeLabel.textColor = UIColor.roomKitFgPrimary
        faultBadge.backgroundColor = UIColor.roomKitWarning
        faultBadge.layer.borderColor = UIColor.roomKitBgSurface.cgColor
    }

    private func applyIcon() {
        iconView.image = (isRoomDisabled ? roomDisabledIcon : nil) ?? icon
    }

    private func applyBadgeVisibility() {
        faultBadge.isHidden = !hasFault || isRoomDisabled
    }

    private func applyBadge() {
        guard let count = badgeCount, count > 0 else {
            badgeLabel.isHidden = true
            return
        }
        badgeLabel.isHidden = false
        badgeLabel.text = count > 99 ? "99+" : "\(count)"
        setNeedsLayout()
    }
}
