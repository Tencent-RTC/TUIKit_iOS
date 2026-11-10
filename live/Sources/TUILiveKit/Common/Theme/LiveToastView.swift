import UIKit

/// A window-centered toast shared by the component and its host app.
/// Calls may originate on any thread. Business code must still reject stale events.
public final class LiveToast {
    private weak var view: LiveToastView?

    private init() {}

    /// Displays one toast per window for two seconds by default.
    /// With multiple foreground scenes, pass the intended scene explicitly.
    /// No visible window (or an ambiguous scene) means the message is discarded.
    @discardableResult
    public static func show(
        _ text: String,
        duration: TimeInterval = 2,
        in scene: UIWindowScene? = nil
    ) -> LiveToast {
        let handle = LiveToast()
        DispatchQueue.main.async {
            guard !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
                  let window = resolveWindow(scene: scene) else { return }
            window.subviews.compactMap { $0 as? LiveToastView }.forEach { $0.dismissImmediately() }
            let toast = LiveToastView(text: text)
            handle.view = toast
            toast.alpha = 0
            toast.isUserInteractionEnabled = false
            // Keep subsequently attached sheets below the non-interactive toast.
            toast.layer.zPosition = 10_000
            window.addSubview(toast)
            toast.translatesAutoresizingMaskIntoConstraints = false
            NSLayoutConstraint.activate([
                toast.centerXAnchor.constraint(equalTo: window.centerXAnchor),
                toast.centerYAnchor.constraint(equalTo: window.centerYAnchor),
                toast.leadingAnchor.constraint(greaterThanOrEqualTo: window.safeAreaLayoutGuide.leadingAnchor, constant: 24),
                toast.trailingAnchor.constraint(lessThanOrEqualTo: window.safeAreaLayoutGuide.trailingAnchor, constant: -24),
            ])
            window.layoutIfNeeded()
            UIView.animate(withDuration: 0.2) { toast.alpha = 1 }
            toast.scheduleDismiss(after: duration.isFinite && duration > 0 ? duration : 2)
        }
        return handle
    }

    /// Cancels only this presentation, never a newer replacement toast.
    public func dismiss() {
        DispatchQueue.main.async {
            self.view?.dismissImmediately()
            self.view = nil
        }
    }

    @MainActor
    private static func resolveWindow(scene: UIWindowScene?) -> UIWindow? {
        let scenes = scene.map { [$0] } ?? UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }
        let activeScenes = scenes.filter { $0.activationState == .foregroundActive }
        guard activeScenes.count == 1, let activeScene = activeScenes.first else { return nil }
        let windows = activeScene.windows.filter { !$0.isHidden && $0.alpha > 0 && $0.windowLevel == .normal }
        if let keyWindow = windows.first(where: { $0.isKeyWindow }) { return keyWindow }
        return windows.count == 1 ? windows.first : nil
    }
}


/// Brand-styled toast capsule shared across live entries.
///
/// The visual follows the Ardot node `910:151` ("Toast / 品牌提示（无前置圆点）")
/// on the Pusher main page: a brand-blue diagonal gradient pill with a faint
/// white border and a blue outer glow. It only renders text and self-dismisses;
/// it holds no AtomicXCore state.
private final class LiveToastView: UIView {
    var dismissTask: DispatchWorkItem?
    private var backgroundObserver: NSObjectProtocol?

    func scheduleDismiss(after duration: TimeInterval) {
        let task = DispatchWorkItem { [weak self] in
            guard let self else { return }
            UIView.animate(withDuration: 0.2, animations: { self.alpha = 0 }) { _ in
                self.dismissImmediately()
            }
        }
        dismissTask = task
        DispatchQueue.main.asyncAfter(deadline: .now() + duration, execute: task)
        backgroundObserver = NotificationCenter.default.addObserver(
            forName: UIScene.willDeactivateNotification, object: window?.windowScene, queue: .main
        ) { [weak self] _ in self?.dismissImmediately() }
    }

    func dismissImmediately() {
        dismissTask?.cancel()
        dismissTask = nil
        layer.removeAllAnimations()
        removeFromSuperview()
    }

    deinit {
        if let backgroundObserver { NotificationCenter.default.removeObserver(backgroundObserver) }
    }

    private enum Metric {
        static let horizontalPadding: CGFloat = 16
        static let verticalPadding: CGFloat = 9
        static let minHeight: CGFloat = 34
        static let lineHeight: CGFloat = 16
    }

    private let gradientLayer = CAGradientLayer()
    private let label = LiveText(.sectionTitle, tone: .primary, alignment: .center)

    init(text: String) {
        super.init(frame: .zero)
        configureContainer()
        label.numberOfLines = 0
        label.lineBreakMode = .byWordWrapping
        label.setContentCompressionResistancePriority(.required, for: .vertical)
        label.setText(text, lineHeight: Metric.lineHeight)
        addSubview(label)
        label.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            label.leadingAnchor.constraint(equalTo: leadingAnchor, constant: Metric.horizontalPadding),
            label.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -Metric.horizontalPadding),
            label.topAnchor.constraint(equalTo: topAnchor, constant: Metric.verticalPadding),
            label.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -Metric.verticalPadding),
            heightAnchor.constraint(greaterThanOrEqualToConstant: Metric.minHeight),
        ])
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func configureContainer() {
        // The view layer carries the outer glow, so it must not clip; the gradient
        // sublayer owns the pill shape and its own clipping.
        layer.masksToBounds = false
        layer.shadowColor = LiveTheme.Color.brandDeepBlue.cgColor
        layer.shadowOpacity = ToastStyle.shadowOpacity
        layer.shadowOffset = CGSize(width: 0, height: 8)
        layer.shadowRadius = ToastStyle.shadowRadius

        gradientLayer.colors = [
            ToastStyle.gradientStart.cgColor,
            ToastStyle.gradientMiddle.cgColor,
            ToastStyle.gradientEnd.cgColor,
        ]
        gradientLayer.locations = [0, 0.5, 1]
        gradientLayer.startPoint = CGPoint(x: 0, y: 0)
        gradientLayer.endPoint = CGPoint(x: 1, y: 1)
        gradientLayer.borderColor = ToastStyle.border.cgColor
        gradientLayer.borderWidth = ToastStyle.borderWidth
        gradientLayer.masksToBounds = true
        layer.insertSublayer(gradientLayer, at: 0)
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        gradientLayer.frame = bounds
        gradientLayer.cornerRadius = min(bounds.height, Metric.minHeight) / 2
    }
}

private enum ToastStyle {
    static let gradientStart: UIColor = UIColor(red: 0.02, green: 0.16, blue: 0.39, alpha: 0.92)
    static let gradientMiddle: UIColor = UIColor(red: 0.10, green: 0.28, blue: 0.49, alpha: 0.90)
    static let gradientEnd: UIColor = UIColor(red: 0.20, green: 0.39, blue: 0.50, alpha: 0.88)
    static let border: UIColor = UIColor.white.withAlphaComponent(0.08)
}

// Styles owned by this component or feature. Values preserve the existing design.
extension ToastStyle {
    static let shadowOpacity: Float = 0.4
    static let shadowRadius: CGFloat = 24
    static let borderWidth: CGFloat = 1
}
