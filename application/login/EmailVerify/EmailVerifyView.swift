//
//  EmailVerifyView.swift
//  login
//

import UIKit
import AtomicX
import Combine
import Toast_Swift

class EmailVerifyView: UIView {
    
    // MARK: - Dependencies
    
    let store: EmailVerifyStore
    private var cancellables = Set<AnyCancellable>()
    weak var navigationController: UINavigationController?
    
    // MARK: - UI Components
    
    private let backgroundImageView: UIImageView = {
        let imageView = UIImageView()
        imageView.contentMode = .scaleAspectFill
        imageView.clipsToBounds = true
        imageView.image = UIImage.loginImage(named: "login_background")
        imageView.backgroundColor = ThemeStore.shared.colorTokens.bgColorDefault
        return imageView
    }()
    
    private let logoImageView: UIImageView = {
        let imageView = UIImageView()
        imageView.contentMode = .scaleAspectFit
        imageView.image = UIImage.loginImage(named: "rtc_logo")
        return imageView
    }()
    
    private let titleLabel: UILabel = {
        let label = UILabel()
        label.text = String.EmailLogin.welcomeTitle
        label.font = UIFont.boldSystemFont(ofSize: 22)
        label.textColor = ThemeStore.shared.colorTokens.textColorPrimary
        label.textAlignment = .left
        return label
    }()
    
    private let subtitleLabel: UILabel = {
        let label = UILabel()
        label.text = String.EmailLogin.subtitle
        label.font = ThemeStore.shared.typographyTokens.Regular12
        label.textColor = ThemeStore.shared.colorTokens.textColorSecondary
        label.textAlignment = .left
        label.numberOfLines = 0
        label.lineBreakMode = .byWordWrapping
        return label
    }()
    
    private let emailInputContainer: UIView = {
        let view = UIView()
        view.backgroundColor = .clear
        return view
    }()
    
    private let emailTextField: UITextField = {
        let textField = UITextField()
        textField.placeholder = String.EmailLogin.emailPlaceholder
        textField.font = ThemeStore.shared.typographyTokens.Regular16
        textField.textColor = ThemeStore.shared.colorTokens.textColorPrimary
        textField.borderStyle = .none
        textField.keyboardType = .emailAddress
        textField.autocapitalizationType = .none
        textField.autocorrectionType = .no
        textField.attributedPlaceholder = NSAttributedString(
            string: String.EmailLogin.emailPlaceholder,
            attributes: [NSAttributedString.Key.foregroundColor: ThemeStore.shared.colorTokens.textColorDisable]
        )
        return textField
    }()
    
    private let inputBottomBorder: UIView = {
        let view = UIView()
        view.backgroundColor = ThemeStore.shared.colorTokens.strokeColorSecondary
        return view
    }()
    
    private let continueButton: UIButton = {
        let button = UIButton(type: .system)
        button.setTitle(String.EmailLogin.continueButton, for: .normal)
        button.titleLabel?.font = ThemeStore.shared.typographyTokens.Bold14
        button.setTitleColor(.white, for: .normal)
        button.setTitleColor(.white, for: .disabled)
        button.isEnabled = false
        button.backgroundColor = ThemeStore.shared.colorTokens.buttonColorPrimaryDisabled
        return button
    }()
    
    private let bottomTextLabel: UILabel = {
        let label = UILabel()
        label.numberOfLines = 0
        label.textAlignment = .left
        return label
    }()
    
    lazy var fullScreenLoadingView: FullScreenLoadingView = {
        let view = FullScreenLoadingView()
        return view
    }()
    
    // MARK: - Init
    
    init(store: EmailVerifyStore) {
        self.store = store
        super.init(frame: .zero)
        backgroundColor = ThemeStore.shared.colorTokens.bgColorOperate
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    // MARK: - Lifecycle
    
    override func layoutSubviews() {
        super.layoutSubviews()
        continueButton.layer.cornerRadius = continueButton.frame.height / 2
        bringSubviewToFront(fullScreenLoadingView)
    }
    
    private var isViewReady = false
    override func didMoveToWindow() {
        super.didMoveToWindow()
        guard !isViewReady else { return }
        setupUI()
        setupConstraints()
        setupBottomText()
        setupActions()
        bindStore()
        fullScreenLoadingView.hide()
        isViewReady = true
    }
    
    // MARK: - Setup UI
    
    private func setupUI() {
        addSubview(backgroundImageView)
        addSubview(logoImageView)
        addSubview(titleLabel)
        addSubview(subtitleLabel)
        addSubview(emailInputContainer)
        emailInputContainer.addSubview(emailTextField)
        emailInputContainer.addSubview(inputBottomBorder)
        addSubview(continueButton)
        addSubview(bottomTextLabel)
        addSubview(fullScreenLoadingView)
    }
    
    private func setupConstraints() {
        backgroundImageView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }
        
        logoImageView.snp.makeConstraints { make in
            make.top.equalTo(safeAreaLayoutGuide).offset(41)
            make.leading.equalToSuperview().offset(24)
            make.size.equalTo(40)
        }
        
        titleLabel.snp.makeConstraints { make in
            make.top.equalTo(logoImageView.snp.bottom).offset(15)
            make.leading.trailing.equalToSuperview().inset(24)
        }
        
        subtitleLabel.snp.makeConstraints { make in
            make.top.equalTo(titleLabel.snp.bottom).offset(4)
            make.leading.trailing.equalToSuperview().inset(24)
        }
        
        emailInputContainer.snp.makeConstraints { make in
            make.top.equalTo(subtitleLabel.snp.bottom).offset(16)
            make.leading.trailing.equalToSuperview().inset(24)
            make.height.equalTo(48)
        }
        
        emailTextField.snp.makeConstraints { make in
            make.top.leading.trailing.equalToSuperview()
            make.height.equalTo(46)
        }
        
        inputBottomBorder.snp.makeConstraints { make in
            make.leading.trailing.bottom.equalToSuperview()
            make.height.equalTo(1)
        }
        
        continueButton.snp.makeConstraints { make in
            make.top.equalTo(emailInputContainer.snp.bottom).offset(96)
            make.leading.trailing.equalToSuperview().inset(24)
            make.height.equalTo(40)
        }
        
        bottomTextLabel.snp.makeConstraints { make in
            make.top.equalTo(continueButton.snp.bottom).offset(8)
            make.leading.trailing.equalToSuperview().inset(24)
        }
        
        fullScreenLoadingView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }
    }
    
    private func setupBottomText() {
        let fullText = String.EmailLogin.bottomText
        let attributedString = NSMutableAttributedString(string: fullText)
        
        let firstPartRange = NSRange(location: 0, length: String.EmailLogin.bottomTextPrefix.count)
        attributedString.addAttributes([
            .font: ThemeStore.shared.typographyTokens.Regular12,
            .foregroundColor: ThemeStore.shared.colorTokens.textColorSecondary,
        ], range: firstPartRange)
        
        let enterCodeRange = NSRange(location: String.EmailLogin.bottomTextPrefix.count, length: String.EmailLogin.enterCodeLink.count)
        attributedString.addAttributes([
            .font: ThemeStore.shared.typographyTokens.Regular12,
            .foregroundColor: ThemeStore.shared.colorTokens.buttonColorPrimaryDefault,
        ], range: enterCodeRange)
        
        bottomTextLabel.attributedText = attributedString
        
        let tapGesture = UITapGestureRecognizer(target: self, action: #selector(bottomTextTapped(_:)))
        bottomTextLabel.addGestureRecognizer(tapGesture)
        bottomTextLabel.isUserInteractionEnabled = true
    }
    
    private func setupActions() {
        continueButton.addTarget(self, action: #selector(continueButtonTapped), for: .touchUpInside)
        continueButton.addTarget(self, action: #selector(buttonTouchDown), for: .touchDown)
        continueButton.addTarget(self, action: #selector(buttonTouchUp), for: [.touchUpInside, .touchUpOutside, .touchCancel])
        
        emailTextField.delegate = self
        emailTextField.addTarget(self, action: #selector(emailTextChanged), for: .editingChanged)
        
        let tapGesture = UITapGestureRecognizer(target: self, action: #selector(dismissKeyboard))
        addGestureRecognizer(tapGesture)
    }
    
    private func bindStore() {
        store.$state
            .map(\.toastMessage)
            .removeDuplicates()
            .sink { [weak self] message in
                guard !message.isEmpty else { return }
                self?.makeToast(message)
            }
            .store(in: &cancellables)
        
        store.$state
            .map(\.email)
            .removeDuplicates()
            .filter { $0.isEmpty }
            .dropFirst()
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in
                guard let self = self else { return }
                self.emailTextField.text = ""
                self.updateContinueButtonState()
                self.hideAllToasts()
            }
            .store(in: &cancellables)
    }
    
    // MARK: - Actions
    
    @objc private func continueButtonTapped() {
        endEditing(true)
        store.continueWithEmail()
    }
    
    @objc private func bottomTextTapped(_ gesture: UITapGestureRecognizer) {
        let text = bottomTextLabel.text ?? ""
        let enterCodeRange = (text as NSString).range(of: String.EmailLogin.enterCodeLink)
        
        if enterCodeRange.location != NSNotFound {
            let tapLocation = gesture.location(in: bottomTextLabel)
            let textContainer = NSTextContainer(size: bottomTextLabel.bounds.size)
            let layoutManager = NSLayoutManager()
            let textStorage = NSTextStorage(attributedString: bottomTextLabel.attributedText ?? NSAttributedString())
            
            layoutManager.addTextContainer(textContainer)
            textStorage.addLayoutManager(layoutManager)
            
            textContainer.lineFragmentPadding = 0
            textContainer.maximumNumberOfLines = bottomTextLabel.numberOfLines
            textContainer.lineBreakMode = bottomTextLabel.lineBreakMode
            
            let characterIndex = layoutManager.characterIndex(for: tapLocation, in: textContainer, fractionOfDistanceBetweenInsertionPoints: nil)
            
            if NSLocationInRange(characterIndex, enterCodeRange) {
                store.navigateToInviteCodeDirectly()
            }
        }
    }
    
    @objc private func buttonTouchDown() {
        UIView.animate(withDuration: 0.1) {
            self.continueButton.transform = CGAffineTransform(scaleX: 0.95, y: 0.95)
            self.continueButton.alpha = 0.8
        }
    }
    
    @objc private func buttonTouchUp() {
        UIView.animate(withDuration: 0.1) {
            self.continueButton.transform = CGAffineTransform.identity
            self.continueButton.alpha = 1.0
        }
    }
    
    @objc private func dismissKeyboard() {
        endEditing(true)
    }
    
    @objc private func emailTextChanged() {
        store.updateEmail(emailTextField.text ?? "")
        updateContinueButtonState()
    }
    
    // MARK: - Button State
    
    private func updateContinueButtonState() {
        let email = emailTextField.text ?? ""
        let trimmed = email.trimmingCharacters(in: .whitespacesAndNewlines)
        let emailRegEx = "[A-Z0-9a-z._%+-]+@[A-Za-z0-9.-]+\\.[A-Za-z]{2,64}"
        let emailPred = NSPredicate(format: "SELF MATCHES %@", emailRegEx)
        let isValidInput = !trimmed.isEmpty && emailPred.evaluate(with: trimmed)
        
        UIView.animate(withDuration: 0.3) {
            if isValidInput {
                self.continueButton.isEnabled = true
                self.continueButton.backgroundColor = ThemeStore.shared.colorTokens.buttonColorPrimaryDefault
            } else {
                self.continueButton.isEnabled = false
                self.continueButton.backgroundColor = ThemeStore.shared.colorTokens.buttonColorPrimaryDisabled
            }
        }
    }
}

// MARK: - UITextFieldDelegate
extension EmailVerifyView: UITextFieldDelegate {
    func textFieldDidBeginEditing(_ textField: UITextField) {
        UIView.animate(withDuration: 0.3) {
            self.inputBottomBorder.backgroundColor = ThemeStore.shared.colorTokens.buttonColorPrimaryDefault
        }
    }
    
    func textFieldDidEndEditing(_ textField: UITextField) {
        UIView.animate(withDuration: 0.3) {
            self.inputBottomBorder.backgroundColor = ThemeStore.shared.colorTokens.strokeColorSecondary
        }
        store.updateEmail(textField.text ?? "")
        updateContinueButtonState()
    }
    
    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        textField.resignFirstResponder()
        if continueButton.isEnabled {
            continueButtonTapped()
        }
        return true
    }
    
    func textField(_ textField: UITextField, shouldChangeCharactersIn range: NSRange, replacementString string: String) -> Bool {
        DispatchQueue.main.async {
            self.store.updateEmail(textField.text ?? "")
            self.updateContinueButtonState()
        }
        return true
    }
}

// MARK: - String Constants
extension String {
    struct EmailLogin {
        // MARK: - Titles and Labels
        static var welcomeTitle: String { LoginLocalize("Demo.TRTC.Email.welcomeTitle") }
        static var subtitle: String { LoginLocalize("Demo.TRTC.Email.subtitle") }
        
        // MARK: - Input Fields
        static var emailPlaceholder: String { LoginLocalize("Demo.TRTC.Email.emailPlaceholder") }
        
        // MARK: - Button Texts
        static var continueButton: String { LoginLocalize("Demo.TRTC.Email.continueButton") }
        static var requesting: String { LoginLocalize("Demo.TRTC.Email.requesting") }
        
        // MARK: - Error Messages
        static var enterEmailError: String { LoginLocalize("Demo.TRTC.Email.enterEmailError") }
        static var validEmailError: String { LoginLocalize("Demo.TRTC.Email.validEmailError") }
        
        // MARK: - Bottom Text
        static var bottomTextPrefix: String { LoginLocalize("Demo.TRTC.Email.bottomTextPrefix") }
        static var enterCodeLink: String { LoginLocalize("Demo.TRTC.Email.enterCodeLink") }
        static var bottomText: String { bottomTextPrefix + enterCodeLink }
    }
}
