import UIKit

internal enum MessageInputAppearanceApplier {
    private static let gradientLayerName = "messageInputAppearanceGradient"
    private static let minimumGradientColorCount = 2

    internal static func apply(fill: MessageInputFill?, to view: UIView, defaultColor: UIColor) {
        view.layer.sublayers?.filter { $0.name == gradientLayerName }.forEach { $0.removeFromSuperlayer() }
        view.backgroundColor = defaultColor
        guard let fill else { return }
        switch fill {
        case .none:
            view.backgroundColor = .clear
        case let .color(color):
            view.backgroundColor = color
        case let .gradient(colors, direction):
            guard colors.count >= minimumGradientColorCount else { return }
            view.backgroundColor = .clear
            let layer = MessageInputGradientLayer(colors: colors, direction: direction)
            layer.name = gradientLayerName
            view.layer.insertSublayer(layer, at: 0)
            update(view)
        }
    }

    internal static func update(_ view: UIView) {
        guard let gradient = view.layer.sublayers?.first(where: { $0.name == gradientLayerName }) as? MessageInputGradientLayer else { return }
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        gradient.frame = view.bounds
        gradient.cornerRadius = view.layer.cornerRadius
        gradient.colors = gradient.sourceColors.map { $0.resolvedColor(with: view.traitCollection).cgColor }
        CATransaction.commit()
    }

    internal static func dimension(_ value: CGFloat?, fallback: CGFloat) -> CGFloat {
        guard let value, value.isFinite, value > 0 else { return fallback }
        return value
    }

    internal static func padding(_ value: CGFloat?, fallback: CGFloat = 0) -> CGFloat {
        guard let value, value.isFinite, value >= 0 else { return fallback }
        return value
    }

    internal static func cornerRadius(_ value: CGFloat?, fallback: CGFloat, size: CGSize) -> CGFloat {
        guard let value, value.isFinite else { return fallback }
        if value == MessageInputButtonAppearance.cornerRadiusPill { return min(size.width, size.height) / 2 }
        return max(0, value)
    }

    internal static func buttonSize(_ appearance: MessageInputButtonAppearance?, fallback: CGFloat, supportsTitle: Bool = false) -> CGSize {
        var width = dimension(appearance?.width, fallback: fallback)
        let height = dimension(appearance?.height, fallback: fallback)
        if supportsTitle, appearance?.width == nil, let title = appearance?.title {
            let font = UIFont.systemFont(ofSize: dimension(appearance?.titleSize, fallback: FontScheme.caption2Regular.pointSize))
            let padding = padding(appearance?.horizontalPadding)
            width = max(1, ceil((title as NSString).size(withAttributes: [.font: font]).width) + padding * 2)
        }
        return CGSize(width: width, height: height)
    }

    internal static func applyButton(_ button: MessageInputAppearanceButton, appearance: MessageInputButtonAppearance?,
                                     active: Bool, defaultImage: UIImage?, defaultTint: UIColor, defaultFill: UIColor,
                                     defaultCornerRadius: CGFloat, size: CGSize, supportsTitle: Bool = false) {
        let hasTitle = supportsTitle && appearance?.title != nil
        let image = active ? appearance?.activeIcon ?? appearance?.icon ?? defaultImage : appearance?.icon ?? defaultImage
        button.setImage(hasTitle ? nil : image?.withRenderingMode(.alwaysTemplate), for: .normal)
        button.setTitle(hasTitle ? appearance?.title : nil, for: .normal)
        button.setTitleColor(appearance?.titleColor ?? defaultTint, for: .normal)
        button.titleLabel?.font = UIFont.systemFont(ofSize: dimension(appearance?.titleSize, fallback: FontScheme.caption2Regular.pointSize))
        button.tintColor = appearance?.iconTint ?? defaultTint
        let horizontalPadding = hasTitle ? padding(appearance?.horizontalPadding) : 0
        button.contentEdgeInsets = UIEdgeInsets(top: 0, left: horizontalPadding, bottom: 0, right: horizontalPadding)
        button.iconSize = appearance?.iconSize.flatMap { $0.isFinite && $0 > 0 ? $0 : nil }
        button.layer.cornerRadius = cornerRadius(appearance?.cornerRadius, fallback: defaultCornerRadius, size: size)
        apply(fill: appearance?.fill, to: button, defaultColor: defaultFill)
    }
}

internal final class MessageInputAppearanceButton: UIButton {
    internal var iconSize: CGFloat?

    internal override func imageRect(forContentRect contentRect: CGRect) -> CGRect {
        guard let iconSize else { return super.imageRect(forContentRect: contentRect) }
        let size = min(iconSize, min(contentRect.width, contentRect.height))
        return CGRect(x: contentRect.midX - size / 2, y: contentRect.midY - size / 2, width: size, height: size)
    }

    internal override func layoutSubviews() {
        super.layoutSubviews()
        MessageInputAppearanceApplier.update(self)
    }
}

private final class MessageInputGradientLayer: CAGradientLayer {
    fileprivate let sourceColors: [UIColor]

    fileprivate init(colors: [UIColor], direction: MessageInputGradientDirection) {
        sourceColors = colors
        super.init()
        switch direction {
        case .topBottom: startPoint = CGPoint(x: 0.5, y: 0); endPoint = CGPoint(x: 0.5, y: 1)
        case .bottomTop: startPoint = CGPoint(x: 0.5, y: 1); endPoint = CGPoint(x: 0.5, y: 0)
        case .leftRight: startPoint = CGPoint(x: 0, y: 0.5); endPoint = CGPoint(x: 1, y: 0.5)
        case .rightLeft: startPoint = CGPoint(x: 1, y: 0.5); endPoint = CGPoint(x: 0, y: 0.5)
        case .topLeftBottomRight: startPoint = CGPoint(x: 0, y: 0); endPoint = CGPoint(x: 1, y: 1)
        case .bottomRightTopLeft: startPoint = CGPoint(x: 1, y: 1); endPoint = CGPoint(x: 0, y: 0)
        }
    }

    override init(layer: Any) {
        sourceColors = (layer as? MessageInputGradientLayer)?.sourceColors ?? []
        super.init(layer: layer)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}
