import UIKit

enum ToastPosition {
    case center
    case bottom(CGFloat)
}

enum ToastType {
    case loading
    case info
    case success
    case warning
    case error
    case help
    var iconName: String {
        switch self {
        case .loading:
            return "loading-blue"
        case .info:
            return "info-circle-filled"
        case .success:
            return "check-circle-filled"
        case .warning:
            return "error-circle-filled"
        case .error:
            return "error-circle-filled"
        case .help:
            return "help-circle-filled"
        }
    }

    var iconColor: UIColor {
        let colors = TUIChatKitTheme.colors
        switch self {
        case .loading, .info, .help:
            return colors.textColorLink
        case .success:
            return colors.textColorSuccess
        case .warning:
            return colors.textColorWarning
        case .error:
            return colors.textColorError
        }
    }
}

private final class ToastContentView: UIView {
    private static let iconSize: CGFloat = 16

    private static let iconTextSpacing: CGFloat = CGFloat(SpacingScheme.iconTextSpacing)

    private static let horizontalPadding: CGFloat = CGFloat(SpacingScheme.bubbleSpacing)

    private static let verticalPadding: CGFloat = CGFloat(SpacingScheme.smallSpacing)

    private static let cornerRadius: CGFloat = 6

    private static let borderWidth: CGFloat = 1

    private static let shadowRadiusLarge: CGFloat = 8

    private static let shadowOffsetLarge = CGSize(width: 0, height: 6)

    private static let trailingIconCornerRadius: CGFloat = 3

    private static let fullCircleRadians = CGFloat.pi * 2

    private static let loadingRotationDuration: TimeInterval = 1.0

    private let iconImageView = UIImageView()

    private let messageLabel = UILabel()

    private let trailingIconImageView = UIImageView()

    private let onDismiss: () -> Void

    init(type: ToastType?, message: String, customIcon: String?, trailingIcon: UIImage? = nil, onDismiss: @escaping () -> Void) {
        self.onDismiss = onDismiss
        super.init(frame: .zero)
        constructViewHierarchy()
        activateConstraints(showTrailingIcon: trailingIcon != nil)
        setupViewStyle()
        configure(type: type, message: message, customIcon: customIcon, trailingIcon: trailingIcon)
        let tap = UITapGestureRecognizer(target: self, action: #selector(handleTapped))
        addGestureRecognizer(tap)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func constructViewHierarchy() {
        addSubview(iconImageView)
        addSubview(messageLabel)
        addSubview(trailingIconImageView)
    }

    private func activateConstraints(showTrailingIcon: Bool) {
        iconImageView.translatesAutoresizingMaskIntoConstraints = false
        messageLabel.translatesAutoresizingMaskIntoConstraints = false
        trailingIconImageView.translatesAutoresizingMaskIntoConstraints = false
        var constraints = [
            iconImageView.leadingAnchor.constraint(equalTo: leadingAnchor, constant: Self.horizontalPadding),
            iconImageView.centerYAnchor.constraint(equalTo: centerYAnchor),
            iconImageView.widthAnchor.constraint(equalToConstant: Self.iconSize),
            iconImageView.heightAnchor.constraint(equalToConstant: Self.iconSize),
            messageLabel.leadingAnchor.constraint(equalTo: iconImageView.trailingAnchor, constant: Self.iconTextSpacing),
            messageLabel.topAnchor.constraint(equalTo: topAnchor, constant: Self.verticalPadding),
            messageLabel.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -Self.verticalPadding)
        ]
        if showTrailingIcon {
            constraints.append(contentsOf: [
                messageLabel.trailingAnchor.constraint(equalTo: trailingIconImageView.leadingAnchor, constant: -Self.iconTextSpacing),
                trailingIconImageView.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -Self.horizontalPadding),
                trailingIconImageView.centerYAnchor.constraint(equalTo: centerYAnchor),
                trailingIconImageView.widthAnchor.constraint(equalToConstant: Self.iconSize),
                trailingIconImageView.heightAnchor.constraint(equalToConstant: Self.iconSize)
            ])
        } else {
            constraints.append(messageLabel.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -Self.horizontalPadding))
        }
        NSLayoutConstraint.activate(constraints)
    }

    private func setupViewStyle() {
        let colors = TUIChatKitTheme.colors
        backgroundColor = colors.floatingColorDefault
        layer.cornerRadius = Self.cornerRadius
        layer.borderWidth = Self.borderWidth
        layer.borderColor = colors.strokeColorSecondary.cgColor
        layer.shadowColor = colors.shadowColor.cgColor
        layer.shadowOpacity = 1
        layer.shadowRadius = Self.shadowRadiusLarge
        layer.shadowOffset = Self.shadowOffsetLarge
        messageLabel.font = ThemeState.shared.fonts.caption2Medium
        messageLabel.textColor = colors.textColorPrimary
        messageLabel.numberOfLines = 0
    }

    private func configure(type: ToastType?, message: String, customIcon: String?, trailingIcon: UIImage?) {
        messageLabel.text = message
        if let trailingIcon = trailingIcon {
            trailingIconImageView.image = trailingIcon
            trailingIconImageView.contentMode = .scaleAspectFit
            trailingIconImageView.layer.cornerRadius = Self.trailingIconCornerRadius
            trailingIconImageView.clipsToBounds = true
        } else {
            trailingIconImageView.isHidden = true
        }
        guard let type = type else {
            iconImageView.isHidden = true
            messageLabel.textAlignment = .center
            return
        }
        iconImageView.image = AtomicXChatResources.image(named: customIcon ?? type.iconName)?.withRenderingMode(.alwaysTemplate)
        iconImageView.tintColor = type.iconColor
        if type == .loading {
            startLoadingAnimation()
        }
    }

    private func startLoadingAnimation() {
        let rotation = CABasicAnimation(keyPath: "transform.rotation.z")
        rotation.toValue = Self.fullCircleRadians
        rotation.duration = Self.loadingRotationDuration
        rotation.repeatCount = .infinity
        rotation.isRemovedOnCompletion = false
        iconImageView.layer.add(rotation, forKey: "toastLoadingRotation")
    }

    @objc private func handleTapped() {
        onDismiss()
    }
}

private class ToastWindow: UIWindow {
    private static let levelIncrementAboveAlert: CGFloat = 2

    override var canBecomeKey: Bool {
        return false
    }

    override init(windowScene: UIWindowScene) {
        super.init(windowScene: windowScene)
        windowLevel = UIWindow.Level.alert + Self.levelIncrementAboveAlert
        backgroundColor = UIColor.clear
        isHidden = true
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
        let hitView = super.hitTest(point, with: event)
        guard let hitView = hitView,
              hitView != self,
              hitView != self.rootViewController?.view else {
            return nil
        }
        return hitView
    }
}

private class ToastRootViewController: UIViewController {
    override var preferredStatusBarStyle: UIStatusBarStyle {
        return .default
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = UIColor.clear
    }
}

public class WindowToastManager {
    public static let shared = WindowToastManager()

    private static let horizontalMargin: CGFloat = CGFloat(SpacingScheme.normalSpacing)

    private static let windowReleaseDelay: TimeInterval = 0.1

    private var toastWindow: ToastWindow?

    private var contentView: ToastContentView?

    private var hideTimer: Timer?

    func loading(_ message: String) {
        show(message, type: .loading)
    }

    public func info(_ message: String) {
        show(message, type: .info)
    }

    public func success(_ message: String) {
        show(message, type: .success)
    }

    func warning(_ message: String) {
        show(message, type: .warning)
    }

    public func error(_ message: String) {
        show(message, type: .error)
    }

    func show(
        _ message: String,
        type: ToastType? = nil,
        icon: String? = nil,
        duration: TimeInterval = 2.0,
        position: ToastPosition = .center,
        trailingIcon: UIImage? = nil
    ) {
        runOnMain {
            self.presentToast(type: type, message: message, customIcon: icon, trailingIcon: trailingIcon, position: position)
            self.hideTimer?.invalidate()
            self.hideTimer = Timer.scheduledTimer(withTimeInterval: duration, repeats: false) { _ in
                DispatchQueue.main.async {
                    self.hide()
                }
            }
        }
    }

    func hide() {
        runOnMain {
            self.hideTimer?.invalidate()
            self.dismissToast()
        }
    }

    private init() {}

    private func presentToast(type: ToastType?, message: String, customIcon: String?, trailingIcon: UIImage?, position: ToastPosition) {
        guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene else {
            return
        }
        dismissToast()

        let window = ToastWindow(windowScene: windowScene)
        LanguageHelper.applyLayoutDirection(to: window)
        window.rootViewController = ToastRootViewController()
        let content = ToastContentView(type: type, message: message, customIcon: customIcon, trailingIcon: trailingIcon) { [weak self] in
            self?.hide()
        }
        guard let rootView = window.rootViewController?.view else { return }
        rootView.addSubview(content)
        content.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            content.centerXAnchor.constraint(equalTo: rootView.centerXAnchor),
            content.leadingAnchor.constraint(greaterThanOrEqualTo: rootView.leadingAnchor, constant: Self.horizontalMargin),
            content.trailingAnchor.constraint(lessThanOrEqualTo: rootView.trailingAnchor, constant: -Self.horizontalMargin)
        ])
        switch position {
        case .center:
            content.centerYAnchor.constraint(equalTo: rootView.centerYAnchor).isActive = true
        case .bottom(let offset):
            content.bottomAnchor.constraint(equalTo: rootView.bottomAnchor, constant: -offset).isActive = true
        }

        toastWindow = window
        contentView = content
        window.isHidden = false
    }

    private func dismissToast() {
        toastWindow?.isHidden = true
        let windowToRelease = toastWindow
        toastWindow = nil
        contentView = nil
        DispatchQueue.main.asyncAfter(deadline: .now() + Self.windowReleaseDelay) {
            windowToRelease?.rootViewController = nil
        }
    }

    private func runOnMain(_ block: @escaping () -> Void) {
        if Thread.isMainThread {
            block()
        } else {
            DispatchQueue.main.async {
                block()
            }
        }
    }
}
