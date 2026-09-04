import UIKit
import SnapKit

final internal class ContactSearchBarView: UIView {
    var onQueryChange: ((String) -> Void)?

    var onSubmit: (() -> Void)?

    var currentText: String {
        return textField.text ?? ""
    }

    var placeholder: String = LocalizedChatString("Search") {
        didSet { applyPlaceholder() }
    }

    var containerInsets = UIEdgeInsets(
        top: CGFloat(SpacingScheme.bubbleSpacing),
        left: CGFloat(SpacingScheme.bubbleSpacing),
        bottom: CGFloat(SpacingScheme.bubbleSpacing),
        right: CGFloat(SpacingScheme.bubbleSpacing)
    ) {
        didSet {
            inputContainer.snp.remakeConstraints { make in
                make.edges.equalToSuperview().inset(containerInsets)
                make.height.equalTo(Self.inputHeight)
            }
        }
    }

    private static let inputHeight: CGFloat = 36

    private static let inputCornerRadius: CGFloat = 10

    private static let searchIconSize: CGFloat = 15

    private static let searchIconLeading: CGFloat = CGFloat(SpacingScheme.smallSpacing)

    private static let textHorizontalPadding: CGFloat = 36

    private static let clearButtonSize: CGFloat = 16

    private static let clearButtonTrailing: CGFloat = 10

    private static let debounceInterval: TimeInterval = 0.3

    private let inputContainer = UIView()

    private let searchIconView = UIImageView()

    private let textField = UITextField()

    private let clearButton = UIButton(type: .custom)

    private var debounceWorkItem: DispatchWorkItem?

    private static let searchIconAspect: CGFloat = 29.6484 / 27.889

    override init(frame: CGRect) {
        super.init(frame: frame)
        constructViewHierarchy()
        activateConstraints()
        bindInteraction()
        setupViewStyle()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func hideKeyboard() {
        textField.resignFirstResponder()
    }

    private func constructViewHierarchy() {
        addSubview(inputContainer)
        inputContainer.addSubview(searchIconView)
        inputContainer.addSubview(textField)
        inputContainer.addSubview(clearButton)
    }

    private func activateConstraints() {
        inputContainer.snp.makeConstraints { make in
            make.edges.equalToSuperview().inset(containerInsets)
            make.height.equalTo(Self.inputHeight)
        }
        searchIconView.snp.makeConstraints { make in
            make.leading.equalToSuperview().offset(Self.searchIconLeading)
            make.centerY.equalToSuperview()
            make.width.equalTo(Self.searchIconSize)
            make.height.equalTo(Self.searchIconSize * Self.searchIconAspect)
        }
        textField.snp.makeConstraints { make in
            make.edges.equalToSuperview().inset(UIEdgeInsets(
                top: 0,
                left: Self.textHorizontalPadding,
                bottom: 0,
                right: Self.textHorizontalPadding
            ))
        }
        clearButton.snp.makeConstraints { make in
            make.trailing.equalToSuperview().offset(-Self.clearButtonTrailing)
            make.centerY.equalToSuperview()
            make.width.height.equalTo(Self.clearButtonSize)
        }
    }

    private func bindInteraction() {
        textField.delegate = self
        textField.addTarget(self, action: #selector(textDidChange), for: .editingChanged)
        clearButton.addTarget(self, action: #selector(handleClearTapped), for: .touchUpInside)
    }

    private func setupViewStyle() {
        let colors = TUIChatKitTheme.colors
        backgroundColor = colors.bgColorOperate
        inputContainer.backgroundColor = colors.bgColorInput
        inputContainer.layer.cornerRadius = Self.inputCornerRadius

        searchIconView.image = AtomicXChatResources.image(named:"contact_search")
        searchIconView.tintColor = colors.textColorTertiary
        searchIconView.contentMode = .scaleAspectFit

        textField.font = FontScheme.caption2Regular
        textField.textColor = colors.textColorPrimary
        applyPlaceholder()
        textField.clearButtonMode = .never
        textField.returnKeyType = .search

        clearButton.setImage(AtomicXChatResources.image(named:"contact_search_clear"), for: .normal)
        clearButton.tintColor = colors.textColorPrimary
        clearButton.isHidden = true
    }

    @objc private func textDidChange() {
        let text = textField.text ?? ""
        clearButton.isHidden = text.isEmpty
        debounceWorkItem?.cancel()
        let workItem = DispatchWorkItem { [weak self] in
            self?.onQueryChange?(text)
        }
        debounceWorkItem = workItem
        DispatchQueue.main.asyncAfter(deadline: .now() + Self.debounceInterval, execute: workItem)
    }

    @objc private func handleClearTapped() {
        textField.text = ""
        clearButton.isHidden = true
        debounceWorkItem?.cancel()
        onQueryChange?("")
    }

    private func applyPlaceholder() {
        textField.attributedPlaceholder = NSAttributedString(
            string: placeholder,
            attributes: [.foregroundColor: TUIChatKitTheme.colors.textColorTertiary]
        )
    }
}

extension ContactSearchBarView: UITextFieldDelegate {

    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        textField.resignFirstResponder()
        onSubmit?()
        return true
    }
}
