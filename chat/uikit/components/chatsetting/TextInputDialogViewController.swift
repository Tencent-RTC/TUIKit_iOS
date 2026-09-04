import UIKit
import SnapKit

public final class TextInputDialogViewController: UIViewController {
    private static let dimAlpha: CGFloat = 0.4

    private static let panelCornerRadius: CGFloat = CGFloat(RadiusScheme.alertRadius)

    private static let panelHorizontalMargin: CGFloat = CGFloat(SpacingScheme.cardSpacing)

    private static let panelMaxWidth: CGFloat = 360

    private static let contentPadding: CGFloat = CGFloat(SpacingScheme.contentSpacing)

    private static let inputCornerRadius: CGFloat = CGFloat(RadiusScheme.smallRadius)

    private static let inputBorderWidth: CGFloat = 1

    private static let inputHorizontalPadding: CGFloat = CGFloat(SpacingScheme.bubbleSpacing)

    private static let inputVerticalPadding: CGFloat = CGFloat(SpacingScheme.iconIconSpacing)

    private static let singleLineInputHeight: CGFloat = 40

    private static let multiLineMinHeight: CGFloat = 160

    private static let multiLineMaxHeight: CGFloat = 280

    private static let counterTopSpacing: CGFloat = 6

    private static let inputBottomSpacing: CGFloat = CGFloat(SpacingScheme.contentSpacing)

    private static let confirmButtonHeight: CGFloat = 36

    private static let keyboardBottomSpacing: CGFloat = CGFloat(SpacingScheme.iconIconSpacing)

    private static let keyboardDefaultAnimationDuration: Double = 0.25

    private let dialogTitle: String

    private let initialText: String

    private let maxLength: Int

    private let multiline: Bool

    private let onConfirm: (String) -> Void

    private let dimView = UIControl()

    private let panelView = UIView()

    private let titleLabel = UILabel()

    private let textField = UITextField()

    private let textView = UITextView()

    private let counterLabel = UILabel()

    private let confirmButton = UIButton(type: .custom)

    private var keyboardBottomConstraint: Constraint?

    private var showsCounter: Bool {
        return multiline && maxLength > 0
    }

    public init(
        title: String,
        initialText: String = "",
        maxLength: Int = 0,
        multiline: Bool = false,
        onConfirm: @escaping (String) -> Void
    ) {
        self.dialogTitle = title
        self.initialText = initialText
        self.maxLength = maxLength
        self.multiline = multiline
        self.onConfirm = onConfirm
        super.init(nibName: nil, bundle: nil)
        modalPresentationStyle = .overFullScreen
        modalTransitionStyle = .crossDissolve
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    public override func viewDidLoad() {
        super.viewDidLoad()
        constructViewHierarchy()
        activateConstraints()
        bindInteraction()
        setupViewStyle()
        applyInitialContent()
    }

    public override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        if multiline {
            textView.becomeFirstResponder()
        } else {
            textField.becomeFirstResponder()
        }
    }

    private func constructViewHierarchy() {
        view.addSubview(dimView)
        view.addSubview(panelView)
        panelView.addSubview(titleLabel)
        if multiline {
            panelView.addSubview(textView)
        } else {
            panelView.addSubview(textField)
        }
        if showsCounter {
            panelView.addSubview(counterLabel)
        }
        panelView.addSubview(confirmButton)
    }

    private func activateConstraints() {
        dimView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }
        panelView.snp.makeConstraints { make in
            make.center.equalToSuperview().priority(.high)
            make.leading.greaterThanOrEqualToSuperview().offset(Self.panelHorizontalMargin)
            make.trailing.lessThanOrEqualToSuperview().offset(-Self.panelHorizontalMargin)
            make.width.lessThanOrEqualTo(Self.panelMaxWidth)
            make.width.equalTo(UIScreen.main.bounds.width - Self.panelHorizontalMargin * 2).priority(.high)
            if #available(iOS 15.0, *) {
                make.bottom.lessThanOrEqualTo(view.keyboardLayoutGuide.snp.top).offset(-Self.keyboardBottomSpacing)
            } else {
                keyboardBottomConstraint = make.bottom.lessThanOrEqualTo(view.snp.bottom)
                    .offset(-Self.keyboardBottomSpacing).constraint
            }
        }
        titleLabel.snp.makeConstraints { make in
            make.top.leading.trailing.equalToSuperview().inset(Self.contentPadding)
        }
        let inputView = multiline ? textView : textField
        inputView.snp.makeConstraints { make in
            make.top.equalTo(titleLabel.snp.bottom).offset(Self.contentPadding)
            make.leading.trailing.equalToSuperview().inset(Self.contentPadding)
        }
        if multiline {
            textView.snp.makeConstraints { make in
                make.height.greaterThanOrEqualTo(Self.multiLineMinHeight)
                make.height.lessThanOrEqualTo(Self.multiLineMaxHeight)
            }
        } else {
            textField.snp.makeConstraints { make in
                make.height.equalTo(Self.singleLineInputHeight)
            }
        }
        if showsCounter {
            counterLabel.snp.makeConstraints { make in
                make.top.equalTo(inputView.snp.bottom).offset(Self.counterTopSpacing)
                make.leading.trailing.equalToSuperview().inset(Self.contentPadding)
            }
        }
        confirmButton.snp.makeConstraints { make in
            if showsCounter {
                make.top.equalTo(counterLabel.snp.bottom).offset(Self.inputBottomSpacing)
            } else {
                make.top.equalTo(inputView.snp.bottom).offset(Self.inputBottomSpacing)
            }
            make.leading.trailing.bottom.equalToSuperview().inset(Self.contentPadding)
            make.height.equalTo(Self.confirmButtonHeight)
        }
    }

    private func bindInteraction() {
        dimView.addTarget(self, action: #selector(handleDimTap), for: .touchUpInside)
        confirmButton.addTarget(self, action: #selector(handleConfirmTap), for: .touchUpInside)
        textView.delegate = self
        if #unavailable(iOS 15.0) {
            NotificationCenter.default.addObserver(
                self,
                selector: #selector(handleKeyboardFrameChange(_:)),
                name: UIResponder.keyboardWillChangeFrameNotification,
                object: nil
            )
            NotificationCenter.default.addObserver(
                self,
                selector: #selector(handleKeyboardFrameChange(_:)),
                name: UIResponder.keyboardWillHideNotification,
                object: nil
            )
        }
    }

    @objc private func handleKeyboardFrameChange(_ notification: Notification) {
        let isHiding = notification.name == UIResponder.keyboardWillHideNotification
        let keyboardFrame = notification.userInfo?[UIResponder.keyboardFrameEndUserInfoKey] as? NSValue
        let keyboardHeight = isHiding ? 0 : (keyboardFrame?.cgRectValue.height ?? 0)
        keyboardBottomConstraint?.update(offset: -(keyboardHeight + Self.keyboardBottomSpacing))
        let duration = notification.userInfo?[UIResponder.keyboardAnimationDurationUserInfoKey] as? Double
        UIView.animate(withDuration: duration ?? Self.keyboardDefaultAnimationDuration) {
            self.view.layoutIfNeeded()
        }
    }

    private func setupViewStyle() {
        view.backgroundColor = .clear
        dimView.backgroundColor = UIColor.black.withAlphaComponent(Self.dimAlpha)
        panelView.backgroundColor = TUIChatKitTheme.colors.bgColorOperate
        panelView.layer.cornerRadius = Self.panelCornerRadius
        panelView.layer.masksToBounds = true
        titleLabel.font = FontScheme.caption1Bold
        titleLabel.textColor = TUIChatKitTheme.colors.textColorPrimary
        titleLabel.textAlignment = .center
        let inputFont = FontScheme.caption1Regular
        textView.font = inputFont
        textField.font = inputFont
        textView.textColor = TUIChatKitTheme.colors.textColorPrimary
        textField.textColor = TUIChatKitTheme.colors.textColorPrimary
        textView.backgroundColor = TUIChatKitTheme.colors.bgColorDialog
        textField.backgroundColor = TUIChatKitTheme.colors.bgColorDialog
        textView.layer.cornerRadius = Self.inputCornerRadius
        textField.layer.cornerRadius = Self.inputCornerRadius
        textView.layer.borderWidth = Self.inputBorderWidth
        textField.layer.borderWidth = Self.inputBorderWidth
        textView.layer.borderColor = TUIChatKitTheme.colors.strokeColorPrimary.cgColor
        textField.layer.borderColor = TUIChatKitTheme.colors.strokeColorPrimary.cgColor
        if multiline {
            textView.textContainerInset = UIEdgeInsets(
                top: Self.inputVerticalPadding,
                left: Self.inputHorizontalPadding - textView.textContainer.lineFragmentPadding,
                bottom: Self.inputVerticalPadding,
                right: Self.inputHorizontalPadding - textView.textContainer.lineFragmentPadding
            )
            textView.isScrollEnabled = false
        } else {
            let paddingView = UIView(frame: CGRect(
                x: 0,
                y: 0,
                width: Self.inputHorizontalPadding,
                height: Self.singleLineInputHeight
            ))
            textField.leftView = paddingView
            textField.leftViewMode = .always
            let rightPaddingView = UIView(frame: CGRect(
                x: 0,
                y: 0,
                width: Self.inputHorizontalPadding,
                height: Self.singleLineInputHeight
            ))
            textField.rightView = rightPaddingView
            textField.rightViewMode = .always
        }
        counterLabel.font = FontScheme.caption3Regular
        counterLabel.textColor = TUIChatKitTheme.colors.textColorTertiary
        counterLabel.textAlignment = LanguageHelper.isRTL ? .left : .right
        confirmButton.setTitle(LocalizedChatString("Confirm"), for: .normal)
        confirmButton.setTitleColor(TUIChatKitTheme.colors.textColorButton, for: .normal)
        confirmButton.titleLabel?.font = FontScheme.caption1Regular
        confirmButton.backgroundColor = TUIChatKitTheme.colors.buttonColorPrimaryDefault
        confirmButton.layer.cornerRadius = Self.confirmButtonHeight / 2
        confirmButton.layer.masksToBounds = true
    }

    private func applyInitialContent() {
        titleLabel.text = dialogTitle
        if multiline {
            textView.text = initialText
        } else {
            textField.text = initialText
        }
        updateCounter()
    }

    private func currentInputText() -> String {
        return multiline ? (textView.text ?? "") : (textField.text ?? "")
    }

    private func updateCounter() {
        guard showsCounter else { return }
        counterLabel.text = "\(currentInputText().count)/\(maxLength)"
    }

    private func updateTextViewScrollability() {
        guard multiline else { return }
        let fittingHeight = textView.sizeThatFits(CGSize(
            width: textView.bounds.width,
            height: .greatestFiniteMagnitude
        )).height
        let shouldScroll = fittingHeight >= Self.multiLineMaxHeight
        if textView.isScrollEnabled != shouldScroll {
            textView.isScrollEnabled = shouldScroll
        }
    }

    @objc private func handleDimTap() {
        dismiss(animated: true)
    }

    @objc private func handleConfirmTap() {
        let text = currentInputText().trimmingCharacters(in: .whitespacesAndNewlines)
        dismiss(animated: true) {
            self.onConfirm(text)
        }
    }
}

extension TextInputDialogViewController: UITextViewDelegate {

    public func textView(
        _ textView: UITextView,
        shouldChangeTextIn range: NSRange,
        replacementText text: String
    ) -> Bool {
        guard maxLength > 0 else { return true }
        let currentText = textView.text ?? ""
        guard let stringRange = Range(range, in: currentText) else { return false }
        let updatedText = currentText.replacingCharacters(in: stringRange, with: text)
        return updatedText.count <= maxLength
    }

    public func textViewDidChange(_ textView: UITextView) {
        updateCounter()
        updateTextViewScrollability()
    }
}
