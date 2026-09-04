import UIKit

final class SelectionCheckBox: UIView {
    private static let iconRadiusRatio: CGFloat = 0.375

    private static let checkmarkHorizontalRatio: CGFloat = 0.5

    private static let checkmarkJointXRatio: CGFloat = 0.1

    private static let checkmarkVerticalRatio: CGFloat = 0.35

    private static let strokeLineWidth: CGFloat = 1.5

    private static let crossRadiusRatio: CGFloat = 0.4

    var isChecked: Bool = false {
        didSet { setNeedsDisplay() }
    }

    var isLocked: Bool = false {
        didSet { setNeedsDisplay() }
    }

    override init(frame: CGRect) {
        super.init(frame: frame)
        backgroundColor = .clear
        isUserInteractionEnabled = false
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func draw(_ rect: CGRect) {
        let colors = TUIChatKitTheme.colors
        let centerX = bounds.width / 2
        let centerY = bounds.height / 2
        let radius = bounds.width / 2
        let iconRadius = bounds.width * Self.iconRadiusRatio

        if isChecked {
            (isLocked ? colors.textColorLinkDisabled : colors.textColorLink).setFill()
            UIBezierPath(ovalIn: bounds).fill()

            let checkPath = UIBezierPath()
            checkPath.move(to: CGPoint(x: centerX - iconRadius * Self.checkmarkHorizontalRatio, y: centerY))
            checkPath.addLine(to: CGPoint(x: centerX - iconRadius * Self.checkmarkJointXRatio, y: centerY + iconRadius * Self.checkmarkVerticalRatio))
            checkPath.addLine(to: CGPoint(x: centerX + iconRadius * Self.checkmarkHorizontalRatio, y: centerY - iconRadius * Self.checkmarkVerticalRatio))
            checkPath.lineWidth = Self.strokeLineWidth
            checkPath.lineCapStyle = .round
            checkPath.lineJoinStyle = .round
            (isLocked ? colors.textColorButtonDisabled : colors.textColorButton).setStroke()
            checkPath.stroke()
        } else {
            let strokeWidth: CGFloat = 1
            let ringRect = bounds.insetBy(dx: strokeWidth / 2, dy: strokeWidth / 2)
            let ringPath = UIBezierPath(ovalIn: ringRect)
            ringPath.lineWidth = strokeWidth
            colors.scrollbarColorDefault.setStroke()
            ringPath.stroke()

            if isLocked {
                let crossRadius = iconRadius * Self.crossRadiusRatio
                let crossPath = UIBezierPath()
                crossPath.move(to: CGPoint(x: centerX - crossRadius, y: centerY - crossRadius))
                crossPath.addLine(to: CGPoint(x: centerX + crossRadius, y: centerY + crossRadius))
                crossPath.move(to: CGPoint(x: centerX + crossRadius, y: centerY - crossRadius))
                crossPath.addLine(to: CGPoint(x: centerX - crossRadius, y: centerY + crossRadius))
                crossPath.lineWidth = Self.strokeLineWidth
                crossPath.lineCapStyle = .round
                colors.textColorButtonDisabled.setStroke()
                crossPath.stroke()
            }
        }
    }
}
