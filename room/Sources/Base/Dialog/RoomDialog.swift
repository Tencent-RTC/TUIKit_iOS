import UIKit
import SnapKit

public final class RoomDialog: UIViewController {

    public enum Variant {
        case primary
        case ghost
        case danger
    }

    public struct Config {
        public let title: String?
        public let message: String?
        public let contentView: UIView?
        public let primaryText: String?
        public let primaryVariant: Variant
        public let onPrimary: (() -> Void)?
        public let secondaryText: String?
        public let onSecondary: (() -> Void)?
        public let onCancel: (() -> Void)?
        public let cancelable: Bool
        public let closable: Bool
        public let keepsOpenOnPrimary: Bool
    }

    public final class Builder {
        private weak var presenter: UIViewController?
        private var titleText: String?
        private var messageText: String?
        private var contentView: UIView?
        private var primaryText: String?
        private var primaryVariant: Variant = .primary
        private var onPrimary: (() -> Void)?
        private var secondaryText: String?
        private var onSecondary: (() -> Void)?
        private var onCancel: (() -> Void)?
        private var cancelable = true
        private var closable = true
        private var keepsOpenOnPrimary = false

        public init(in presenter: UIViewController) {
            self.presenter = presenter
        }

        public func title(_ text: String?) -> Builder {
            titleText = text
            return self
        }

        public func message(_ text: String?) -> Builder {
            messageText = text
            return self
        }

        public func contentView(_ view: UIView?) -> Builder {
            contentView = view
            return self
        }

        public func cancelable(_ value: Bool) -> Builder {
            cancelable = value
            return self
        }

        public func closable(_ value: Bool) -> Builder {
            closable = value
            return self
        }

        public func onCancel(_ action: @escaping () -> Void) -> Builder {
            onCancel = action
            return self
        }

        public func primaryAction(
            _ text: String,
            variant: Variant = .primary,
            onTap: @escaping () -> Void = {}
        ) -> Builder {
            primaryText = text
            primaryVariant = variant
            onPrimary = onTap
            return self
        }

        public func secondaryAction(_ text: String, onTap: @escaping () -> Void = {}) -> Builder {
            secondaryText = text
            onSecondary = onTap
            return self
        }

        public func keepsOpenOnPrimary(_ value: Bool) -> Builder {
            keepsOpenOnPrimary = value
            return self
        }

        public func build() -> RoomDialog {
            RoomDialog(
                config: Config(
                    title: titleText,
                    message: messageText,
                    contentView: contentView,
                    primaryText: primaryText,
                    primaryVariant: primaryVariant,
                    onPrimary: onPrimary,
                    secondaryText: secondaryText,
                    onSecondary: onSecondary,
                    onCancel: onCancel,
                    cancelable: cancelable,
                    closable: closable,
                    keepsOpenOnPrimary: keepsOpenOnPrimary
                )
            )
        }

        @discardableResult
        public func show() -> RoomDialog {
            let dialog = build()
            if let presenter {
                presenter.present(dialog, animated: true)
            }
            return dialog
        }
    }

    private let config: Config
    private var cardCenterY: NSLayoutConstraint?
    private var keyboardToken: RoomKeyboardGuide.Token?

    private var isConfirmStyle: Bool {
        !config.closable
    }

    private var textAlignment: NSTextAlignment {
        isConfirmStyle ? .center : .natural
    }

    private init(config: Config) {
        self.config = config
        super.init(nibName: nil, bundle: nil)
        modalPresentationStyle = .overFullScreen
        modalTransitionStyle = .crossDissolve
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override public func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .roomKitScrim

        if config.cancelable {
            let tap = UITapGestureRecognizer(target: self, action: #selector(handleBackgroundTap))
            tap.delegate = self
            view.addGestureRecognizer(tap)
        }

        let card = UIView()
        card.backgroundColor = .roomKitBgSurface
        card.layer.cornerRadius = 12
        card.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(card)

        let contentStack = UIStackView()
        contentStack.axis = .vertical
        contentStack.translatesAutoresizingMaskIntoConstraints = false
        card.addSubview(contentStack)

        let centerY = card.centerYAnchor.constraint(equalTo: view.centerYAnchor)
        cardCenterY = centerY
        NSLayoutConstraint.activate([
            card.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            centerY,
            card.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            card.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),
            contentStack.topAnchor.constraint(equalTo: card.topAnchor, constant: 18),
            contentStack.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: 16),
            contentStack.trailingAnchor.constraint(equalTo: card.trailingAnchor, constant: -16),
            contentStack.bottomAnchor.constraint(equalTo: card.bottomAnchor, constant: -14),
        ])

        if config.title != nil || config.closable {
            contentStack.addArrangedSubview(makeHead())
        }

        if let message = config.message {
            if let previous = contentStack.arrangedSubviews.last {
                contentStack.setCustomSpacing(8, after: previous)
            }
            contentStack.addArrangedSubview(makeMessageLabel(message))
        }

        if let contentView = config.contentView {
            if let previous = contentStack.arrangedSubviews.last {
                contentStack.setCustomSpacing(12, after: previous)
            }
            contentStack.addArrangedSubview(contentView)
        }

        if config.primaryText != nil || config.secondaryText != nil {
            if let previous = contentStack.arrangedSubviews.last {
                contentStack.setCustomSpacing(16, after: previous)
            }
            contentStack.addArrangedSubview(makeActions())
        }
    }

    override public func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        keyboardToken = RoomKeyboardGuide.shared.onChange { [weak self] frame, duration in
            self?.handleKeyboard(frame: frame, duration: duration)
        }
    }

    private func handleKeyboard(frame: CGRect, duration: TimeInterval) {
        guard let card = view.subviews.first, let cardCenterY, view.window != nil else { return }
        let shift = RoomKeyboardGuide.shift(
            frame: frame,
            top: card.frame.minY,
            bottom: card.frame.maxY,
            topLimit: view.safeAreaInsets.top + 8
        )
        cardCenterY.constant = -shift
        UIView.animate(withDuration: duration) {
            self.view.layoutIfNeeded()
        }
    }

    deinit {
        if let keyboardToken {
            RoomKeyboardGuide.shared.remove(keyboardToken)
        }
    }

    @objc private func handleBackgroundTap() {
        cancelDialog()
    }

    private func cancelDialog() {
        config.onCancel?()
        dismiss(animated: true)
    }

    private func makeHead() -> UIView {
        let head = UIStackView()
        head.axis = .horizontal
        head.alignment = .center
        head.spacing = 8

        if let title = config.title {
            let label = UILabel()
            label.text = title
            label.textColor = .roomKitFgPrimary
            label.font = .boldSystemFont(ofSize: 15)
            label.textAlignment = textAlignment
            label.numberOfLines = 0
            label.setContentHuggingPriority(.defaultLow, for: .horizontal)
            head.addArrangedSubview(label)
        } else {
            head.addArrangedSubview(UIView())
        }
        if config.closable {
            let closeButton = DialogCloseButton()
            closeButton.setContentHuggingPriority(.required, for: .horizontal)
            closeButton.addAction(UIAction { [weak self] _ in
                self?.cancelDialog()
            }, for: .touchUpInside)
            head.addArrangedSubview(closeButton)
        }
        return head
    }

    private func makeMessageLabel(_ text: String) -> UILabel {
        let font = UIFont.systemFont(ofSize: 13)
        let paragraph = NSMutableParagraphStyle()
        paragraph.alignment = textAlignment
        paragraph.lineSpacing = max(13 * 1.45 - font.lineHeight, 0)

        let label = UILabel()
        label.numberOfLines = 0
        label.attributedText = NSAttributedString(string: text, attributes: [
            .font: font,
            .foregroundColor: UIColor.roomKitFgSecondary,
            .paragraphStyle: paragraph,
        ])
        return label
    }

    private func makeActions() -> UIStackView {
        let actions = UIStackView()
        actions.axis = .horizontal
        actions.distribution = .fillEqually
        actions.spacing = 8

        if let secondaryText = config.secondaryText {
            actions.addArrangedSubview(makeButton(text: secondaryText, variant: .ghost) { [weak self] in
                self?.config.onSecondary?()
                self?.dismiss(animated: true)
            })
        }
        if let primaryText = config.primaryText {
            actions.addArrangedSubview(makeButton(text: primaryText, variant: config.primaryVariant) { [weak self] in
                self?.config.onPrimary?()
                if self?.config.keepsOpenOnPrimary != true {
                    self?.dismiss(animated: true)
                }
            })
        }
        return actions
    }

    private func makeButton(text: String, variant: Variant, onTap: @escaping () -> Void) -> UIButton {
        let button = UIButton(type: .system)
        button.setTitle(text, for: .normal)
        button.titleLabel?.font = .boldSystemFont(ofSize: 14)
        button.contentEdgeInsets = UIEdgeInsets(top: 0, left: 16, bottom: 0, right: 16)
        button.layer.cornerRadius = 8
        button.clipsToBounds = true
        button.heightAnchor.constraint(equalToConstant: 40).isActive = true

        let normalBackground: UIColor
        let normalTitle: UIColor
        let pressedBackground: UIColor
        switch variant {
        case .ghost:
            normalBackground = .roomKitBgHover
            normalTitle = .roomKitFgPrimary
            pressedBackground = .roomKitBgPress
        case .primary:
            normalBackground = .roomKitAccent
            normalTitle = .roomKitFgOnAccent
            pressedBackground = .roomKitAccentSoft
        case .danger:
            normalBackground = .roomKitDanger
            normalTitle = .roomKitFgOnDanger
            pressedBackground = .roomKitDangerPressed
        }
        button.setBackgroundImage(.solid(normalBackground), for: .normal)
        button.setBackgroundImage(.solid(pressedBackground), for: .highlighted)
        button.setTitleColor(normalTitle, for: .normal)
        button.addAction(UIAction { _ in onTap() }, for: .touchUpInside)
        return button
    }
}

extension RoomDialog: UIGestureRecognizerDelegate {

    public func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldReceive touch: UITouch) -> Bool {
        guard let card = view.subviews.first else { return true }
        return !card.bounds.contains(touch.location(in: card))
    }
}

private final class DialogCloseButton: UIControl {

    override init(frame: CGRect) {
        super.init(frame: frame)
        translatesAutoresizingMaskIntoConstraints = false
        layer.cornerRadius = 8
        clipsToBounds = true

        let iconView = UIImageView(image: RoomKitResources.image(named: "roomkit_icon_close"))
        iconView.isUserInteractionEnabled = false
        iconView.translatesAutoresizingMaskIntoConstraints = false
        addSubview(iconView)
        NSLayoutConstraint.activate([
            widthAnchor.constraint(equalToConstant: 28),
            heightAnchor.constraint(equalToConstant: 28),
            iconView.centerXAnchor.constraint(equalTo: centerXAnchor),
            iconView.centerYAnchor.constraint(equalTo: centerYAnchor),
            iconView.widthAnchor.constraint(equalToConstant: 14),
            iconView.heightAnchor.constraint(equalToConstant: 14),
        ])
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override var isHighlighted: Bool {
        didSet {
            backgroundColor = isHighlighted ? .roomKitBgHover : .clear
        }
    }
}
