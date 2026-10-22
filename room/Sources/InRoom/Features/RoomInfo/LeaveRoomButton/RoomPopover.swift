import UIKit
import SnapKit

///
///
/// ```swift
/// let popover = RoomPopover(anchor: triggerButton)
/// popover.placement = .bottom
/// popover.align = .end
/// popover.showsArrow = true
/// popover.contentView.addSubview(stack)
/// popover.show(in: host)
/// ```
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
        contentView.snp.makeConstraints { $0.edges.equalToSuperview().inset(RoomPopoverBubble.contentInset) }
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

// MARK: - public methods

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

// MARK: - private methods

extension RoomPopover {

    @objc private func handleOutsideTap() {
        onClose?()
    }
}
