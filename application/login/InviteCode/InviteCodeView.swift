//
//  InviteCodeView.swift
//  login
//

import UIKit
import Combine
import Toast_Swift
import SafariServices
import AtomicX

// MARK: - CodeInputTextField

class CodeInputTextField: UITextField {
    
    var onDeleteBackward: (() -> Void)?
    
    override func deleteBackward() {
        onDeleteBackward?()
        super.deleteBackward()
    }
    
    override func closestPosition(to point: CGPoint) -> UITextPosition? {
        if let text = self.text, !text.isEmpty {
            return self.endOfDocument
        }
        return super.closestPosition(to: point)
    }
    
    override func selectionRects(for range: UITextRange) -> [UITextSelectionRect] {
        if let text = self.text, !text.isEmpty {
            let endPosition = self.endOfDocument
            let endRange = self.textRange(from: endPosition, to: endPosition) ?? UITextRange()
            return super.selectionRects(for: endRange)
        }
        return super.selectionRects(for: range)
    }
    
    override func canPerformAction(_ action: Selector, withSender sender: Any?) -> Bool {
        if action == #selector(UIResponderStandardEditActions.copy(_:)) ||
            action == #selector(UIResponderStandardEditActions.paste(_:)) ||
            action == #selector(UIResponderStandardEditActions.cut(_:)) ||
            action == #selector(UIResponderStandardEditActions.select(_:)) ||
            action == #selector(UIResponderStandardEditActions.selectAll(_:)) {
            return false
        }
        return super.canPerformAction(action, withSender: sender)
    }
    
    override func textRange(from fromPosition: UITextPosition, to toPosition: UITextPosition) -> UITextRange? {
        if let text = self.text, !text.isEmpty {
            let endPosition = self.endOfDocument
            return super.textRange(from: endPosition, to: endPosition)
        }
        return super.textRange(from: fromPosition, to: toPosition)
    }
    
    override func becomeFirstResponder() -> Bool {
        let result = super.becomeFirstResponder()
        DispatchQueue.main.async {
            if let text = self.text, !text.isEmpty {
                let endPosition = self.endOfDocument
                self.selectedTextRange = self.textRange(from: endPosition, to: endPosition)
            }
        }
        return result
    }
}

// MARK: - InviteCodeView

class InviteCodeView: UIView {
    
    // MARK: - Dependencies
    
    let store: InviteCodeStore
    private var cancellables = Set<AnyCancellable>()
    private var codeInputFields: [CodeInputTextField] = []
    
    private lazy var alphanumericKeyboard: AlphanumericKeyboardView = {
        let keyboard = AlphanumericKeyboardView()
        keyboard.onKeyTapped = { [weak self] key in
            self?.handleKeyboardInput(key)
        }
        keyboard.onDeleteTapped = { [weak self] in
            self?.handleKeyboardDelete()
        }
        return keyboard
    }()
    
    // MARK: - UI Components
    
    private let backgroundImageView: UIImageView = {
        let imageView = UIImageView()
        imageView.contentMode = .scaleAspectFill
        imageView.clipsToBounds = true
        imageView.image = UIImage.loginImage(named: "login_background")
        imageView.backgroundColor = UIColor("F3F5FA")
        return imageView
    }()
    
    private let backButton: UIButton = {
        let button = UIButton(type: .system)
        button.setImage(UIImage(systemName: "chevron.left"), for: .normal)
        button.tintColor = UIColor("676A70")
        return button
    }()
    
    private let titleLabel: UILabel = {
        let label = UILabel()
        label.font = UIFont.boldSystemFont(ofSize: 22)
        label.textColor = UIColor.black
        label.textAlignment = .left
        return label
    }()
    
    private let descriptionLabel: UILabel = {
        let label = UILabel()
        label.font = ThemeStore.shared.typographyTokens.Regular12
        label.textColor = UIColor.black.withAlphaComponent(0.55)
        label.numberOfLines = 0
        label.textAlignment = .left
        return label
    }()
    
    private let codeInputContainer: UIStackView = {
        let stackView = UIStackView()
        stackView.axis = .horizontal
        stackView.distribution = .equalSpacing
        stackView.alignment = .center
        stackView.spacing = 7.8
        return stackView
    }()
    
    private let resendLabel: UILabel = {
        let label = UILabel()
        label.font = ThemeStore.shared.typographyTokens.Regular12
        label.numberOfLines = 0
        label.textAlignment = .left
        label.isUserInteractionEnabled = true
        return label
    }()
    
    private let getStartedButton: UIButton = {
        let button = UIButton(type: .system)
        button.setTitle(String.InvitationCode.getStarted, for: .normal)
        button.titleLabel?.font = ThemeStore.shared.typographyTokens.Bold14
        button.setTitleColor(.white, for: .normal)
        button.backgroundColor = ThemeStore.shared.colorTokens.buttonColorPrimaryDisabled
        button.layer.cornerRadius = ThemeStore.shared.borderRadius.radius20
        button.isEnabled = false
        return button
    }()
    
    private let agreementContainer: UIView = {
        return UIView()
    }()
    
    private let termsCheckbox: UIButton = {
        let button = UIButton(type: .custom)
        button.setBackgroundImage(UIImage.loginImage(named: "checkbox"), for: .selected)
        button.setBackgroundImage(nil, for: .normal)
        button.layer.cornerRadius = 2.33
        button.layer.borderWidth = 1
        button.isSelected = false
        return button
    }()
    
    private let termsLabel: UILabel = {
        let label = UILabel()
        let text = String.InvitationCode.agreeToTermsText
        let attributedString = NSMutableAttributedString(string: text)
        
        let baseFont = ThemeStore.shared.typographyTokens.Regular12
        let baseColor = UIColor.black.withAlphaComponent(0.55)
        let linkColor = ThemeStore.shared.colorTokens.textColorLink
        
        attributedString.addAttribute(.font, value: baseFont, range: NSRange(location: 0, length: text.count))
        attributedString.addAttribute(.foregroundColor, value: baseColor, range: NSRange(location: 0, length: text.count))
        
        [String.InvitationCode.termsOfService, String.InvitationCode.privacyPolicy].forEach { linkText in
            if let range = text.range(of: linkText) {
                let nsRange = NSRange(range, in: text)
                attributedString.addAttribute(.foregroundColor, value: linkColor, range: nsRange)
            }
        }
        
        label.attributedText = attributedString
        label.numberOfLines = 0
        label.isUserInteractionEnabled = true
        return label
    }()
    
    private let marketingCheckbox: UIButton = {
        let button = UIButton(type: .custom)
        button.setBackgroundImage(UIImage.loginImage(named: "checkbox"), for: .selected)
        button.setBackgroundImage(nil, for: .normal)
        button.layer.cornerRadius = 2.33
        button.layer.borderWidth = 1
        button.isSelected = false
        return button
    }()
    
    private let marketingLabel: UILabel = {
        let label = UILabel()
        label.text = String.InvitationCode.marketingInfo
        label.font = ThemeStore.shared.typographyTokens.Regular12
        label.textColor = UIColor.black.withAlphaComponent(0.55)
        label.numberOfLines = 0
        return label
    }()
    
    private lazy var agreeCheckBubbleView: InvitationBubbleView = {
        let view = InvitationBubbleView()
        view.label.text = LoginLocalize("Demo.TRTC.Portal.Main.AgreeBeforeUse")
        view.label.font = ThemeStore.shared.typographyTokens.Medium14
        view.label.adjustsFontSizeToFitWidth = true
        view.triangleWidth = 10
        view.triangleOffset = 20
        view.layer.shadowColor = UIColor("46628C").cgColor
        view.layer.shadowOpacity = 0.8
        view.layer.shadowOffset = CGSize(width: 0, height: 2)
        view.layer.shadowRadius = 3
        view.isHidden = true
        return view
    }()
    
    // MARK: - Init
    
    init(store: InviteCodeStore) {
        self.store = store
        super.init(frame: .zero)
        backgroundColor = ThemeStore.shared.colorTokens.bgColorOperate
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    // MARK: - Lifecycle
    
    private var isViewReady = false
    override func didMoveToWindow() {
        super.didMoveToWindow()
        guard !isViewReady else { return }
        setupUI()
        setupConstraints()
        setupActions()
        setupCodeInputFields()
        updateCheckboxAppearance(termsCheckbox)
        updateCheckboxAppearance(marketingCheckbox)
        bindStore()
        updateGetStartedButtonState()
        
        DispatchQueue.main.async {
            _ = self.codeInputFields.first?.becomeFirstResponder()
        }
        
        store.sendInvitationCodeIfNeeded()
        
        isViewReady = true
    }
    
    // MARK: - Setup UI
    
    private func setupUI() {
        addSubview(backgroundImageView)
        addSubview(backButton)
        addSubview(titleLabel)
        addSubview(descriptionLabel)
        addSubview(codeInputContainer)
        addSubview(getStartedButton)
        addSubview(resendLabel)
        addSubview(agreementContainer)
        
        agreementContainer.addSubview(termsCheckbox)
        agreementContainer.addSubview(termsLabel)
        agreementContainer.addSubview(marketingCheckbox)
        agreementContainer.addSubview(marketingLabel)
        
        addSubview(agreeCheckBubbleView)
        
        titleLabel.text = store.state.titleText
        descriptionLabel.text = store.state.descriptionText
        marketingCheckbox.isHidden = !store.state.showMarketingCheckbox
        marketingLabel.isHidden = !store.state.showMarketingCheckbox
    }
    
    private func setupConstraints() {
        backgroundImageView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }
        
        backButton.snp.makeConstraints { make in
            make.top.equalTo(safeAreaLayoutGuide).offset(9)
            make.leading.equalToSuperview().offset(24)
            make.width.equalTo(16)
            make.height.equalTo(28)
        }
        
        titleLabel.snp.makeConstraints { make in
            make.top.equalTo(backButton.snp.bottom).offset(23)
            make.leading.trailing.equalToSuperview().inset(24)
        }
        
        descriptionLabel.snp.makeConstraints { make in
            make.top.equalTo(titleLabel.snp.bottom).offset(4)
            make.leading.trailing.equalToSuperview().inset(24)
        }
        
        codeInputContainer.snp.makeConstraints { make in
            make.top.equalTo(descriptionLabel.snp.bottom).offset(32)
            make.leading.trailing.equalToSuperview().inset(24)
            make.height.equalTo(48)
        }
        
        resendLabel.snp.makeConstraints { make in
            make.top.equalTo(codeInputContainer.snp.bottom).offset(8)
            make.leading.trailing.equalToSuperview().inset(24)
        }
        
        getStartedButton.snp.makeConstraints { make in
            make.top.equalTo(resendLabel.snp.bottom).offset(48)
            make.leading.trailing.equalToSuperview().inset(24)
            make.height.equalTo(40)
        }
        
        agreementContainer.snp.makeConstraints { make in
            make.top.equalTo(getStartedButton.snp.bottom).offset(8)
            make.leading.trailing.equalToSuperview().inset(24)
            make.height.equalTo(44)
        }
        
        let checkBoxSize = 14
        termsCheckbox.snp.makeConstraints { make in
            make.centerY.equalTo(termsLabel.snp.centerY)
            make.leading.equalToSuperview()
            make.width.height.equalTo(checkBoxSize)
        }
        
        termsLabel.snp.makeConstraints { make in
            make.top.equalToSuperview()
            make.leading.equalTo(termsCheckbox.snp.trailing).offset(8)
            make.trailing.equalToSuperview()
            make.height.equalTo(18)
        }
        
        marketingCheckbox.snp.makeConstraints { make in
            make.centerY.equalTo(marketingLabel.snp.centerY)
            make.leading.equalToSuperview()
            make.width.height.equalTo(checkBoxSize)
        }
        
        marketingLabel.snp.makeConstraints { make in
            make.top.equalTo(termsLabel.snp.bottom).offset(8)
            make.leading.equalTo(marketingCheckbox.snp.trailing).offset(8)
            make.trailing.equalToSuperview()
            make.height.equalTo(18)
        }
        
        let triangleOffset = agreeCheckBubbleView.triangleOffset ?? 20
        let triangleCenterX = triangleOffset + agreeCheckBubbleView.triangleWidth * 0.5
        let checkBoxCenterOffset = CGFloat(checkBoxSize) * 0.5
        let offsetX = triangleCenterX - checkBoxCenterOffset
        agreeCheckBubbleView.snp.makeConstraints { make in
            make.width.equalTo(217)
            make.height.equalTo(36)
            make.leading.equalTo(termsCheckbox.snp.leading).offset(-offsetX)
            make.bottom.equalTo(termsCheckbox.snp.top).offset(-4)
        }
    }
    
    private func setupActions() {
        backButton.addTarget(self, action: #selector(backButtonTapped), for: .touchUpInside)
        getStartedButton.addTarget(self, action: #selector(getStartedButtonTapped), for: .touchUpInside)
        termsCheckbox.addTarget(self, action: #selector(termsCheckboxTapped), for: .touchUpInside)
        marketingCheckbox.addTarget(self, action: #selector(marketingCheckboxTapped), for: .touchUpInside)
        
        let resendTapGesture = UITapGestureRecognizer(target: self, action: #selector(resendLabelTapped))
        resendLabel.addGestureRecognizer(resendTapGesture)
        
        let termsLabelTapGesture = UITapGestureRecognizer(target: self, action: #selector(termsLabelTapped(_:)))
        termsLabel.addGestureRecognizer(termsLabelTapGesture)
        
        let tapGesture = UITapGestureRecognizer(target: self, action: #selector(dismissKeyboard))
        addGestureRecognizer(tapGesture)
        
        let containerTapGesture = UITapGestureRecognizer(target: self, action: #selector(codeInputContainerTapped))
        codeInputContainer.addGestureRecognizer(containerTapGesture)
    }
    
    private func setupCodeInputFields() {
        codeInputFields = (0..<6).map { i in
            let textField = createCodeInputField(tag: i)
            codeInputContainer.addArrangedSubview(textField)
            return textField
        }
        updateFieldAppearance(at: 0)
    }
    
    private func createCodeInputField(tag: Int) -> CodeInputTextField {
        let textField = CodeInputTextField()
        textField.borderStyle = .none
        textField.textAlignment = .center
        textField.font = ThemeStore.shared.typographyTokens.Regular20
        textField.inputView = alphanumericKeyboard
        textField.autocorrectionType = .no
        textField.layer.cornerRadius = ThemeStore.shared.borderRadius.radius8
        textField.layer.borderWidth = 1
        textField.layer.borderColor = UIColor("E7ECF6").cgColor
        textField.backgroundColor = .clear
        textField.delegate = self
        textField.tag = tag
        textField.addTarget(self, action: #selector(textFieldDidChange(_:)), for: .editingChanged)
        
        textField.snp.makeConstraints { make in
            make.width.height.equalTo(48)
        }
        
        textField.onDeleteBackward = { [weak self] in
            guard let self = self else { return }
            self.handleDeleteBackward(for: textField)
        }
        
        return textField
    }
    
    // MARK: - Store Binding
    
    private func bindStore() {
        store.$state
            .map(\.toastMessage)
            .removeDuplicates()
            .sink { [weak self] message in
                guard !message.isEmpty else { return }
                self?.makeToast(message, position: .center)
            }
            .store(in: &cancellables)
        
        store.$state
            .map(\.isValidating)
            .removeDuplicates()
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in
                self?.updateGetStartedButtonState()
            }
            .store(in: &cancellables)
        
        store.$state
            .map(\.isCodeInvalid)
            .removeDuplicates()
            .receive(on: RunLoop.main)
            .sink { [weak self] isInvalid in
                guard let self = self else { return }
                if isInvalid {
                    self.setErrorState()
                }
            }
            .store(in: &cancellables)
        
        store.$state
            .map(\.showAgreeCheckBubble)
            .removeDuplicates()
            .receive(on: RunLoop.main)
            .sink { [weak self] show in
                self?.agreeCheckBubbleView.isHidden = !show
            }
            .store(in: &cancellables)
        
        store.$state
            .map(\.remainingSeconds)
            .removeDuplicates()
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in
                self?.updateResendLabel()
            }
            .store(in: &cancellables)
        
        store.$state
            .map(\.inviteCode)
            .removeDuplicates()
            .filter { $0.isEmpty }
            .dropFirst()
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in
                guard let self = self else { return }
                self.codeInputFields.forEach { $0.text = "" }
                self.updateGetStartedButtonState()
                self.hideAllToasts()
            }
            .store(in: &cancellables)
    }
    
    // MARK: - Actions
    
    @objc private func backButtonTapped() {
        store.goBack()
    }
    
    @objc private func getStartedButtonTapped() {
        guard getStartedButton.isEnabled else { return }
        let code = getInputInvitationCode()
        store.updateInviteCode(code)
        store.getStarted()
    }
    
    @objc private func termsCheckboxTapped() {
        store.toggleTermsCheckbox()
        termsCheckbox.isSelected = store.state.isTermsAgreed
        updateCheckboxAppearance(termsCheckbox)
        updateGetStartedButtonState()
    }
    
    @objc private func marketingCheckboxTapped() {
        store.toggleMarketingCheckbox()
        marketingCheckbox.isSelected = store.state.isMarketingAgreed
        updateCheckboxAppearance(marketingCheckbox)
    }
    
    @objc private func dismissKeyboard() {
        endEditing(true)
    }
    
    @objc private func codeInputContainerTapped() {
        moveToCorrectField()
    }
    
    @objc private func textFieldDidChange(_ textField: UITextField) {
        updateGetStartedButtonState()
    }
    
    @objc private func resendLabelTapped() {
        store.resendInvitationCode()
    }
    
    @objc private func termsLabelTapped(_ gesture: UITapGestureRecognizer) {
        guard let label = gesture.view as? UILabel,
              let attributedText = label.attributedText else { return }
        
        let text = attributedText.string
        let tapLocation = gesture.location(in: label)
        
        let textContainer = NSTextContainer(size: label.bounds.size)
        textContainer.lineFragmentPadding = 0
        textContainer.maximumNumberOfLines = label.numberOfLines
        textContainer.lineBreakMode = label.lineBreakMode
        
        let layoutManager = NSLayoutManager()
        layoutManager.addTextContainer(textContainer)
        
        let textStorage = NSTextStorage(attributedString: attributedText)
        textStorage.addLayoutManager(layoutManager)
        
        let characterIndex = layoutManager.characterIndex(for: tapLocation, in: textContainer, fractionOfDistanceBetweenInsertionPoints: nil)
        
        if let termsRange = text.range(of: String.InvitationCode.termsOfService) {
            let nsTermsRange = NSRange(termsRange, in: text)
            if NSLocationInRange(characterIndex, nsTermsRange) {
                provideTapFeedback()
                openLink(with: URL(string: "https://trtc.io/app/service"))
                return
            }
        }
        
        if let privacyRange = text.range(of: String.InvitationCode.privacyPolicy) {
            let nsPrivacyRange = NSRange(privacyRange, in: text)
            if NSLocationInRange(characterIndex, nsPrivacyRange) {
                provideTapFeedback()
                openLink(with: URL(string: "https://trtc.io/app/privacy"))
                return
            }
        }
    }
    
    // MARK: - Custom Keyboard Input Handling
    
    private func handleKeyboardInput(_ key: String) {
        if store.state.isCodeInvalid {
            clearErrorState()
        }
        
        guard let currentField = codeInputFields.first(where: { $0.isFirstResponder }) else { return }
        
        if let text = currentField.text, !text.isEmpty { return }
        
        currentField.text = key.uppercased()
        moveToNextField(from: currentField)
        updateGetStartedButtonState()
    }
    
    private func handleKeyboardDelete() {
        if store.state.isCodeInvalid {
            clearErrorState()
        }
        
        guard let currentField = codeInputFields.first(where: { $0.isFirstResponder }) else { return }
        
        if let text = currentField.text, !text.isEmpty {
            currentField.text = ""
            updateFieldAppearance(at: currentField.tag)
            updateGetStartedButtonState()
        } else {
            let previousTag = currentField.tag - 1
            if previousTag >= 0 {
                let previousField = codeInputFields[previousTag]
                previousField.text = ""
                _ = previousField.becomeFirstResponder()
                updateFieldAppearance(at: previousTag)
                updateGetStartedButtonState()
            }
        }
    }
    
    // MARK: - Delete Backward Handling
    
    private func handleDeleteBackward(for textField: UITextField) {
        if textField.text?.isEmpty != false {
            let previousTag = textField.tag - 1
            if previousTag >= 0 {
                let previousField = codeInputFields[previousTag]
                previousField.text = ""
                _ = previousField.becomeFirstResponder()
                updateFieldAppearance(at: previousTag)
                updateGetStartedButtonState()
            }
        } else {
            DispatchQueue.main.async {
                self.updateGetStartedButtonState()
            }
        }
    }
    
    // MARK: - Button State
    
    private func updateGetStartedButtonState() {
        let invitationCode = codeInputFields.compactMap { $0.text }.joined()
        let isCodeComplete = invitationCode.count == 6
        let isValidating = store.state.isValidating
        
        let shouldEnable = isCodeComplete && !isValidating
        
        getStartedButton.isEnabled = shouldEnable
        
        if isValidating {
            getStartedButton.setTitle(String.InvitationCode.validating, for: .normal)
            getStartedButton.backgroundColor = ThemeStore.shared.colorTokens.buttonColorPrimaryDisabled
        } else {
            getStartedButton.setTitle(String.InvitationCode.getStarted, for: .normal)
            if shouldEnable {
                getStartedButton.backgroundColor = ThemeStore.shared.colorTokens.buttonColorPrimaryDefault
            } else {
                getStartedButton.backgroundColor = ThemeStore.shared.colorTokens.buttonColorPrimaryDisabled
            }
        }
    }
    
    // MARK: - Resend Label
    
    private func updateResendLabel() {
        guard !store.state.isCodeInvalid, store.state.emailAddress != nil else {
            resendLabel.attributedText = nil
            return
        }
        
        let isResendEnabled = store.state.isResendEnabled
        let remainingSeconds = store.state.remainingSeconds
        
        let (text, highlightText, highlightColor): (String, String, UIColor) = isResendEnabled
            ? (String.InvitationCode.resendClickable, String.InvitationCode.clickToResend, ThemeStore.shared.colorTokens.textColorLink)
            : (String.InvitationCode.resendCountdown(remainingSeconds), String.InvitationCode.resendAfter(remainingSeconds), UIColor("ADCFFF"))
        
        let attributedString = NSMutableAttributedString(string: text)
        let baseFont = ThemeStore.shared.typographyTokens.Regular12
        let baseColor = UIColor.black.withAlphaComponent(0.55)
        
        attributedString.addAttribute(.font, value: baseFont, range: NSRange(location: 0, length: text.count))
        attributedString.addAttribute(.foregroundColor, value: baseColor, range: NSRange(location: 0, length: text.count))
        
        if let range = text.range(of: highlightText) {
            let nsRange = NSRange(range, in: text)
            attributedString.addAttribute(.foregroundColor, value: highlightColor, range: nsRange)
        }
        
        resendLabel.attributedText = attributedString
    }
    
    // MARK: - Error State
    
    private func setErrorState() {
        updateFieldsErrorState(isError: true)
        updateResendLabelToError()
        let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
        impactFeedback.impactOccurred()
    }
    
    private func clearErrorState() {
        store.clearErrorState()
        updateFieldsErrorState(isError: false)
        updateResendLabel()
        updateGetStartedButtonState()
        moveToCorrectField()
    }
    
    private func updateFieldsErrorState(isError: Bool) {
        let borderColor = isError ? ThemeStore.shared.colorTokens.textColorError : UIColor("E7ECF6")
        let textColor = isError ? ThemeStore.shared.colorTokens.textColorError : UIColor.black
        
        codeInputFields.forEach { field in
            field.textColor = textColor
            if isError || (field.text?.isEmpty != false) {
                field.layer.borderColor = borderColor.cgColor
            } else {
                field.layer.borderColor = ThemeStore.shared.colorTokens.buttonColorPrimaryDefault.cgColor
            }
        }
    }
    
    private func updateResendLabelToError() {
        let text = String.InvitationCode.codeIncorrect
        let attributedString = NSMutableAttributedString(string: text)
        let font = ThemeStore.shared.typographyTokens.Regular12
        
        attributedString.addAttribute(.font, value: font, range: NSRange(location: 0, length: text.count))
        attributedString.addAttribute(.foregroundColor, value: ThemeStore.shared.colorTokens.textColorError, range: NSRange(location: 0, length: text.count))
        
        resendLabel.attributedText = attributedString
    }
    
    // MARK: - Field Appearance
    
    private func updateFieldAppearance(at index: Int) {
        if store.state.isCodeInvalid { clearErrorState() }
        
        codeInputFields.enumerated().forEach { (i, field) in
            field.subviews.filter { $0.backgroundColor == ThemeStore.shared.colorTokens.buttonColorPrimaryDefault }.forEach { $0.removeFromSuperview() }
            field.layer.borderColor = (i == index ? ThemeStore.shared.colorTokens.buttonColorPrimaryDefault : UIColor("E7ECF6")).cgColor
        }
        
        let currentField = codeInputFields[index]
        if currentField.text?.isEmpty == true {
            let lineView = UIView()
            lineView.backgroundColor = ThemeStore.shared.colorTokens.buttonColorPrimaryDefault
            currentField.addSubview(lineView)
            lineView.snp.makeConstraints { make in
                make.center.equalToSuperview()
                make.width.equalTo(1)
                make.height.equalTo(24)
            }
        }
    }
    
    private func updateCheckboxAppearance(_ checkbox: UIButton) {
        if checkbox.isSelected {
            checkbox.layer.borderColor = UIColor("4588F5").cgColor
        } else {
            checkbox.layer.borderColor = UIColor("E7ECF6").cgColor
        }
    }
    
    // MARK: - Navigation Helpers
    
    private func moveToNextField(from currentField: UITextField) {
        let nextTag = currentField.tag + 1
        if nextTag < codeInputFields.count {
            _ = codeInputFields[nextTag].becomeFirstResponder()
            updateFieldAppearance(at: nextTag)
        } else {
            currentField.resignFirstResponder()
        }
    }
    
    private func moveToCorrectField() {
        let targetIndex = codeInputFields.firstIndex { $0.text?.isEmpty != false } ?? (codeInputFields.count - 1)
        focusField(at: targetIndex)
    }
    
    private func focusField(at index: Int) {
        _ = codeInputFields[index].becomeFirstResponder()
        updateFieldAppearance(at: index)
    }
    
    private func getInputInvitationCode() -> String {
        return codeInputFields.compactMap { $0.text }.joined()
    }
    
    // MARK: - Helpers
    
    private func provideTapFeedback() {
        let impactFeedback = UIImpactFeedbackGenerator(style: .light)
        impactFeedback.impactOccurred()
        
        UIView.animate(withDuration: 0.1, animations: {
            self.termsLabel.alpha = 0.6
        }) { _ in
            UIView.animate(withDuration: 0.1) {
                self.termsLabel.alpha = 1.0
            }
        }
    }
    
    private func openLink(with url: URL?) {
        guard let url = url else { return }
        guard let vc = findViewController() else { return }
        let controller = SFSafariViewController(url: url)
        vc.present(controller, animated: true)
    }
    
    private func findViewController() -> UIViewController? {
        var responder: UIResponder? = self
        while let r = responder {
            if let vc = r as? UIViewController {
                return vc
            }
            responder = r.next
        }
        return nil
    }
}

// MARK: - UITextFieldDelegate
extension InviteCodeView: UITextFieldDelegate {
    func textField(_ textField: UITextField, shouldChangeCharactersIn range: NSRange, replacementString string: String) -> Bool {
        if store.state.isCodeInvalid {
            clearErrorState()
        }
        
        if !string.isEmpty {
            let allowedCharacters = CharacterSet.alphanumerics
            let characterSet = CharacterSet(charactersIn: string)
            
            if !allowedCharacters.isSuperset(of: characterSet) {
                return false
            }
            
            let currentText = textField.text ?? ""
            let newLength = currentText.count + string.count - range.length
            
            if newLength > 1 {
                return false
            }
            
            textField.text = string.uppercased()
            moveToNextField(from: textField)
            updateGetStartedButtonState()
            return false
        }
        
        return true
    }
    
    func textFieldDidBeginEditing(_ textField: UITextField) {
        DispatchQueue.main.async {
            if let text = textField.text, !text.isEmpty {
                let endPosition = textField.endOfDocument
                textField.selectedTextRange = textField.textRange(from: endPosition, to: endPosition)
            }
        }
        updateFieldAppearance(at: textField.tag)
    }
    
    func textFieldDidEndEditing(_ textField: UITextField) {
        textField.subviews.filter { $0.backgroundColor == ThemeStore.shared.colorTokens.buttonColorPrimaryDefault }.forEach { $0.removeFromSuperview() }
        
        if textField.text?.isEmpty != false {
            textField.layer.borderColor = UIColor("E7ECF6").cgColor
        }
    }
}
