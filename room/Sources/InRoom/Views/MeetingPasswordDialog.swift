import UIKit
import SnapKit

final class MeetingPasswordDialog: UIViewController {

    static func present(
        in host: UIView,
        wrongPassword: Bool,
        onSubmit: @escaping (String) -> Void,
        onCancel: @escaping () -> Void
    ) {
        guard let presenter = viewController(from: host) else { return }
        let dialog = MeetingPasswordDialog(wrongPassword: wrongPassword, onSubmit: onSubmit, onCancel: onCancel)
        dialog.modalPresentationStyle = .overFullScreen
        dialog.modalTransitionStyle = .crossDissolve
        presenter.present(dialog, animated: true) { dialog.startEditing() }
    }

    private let wrongPassword: Bool
    private let onSubmit: (String) -> Void
    private let onCancel: () -> Void

    private let cardView = UIView()
    private let contentStack = UIStackView()
    private let titleLabel = UILabel()
    private let fieldRow = UIView()
    private let field = UITextField()
    private let eyeButton = EyeToggleButton()
    private let errorLabel = UILabel()
    private let cancelButton = UIButton(type: .system)
    private let confirmButton = UIButton(type: .system)

    private var cardCenterY: NSLayoutConstraint?
    private var keyboardToken: RoomKeyboardGuide.Token?
    private var isPlainText = false

    init(wrongPassword: Bool, onSubmit: @escaping (String) -> Void, onCancel: @escaping () -> Void) {
        self.wrongPassword = wrongPassword
        self.onSubmit = onSubmit
        self.onCancel = onCancel
        super.init(nibName: nil, bundle: nil)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    deinit {
        if let keyboardToken {
            RoomKeyboardGuide.shared.remove(keyboardToken)
        }
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .roomKitScrim
        setupViews()
        setupStyles()
        setupBindings()
        if wrongPassword { showError(.joinWrongPassword) }
    }

    private func setupViews() {
        view.addSubview(cardView)
        cardView.addSubview(contentStack)

        contentStack.axis = .vertical
        contentStack.addArrangedSubview(titleLabel)
        contentStack.addArrangedSubview(fieldRow)
        contentStack.addArrangedSubview(errorLabel)
        contentStack.addArrangedSubview(makeActions())
        contentStack.setCustomSpacing(20, after: titleLabel)
        contentStack.setCustomSpacing(16, after: fieldRow)
        contentStack.setCustomSpacing(16, after: errorLabel)

        fieldRow.addSubview(field)
        fieldRow.addSubview(eyeButton)

        cardView.snp.makeConstraints {
            $0.centerX.equalToSuperview()
            $0.leading.greaterThanOrEqualToSuperview().offset(20)
            $0.trailing.lessThanOrEqualToSuperview().offset(-20)
            $0.width.lessThanOrEqualTo(420)
        }
        cardCenterY = cardView.centerYAnchor.constraint(equalTo: view.centerYAnchor)
        cardCenterY?.isActive = true

        contentStack.snp.makeConstraints {
            $0.edges.equalToSuperview().inset(36)
        }

        fieldRow.snp.makeConstraints {
            $0.height.equalTo(44)
        }
        field.snp.makeConstraints {
            $0.leading.equalToSuperview().offset(44)
            $0.trailing.equalToSuperview().offset(-44)
            $0.top.bottom.equalToSuperview()
        }
        eyeButton.snp.makeConstraints {
            $0.size.equalTo(32)
            $0.trailing.equalToSuperview().offset(-10)
            $0.centerY.equalToSuperview()
        }
    }

    private func setupStyles() {
        cardView.backgroundColor = UIColor.roomKitBgSurface
        cardView.layer.cornerRadius = 24
        cardView.clipsToBounds = true

        titleLabel.text = .joinPasswordTitle
        titleLabel.font = .systemFont(ofSize: 17, weight: .semibold)
        titleLabel.textColor = UIColor.roomKitFgPrimary
        titleLabel.textAlignment = .center

        fieldRow.layer.cornerRadius = 12
        fieldRow.layer.borderWidth = 1.5
        fieldRow.backgroundColor = UIColor.roomKitBgSurface

        field.isSecureTextEntry = true
        field.keyboardType = .numberPad
        field.textAlignment = .center
        field.textColor = UIColor.roomKitFgPrimary
        field.font = .monospacedDigitSystemFont(ofSize: 15, weight: .regular)
        var textAttributes = field.defaultTextAttributes
        textAttributes[.kern] = 1.8
        field.defaultTextAttributes = textAttributes
        field.attributedPlaceholder = NSAttributedString(
            string: .joinPasswordPlaceholder,
            attributes: [.foregroundColor: UIColor.roomKitFgTertiary]
        )
        field.inputAccessoryView = makeDoneToolbar()

        errorLabel.font = .systemFont(ofSize: 11)
        errorLabel.textColor = UIColor.roomKitDanger
        errorLabel.textAlignment = .center
        errorLabel.numberOfLines = 0
        errorLabel.isHidden = true

        cancelButton.setTitle(.commonCancel, for: .normal)
        confirmButton.setTitle(.joinConfirm, for: .normal)
        [cancelButton, confirmButton].forEach { button in
            button.titleLabel?.font = .systemFont(ofSize: 13, weight: .semibold)
            button.layer.cornerRadius = 12
            button.clipsToBounds = true
            button.snp.makeConstraints { $0.height.equalTo(42) }
        }
        cancelButton.backgroundColor = UIColor.roomKitBgHover
        cancelButton.setTitleColor(UIColor.roomKitFgPrimary, for: .normal)
        confirmButton.backgroundColor = UIColor.roomKitAccent
        confirmButton.setTitleColor(UIColor.roomKitFgOnAccent, for: .normal)

        refreshBorder()
    }

    private func setupBindings() {
        cancelButton.addAction(UIAction { [weak self] _ in
            self?.onCancel()
            self?.dismiss(animated: true)
        }, for: .touchUpInside)

        confirmButton.addAction(UIAction { [weak self] _ in
            guard let self else { return }
            guard !password.isEmpty else {
                self.showError(.joinPasswordPlaceholder)
                return
            }
            guard password.count == 6 else {
                self.showError(.joinPasswordPlaceholder)
                return
            }
            self.dismiss(animated: true) { self.onSubmit(self.password) }
        }, for: .touchUpInside)

        field.addTarget(self, action: #selector(handleEditingChanged), for: .editingChanged)
        field.addTarget(self, action: #selector(handleFocusChanged), for: [.editingDidBegin, .editingDidEnd])
        eyeButton.addTarget(self, action: #selector(handleEyeTap), for: .touchUpInside)

        keyboardToken = RoomKeyboardGuide.shared.onChange { [weak self] frame, duration in
            self?.handleKeyboard(frame: frame, duration: duration)
        }
    }

    func startEditing() {
        field.becomeFirstResponder()
    }

    private var password: String {
        field.text?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
    }

    private func showError(_ message: String) {
        errorLabel.text = message
        errorLabel.isHidden = false
        contentStack.setCustomSpacing(8, after: fieldRow)
        refreshBorder()
    }

    private func clearError() {
        guard !errorLabel.isHidden else { return }
        errorLabel.isHidden = true
        contentStack.setCustomSpacing(16, after: fieldRow)
        refreshBorder()
    }

    private func refreshBorder() {
        fieldRow.layer.borderColor = borderColor.cgColor
    }

    private var borderColor: UIColor {
        if !errorLabel.isHidden { return UIColor.roomKitDanger }
        return field.isFirstResponder ? UIColor.roomKitAccent : UIColor.roomKitBorderStrong
    }

    @objc private func handleEditingChanged() {
        if let text = field.text, text.count > 6 {
            field.text = String(text.prefix(6))
        }
        clearError()
    }

    @objc private func handleFocusChanged() {
        refreshBorder()
    }

    @objc private func handleEyeTap() {
        isPlainText.toggle()
        field.isSecureTextEntry = !isPlainText
        eyeButton.setPlainText(isPlainText)
        clearError()
        let text = field.text
        field.text = nil
        field.text = text
    }

    private func handleKeyboard(frame: CGRect, duration: TimeInterval) {
        guard let cardCenterY, view.window != nil else { return }
        view.layoutIfNeeded()
        let shift = RoomKeyboardGuide.shift(
            frame: frame,
            top: cardView.frame.minY,
            bottom: cardView.frame.maxY,
            topLimit: view.safeAreaInsets.top + 8
        )
        cardCenterY.constant = -shift
        UIView.animate(withDuration: duration) {
            self.view.layoutIfNeeded()
        }
    }

    private func makeActions() -> UIView {
        let actions = UIStackView(arrangedSubviews: [cancelButton, confirmButton])
        actions.axis = .horizontal
        actions.distribution = .fillEqually
        actions.spacing = 10
        return actions
    }

    private func makeDoneToolbar() -> UIToolbar {
        let toolbar = UIToolbar(frame: CGRect(x: 0, y: 0, width: 320, height: 44))
        toolbar.items = [
            UIBarButtonItem(barButtonSystemItem: .flexibleSpace, target: nil, action: nil),
            UIBarButtonItem(barButtonSystemItem: .done, target: field, action: #selector(UIResponder.resignFirstResponder)),
        ]
        toolbar.sizeToFit()
        return toolbar
    }

    private static func viewController(from view: UIView) -> UIViewController? {
        var responder: UIResponder? = view.next
        while let current = responder {
            if let controller = current as? UIViewController { return controller }
            responder = current.next
        }
        return nil
    }
}

private final class EyeToggleButton: UIControl {

    private let iconView = UIImageView()

    override var isHighlighted: Bool {
        didSet { tintColor = isHighlighted ? UIColor.roomKitFgPrimary : UIColor.roomKitFgTertiary }
    }

    override init(frame: CGRect) {
        super.init(frame: frame)
        tintColor = UIColor.roomKitFgTertiary
        layer.cornerRadius = 8
        clipsToBounds = true
        isAccessibilityElement = true
        accessibilityLabel = RoomKitResources.localizedString("roomkit.schedule.show_password")

        iconView.isUserInteractionEnabled = false
        iconView.contentMode = .scaleAspectFit
        addSubview(iconView)
        iconView.snp.makeConstraints { make in
            make.size.equalTo(18)
            make.center.equalToSuperview()
        }
        setPlainText(false)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func setPlainText(_ value: Bool) {
        let name = value ? "roomkit_icon_eye" : "roomkit_icon_eye_off"
        iconView.image = RoomKitResources.image(named: name)?.withRenderingMode(.alwaysTemplate)
    }
}

private extension String {
    static var joinPasswordTitle: String { RoomKitResources.localizedString("roomkit.join.password_title") }
    static var joinPasswordPlaceholder: String { RoomKitResources.localizedString("roomkit.join.password_placeholder") }
    static var joinWrongPassword: String { RoomKitResources.localizedString("roomkit.join.wrong_password") }
    static var joinConfirm: String { RoomKitResources.localizedString("roomkit.join.confirm") }
    static var commonCancel: String { RoomKitResources.localizedString("roomkit.common.cancel") }
}
