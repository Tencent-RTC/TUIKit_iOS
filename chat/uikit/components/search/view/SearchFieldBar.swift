import UIKit
import SnapKit

final class SearchFieldBar: UIView {
    var onTextChanged: ((String) -> Void)?

    var onCancel: (() -> Void)?

    let textField = UITextField()

    private static let barHorizontalPadding: CGFloat = CGFloat(SpacingScheme.bubbleSpacing)

    private static let barTopPadding: CGFloat = 10

    private static let barBottomPadding: CGFloat = CGFloat(SpacingScheme.bubbleSpacing)

    private static let inputHeight: CGFloat = 40

    private static let inputCornerRadius: CGFloat = CGFloat(RadiusScheme.tipsRadius)

    private static let iconSize: CGFloat = 15

    private static let iconLeading: CGFloat = CGFloat(SpacingScheme.iconIconSpacing)

    private static let textLeadingGap: CGFloat = 3

    private static let clearButtonSize: CGFloat = 16

    private static let clearButtonTrailing: CGFloat = 10

    private static let cancelLeadingGap: CGFloat = CGFloat(SpacingScheme.iconIconSpacing)

    private let inputContainer = UIView()

    private let iconView = UIImageView()

    private let clearButton = UIButton(type: .custom)

    private let cancelButton = UIButton(type: .system)

    init() {
        super.init(frame: .zero)
        constructViewHierarchy()
        activateConstraints()
        bindInteraction()
        setupViewStyle()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    // MARK: - API

    func setText(_ text: String) {
        textField.text = text
        updateClearButtonVisibility()
    }

    @discardableResult

    override func becomeFirstResponder() -> Bool {
        return textField.becomeFirstResponder()
    }

    private func constructViewHierarchy() {
        addSubview(inputContainer)
        inputContainer.addSubview(iconView)
        inputContainer.addSubview(textField)
        inputContainer.addSubview(clearButton)
        addSubview(cancelButton)
    }

    private func activateConstraints() {
        inputContainer.snp.makeConstraints { make in
            make.leading.equalToSuperview().offset(Self.barHorizontalPadding)
            make.top.equalToSuperview().offset(Self.barTopPadding)
            make.bottom.equalToSuperview().offset(-Self.barBottomPadding)
            make.height.equalTo(Self.inputHeight)
        }
        iconView.snp.makeConstraints { make in
            make.leading.equalToSuperview().offset(Self.iconLeading)
            make.centerY.equalToSuperview()
            make.width.height.equalTo(Self.iconSize)
        }
        textField.snp.makeConstraints { make in
            make.leading.equalTo(iconView.snp.trailing).offset(Self.textLeadingGap)
            make.trailing.equalTo(clearButton.snp.leading).offset(-Self.textLeadingGap)
            make.centerY.equalToSuperview()
        }
        clearButton.snp.makeConstraints { make in
            make.trailing.equalToSuperview().offset(-Self.clearButtonTrailing)
            make.centerY.equalToSuperview()
            make.width.height.equalTo(Self.clearButtonSize)
        }
        cancelButton.snp.makeConstraints { make in
            make.leading.equalTo(inputContainer.snp.trailing).offset(Self.cancelLeadingGap)
            make.trailing.equalToSuperview().offset(-Self.barHorizontalPadding)
            make.centerY.equalTo(inputContainer)
        }
        cancelButton.setContentHuggingPriority(.required, for: .horizontal)
        cancelButton.setContentCompressionResistancePriority(.required, for: .horizontal)
    }

    private func bindInteraction() {
        textField.delegate = self
        textField.addTarget(self, action: #selector(textFieldDidChange), for: .editingChanged)
        clearButton.addTarget(self, action: #selector(handleClearTapped), for: .touchUpInside)
        cancelButton.addTarget(self, action: #selector(handleCancel), for: .touchUpInside)
    }

    private func setupViewStyle() {
        let colors = TUIChatKitTheme.colors
        backgroundColor = colors.bgColorOperate
        inputContainer.backgroundColor = colors.bgColorInput
        inputContainer.layer.cornerRadius = Self.inputCornerRadius
        inputContainer.layer.masksToBounds = true

        iconView.image = UIImage(systemName: "magnifyingglass")
        iconView.tintColor = colors.textColorTertiary
        iconView.contentMode = .scaleAspectFit

        textField.font = FontScheme.caption2Regular
        textField.textColor = colors.textColorPrimary
        textField.tintColor = colors.textColorLink
        textField.returnKeyType = .search
        textField.attributedPlaceholder = NSAttributedString(
            string: LocalizedChatString("Search"),
            attributes: [.foregroundColor: colors.textColorTertiary]
        )

        clearButton.setImage(AtomicXChatResources.image(named: "contact_search_clear"), for: .normal)
        clearButton.tintColor = colors.textColorPrimary
        clearButton.isHidden = true

        cancelButton.setTitle(LocalizedChatString("Cancel"), for: .normal)
        cancelButton.setTitleColor(colors.textColorPrimary, for: .normal)
        cancelButton.titleLabel?.font = FontScheme.caption1Regular
    }

    private func updateClearButtonVisibility() {
        clearButton.isHidden = (textField.text ?? "").isEmpty
    }

    @objc private func textFieldDidChange() {
        updateClearButtonVisibility()
        onTextChanged?(textField.text ?? "")
    }

    @objc private func handleClearTapped() {
        textField.text = ""
        updateClearButtonVisibility()
        onTextChanged?("")
    }

    @objc private func handleCancel() {
        onCancel?()
    }
}

// MARK: - UITextFieldDelegate

extension SearchFieldBar: UITextFieldDelegate {

    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        textField.resignFirstResponder()
        return true
    }
}
