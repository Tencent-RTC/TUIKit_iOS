import UIKit
import SnapKit

struct AudienceWelcome: Equatable {
    let userID: String
    let userName: String
    let level: Int
}

final class AudienceWelcomeView: UIView {
    var onVisibilityChanged: ((Bool) -> Void)?

    private enum Constants {
        static let bannerSize = CGSize(width: 228, height: 28)
        static let fadeInDuration: TimeInterval = 0.42
        static let slideInDuration: TimeInterval = 0.68
        static let displayDuration: TimeInterval = 3.2
        static let fadeOutDuration: TimeInterval = 0.32
        static let cleanupDelay: TimeInterval = 0.36
    }

    private let bannerView = UIView()
    private let backgroundView = AudienceWelcomeBackgroundView()
    private let levelBadge = LevelBadgeView(level: 0)
    private let nameLabel = LiveText(.action)
    private let actionLabel = LiveText(.action)
    private var queue: [AudienceWelcome] = []
    private var activeToken: UUID?
    private var slideAnimator: UIViewPropertyAnimator?
    private var isWelcomeVisible = false

    override init(frame: CGRect) {
        super.init(frame: frame)
        configureUI()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func enqueue(_ welcome: AudienceWelcome) {
        queue.append(welcome)
        showNextIfNeeded()
    }

    func reset() {
        activeToken = nil
        slideAnimator?.stopAnimation(true)
        slideAnimator = nil
        bannerView.layer.removeAllAnimations()
        queue.removeAll()
        bannerView.alpha = 0
        bannerView.transform = .identity
        isHidden = true
        updateWelcomeVisibility(false)
    }

    private func configureUI() {
        isHidden = true
        isUserInteractionEnabled = false
        clipsToBounds = false

        bannerView.layer.cornerRadius = 12
        addSubview(bannerView)

        backgroundView.isUserInteractionEnabled = false
        backgroundView.layer.cornerRadius = 12
        backgroundView.layer.masksToBounds = true
        bannerView.addSubview(backgroundView)

        bannerView.addSubview(levelBadge)

        nameLabel.textColor = LiveTheme.Color.nickname
        nameLabel.lineBreakMode = .byTruncatingTail
        nameLabel.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        bannerView.addSubview(nameLabel)

        actionLabel.text = LiveKitResources.localizedString("tuilivekit.pusher.living.audience_entered")
        actionLabel.textColor = UIColor(red: 0.949, green: 0.961, blue: 0.98, alpha: 1)
        actionLabel.setContentCompressionResistancePriority(.required, for: .horizontal)
        bannerView.addSubview(actionLabel)

        bannerView.snp.makeConstraints { make in
            make.leading.equalToSuperview().offset(12)
            make.top.equalToSuperview()
            make.size.equalTo(Constants.bannerSize)
        }
        backgroundView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }
        levelBadge.snp.makeConstraints { make in
            make.leading.equalToSuperview().offset(9)
            make.centerY.equalToSuperview()
            make.height.equalTo(15)
        }
        nameLabel.snp.makeConstraints { make in
            make.leading.equalTo(levelBadge.snp.trailing).offset(5)
            make.centerY.equalToSuperview()
        }
        actionLabel.snp.makeConstraints { make in
            make.leading.equalTo(nameLabel.snp.trailing).offset(6)
            make.centerY.equalToSuperview()
            make.trailing.lessThanOrEqualToSuperview().inset(9)
        }
    }

    private func showNextIfNeeded() {
        guard activeToken == nil, let welcome = queue.first else { return }
        queue.removeFirst()
        let token = UUID()
        activeToken = token

        configureBanner(for: welcome)
        isHidden = false
        updateWelcomeVisibility(true)
        layoutIfNeeded()
        bannerView.alpha = 0
        bannerView.transform = CGAffineTransform(
            translationX: -(Constants.bannerSize.width + 24),
            y: 0
        )

        UIView.animate(
            withDuration: Constants.fadeInDuration,
            delay: 0,
            options: [.curveEaseOut, .beginFromCurrentState, .allowUserInteraction]
        ) { [weak self] in
            self?.bannerView.alpha = 1
        }

        let animator = UIViewPropertyAnimator(
            duration: Constants.slideInDuration,
            controlPoint1: CGPoint(x: 0.18, y: 0.78),
            controlPoint2: CGPoint(x: 0.22, y: 1)
        ) { [weak self] in
            self?.bannerView.transform = .identity
        }
        slideAnimator = animator
        animator.startAnimation()

        DispatchQueue.main.asyncAfter(deadline: .now() + Constants.displayDuration) { [weak self] in
            guard let self, self.activeToken == token else { return }
            self.dismissActiveWelcome(token: token)
        }
    }

    private func dismissActiveWelcome(token: UUID) {
        slideAnimator = nil
        UIView.animate(
            withDuration: Constants.fadeOutDuration,
            delay: 0,
            options: [.curveEaseIn, .beginFromCurrentState, .allowUserInteraction]
        ) { [weak self] in
            self?.bannerView.alpha = 0
            self?.bannerView.transform = CGAffineTransform(translationX: -30, y: 0)
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + Constants.cleanupDelay) { [weak self] in
            guard let self, self.activeToken == token else { return }
            self.activeToken = nil
            self.bannerView.transform = .identity
            if self.queue.isEmpty {
                self.isHidden = true
                self.updateWelcomeVisibility(false)
            } else {
                self.showNextIfNeeded()
            }
        }
    }

    private func updateWelcomeVisibility(_ isVisible: Bool) {
        guard isWelcomeVisible != isVisible else { return }
        isWelcomeVisible = isVisible
        onVisibilityChanged?(isVisible)
    }

    private func configureBanner(for welcome: AudienceWelcome) {
        nameLabel.text = welcome.userName.isEmpty ? welcome.userID : welcome.userName
        levelBadge.bind(level: welcome.level)
        let tier = AudienceWelcomeTier(level: welcome.level)

        backgroundView.bind(tier: tier)
        bannerView.layer.shadowColor = tier.shadowColor.cgColor
        bannerView.layer.shadowOpacity = tier.shadowOpacity
        bannerView.layer.shadowOffset = .zero
        bannerView.layer.shadowRadius = tier.shadowRadius
        actionLabel.textColor = tier.actionTextColor
    }
}

private final class AudienceWelcomeBackgroundView: UIView {
    private let gradient = CAGradientLayer()

    override init(frame: CGRect) {
        super.init(frame: frame)
        layer.insertSublayer(gradient, at: 0)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        gradient.frame = bounds
        gradient.cornerRadius = layer.cornerRadius
    }

    func bind(tier: AudienceWelcomeTier) {
        layer.borderWidth = tier.borderWidth
        layer.borderColor = tier.borderColor.cgColor

        if tier == .basic {
            backgroundColor = tier.backgroundColors[0]
            gradient.isHidden = true
            return
        }

        backgroundColor = .clear
        gradient.isHidden = false
        gradient.colors = tier.backgroundColors.map(\.cgColor)
        gradient.locations = tier.backgroundLocations
        gradient.startPoint = CGPoint(x: 0, y: 0.37)
        gradient.endPoint = CGPoint(x: 1, y: 0.63)
        setNeedsLayout()
    }
}

private enum AudienceWelcomeTier: Equatable {
    case basic
    case premium
    case elite

    init(level: Int) {
        switch level {
        case 25..<40: self = .premium
        case 40...: self = .elite
        default: self = .basic
        }
    }

    var backgroundColors: [UIColor] {
        switch self {
        case .basic:
            return [UIColor(red: 0.04, green: 0.04, blue: 0.06, alpha: 0.34), UIColor(red: 0.04, green: 0.04, blue: 0.06, alpha: 0.34)]
        case .premium:
            return [UIColor(red: 0.31, green: 0.22, blue: 0.67, alpha: 0.82), UIColor(red: 0.5, green: 0.25, blue: 0.72, alpha: 0.7), UIColor(red: 0.12, green: 0.08, blue: 0.23, alpha: 0.54)]
        case .elite:
            return [UIColor(red: 0.59, green: 0.36, blue: 0.14, alpha: 0.82), UIColor(red: 0.53, green: 0.28, blue: 0.61, alpha: 0.72), UIColor(red: 0.15, green: 0.1, blue: 0.27, alpha: 0.56)]
        }
    }

    var backgroundLocations: [NSNumber] { [0, 0.58, 1] }

    var borderWidth: CGFloat { self == .basic ? 0 : 1 }

    var borderColor: UIColor {
        switch self {
        case .basic: return .clear
        case .premium: return UIColor(red: 0.83, green: 0.68, blue: 1, alpha: 0.2)
        case .elite: return UIColor(red: 1, green: 0.9, blue: 0.62, alpha: 0.3)
        }
    }

    var shadowColor: UIColor {
        self == .elite ? UIColor(red: 0.86, green: 0.58, blue: 0.27, alpha: 1) : .clear
    }

    var shadowOpacity: Float { self == .elite ? 0.18 : 0 }
    var shadowRadius: CGFloat { self == .elite ? 8 : 0 }
    var actionTextColor: UIColor {
        self == .elite
            ? UIColor(red: 1, green: 0.973, blue: 0.867, alpha: 1)
            : UIColor(red: 0.949, green: 0.961, blue: 0.98, alpha: 1)
    }
}
