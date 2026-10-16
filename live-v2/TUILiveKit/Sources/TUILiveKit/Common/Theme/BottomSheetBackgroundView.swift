import UIKit

final class BottomSheetBackgroundView: UIView {
    private let blackShadow = CAShapeLayer()
    private let blueShadow = CAShapeLayer()
    private let clippedContainer = CALayer()
    private let backgroundGradient = CAGradientLayer()
    private let highlightGradient = CAGradientLayer()
    private let whiteWashGradient = CAGradientLayer()
    private let bottomGlow = CAGradientLayer()
    private let bokeh1 = CAGradientLayer()
    private let bokeh2 = CAGradientLayer()
    private let bokeh3 = CAGradientLayer()
    private let bokeh4 = CAGradientLayer()
    private let bokeh5 = CAGradientLayer()
    private let brandLine = CAGradientLayer()
    private let handle = CALayer()
    private let innerTopLine = CALayer()

    override init(frame: CGRect) {
        super.init(frame: frame)
        clipsToBounds = false

        configureShadow(
            blackShadow,
            color: UIColor.black,
            opacity: 0.7,
            offset: CGSize(width: 0, height: -24),
            radius: 80
        )
        configureShadow(
            blueShadow,
            color: LiveTheme.Color.brandBlue,
            opacity: 0.3,
            offset: CGSize(width: 0, height: -6),
            radius: 32
        )
        layer.addSublayer(blackShadow)
        layer.addSublayer(blueShadow)

        clippedContainer.masksToBounds = true
        clippedContainer.cornerRadius = SheetBackgroundStyle.cornerRadius
        // All bottom sheets are bottom-anchored, so the bottom corners must stay
        // square instead of exposing the content behind the sheet edge.
        clippedContainer.maskedCorners = [.layerMinXMinYCorner, .layerMaxXMinYCorner]
        layer.addSublayer(clippedContainer)

        backgroundGradient.colors = [
            SheetBackgroundStyle.top.cgColor,
            SheetBackgroundStyle.bottom.cgColor,
        ]
        backgroundGradient.startPoint = CGPoint(x: 0.5, y: 0)
        backgroundGradient.endPoint = CGPoint(x: 0.5, y: 1)
        clippedContainer.addSublayer(backgroundGradient)

        highlightGradient.colors = [UIColor.white.withAlphaComponent(0.05).cgColor, UIColor.clear.cgColor]
        highlightGradient.locations = [0, 0.2]
        highlightGradient.startPoint = CGPoint(x: 0.5, y: 0)
        highlightGradient.endPoint = CGPoint(x: 0.5, y: 1)
        clippedContainer.addSublayer(highlightGradient)

        whiteWashGradient.colors = [
            UIColor.white.withAlphaComponent(0.035).cgColor,
            UIColor.white.withAlphaComponent(0.015).cgColor,
        ]
        whiteWashGradient.startPoint = CGPoint(x: 0.5, y: 0)
        whiteWashGradient.endPoint = CGPoint(x: 0.5, y: 1)
        clippedContainer.addSublayer(whiteWashGradient)

        configureGlow(bottomGlow, color: LiveTheme.Color.brandBlue.withAlphaComponent(0.22))
        configureGlow(bokeh1, color: LiveTheme.Color.brandBlue.withAlphaComponent(0.319))
        configureGlow(bokeh2, color: LiveTheme.Color.brandCyan.withAlphaComponent(0.29))
        configureGlow(bokeh3, color: LiveTheme.Color.brandDeepBlue.withAlphaComponent(0.348))
        configureGlow(bokeh4, color: LiveTheme.Color.brandCyan.withAlphaComponent(0.232))
        configureGlow(bokeh5, color: LiveTheme.Color.brandBlue.withAlphaComponent(0.261))
        [bottomGlow, bokeh1, bokeh2, bokeh3, bokeh4, bokeh5].forEach {
            clippedContainer.addSublayer($0)
        }

        brandLine.colors = [
            UIColor.clear.cgColor,
            LiveTheme.Color.brandBlue.withAlphaComponent(0.9).cgColor,
            LiveTheme.Color.brandCyan.withAlphaComponent(0.9).cgColor,
            UIColor.clear.cgColor,
        ]
        brandLine.locations = [0, 0.3, 0.7, 1]
        brandLine.startPoint = CGPoint(x: 0, y: 0.5)
        brandLine.endPoint = CGPoint(x: 1, y: 0.5)
        brandLine.shadowColor = LiveTheme.Color.brandBlue.withAlphaComponent(0.7).cgColor
        brandLine.shadowOpacity = 1
        brandLine.shadowRadius = 8

        innerTopLine.backgroundColor = UIColor.white.withAlphaComponent(0.14).cgColor
        clippedContainer.addSublayer(innerTopLine)

        // The Ardot brand line owns an outer glow, so it must sit outside the
        // clipped content layer instead of being cut off at the sheet edge.
        layer.addSublayer(brandLine)

        handle.backgroundColor = SheetBackgroundStyle.handle.cgColor
        handle.cornerRadius = 2
        clippedContainer.addSublayer(handle)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        guard bounds.width.isFinite, bounds.height.isFinite,
              bounds.width > 0, bounds.height > 0 else { return }
        let horizontalScale = bounds.width / 390
        // Matches the clipped container: only the top corners are rounded, so
        // the shadow silhouette must use the same shape.
        let roundedPath = UIBezierPath(
            roundedRect: bounds,
            byRoundingCorners: [.topLeft, .topRight],
            cornerRadii: CGSize(width: SheetBackgroundStyle.cornerRadius, height: SheetBackgroundStyle.cornerRadius)
        ).cgPath
        blackShadow.frame = bounds
        blackShadow.path = roundedPath
        blackShadow.shadowPath = UIBezierPath(
            roundedRect: bounds.insetBy(dx: 24, dy: 24),
            cornerRadius: 2
        ).cgPath
        blueShadow.frame = bounds
        blueShadow.path = roundedPath
        blueShadow.shadowPath = UIBezierPath(
            roundedRect: bounds.insetBy(dx: 12, dy: 12),
            cornerRadius: 14
        ).cgPath
        clippedContainer.frame = bounds
        backgroundGradient.frame = bounds
        highlightGradient.frame = bounds
        whiteWashGradient.frame = bounds
        bottomGlow.frame = CGRect(x: 39 * horizontalScale, y: bounds.height - 40, width: 312 * horizontalScale, height: 80)
        bokeh1.frame = CGRect(x: -148.8 * horizontalScale, y: -180 + 0.08 * bounds.height, width: 360 * horizontalScale, height: 360)
        bokeh2.frame = CGRect(x: 218.8 * horizontalScale, y: -140 + 0.01 * bounds.height, width: 280 * horizontalScale, height: 280)
        bokeh3.frame = CGRect(x: 135 * horizontalScale, y: -60 + 0.43 * bounds.height, width: 120 * horizontalScale, height: 120)
        bokeh4.frame = CGRect(x: -45.4 * horizontalScale, y: -100 + 0.99 * bounds.height, width: 200 * horizontalScale, height: 200)
        bokeh5.frame = CGRect(x: 262.2 * horizontalScale, y: -120 + 0.99 * bounds.height, width: 240 * horizontalScale, height: 240)
        brandLine.frame = CGRect(x: bounds.width * 0.15, y: 0, width: bounds.width * 0.7, height: 2)
        innerTopLine.frame = CGRect(x: 0, y: 0, width: bounds.width, height: 1 / UIScreen.main.scale)
        handle.frame = CGRect(x: (bounds.width - 36) / 2, y: 10, width: 36, height: 4)
    }

    private func configureGlow(_ gradient: CAGradientLayer, color: UIColor) {
        gradient.type = .radial
        gradient.colors = [color.cgColor, UIColor.clear.cgColor]
        gradient.locations = [0, 1]
        gradient.startPoint = CGPoint(x: 0.5, y: 0.5)
        gradient.endPoint = CGPoint(x: 1, y: 1)
    }

    private func configureShadow(
        _ shadow: CAShapeLayer,
        color: UIColor,
        opacity: Float,
        offset: CGSize,
        radius: CGFloat
    ) {
        shadow.fillColor = SheetBackgroundStyle.bottom.cgColor
        shadow.shadowColor = color.cgColor
        shadow.shadowOpacity = opacity
        shadow.shadowOffset = offset
        shadow.shadowRadius = radius
    }
}

private enum SheetBackgroundStyle {
    static let cornerRadius: CGFloat = 26
    static let top: UIColor = UIColor(red: 0.094, green: 0.086, blue: 0.125, alpha: 1)
    static let bottom: UIColor = UIColor(red: 0.039, green: 0.035, blue: 0.055, alpha: 1)
    static let handle: UIColor = UIColor.white.withAlphaComponent(0.2)
}
