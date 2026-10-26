import UIKit

final class VideoRecorderCircleProgressView: UIView {
    private static let progressAnimationDuration: TimeInterval = 0.25

    var progress: CGFloat = 0 {
        didSet {
            progress = max(0, min(1, progress))
        }
    }

    var progressColor: UIColor = .green {
        didSet {
            frontLayer.strokeColor = progressColor.cgColor
        }
    }

    var progressBgColor: UIColor = .gray {
        didSet {
            backLayer.strokeColor = progressBgColor.cgColor
        }
    }

    var width: CGFloat = 5 {
        didSet {
            setNeedsLayout()
        }
    }

    var clockwise: Bool = true {
        didSet {
            setNeedsLayout()
        }
    }

    var startAngle: CGFloat = -.pi / 2 {
        didSet {
            setNeedsLayout()
        }
    }

    var lineCap: CAShapeLayerLineCap = .round {
        didSet {
            frontLayer.lineCap = lineCap
        }
    }

    private let backLayer = CAShapeLayer()

    private let frontLayer = CAShapeLayer()

    override init(frame: CGRect) {
        super.init(frame: frame)
        initUI()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        let length = min(bounds.width, bounds.height)
        let center = CGPoint(x: bounds.width / 2, y: bounds.height / 2)
        let radius = (length - width) / 2
        let backgroundPath = UIBezierPath(arcCenter: center, radius: radius, startAngle: 0,
                                          endAngle: .pi * 2, clockwise: clockwise)
        let frontPath = UIBezierPath(arcCenter: center, radius: radius, startAngle: startAngle,
                                     endAngle: startAngle + (clockwise ? 2 * .pi : -2 * .pi), clockwise: clockwise)
        backLayer.path = backgroundPath.cgPath
        frontLayer.path = frontPath.cgPath
        frontLayer.lineWidth = width
        backLayer.lineWidth = width
        frontLayer.strokeEnd = 0
    }

    func setProgress(_ progress: CGFloat, animated: Bool) {
        self.progress = progress
        if animated {
            UIView.animate(withDuration: Self.progressAnimationDuration) {
                self.frontLayer.strokeEnd = self.progress
            }
        } else {
            frontLayer.strokeEnd = self.progress
        }
    }

    private func initUI() {
        layer.addSublayer(backLayer)
        backLayer.fillColor = nil
        backLayer.strokeColor = progressBgColor.cgColor

        layer.addSublayer(frontLayer)
        frontLayer.fillColor = nil
        frontLayer.lineCap = lineCap
        frontLayer.strokeColor = progressColor.cgColor
    }
}
