import SnapKit
import UIKit

final class VoiceLoungeLikeButton: UIControl {
    static let size: CGFloat = 52
    private static let iconSize: CGFloat = 24

    static let gradientColors: [UIColor] = [
        UIColor(red: 0.851, green: 0.494, blue: 0.851, alpha: 1),
        UIColor(red: 0.682, green: 0.478, blue: 0.937, alpha: 1),
        UIColor(red: 0.510, green: 0.596, blue: 0.937, alpha: 1),
    ]

    var onLike: (() -> Void)?

    private let pressView = UIView()
    private let shadowView = UIView()
    private let discView = VoiceLoungeLikeGlassView()
    private let iconView = VoiceLoungeThumbIconView()
    private let isInteractive: Bool

    init(isInteractive: Bool) {
        self.isInteractive = isInteractive
        super.init(frame: .zero)
        setupViews()
    }

    @available(*, unavailable) required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    func heartCenter(in view: UIView) -> CGPoint {
        discView.convert(CGPoint(x: discView.bounds.midX, y: discView.bounds.midY), to: view)
    }

    func pulse() {
        let anim = CAKeyframeAnimation(keyPath: "transform.scale")
        anim.values = [1, 1.34, 0.92, 1]
        anim.keyTimes = [0, 0.32, 0.64, 1]
        anim.duration = 0.45
        anim.timingFunction = CAMediaTimingFunction(controlPoints: 0.2, 0.8, 0.3, 1)
        iconView.layer.removeAnimation(forKey: "voiceLounge.likePulse")
        iconView.layer.add(anim, forKey: "voiceLounge.likePulse")
    }

    private func setupViews() {
        isUserInteractionEnabled = isInteractive
        [pressView, shadowView, discView, iconView].forEach { $0.isUserInteractionEnabled = false }

        addSubview(pressView)
        [shadowView, discView].forEach(pressView.addSubview)
        discView.addSubview(iconView)

        discView.clipsToBounds = true
        discView.layer.cornerRadius = Self.size / 2
        discView.layer.borderWidth = 0.8
        discView.layer.borderColor = UIColor.white.withAlphaComponent(0.5).cgColor

        shadowView.backgroundColor = Self.gradientColors[1]
        shadowView.layer.cornerRadius = Self.size / 2
        shadowView.layer.shadowColor = Self.gradientColors[1].cgColor
        shadowView.layer.shadowOpacity = 0.55
        shadowView.layer.shadowRadius = 14
        shadowView.layer.shadowOffset = CGSize(width: 0, height: 5)

        pressView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
            make.size.equalTo(Self.size)
        }
        [shadowView, discView].forEach { view in view.snp.makeConstraints { $0.edges.equalToSuperview() } }
        iconView.snp.makeConstraints { make in
            make.center.equalToSuperview()
            make.size.equalTo(Self.iconSize)
        }

        addTarget(self, action: #selector(tap), for: .touchUpInside)
        addTarget(self, action: #selector(touchDown), for: .touchDown)
        addTarget(self, action: #selector(touchUp), for: [.touchUpOutside, .touchCancel])
    }

    @objc private func touchDown() {
        UIView.animate(withDuration: 0.12) { self.pressView.transform = CGAffineTransform(scaleX: 0.88, y: 0.88) }
    }

    @objc private func touchUp() { UIView.animate(withDuration: 0.18) { self.pressView.transform = .identity } }

    @objc private func tap() {
        touchUp()
        pulse()
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        onLike?()
    }
}

private final class VoiceLoungeLikeGlassView: UIView {
    private let liquidLayer = CAGradientLayer()
    private let edgeShadeLayer = CAGradientLayer()
    private let topGlossLayer = CAGradientLayer()
    private let specularLayer = CAShapeLayer()

    override init(frame: CGRect) {
        super.init(frame: frame)
        isUserInteractionEnabled = false

        liquidLayer.colors = VoiceLoungeLikeButton.gradientColors.map(\.cgColor)
        liquidLayer.locations = [0, 0.5, 1]
        liquidLayer.startPoint = CGPoint(x: 0.15, y: 0.1)
        liquidLayer.endPoint = CGPoint(x: 0.85, y: 0.95)
        layer.addSublayer(liquidLayer)

        edgeShadeLayer.type = .radial
        edgeShadeLayer.colors = [UIColor.clear.cgColor, UIColor.black.withAlphaComponent(0.28).cgColor]
        edgeShadeLayer.locations = [0.55, 1]
        edgeShadeLayer.startPoint = CGPoint(x: 0.5, y: 0.5)
        edgeShadeLayer.endPoint = CGPoint(x: 1.05, y: 1.05)
        layer.addSublayer(edgeShadeLayer)

        topGlossLayer.type = .radial
        topGlossLayer.colors = [
            UIColor.white.withAlphaComponent(0.85).cgColor, UIColor.white.withAlphaComponent(0).cgColor,
        ]
        topGlossLayer.locations = [0, 1]
        topGlossLayer.startPoint = CGPoint(x: 0.32, y: 0.22)
        topGlossLayer.endPoint = CGPoint(x: 0.72, y: 0.62)
        layer.addSublayer(topGlossLayer)

        specularLayer.fillColor = UIColor.white.withAlphaComponent(0.95).cgColor
        layer.addSublayer(specularLayer)
    }

    @available(*, unavailable) required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    override func layoutSubviews() {
        super.layoutSubviews()
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        liquidLayer.frame = bounds
        edgeShadeLayer.frame = bounds
        topGlossLayer.frame = bounds
        let w = bounds.width * 0.2, h = bounds.height * 0.12
        let x = bounds.width * 0.22, y = bounds.height * 0.17
        specularLayer.path = UIBezierPath(ovalIn: CGRect(x: x, y: y, width: w, height: h)).cgPath
        CATransaction.commit()
    }
}

private final class VoiceLoungeThumbIconView: UIView {
    private let shapeLayer = CAShapeLayer()

    override init(frame: CGRect) {
        super.init(frame: frame)
        isUserInteractionEnabled = false
        backgroundColor = .clear
        shapeLayer.fillColor = UIColor.white.cgColor
        layer.addSublayer(shapeLayer)
    }

    @available(*, unavailable) required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    override func layoutSubviews() {
        super.layoutSubviews()
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        shapeLayer.frame = bounds
        shapeLayer.path = Self.thumbPath(in: bounds).cgPath
        CATransaction.commit()
    }

    static func thumbPath(in rect: CGRect) -> UIBezierPath {
        let sx = rect.width / 24, sy = rect.height / 24
        func p(_ x: CGFloat, _ y: CGFloat) -> CGPoint { CGPoint(x: rect.minX + x * sx, y: rect.minY + y * sy) }

        let path = UIBezierPath(
            roundedRect: CGRect(x: rect.minX + 2.5 * sx, y: rect.minY + 9 * sy, width: 4.5 * sx, height: 12 * sy),
            cornerRadius: 1.2 * sx)

        let hand = UIBezierPath()
        hand.move(to: p(9, 19.4))
        hand.addLine(to: p(9, 9.9))
        hand.addCurve(to: p(9.56, 8.57), controlPoint1: p(9, 9.4), controlPoint2: p(9.2, 8.92))
        hand.addLine(to: p(14.66, 3.55))
        hand.addCurve(to: p(16.64, 3.89), controlPoint1: p(15.26, 2.95), controlPoint2: p(16.26, 3.13))
        hand.addCurve(to: p(16.76, 5.19), controlPoint1: p(16.84, 4.29), controlPoint2: p(16.88, 4.75))
        hand.addLine(to: p(15.9, 9))
        hand.addLine(to: p(20.2, 9))
        hand.addCurve(to: p(22.14, 11.52), controlPoint1: p(21.52, 9), controlPoint2: p(22.48, 10.25))
        hand.addLine(to: p(20.28, 18.42))
        hand.addQuadCurve(to: p(18.16, 20), controlPoint: p(19.85, 20))
        hand.addLine(to: p(10.6, 20))
        hand.addCurve(to: p(9, 19.4), controlPoint1: p(9.72, 20), controlPoint2: p(9, 19.73))
        hand.close()
        path.append(hand)
        return path
    }
}
