import UIKit
import SnapKit

///
///
/// ```swift
/// let popup = RoomPopup()
/// popup.contentView.addSubview(myContent)
/// popup.show(in: hostView)
/// ```
public final class RoomPopup: UIView {

    public enum DismissReason {
        case mask
        case drag
    }

    public let contentView = UIView()

    public var onDismiss: ((DismissReason) -> Void)?

    public var closeOnMask = true

    public var dragDismiss = true

    public private(set) var isDismissing = false

    private let dimmingView = UIControl()
    private let panelView = UIView()
    private let handleArea = UIView()
    private let handleBar = UIView()
    private var panelOffset: CGFloat = 0
    private var heightCapConstraint: Constraint?

    public override init(frame: CGRect) {
        super.init(frame: frame)
        setupViews()
        setupConstraints()
        setupStyles()
        setupBindings()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    public override func didMoveToWindow() {
        super.didMoveToWindow()
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }


    private func setupViews() {
        addSubview(dimmingView)
        addSubview(panelView)
        handleArea.addSubview(handleBar)
        panelView.addSubview(handleArea)
        panelView.addSubview(contentView)
    }

    private func setupConstraints() {
        dimmingView.snp.makeConstraints { $0.edges.equalToSuperview() }
        panelView.snp.makeConstraints { $0.leading.trailing.bottom.equalToSuperview() }
        handleArea.snp.makeConstraints {
            $0.top.leading.trailing.equalToSuperview()
            $0.height.equalTo(20)
        }
        handleBar.snp.makeConstraints {
            $0.center.equalToSuperview()
            $0.size.equalTo(CGSize(width: 36, height: 4))
        }
        contentView.snp.makeConstraints {
            $0.top.equalTo(handleArea.snp.bottom)
            $0.leading.trailing.equalToSuperview()
            $0.bottom.equalTo(safeAreaLayoutGuide.snp.bottom)
        }
    }

    private func setupStyles() {
        dimmingView.backgroundColor = .roomKitScrim

        panelView.backgroundColor = .roomKitBgSurface
        panelView.layer.cornerRadius = 16
        panelView.layer.maskedCorners = [.layerMinXMinYCorner, .layerMaxXMinYCorner]
        panelView.layer.borderWidth = 1
        panelView.layer.borderColor = UIColor.roomKitPopupBorder.cgColor
        panelView.layer.masksToBounds = true

        handleBar.backgroundColor = .roomKitDragHandle
        handleBar.layer.cornerRadius = 2
    }

    private func setupBindings() {
        dimmingView.addTarget(self, action: #selector(handleMaskTap), for: .touchUpInside)
        let pan = UIPanGestureRecognizer(target: self, action: #selector(handlePan(_:)))
        pan.delegate = self
        panelView.addGestureRecognizer(pan)

    }

    // MARK: - show / dismiss

    public func show(in host: UIView) {
        guard superview == nil else { return }
        isDismissing = false
        isUserInteractionEnabled = true

        let container = Self.fullScreenContainer(for: host)
        container.addSubview(self)
        snp.remakeConstraints { $0.edges.equalToSuperview() }
        if heightCapConstraint == nil, let capTarget = superview {
            contentView.snp.makeConstraints {
                heightCapConstraint = $0.height.lessThanOrEqualTo(capTarget.snp.height).multipliedBy(0.9).constraint
            }
        }
        container.layoutIfNeeded()

        dimmingView.alpha = 0
        setPanelOffset(max(bounds.height - panelView.frame.minY, panelView.bounds.height), animated: false)
        UIView.animate(withDuration: 0.25) { self.dimmingView.alpha = 1 }
        Self.slideAnimator(duration: 0.32) { self.setPanelOffset(0, animated: false) }
    }

    private static func fullScreenContainer(for host: UIView) -> UIView {
        var controller = host.window?.rootViewController
        while let current = controller {
            if let navigation = current as? UINavigationController {
                controller = navigation.topViewController
                continue
            }
            if let tab = current as? UITabBarController {
                controller = tab.selectedViewController
                continue
            }
            break
        }
        return controller?.view ?? host.window ?? host
    }

    public func dismiss(completion: (() -> Void)? = nil) {
        guard !isDismissing else { return }
        isDismissing = true
        isUserInteractionEnabled = false
        let finish = {
            self.removeFromSuperview()
            completion?()
        }
        let offset = max(bounds.height - panelView.frame.minY, panelView.bounds.height)
        UIView.animate(
            withDuration: 0.25,
            delay: 0,
            options: .curveEaseIn,
            animations: {
                self.dimmingView.alpha = 0
                self.setPanelOffset(offset, animated: false)
            },
            completion: { _ in finish() }
        )
    }

    private func setPanelOffset(_ offset: CGFloat, animated: Bool) {
        panelOffset = offset
        if animated {
            UIView.animate(withDuration: 0.25) {
                self.panelView.transform = CGAffineTransform(translationX: 0, y: offset)
            }
        } else {
            panelView.transform = CGAffineTransform(translationX: 0, y: offset)
        }
    }

    private static func slideAnimator(duration: TimeInterval, animations: @escaping () -> Void) {
        let timing = UICubicTimingParameters(controlPoint1: CGPoint(x: 0.16, y: 1), controlPoint2: CGPoint(x: 0.3, y: 1))
        let animator = UIViewPropertyAnimator(duration: duration, timingParameters: timing)
        animator.addAnimations(animations)
        animator.startAnimation()
    }
}

// MARK: - private methods

extension RoomPopup {

    private func dismissByUser(_ reason: DismissReason) {
        guard !isDismissing else { return }
        let action = onDismiss
        dismiss { action?(reason) }
    }

    @objc private func handleMaskTap() {
        guard closeOnMask else { return }
        dismissByUser(.mask)
    }

    @objc private func handlePan(_ pan: UIPanGestureRecognizer) {
        guard !isDismissing else { return }
        let offset = max(pan.translation(in: self).y, 0)
        switch pan.state {
        case .changed:
            setPanelOffset(offset, animated: false)
            dimmingView.alpha = 1 - min(offset / max(panelView.bounds.height, 1), 1)
        case .ended, .cancelled:
            if offset > 80 || pan.velocity(in: self).y > 800 {
                dismissByUser(.drag)
            } else {
                Self.slideAnimator(duration: 0.32) {
                    self.setPanelOffset(0, animated: false)
                    self.dimmingView.alpha = 1
                }
            }
        default:
            break
        }
    }

}

final class RoomKeyboardGuide: NSObject {

    typealias Token = Int
    typealias Handler = (_ frame: CGRect, _ duration: TimeInterval) -> Void

    static let shared = RoomKeyboardGuide()

    private var handlers: [Token: Handler] = [:]
    private var nextToken: Token = 0

    private override init() {
        super.init()
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleWillChangeFrame(_:)),
            name: UIResponder.keyboardWillChangeFrameNotification,
            object: nil
        )
    }

    @discardableResult
    func onChange(_ handler: @escaping Handler) -> Token {
        let token = nextToken
        nextToken += 1
        handlers[token] = handler
        return token
    }

    func remove(_ token: Token) {
        handlers.removeValue(forKey: token)
    }

    @objc private func handleWillChangeFrame(_ notification: Notification) {
        let frame = notification.userInfo?[UIResponder.keyboardFrameEndUserInfoKey] as? CGRect ?? .zero
        let duration = notification.userInfo?[UIResponder.keyboardAnimationDurationUserInfoKey] as? TimeInterval ?? 0
        handlers.values.forEach { $0(frame, duration) }
    }

    static func shift(frame: CGRect, top: CGFloat, bottom: CGFloat, topLimit: CGFloat) -> CGFloat {
        let overlap = max(bottom - frame.minY, 0)
        let available = max(top - topLimit, 0)
        return min(overlap, available)
    }
}

extension RoomPopup: UIGestureRecognizerDelegate {

    public override func gestureRecognizerShouldBegin(_ gestureRecognizer: UIGestureRecognizer) -> Bool {
        guard let pan = gestureRecognizer as? UIPanGestureRecognizer else {
            return super.gestureRecognizerShouldBegin(gestureRecognizer)
        }
        guard dragDismiss, !isDismissing else { return false }
        let velocity = pan.velocity(in: self)
        return abs(velocity.y) > abs(velocity.x)
    }
}
