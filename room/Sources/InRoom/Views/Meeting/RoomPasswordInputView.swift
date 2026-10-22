import UIKit
import SnapKit

final class RoomPasswordInputView: UIView {

    private let fieldRow = UIView()
    private let field = UITextField()
    private let eyeButton = EyeToggleButton()
    private let errorLabel = UILabel()

    private var isPlainText = false

    var password: String {
        field.text?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
    }

    init(placeholder: String) {
        super.init(frame: .zero)

        fieldRow.layer.cornerRadius = Self.cornerRadius
        fieldRow.layer.borderWidth = Self.borderWidth

        field.placeholder = placeholder
        field.isSecureTextEntry = true
        field.keyboardType = .numberPad
        field.textAlignment = .center
        field.font = .systemFont(ofSize: 15)
        field.addTarget(self, action: #selector(handleEditingChanged), for: .editingChanged)
        field.addTarget(self, action: #selector(handleFocusChanged), for: [.editingDidBegin, .editingDidEnd])

        let toolbar = UIToolbar(frame: CGRect(x: 0, y: 0, width: 320, height: 44))
        toolbar.items = [
            UIBarButtonItem(barButtonSystemItem: .flexibleSpace, target: nil, action: nil),
            UIBarButtonItem(barButtonSystemItem: .done, target: field, action: #selector(UIResponder.resignFirstResponder)),
        ]
        toolbar.sizeToFit()
        field.inputAccessoryView = toolbar

        errorLabel.font = .systemFont(ofSize: 11)
        errorLabel.textColor = UIColor.roomKitDanger
        errorLabel.textAlignment = .center
        errorLabel.numberOfLines = 0
        errorLabel.isHidden = true

        let stack = UIStackView(arrangedSubviews: [fieldRow, errorLabel])
        stack.axis = .vertical
        stack.spacing = 8
        addSubview(stack)
        stack.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }
        fieldRow.snp.makeConstraints { make in
            make.height.equalTo(Self.fieldHeight)
        }

        fieldRow.addSubview(field)
        field.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }
        fieldRow.addSubview(eyeButton)
        eyeButton.snp.makeConstraints { make in
            make.size.equalTo(Self.eyeButtonSize)
            make.trailing.equalToSuperview().offset(-Self.eyeTrailing)
            make.centerY.equalToSuperview()
        }
        eyeButton.addTarget(self, action: #selector(handleEyeTap), for: .touchUpInside)

        refreshBorder()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func showError(_ message: String) {
        errorLabel.text = message
        errorLabel.isHidden = false
        refreshBorder()
    }

    func startEditing() {
        field.becomeFirstResponder()
    }

    private func clearError() {
        guard !errorLabel.isHidden else { return }
        errorLabel.isHidden = true
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
        if let text = field.text, text.count > Self.passwordMaxLength {
            field.text = String(text.prefix(Self.passwordMaxLength))
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
        let text = field.text
        field.text = nil
        field.text = text
    }

    private static let fieldHeight: CGFloat = 44
    private static let cornerRadius: CGFloat = 12
    private static let borderWidth: CGFloat = 1.5
    private static let eyeButtonSize: CGFloat = 32
    private static let eyeTrailing: CGFloat = 10
    private static let passwordMaxLength = 6
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
