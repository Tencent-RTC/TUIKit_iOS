import SnapKit
import UIKit

final class LevelBadgeView: UIView {
    private let gradient = CAGradientLayer()
    private let iconView = UIImageView()
    private let valueLabel = UILabel()

    init(level: Int) {
        super.init(frame: .zero)
        configureUI()
        bind(level: level)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        gradient.frame = bounds
        gradient.cornerRadius = bounds.height / 2
    }

    override var intrinsicContentSize: CGSize {
        CGSize(width: max(34, 14 + ceil(valueLabel.intrinsicContentSize.width) + 4), height: 15)
    }

    func bind(level: Int) {
        let normalizedLevel = max(0, level)
        let tier = Tier(level: normalizedLevel)
        valueLabel.text = String(normalizedLevel)
        invalidateIntrinsicContentSize()
        valueLabel.textColor = tier.textColor
        iconView.image = LiveKitResources.image(named: tier.assetName)
        gradient.colors = tier.colors.map(\.cgColor)
        layer.borderWidth = tier == .basic ? 0 : 0.5
        layer.borderColor = tier.borderColor.cgColor
        layer.masksToBounds = tier != .elite
        layer.shadowColor = tier == .elite
            ? UIColor(red: 0.93, green: 0.67, blue: 0.29, alpha: 0.44).cgColor
            : UIColor.clear.cgColor
        layer.shadowOpacity = tier == .elite ? 1 : 0
        layer.shadowRadius = tier == .elite ? 6 : 0
    }

    private func configureUI() {
        setContentHuggingPriority(.required, for: .horizontal)
        setContentCompressionResistancePriority(.required, for: .horizontal)
        gradient.startPoint = CGPoint(x: 0, y: 0)
        gradient.endPoint = CGPoint(x: 1, y: 1)
        layer.insertSublayer(gradient, at: 0)
        layer.cornerRadius = 7.5

        iconView.contentMode = .scaleAspectFit
        addSubview(iconView)

        valueLabel.font = LevelBadgeViewTypography.valueFont
        valueLabel.textAlignment = .center
        valueLabel.layer.shadowColor = UIColor.black.withAlphaComponent(0.34).cgColor
        valueLabel.layer.shadowOffset = CGSize(width: 0, height: 1)
        valueLabel.layer.shadowRadius = 2
        valueLabel.layer.shadowOpacity = 1
        addSubview(valueLabel)

        iconView.snp.makeConstraints { make in
            make.leading.equalToSuperview().offset(4)
            make.centerY.equalToSuperview()
            make.size.equalTo(10)
        }
        valueLabel.snp.makeConstraints { make in
            make.leading.equalToSuperview().offset(14)
            make.top.equalToSuperview().offset(1)
            make.trailing.equalToSuperview().inset(4)
            make.height.equalTo(12)
        }
    }

    private enum Tier: Equatable {
        case basic
        case advanced
        case premium
        case elite

        init(level: Int) {
            switch level {
            case ..<10: self = .basic
            case 10..<25: self = .advanced
            case 25..<40: self = .premium
            default: self = .elite
            }
        }

        var colors: [UIColor] {
            switch self {
            case .basic:
                return [UIColor(red: 0.325, green: 0.388, blue: 0.498, alpha: 1), UIColor(red: 0.443, green: 0.525, blue: 0.678, alpha: 1)]
            case .advanced:
                return [UIColor(red: 0.224, green: 0.482, blue: 0.847, alpha: 1), UIColor(red: 0.333, green: 0.725, blue: 0.863, alpha: 1)]
            case .premium:
                return [UIColor(red: 0.4, green: 0.333, blue: 0.91, alpha: 1), UIColor(red: 0.639, green: 0.365, blue: 0.941, alpha: 1), UIColor(red: 0.906, green: 0.427, blue: 0.741, alpha: 1)]
            case .elite:
                return [UIColor(red: 0.898, green: 0.529, blue: 0.263, alpha: 1), UIColor(red: 0.945, green: 0.784, blue: 0.325, alpha: 1), UIColor(red: 0.459, green: 0.408, blue: 0.941, alpha: 1)]
            }
        }

        var assetName: String {
            switch self {
            case .basic: return "livekit_level_basic"
            case .advanced: return "livekit_level_advanced"
            case .premium: return "livekit_level_premium"
            case .elite: return "livekit_level_elite"
            }
        }

        var borderColor: UIColor {
            switch self {
            case .basic: return .clear
            case .advanced: return UIColor(red: 0.824, green: 0.965, blue: 1, alpha: 0.3)
            case .premium: return UIColor.white.withAlphaComponent(0.42)
            case .elite: return UIColor(red: 1, green: 0.98, blue: 0.812, alpha: 1)
            }
        }

        var textColor: UIColor {
            switch self {
            case .basic: return UIColor(red: 0.859, green: 0.906, blue: 1, alpha: 1)
            case .advanced: return UIColor(red: 0.914, green: 0.984, blue: 1, alpha: 1)
            case .premium: return UIColor(red: 1, green: 0.953, blue: 1, alpha: 1)
            case .elite: return UIColor(red: 1, green: 0.976, blue: 0.867, alpha: 1)
            }
        }
    }
}

// Styles owned by this component or feature. Values preserve the existing design.
private enum LevelBadgeViewTypography {
    static let valueFont: UIFont = UIFont.systemFont(ofSize: 8.5, weight: .bold)
}
