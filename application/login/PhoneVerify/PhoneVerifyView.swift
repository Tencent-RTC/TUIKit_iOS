//
//  PhoneVerifyView.swift
//  login
//

import UIKit
import AtomicX
import Combine
import Toast_Swift

class PhoneVerifyView: UIView {
    
    // MARK: - Dependencies
    
    let store: PhoneVerifyStore
    private var cancellables = Set<AnyCancellable>()
    weak var navigationController: UINavigationController?
    
    // MARK: - SubViews
    
    lazy var headerView: LoginHeaderView = {
        let view = LoginHeaderView()
        return view
    }()
    
    lazy var contentView: UIView = {
        let view = UIView(frame: .zero)
        view.backgroundColor = ThemeStore.shared.colorTokens.bgColorOperate
        return view
    }()
    
    lazy var phoneInputView: PhoneInputView = {
        let view = PhoneInputView()
        return view
    }()
    
    lazy var verifyCodeInputView: VerifyCodeInputView = {
        let view = VerifyCodeInputView()
        return view
    }()
    
    lazy var privacyAgreementView: PrivacyAgreementView = {
        let view = PrivacyAgreementView()
        return view
    }()
    
    lazy var loginButton: UIButton = {
        let button = UIButton(type: .custom)
        button.setTitleColor(.white, for: .normal)
        button.setTitle(LoginLocalize("V2.Live.LoginMock.login"), for: .normal)
        button.adjustsImageWhenHighlighted = false
        button.setBackgroundImage(ThemeStore.shared.colorTokens.buttonColorPrimaryDefault.trans2Image(), for: .normal)
        button.titleLabel?.font = ThemeStore.shared.typographyTokens.Medium18
        button.layer.shadowColor = ThemeStore.shared.colorTokens.buttonColorPrimaryDefault.cgColor
        button.layer.shadowOffset = CGSize(width: 0, height: 6)
        button.layer.shadowRadius = 16
        button.layer.shadowOpacity = 0.4
        button.layer.masksToBounds = true
        button.isEnabled = false
        return button
    }()
    
    lazy var dividerContainerView: UIView = {
        let view = UIView()
        return view
    }()
    
    lazy var leftDividerLine: UIView = {
        let line = UIView()
        line.backgroundColor = ThemeStore.shared.colorTokens.strokeColorSecondary
        return line
    }()
    
    lazy var rightDividerLine: UIView = {
        let line = UIView()
        line.backgroundColor = ThemeStore.shared.colorTokens.strokeColorSecondary
        return line
    }()
    
    lazy var dividerLabel: UILabel = {
        let label = UILabel()
        label.text = LoginLocalize("Demo.TRTC.Login.ioatext")
        label.textColor = ThemeStore.shared.colorTokens.textColorTertiary
        label.font = ThemeStore.shared.typographyTokens.Regular14
        label.textAlignment = .center
        return label
    }()
    
    lazy var ioaLoginButton: UIButton = {
        let button = UIButton(type: .custom)
        button.backgroundColor = ThemeStore.shared.colorTokens.bgColorDefault.withAlphaComponent(0.7)
        button.layer.cornerRadius = ThemeStore.shared.borderRadius.radius20
        button.clipsToBounds = true
        button.setImage(UIImage.loginImage(named: "ioa_login_icon"), for: .normal)
        button.imageView?.contentMode = .scaleAspectFit
        button.contentEdgeInsets = .zero
        button.imageEdgeInsets = UIEdgeInsets(top: 9, left: 9, bottom: 9, right: 9)
        return button
    }()
    
    lazy var fullScreenLoadingView: FullScreenLoadingView = {
        let view = FullScreenLoadingView()
        return view
    }()
    
    // MARK: - Init
    
    init(store: PhoneVerifyStore) {
        self.store = store
        super.init(frame: .zero)
        backgroundColor = ThemeStore.shared.colorTokens.bgColorOperate
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    // MARK: - Lifecycle
    
    override func draw(_ rect: CGRect) {
        super.draw(rect)
        loginButton.layer.cornerRadius = loginButton.frame.height * 0.5
    }
    
    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        super.touchesBegan(touches, with: event)
        window?.endEditing(true)
        checkButtonStates()
    }
    
    private var isViewReady = false
    override func didMoveToWindow() {
        super.didMoveToWindow()
        guard !isViewReady else { return }
        constructViewHierarchy()
        activateConstraints()
        bindInteraction()
        setupViewStyle()
        isViewReady = true
    }
    
    // MARK: - UI Lifecycle Methods
    
    func constructViewHierarchy() {
        addSubview(headerView)
        addSubview(contentView)
        contentView.addSubview(phoneInputView)
        contentView.addSubview(verifyCodeInputView)
        contentView.addSubview(privacyAgreementView)
        contentView.addSubview(loginButton)
        
        #if LOGIN_FULL
        addSubview(dividerContainerView)
        dividerContainerView.addSubview(leftDividerLine)
        dividerContainerView.addSubview(rightDividerLine)
        dividerContainerView.addSubview(dividerLabel)
        addSubview(ioaLoginButton)
        #endif
        
        addSubview(fullScreenLoadingView)
    }
    
    func activateConstraints() {
        headerView.snp.makeConstraints { make in
            make.top.leading.trailing.equalToSuperview()
            make.height.equalTo(200 + statusBarHeight())
        }
        
        contentView.snp.makeConstraints { make in
            make.top.equalTo(headerView.bgView.snp.bottom)
            make.leading.trailing.bottom.equalToSuperview()
        }
        
        phoneInputView.snp.makeConstraints { make in
            make.top.equalToSuperview().offset(convertPixel(h: 40))
            make.leading.equalToSuperview().offset(convertPixel(w: 30))
            make.trailing.equalToSuperview().offset(-convertPixel(w: 30))
            make.height.equalTo(convertPixel(h: 57))
        }
        
        verifyCodeInputView.snp.makeConstraints { make in
            make.leading.height.trailing.equalTo(phoneInputView)
            make.top.equalTo(phoneInputView.snp.bottom).offset(convertPixel(h: 20))
        }
        
        privacyAgreementView.snp.makeConstraints { make in
            make.top.equalTo(verifyCodeInputView.snp.bottom).offset(30)
            make.leading.equalTo(verifyCodeInputView)
            make.trailing.equalTo(verifyCodeInputView)
            make.height.equalTo(convertPixel(h: 56))
        }
        
        loginButton.snp.makeConstraints { make in
            make.top.equalTo(privacyAgreementView.snp.bottom).offset(convertPixel(h: 20))
            make.leading.equalToSuperview().offset(convertPixel(w: 20))
            make.trailing.equalToSuperview().offset(-convertPixel(w: 20))
            make.height.equalTo(convertPixel(h: 52))
        }
        
        #if LOGIN_FULL
        dividerContainerView.snp.makeConstraints { make in
            make.left.right.equalToSuperview().inset(40)
            make.bottom.equalToSuperview().offset(-130)
            make.height.equalTo(20)
        }
        
        dividerLabel.snp.makeConstraints { make in
            make.center.equalToSuperview()
        }
        
        leftDividerLine.snp.makeConstraints { make in
            make.left.equalToSuperview()
            make.right.equalTo(dividerLabel.snp.left).offset(-12)
            make.centerY.equalToSuperview()
            make.height.equalTo(1)
        }
        
        rightDividerLine.snp.makeConstraints { make in
            make.left.equalTo(dividerLabel.snp.right).offset(12)
            make.right.equalToSuperview()
            make.centerY.equalToSuperview()
            make.height.equalTo(1)
        }
        
        ioaLoginButton.snp.makeConstraints { make in
            make.centerX.equalToSuperview()
            make.top.equalTo(dividerContainerView.snp.bottom).offset(20)
            make.width.height.equalTo(40)
        }
        #endif
        
        fullScreenLoadingView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }
    }
    
    func bindInteraction() {
        loginButton.addTarget(self, action: #selector(loginButtonClick), for: .touchUpInside)
        verifyCodeInputView.getVerifyCodeButton.addTarget(self, action: #selector(getVerifyCodeButtonClick), for: .touchUpInside)
        #if LOGIN_FULL
        ioaLoginButton.addTarget(self, action: #selector(ioaLoginButtonClick), for: .touchUpInside)
        #endif
        
        phoneInputView.onTextChanged = { [weak self] text in
            guard let self = self else { return }
            self.store.updatePhoneNumber(text)
            self.checkButtonStates()
        }
        
        verifyCodeInputView.onTextChanged = { [weak self] text in
            guard let self = self else { return }
            self.store.updateVerifyCode(text)
            self.checkButtonStates()
        }
        
        privacyAgreementView.hostViewController = navigationController
        
        // Subscribe to state changes
        store.$state
            .map(\.toastMessage)
            .removeDuplicates()
            .sink { [weak self] message in
                guard !message.isEmpty else { return }
                self?.makeToast(message)
            }
            .store(in: &cancellables)
        
        store.$state
            .map(\.isLoading)
            .removeDuplicates()
            .sink { [weak self] isLoading in
                // loading handled by individual buttons
            }
            .store(in: &cancellables)
        
        store.$state
            .map(\.isFullScreenLoading)
            .removeDuplicates()
            .sink { [weak self] isFullScreenLoading in
                guard let self = self else { return }
                if isFullScreenLoading {
                    self.fullScreenLoadingView.show(with: self.store.state.fullScreenLoadingMessage)
                } else {
                    self.fullScreenLoadingView.hide()
                }
            }
            .store(in: &cancellables)
        
        store.$state
            .map(\.countdownSeconds)
            .removeDuplicates()
            .sink { [weak self] seconds in
                guard let self = self else { return }
                if seconds > 0 {
                    self.verifyCodeInputView.getVerifyCodeButton.updateCountdown(seconds)
                } else {
                    self.verifyCodeInputView.getVerifyCodeButton.stopCountdown()
                }
            }
            .store(in: &cancellables)
        
        store.$state
            .map(\.phoneNumber)
            .removeDuplicates()
            .filter { $0.isEmpty }
            .dropFirst()
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in
                guard let self = self else { return }
                self.phoneInputView.textField.text = ""
                self.verifyCodeInputView.textField.text = ""
                self.loginButton.isEnabled = false
                self.hideAllToasts()
            }
            .store(in: &cancellables)
    }
    
    func setupViewStyle() {
        fullScreenLoadingView.hide()
    }
    
    // MARK: - Actions
    
    @objc private func loginButtonClick() {
        window?.endEditing(true)
        guard privacyAgreementView.isAgreed else {
            showPrivacyPanel { [weak self] in
                self?.store.login()
            }
            return
        }
        store.login()
    }
    
    @objc private func getVerifyCodeButtonClick() {
        window?.endEditing(true)
        guard privacyAgreementView.isAgreed else {
            showPrivacyPanel { [weak self] in
                guard let self = self else { return }
                guard let phone = self.phoneInputView.textField.text, phone.count > 0 else { return }
                self.store.sendVerifyCode()
            }
            return
        }
        guard let phone = phoneInputView.textField.text, phone.count > 0 else { return }
        store.sendVerifyCode()
    }
    
    @objc private func ioaLoginButtonClick() {
        guard privacyAgreementView.isAgreed else {
            showPrivacyPanel { [weak self] in
                self?.store.switchToIOA()
            }
            return
        }
        store.switchToIOA()
    }
    
    // MARK: - Helpers
    
    private func checkButtonStates() {
        let phoneCount = phoneInputView.textField.text?.count ?? 0
        let codeCount = verifyCodeInputView.textField.text?.count ?? 0
        loginButton.isEnabled = phoneCount > 0 && codeCount == 6
        verifyCodeInputView.getVerifyCodeButton.isEnabled = phoneCount > 0 && store.state.countdownSeconds == 0
    }
    
    private func showPrivacyPanel(pendingAction: (() -> Void)? = nil) {
        #if LOGIN_FULL
        ioaLoginButton.isHidden = true
        dividerContainerView.isHidden = true
        #endif
        
        let privacyPanelView = PrivacyPanelView()
        privacyPanelView.rootVC = findViewController()
        privacyPanelView.onAgreeButtonClickedClosure = { [weak self] in
            self?.privacyAgreementView.setAgreed(true)
            pendingAction?()
        }
        privacyPanelView.onDismissClosure = { [weak self] in
            #if LOGIN_FULL
            self?.ioaLoginButton.isHidden = false
            self?.dividerContainerView.isHidden = false
            #endif
        }
        
        addSubview(privacyPanelView)
        privacyPanelView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }
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
