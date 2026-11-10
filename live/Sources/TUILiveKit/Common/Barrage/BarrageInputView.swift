import SnapKit
import UIKit

final class BarrageInputView: UIControl {
    var onSend: ((String) -> Void)?
    var onPresentationChanged: ((Bool) -> Void)?
    var inputBarLayoutView: UIView { inputBar }

    private enum Constants {
        static let horizontalInset: CGFloat = 12
        static let inputHeight: CGFloat = 36
        static let keyboardGap: CGFloat = 4
        static let cancelCenterX: CGFloat = 19
        static let textLeading: CGFloat = 36
        static let sendSize = CGSize(width: 60, height: 28)
        static let sendTrailingInset: CGFloat = 6
        static let characterLimit: Int = 200
    }

    private let inputBar = UIView()
    private let cancelButton = CommentCancelButton(type: .custom)
    private let textInput = LiveTextInputView(limit: Constants.characterLimit, maximumLines: 4, minimumHeight: 20)
    private let sendButton = UIButton(type: .custom)
    private let sendGradient = CAGradientLayer()
    private var inputBottomConstraint: Constraint?

    override init(frame: CGRect) {
        super.init(frame: frame)
        configureUI()
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(keyboardChanged),
            name: UIResponder.keyboardWillChangeFrameNotification,
            object: nil
        )
        isHidden = true
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        sendGradient.frame = sendButton.bounds
        sendGradient.cornerRadius = sendButton.layer.cornerRadius
    }

    override var keyCommands: [UIKeyCommand]? {
        [UIKeyCommand(input: UIKeyCommand.inputEscape, modifierFlags: [], action: #selector(dismiss))]
    }

    func show() {
        guard isHidden else {
            textInput.becomeFirstResponder()
            return
        }
        inputBottomConstraint?.update(offset: -Constants.keyboardGap)
        isHidden = false
        onPresentationChanged?(true)
        textInput.becomeFirstResponder()
    }

    func reset() {
        textInput.setContent("")
        updateTextState()
        dismiss()
    }

    private func configureUI() {
        backgroundColor = .clear
        addTarget(self, action: #selector(dismiss), for: .touchUpInside)

        inputBar.backgroundColor = CommentComposerStyle.inputBackground
        inputBar.layer.cornerRadius = Constants.inputHeight / 2
        inputBar.layer.borderWidth = 1
        inputBar.layer.borderColor = CommentComposerStyle.inputBorder.cgColor
        inputBar.layer.shadowColor = UIColor.black.cgColor
        inputBar.layer.shadowOpacity = 0.3
        inputBar.layer.shadowOffset = CGSize(width: 0, height: 9)
        inputBar.layer.shadowRadius = 14
        addSubview(inputBar)

        cancelButton.setTitle("×", for: .normal)
        cancelButton.setTitleColor(CommentComposerStyle.cancelForeground, for: .normal)
        cancelButton.titleLabel?.font = CommentComposerStyle.cancelFont
        cancelButton.accessibilityLabel = LiveKitResources.localizedString("tuilivekit.comment.cancel")
        cancelButton.addTarget(self, action: #selector(dismiss), for: .touchUpInside)

        let placeholder = LiveKitResources.localizedString("tuilivekit.comment.friendly_placeholder")
        textInput.textColor = .white
        textInput.tintColor = .white
        textInput.font = CommentComposerStyle.inputFont
        textInput.placeholder = placeholder
        textInput.returnKeyType = .send
        textInput.enablesReturnKeyAutomatically = true
        textInput.onSubmit = { [weak self] in self?.send() }
        textInput.onTextChanged = { [weak self] in self?.updateTextState() }
        textInput.onLimitExceeded = { [weak self] in
            guard self?.window != nil else { return }
            LiveToast.show(
                LiveKitResources.localizedFormat("tuilivekit.comment.character_limit", Constants.characterLimit)
            )
        }

        sendGradient.colors = [
            LiveTheme.Color.brandBlue.cgColor,
            CommentComposerStyle.sendGradientEnd.cgColor,
        ]
        sendGradient.startPoint = CGPoint(x: 0, y: 1)
        sendGradient.endPoint = CGPoint(x: 1, y: 0)
        sendButton.layer.insertSublayer(sendGradient, at: 0)
        sendButton.layer.cornerRadius = Constants.sendSize.height / 2
        sendButton.clipsToBounds = true
        sendButton.setTitle(LiveKitResources.localizedString("tuilivekit.common.send"), for: .normal)
        sendButton.setTitleColor(.white, for: .normal)
        sendButton.titleLabel?.font = CommentComposerStyle.sendFont
        sendButton.addTarget(self, action: #selector(send), for: .touchUpInside)

        [cancelButton, textInput, sendButton].forEach(inputBar.addSubview)

        inputBar.snp.makeConstraints { make in
            make.leading.trailing.equalToSuperview().inset(Constants.horizontalInset)
            inputBottomConstraint = make.bottom.equalTo(safeAreaLayoutGuide.snp.bottom)
                .offset(-Constants.keyboardGap).constraint
            make.height.greaterThanOrEqualTo(Constants.inputHeight)
        }
        cancelButton.snp.makeConstraints { make in
            make.centerX.equalTo(inputBar.snp.leading).offset(Constants.cancelCenterX)
            make.centerY.equalToSuperview()
            make.width.equalTo(22)
            make.height.equalTo(24)
        }
        textInput.snp.makeConstraints { make in
            make.leading.equalToSuperview().offset(Constants.textLeading)
            make.top.bottom.equalToSuperview().inset(8)
            make.trailing.equalTo(sendButton.snp.leading).offset(-8)
        }
        sendButton.snp.makeConstraints { make in
            make.trailing.equalToSuperview().inset(Constants.sendTrailingInset)
            make.centerY.equalToSuperview()
            make.size.equalTo(Constants.sendSize)
        }
        updateTextState()
    }

    private func updateTextState() {
        let hasText = !(textInput.text?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ?? true)
        sendButton.isEnabled = hasText
        sendButton.alpha = hasText ? 1 : 0.45
    }

    @objc private func send() {
        guard textInput.markedTextRange == nil else { return }
        let text = textInput.text?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        guard !text.isEmpty else {
            textInput.becomeFirstResponder()
            return
        }
        onSend?(text)
        textInput.setContent("")
        updateTextState()
        dismiss()
    }

    @objc func dismiss() {
        guard !isHidden else { return }
        textInput.resignFirstResponder()
        isHidden = true
        onPresentationChanged?(false)
    }

    @objc private func keyboardChanged(_ notification: Notification) {
        guard !isHidden,
              let frame = notification.userInfo?[UIResponder.keyboardFrameEndUserInfoKey] as? CGRect,
              let window = window
        else { return }

        let localFrame = convert(frame, from: window.screen.coordinateSpace)
        let overlap = max(0, safeAreaLayoutGuide.layoutFrame.maxY - localFrame.minY)
        inputBottomConstraint?.update(offset: -overlap - Constants.keyboardGap)

        let duration = notification.userInfo?[UIResponder.keyboardAnimationDurationUserInfoKey] as? Double ?? 0.25
        let curveRaw = notification.userInfo?[UIResponder.keyboardAnimationCurveUserInfoKey] as? UInt ?? 7
        let options: UIView.AnimationOptions = [
            UIView.AnimationOptions(rawValue: curveRaw << 16),
            .beginFromCurrentState,
            .allowUserInteraction,
        ]
        UIView.animate(withDuration: duration, delay: 0, options: options) {
            self.superview?.layoutIfNeeded()
        }
    }
}

private final class CommentCancelButton: UIButton {
    override func point(inside point: CGPoint, with event: UIEvent?) -> Bool {
        bounds.insetBy(dx: -11, dy: -6).contains(point)
    }
}

// Styles owned by this component or feature. Values preserve the existing design.
private enum CommentComposerStyle {
    static let inputBackground: UIColor = UIColor(red: 0.047, green: 0.051, blue: 0.071, alpha: 0.878)
    static let inputBorder: UIColor = UIColor.white.withAlphaComponent(0.08)
    static let cancelForeground: UIColor = UIColor.white.withAlphaComponent(0.58)
    static let sendGradientEnd: UIColor = UIColor(red: 0.35, green: 0.42, blue: 1, alpha: 1)
    static let cancelFont: UIFont = UIFont.systemFont(ofSize: 18, weight: .regular)
    static let inputFont: UIFont = UIFont.systemFont(ofSize: 14, weight: .semibold)
    static let sendFont: UIFont = UIFont.systemFont(ofSize: 12, weight: .semibold)
}
