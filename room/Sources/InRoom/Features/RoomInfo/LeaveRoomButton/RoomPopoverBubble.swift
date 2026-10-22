import UIKit

final class RoomPopoverBubble: UIView {

    static let contentInset: CGFloat = 9

    private static let cornerRadius: CGFloat = 14
    private static let arrowHalf: CGFloat = 7.5
    private static let arrowEdgeInset: CGFloat = 28

    private let shape = CAShapeLayer()
    private var placement: RoomPopover.Placement = .top
    private var align: RoomPopover.Align = .center
    private var showsArrow = false

    override init(frame: CGRect) {
        super.init(frame: frame)
        shape.lineWidth = 1
        shape.lineJoin = .miter
        layer.insertSublayer(shape, at: 0)
        layer.shadowOffset = CGSize(width: 0, height: 8)
        layer.shadowRadius = 12
        layer.shadowOpacity = 1
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        let path = makePath()
        shape.frame = bounds
        shape.path = path
        layer.shadowPath = path
    }

    func configure(placement: RoomPopover.Placement, align: RoomPopover.Align, showsArrow: Bool) {
        self.placement = placement
        self.align = align
        self.showsArrow = showsArrow
        setNeedsLayout()
    }

    func applyTheme() {
        shape.fillColor = UIColor.roomKitBgPopoverSolid.cgColor
        shape.strokeColor = UIColor.roomKitBorderStrong.cgColor
        layer.shadowColor = UIColor.roomKitShadowLg.cgColor
    }

    private func makePath() -> CGPath {
        let rect = bounds.insetBy(dx: 0.5, dy: 0.5)
        let radius = Self.cornerRadius - 0.5
        let half = Self.arrowHalf

        let path = UIBezierPath()
        path.move(to: CGPoint(x: rect.minX + radius, y: rect.minY))
        if showsArrow {
            let arrowX: CGFloat
            switch align {
            case .start: arrowX = Self.arrowEdgeInset
            case .center: arrowX = bounds.midX
            case .end: arrowX = bounds.width - Self.arrowEdgeInset
            }
            path.addLine(to: CGPoint(x: arrowX - half, y: rect.minY))
            path.addLine(to: CGPoint(x: arrowX, y: rect.minY - half))
            path.addLine(to: CGPoint(x: arrowX + half, y: rect.minY))
        }
        path.addLine(to: CGPoint(x: rect.maxX - radius, y: rect.minY))
        path.addArc(withCenter: CGPoint(x: rect.maxX - radius, y: rect.minY + radius),
                    radius: radius, startAngle: -.pi / 2, endAngle: 0, clockwise: true)
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY - radius))
        path.addArc(withCenter: CGPoint(x: rect.maxX - radius, y: rect.maxY - radius),
                    radius: radius, startAngle: 0, endAngle: .pi / 2, clockwise: true)
        path.addLine(to: CGPoint(x: rect.minX + radius, y: rect.maxY))
        path.addArc(withCenter: CGPoint(x: rect.minX + radius, y: rect.maxY - radius),
                    radius: radius, startAngle: .pi / 2, endAngle: .pi, clockwise: true)
        path.addLine(to: CGPoint(x: rect.minX, y: rect.minY + radius))
        path.addArc(withCenter: CGPoint(x: rect.minX + radius, y: rect.minY + radius),
                    radius: radius, startAngle: .pi, endAngle: -.pi / 2, clockwise: true)
        path.close()

        if placement == .top {
            path.apply(CGAffineTransform(translationX: 0, y: bounds.height).scaledBy(x: 1, y: -1))
        }
        return path.cgPath
    }
}
