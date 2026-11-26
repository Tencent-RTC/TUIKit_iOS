import UIKit
import SnapKit

final class RoomLeavePopoverView {

    var onSelect: ((RoomLeaveRoomButton.Kind) -> Void)?
    var onDismiss: (() -> Void)?

    private let popover: RoomPopover
    private let endItem = UIButton(type: .system)
    private let leaveItem = UIButton(type: .system)

    init(anchor: UIView) {
        popover = RoomPopover(anchor: anchor)
        popover.placement = .bottom
        popover.align = .end
        popover.showsArrow = false
        popover.gap = 8
        popover.minWidth = 176

        Self.configure(
            endItem, title: RoomKitResources.localizedString("roomkit.main.leave_end"),
            background: .roomKitDanger, pressed: .roomKitDangerPressed, titleColor: .roomKitFgOnDanger
        )
        Self.configure(
            leaveItem, title: RoomKitResources.localizedString("roomkit.main.leave_self"),
            background: .roomKitBgHover, pressed: .roomKitBgPress, titleColor: .roomKitFgPrimary
        )

        let stack = UIStackView(arrangedSubviews: [endItem, leaveItem])
        stack.axis = .vertical
        stack.spacing = 6
        popover.contentView.addSubview(stack)
        stack.snp.makeConstraints { $0.edges.equalToSuperview() }

        popover.onClose = { [weak self] in self?.onDismiss?() }
        endItem.addAction(UIAction { [weak self] _ in self?.onSelect?(.endAll) }, for: .touchUpInside)
        leaveItem.addAction(UIAction { [weak self] _ in self?.onSelect?(.leaveSelf) }, for: .touchUpInside)
    }

    static func makeAnimator() -> UIViewPropertyAnimator {
        RoomPopover.makeAnimator()
    }

    private static func configure(
        _ button: UIButton, title: String, background: UIColor, pressed: UIColor, titleColor: UIColor
    ) {
        button.setTitle(title, for: .normal)
        button.setTitleColor(titleColor, for: .normal)
        button.titleLabel?.font = .systemFont(ofSize: 15, weight: .medium)
        button.layer.cornerRadius = 12
        button.clipsToBounds = true
        button.heightAnchor.constraint(equalToConstant: 44).isActive = true
        button.setBackgroundImage(.solid(background), for: .normal)
        button.setBackgroundImage(.solid(pressed), for: .highlighted)
    }
}

extension RoomLeavePopoverView {

    func show(in host: UIView) {
        popover.show(in: host)
    }

    func close(animated: Bool = true, completion: (() -> Void)? = nil) {
        popover.close(animated: animated, completion: completion)
    }
}

public final class RoomPopover: UIControl {

    public enum Placement {
        case top
        case bottom
    }

    public enum Align {
        case start
        case center
        case end
    }

    public var placement: Placement = .top
    public var align: Align = .center
    public var showsArrow = false

    public var gap: CGFloat = 12

    public var minWidth: CGFloat = 160

    public let contentView = UIView()

    public var onClose: (() -> Void)?

    public private(set) var isClosing = false

    private weak var anchor: UIView?
    private let bubble = RoomPopoverBubble()

    public init(anchor: UIView) {
        self.anchor = anchor
        super.init(frame: .zero)
        addTarget(self, action: #selector(handleOutsideTap), for: .touchUpInside)
        addSubview(bubble)
        bubble.addSubview(contentView)
        contentView.snp.makeConstraints { $0.edges.equalToSuperview().inset(9) }
        applyTheme()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    public override func didMoveToWindow() {
        super.didMoveToWindow()
        if window != nil {
            applyTheme()
        }
    }

    private func applyTheme() {
        bubble.applyTheme()
    }

    public static func makeAnimator() -> UIViewPropertyAnimator {
        UIViewPropertyAnimator(
            duration: 0.2,
            timingParameters: UICubicTimingParameters(
                controlPoint1: CGPoint(x: 0.23, y: 1),
                controlPoint2: CGPoint(x: 0.32, y: 1)
            )
        )
    }

    private var hiddenTransform: CGAffineTransform {
        CGAffineTransform(translationX: 0, y: placement == .bottom ? -8 : 8)
    }
}

extension RoomPopover {

    public func show(in host: UIView) {
        guard let anchor, anchor.isDescendant(of: host), superview == nil else { return }
        bubble.configure(placement: placement, align: align, showsArrow: showsArrow)
        host.addSubview(self)
        snp.remakeConstraints { $0.edges.equalToSuperview() }
        bubble.snp.remakeConstraints {
            switch placement {
            case .bottom: $0.top.equalTo(anchor.snp.bottom).offset(gap)
            case .top: $0.bottom.equalTo(anchor.snp.top).offset(-gap)
            }
            switch align {
            case .start: $0.leading.equalTo(anchor.snp.leading)
            case .center: $0.centerX.equalTo(anchor.snp.centerX)
            case .end: $0.trailing.equalTo(anchor.snp.trailing)
            }
            $0.width.greaterThanOrEqualTo(minWidth)
        }
        host.layoutIfNeeded()

        bubble.alpha = 0
        bubble.transform = hiddenTransform
        let animator = Self.makeAnimator()
        animator.addAnimations {
            self.bubble.alpha = 1
            self.bubble.transform = .identity
        }
        animator.startAnimation()
    }

    public func close(animated: Bool = true, completion: (() -> Void)? = nil) {
        guard !isClosing else { return }
        isClosing = true
        isUserInteractionEnabled = false
        guard animated else {
            removeFromSuperview()
            completion?()
            return
        }
        let animator = Self.makeAnimator()
        animator.addAnimations {
            self.bubble.alpha = 0
            self.bubble.transform = self.hiddenTransform
        }
        animator.addCompletion { _ in
            self.removeFromSuperview()
            completion?()
        }
        animator.startAnimation()
    }
}

extension RoomPopover {

    @objc private func handleOutsideTap() {
        onClose?()
    }
}

final class RoomPopoverBubble: UIView {

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
        let radius = 14 - 0.5
        let half = 7.5

        let path = UIBezierPath()
        path.move(to: CGPoint(x: rect.minX + radius, y: rect.minY))
        if showsArrow {
            let arrowX: CGFloat
            switch align {
            case .start: arrowX = 28
            case .center: arrowX = bounds.midX
            case .end: arrowX = bounds.width - 28
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
