import UIKit

final class PusherStageShadingView: UIView {
    private let topGradient = CAGradientLayer()
    private let bottomGradient = CAGradientLayer()

    override init(frame: CGRect) {
        super.init(frame: frame)
        isUserInteractionEnabled = false
        backgroundColor = .clear

        topGradient.colors = [
            PusherStageShadeStyle.topStart.cgColor,
            PusherStageShadeStyle.topMiddle.cgColor,
            UIColor.clear.cgColor,
        ]
        topGradient.locations = [0, 0.4, 1]
        topGradient.startPoint = CGPoint(x: 0.5, y: 0)
        topGradient.endPoint = CGPoint(x: 0.5, y: 1)

        bottomGradient.colors = [
            UIColor.clear.cgColor,
            PusherStageShadeStyle.bottomMiddle.cgColor,
            PusherStageShadeStyle.bottomEnd.cgColor,
        ]
        bottomGradient.locations = [0, 0.62, 1]
        bottomGradient.startPoint = CGPoint(x: 0.5, y: 0)
        bottomGradient.endPoint = CGPoint(x: 0.5, y: 1)

        layer.addSublayer(topGradient)
        layer.addSublayer(bottomGradient)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        let stageHeight = max(0, bounds.height - 112)
        topGradient.frame = CGRect(x: 0, y: 0, width: bounds.width, height: stageHeight * 337 / 732)
        bottomGradient.frame = CGRect(
            x: 0,
            y: stageHeight * 425 / 732,
            width: bounds.width,
            height: stageHeight * 307 / 732
        )
    }
}

// Styles owned by this component or feature. Values preserve the existing design.
private enum PusherStageShadeStyle {
    static let topStart: UIColor = UIColor.black.withAlphaComponent(0.55)
    static let topMiddle: UIColor = UIColor.black.withAlphaComponent(0.28)
    static let bottomMiddle: UIColor = UIColor.black.withAlphaComponent(0.32)
    static let bottomEnd: UIColor = UIColor.black.withAlphaComponent(0.7)
}
