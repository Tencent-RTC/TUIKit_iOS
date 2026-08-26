import UIKit

private class AlertWindow: UIWindow {
    override init(windowScene: UIWindowScene) {
        super.init(windowScene: windowScene)
        windowLevel = UIWindow.Level.alert + 1
        backgroundColor = UIColor.clear
        isHidden = true
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}

private final class AlertDialogView: UIView {
    var onConfirm: (() -> Void)?

    var onCancel: (() -> Void)?

    var onDismiss: (() -> Void)?

    private static let dialogWidth: CGFloat = 327

    private static let cornerRadius: CGFloat = CGFloat(RadiusScheme.superLargeRadius)

    private static let horizontalPadding: CGFloat = CGFloat(SpacingScheme.normalSpacing)

    private static let titleTopPadding: CGFloat = CGFloat(SpacingScheme.titleSpacing)

    private static let messageTopWithoutTitle: CGFloat = CGFloat(SpacingScheme.titleSpacing)

    private static let messageTopWithTitle: CGFloat = CGFloat(SpacingScheme.iconIconSpacing)

    private static let messageBottomPadding: CGFloat = CGFloat(SpacingScheme.contentSpacing)

    private static let messageMaxHeight: CGFloat = 330

    private static let messageLineSpacing: CGFloat = 6

    private static let buttonSpacingHeight: CGFloat = 20

    private static let buttonRowHeight: CGFloat = 56

    private static let dividerWidth: CGFloat = 1

    private let titleLabel = UILabel()

    private let messageScrollView = UIScrollView()

    private let messageLabel = UILabel()

    private let topDivider = UIView()

    private let buttonStack = UIStackView()

    private var messageScrollViewTopToTitle: NSLayoutConstraint!

    private var messageScrollViewTopToSuper: NSLayoutConstraint!

    private var topDividerTopToMessage: NSLayoutConstraint!

    private var topDividerTopToTitle: NSLayoutConstraint!

    private var topDividerTopToSuper: NSLayoutConstraint!

    init(title: String?, message: String?, cancelText: String?, confirmText: String) {
        super.init(frame: .zero)
        constructViewHierarchy()
        activateConstraints()
        setupViewStyle()
        configure(title: title, message: message, cancelText: cancelText, confirmText: confirmText)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func constructViewHierarchy() {
        addSubview(titleLabel)
        addSubview(messageScrollView)
        messageScrollView.addSubview(messageLabel)
        addSubview(topDivider)
        addSubview(buttonStack)
    }

    private func activateConstraints() {
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        messageScrollView.translatesAutoresizingMaskIntoConstraints = false
        messageLabel.translatesAutoresizingMaskIntoConstraints = false
        topDivider.translatesAutoresizingMaskIntoConstraints = false
        buttonStack.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            widthAnchor.constraint(equalToConstant: Self.dialogWidth),
            titleLabel.topAnchor.constraint(equalTo: topAnchor, constant: Self.titleTopPadding),
            titleLabel.leadingAnchor.constraint(equalTo: leadingAnchor, constant: Self.horizontalPadding),
            titleLabel.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -Self.horizontalPadding),
            messageScrollView.leadingAnchor.constraint(equalTo: leadingAnchor, constant: Self.horizontalPadding),
            messageScrollView.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -Self.horizontalPadding),
            messageScrollView.heightAnchor.constraint(lessThanOrEqualToConstant: Self.messageMaxHeight),
            messageLabel.topAnchor.constraint(equalTo: messageScrollView.topAnchor),
            messageLabel.leadingAnchor.constraint(equalTo: messageScrollView.leadingAnchor),
            messageLabel.trailingAnchor.constraint(equalTo: messageScrollView.trailingAnchor),
            messageLabel.bottomAnchor.constraint(equalTo: messageScrollView.bottomAnchor),
            messageLabel.widthAnchor.constraint(equalTo: messageScrollView.widthAnchor),
            topDivider.leadingAnchor.constraint(equalTo: leadingAnchor),
            topDivider.trailingAnchor.constraint(equalTo: trailingAnchor),
            topDivider.heightAnchor.constraint(equalToConstant: Self.dividerWidth),
            buttonStack.topAnchor.constraint(equalTo: topDivider.bottomAnchor),
            buttonStack.leadingAnchor.constraint(equalTo: leadingAnchor),
            buttonStack.trailingAnchor.constraint(equalTo: trailingAnchor),
            buttonStack.heightAnchor.constraint(equalToConstant: Self.buttonRowHeight),
            buttonStack.bottomAnchor.constraint(equalTo: bottomAnchor)
        ])
        messageScrollViewTopToTitle = messageScrollView.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: Self.messageTopWithTitle)
        messageScrollViewTopToSuper = messageScrollView.topAnchor.constraint(equalTo: topAnchor, constant: Self.messageTopWithoutTitle)
        topDividerTopToMessage = topDivider.topAnchor.constraint(equalTo: messageScrollView.bottomAnchor, constant: Self.messageBottomPadding + Self.buttonSpacingHeight)
        topDividerTopToTitle = topDivider.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: Self.buttonSpacingHeight)
        topDividerTopToSuper = topDivider.topAnchor.constraint(equalTo: topAnchor, constant: Self.titleTopPadding + Self.buttonSpacingHeight)
    }

    private func setupViewStyle() {
        let colors = ChatUIKitTheme.colors
        backgroundColor = colors.bgColorDialog
        layer.cornerRadius = Self.cornerRadius
        layer.masksToBounds = true
        titleLabel.font = ThemeState.shared.fonts.body4Bold
        titleLabel.textColor = colors.textColorPrimary
        titleLabel.textAlignment = .center
        titleLabel.numberOfLines = 0
        messageLabel.font = ThemeState.shared.fonts.caption1Regular
        messageLabel.textColor = colors.textColorSecondary
        messageLabel.numberOfLines = 0
        topDivider.backgroundColor = colors.strokeColorModule
        buttonStack.axis = .horizontal
        buttonStack.distribution = .fillEqually
        buttonStack.spacing = 0
    }

    private func configure(title: String?, message: String?, cancelText: String?, confirmText: String) {
        let hasTitle = !(title ?? "").isEmpty
        let hasMessage = !(message ?? "").isEmpty
        titleLabel.text = title
        titleLabel.isHidden = !hasTitle
        if hasMessage {
            let paragraphStyle = NSMutableParagraphStyle()
            paragraphStyle.lineSpacing = Self.messageLineSpacing
            messageLabel.attributedText = NSAttributedString(
                string: message ?? "",
                attributes: [
                    .font: ThemeState.shared.fonts.caption1Regular,
                    .foregroundColor: ChatUIKitTheme.colors.textColorSecondary,
                    .paragraphStyle: paragraphStyle
                ]
            )
        }
        messageScrollView.isHidden = !hasMessage
        messageScrollViewTopToTitle.isActive = hasTitle
        messageScrollViewTopToSuper.isActive = !hasTitle
        if hasMessage {
            topDividerTopToMessage.isActive = true
        } else if hasTitle {
            topDividerTopToTitle.isActive = true
        } else {
            topDividerTopToSuper.isActive = true
        }

        if let cancelText = cancelText {
            let cancelButton = makeButton(title: cancelText, color: ChatUIKitTheme.colors.textColorPrimary)
            cancelButton.addTarget(self, action: #selector(handleCancel), for: .touchUpInside)
            buttonStack.addArrangedSubview(cancelButton)
            let divider = UIView()
            divider.backgroundColor = ChatUIKitTheme.colors.strokeColorModule
            divider.translatesAutoresizingMaskIntoConstraints = false
            divider.widthAnchor.constraint(equalToConstant: Self.dividerWidth).isActive = true
            buttonStack.addArrangedSubview(divider)
        }
        let confirmButton = makeButton(title: confirmText, color: ChatUIKitTheme.colors.textColorLink)
        confirmButton.addTarget(self, action: #selector(handleConfirm), for: .touchUpInside)
        buttonStack.addArrangedSubview(confirmButton)
    }

    private func makeButton(title: String, color: UIColor) -> UIButton {
        let button = UIButton(type: .custom)
        button.setTitle(title, for: .normal)
        button.setTitleColor(color, for: .normal)
        button.titleLabel?.font = ThemeState.shared.fonts.caption1Medium
        return button
    }

    @objc private func handleConfirm() {
        onDismiss?()
        onConfirm?()
    }

    @objc private func handleCancel() {
        onDismiss?()
        onCancel?()
    }
}

class WindowAlertManager: NSObject {
    public static let shared = WindowAlertManager()

    private static let maskBackgroundAlpha: CGFloat = 0.4

    private static let windowReleaseDelay: TimeInterval = 0.1

    private var alertWindow: AlertWindow?

    private var onConfirm: (() -> Void)?

    private var onCancel: (() -> Void)?

    private var onDismiss: (() -> Void)?

    public func showAlert(
        title: String? = nil,
        message: String? = nil,
        cancelText: String? = nil,
        confirmText: String = LocalizedChatString("Confirm"),
        onConfirm: @escaping () -> Void = {},
        onCancel: (() -> Void)? = nil,
        onDismiss: (() -> Void)? = nil
    ) {
        DispatchQueue.main.async {
            self.onConfirm = onConfirm
            self.onCancel = onCancel
            self.onDismiss = onDismiss
            if cancelText == nil {
                self.presentSystemAlert(title: title, message: message, confirmText: confirmText)
            } else {
                self.presentCustomAlert(title: title, message: message, cancelText: cancelText, confirmText: confirmText)
            }
        }
    }

    public func dismiss() {
        DispatchQueue.main.async {
            self.onDismiss?()
            self.dismissAlert()
            self.clearCallbacks()
        }
    }

    private override init() {}

    private func presentSystemAlert(title: String?, message: String?, confirmText: String) {
        guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let rootViewController = windowScene.windows.first?.rootViewController else {
            return
        }
        var topViewController = rootViewController
        while let presented = topViewController.presentedViewController {
            topViewController = presented
        }
        let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: confirmText, style: .default) { [weak self] _ in
            self?.onConfirm?()
            self?.dismiss()
        })
        topViewController.present(alert, animated: true)
    }

    private func presentCustomAlert(title: String?, message: String?, cancelText: String?, confirmText: String) {
        guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene else {
            return
        }
        dismissAlert()
        let window = AlertWindow(windowScene: windowScene)
        LanguageHelper.applyLayoutDirection(to: window)
        let rootViewController = UIViewController()
        rootViewController.view.backgroundColor = UIColor.black.withAlphaComponent(Self.maskBackgroundAlpha)
        window.rootViewController = rootViewController

        let dialog = AlertDialogView(title: title, message: message, cancelText: cancelText, confirmText: confirmText)
        dialog.onConfirm = { [weak self] in self?.onConfirm?() }
        dialog.onCancel = { [weak self] in self?.onCancel?() }
        dialog.onDismiss = { [weak self] in self?.dismiss() }
        rootViewController.view.addSubview(dialog)
        dialog.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            dialog.centerXAnchor.constraint(equalTo: rootViewController.view.centerXAnchor),
            dialog.centerYAnchor.constraint(equalTo: rootViewController.view.centerYAnchor)
        ])

        let maskTap = UITapGestureRecognizer(target: self, action: #selector(handleMaskTapped))
        maskTap.cancelsTouchesInView = false
        maskTap.delegate = self
        rootViewController.view.addGestureRecognizer(maskTap)

        alertWindow = window
        window.isHidden = false
    }

    @objc private func handleMaskTapped() {
        dismiss()
    }

    private func dismissAlert() {
        alertWindow?.isHidden = true
        let windowToRelease = alertWindow
        alertWindow = nil
        DispatchQueue.main.asyncAfter(deadline: .now() + Self.windowReleaseDelay) {
            windowToRelease?.rootViewController = nil
        }
    }

    private func clearCallbacks() {
        onConfirm = nil
        onCancel = nil
        onDismiss = nil
    }
}

extension WindowAlertManager: UIGestureRecognizerDelegate {
    public func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldReceive touch: UITouch) -> Bool {
        var view = touch.view
        while let current = view {
            if current is AlertDialogView { return false }
            view = current.superview
        }
        return true
    }
}
