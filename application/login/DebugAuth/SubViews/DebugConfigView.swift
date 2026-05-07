//
//  DebugConfigView.swift
//  login
//

import UIKit
import TUICore
import AtomicX

class DebugConfigView: UIView {
    
    var onLoginButtonTapped: (() -> Void)?
    var onUserNameChanged: ((String) -> Void)?
    
    weak var currentTextField: UITextField?
    
    // MARK: - SubViews
    
    lazy var bgView: UIImageView = {
        let imageView = UIImageView(image: UIImage.loginImage(named: "login_bg"))
        return imageView
    }()
    
    lazy var logoView: UIImageView = {
        let imageView = UIImageView(image: UIImage.loginImage(named: getMainLogoStr()))
        imageView.contentMode = .scaleAspectFit
        return imageView
    }()
    
    lazy var contentView: UIView = {
        let view = UIView(frame: .zero)
        view.backgroundColor = ThemeStore.shared.colorTokens.bgColorOperate
        return view
    }()
    
    lazy var accountTextField: UITextField = {
        let textField = createTextField(LoginLocalize("Demo.TRTC.Login.enterUserName"))
        textField.keyboardType = .default
        textField.layer.borderWidth = 1.0
        textField.layer.borderColor = ThemeStore.shared.colorTokens.strokeColorPrimary.cgColor
        textField.layer.cornerRadius = 5.0
        return textField
    }()
    
    lazy var loginButton: UIButton = {
        let button = UIButton(type: .custom)
        button.setTitleColor(ThemeStore.shared.colorTokens.textColorButton, for: .normal)
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
    
    let versionTipLabel: UILabel = {
        let tip = UILabel()
        tip.textAlignment = .center
        tip.font = ThemeStore.shared.typographyTokens.Regular14
        tip.textColor = ThemeStore.shared.colorTokens.textColorDisable
        let appVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "0.0.0"
        let buildNumber = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "0"
        tip.text = "Tencent Cloud Media Services v\(appVersion)(\(buildNumber))"
        tip.adjustsFontSizeToFitWidth = true
        return tip
    }()
    
    private lazy var leftAccountTFContainerView: UIView = {
        let iconSize: CGFloat = 20
        let horizontalPadding: CGFloat = 8
        let containerHeight: CGFloat = 24
        let containerWidth = iconSize + horizontalPadding * 2
        
        let view = UIView(frame: CGRect(x: 0, y: 0, width: containerWidth, height: containerHeight))
        let iconView = UIImageView(frame: CGRect(x: horizontalPadding, y: (containerHeight - iconSize) / 2, width: iconSize, height: iconSize))
        iconView.contentMode = .scaleAspectFit
        iconView.image = UIImage.loginImage(named: "login_phone")
        view.addSubview(iconView)
        return view
    }()
    
    // MARK: - Init
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        NotificationCenter.default.addObserver(self, selector: #selector(keyboardFrameChange(noti:)),
                                               name: UIResponder.keyboardWillChangeFrameNotification, object: nil)
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
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
        if let current = currentTextField {
            current.resignFirstResponder()
            currentTextField = nil
        }
        UIView.animate(withDuration: 0.3) {
            self.transform = .identity
        }
    }
    
    private var isViewReady = false
    override func didMoveToWindow() {
        super.didMoveToWindow()
        loginButton.isEnabled = true
        guard !isViewReady else { return }
        isViewReady = true
        constructViewHierarchy()
        activateConstraints()
        bindInteraction()
    }
    
    func constructViewHierarchy() {
        addSubview(bgView)
        addSubview(contentView)
        bgView.addSubview(logoView)
        contentView.addSubview(accountTextField)
        contentView.addSubview(loginButton)
        contentView.addSubview(versionTipLabel)
    }
    
    func activateConstraints() {
        bgView.snp.makeConstraints { make in
            make.top.leading.trailing.equalToSuperview()
            make.height.equalTo(200)
        }
        logoView.snp.makeConstraints { make in
            make.centerX.equalToSuperview()
            make.bottom.equalToSuperview().offset(-20)
            make.height.equalTo(48)
            make.width.equalTo(213)
        }
        contentView.snp.makeConstraints { make in
            make.top.equalTo(bgView.snp.bottom)
            make.leading.trailing.bottom.equalToSuperview()
        }
        accountTextField.snp.makeConstraints { make in
            make.top.equalToSuperview().offset(convertPixel(h: 40))
            make.leading.equalToSuperview().offset(convertPixel(w: 30))
            make.trailing.equalToSuperview().offset(-convertPixel(w: 30))
            make.height.equalTo(convertPixel(h: 57))
        }
        loginButton.snp.makeConstraints { make in
            make.top.equalTo(accountTextField.snp.bottom).offset(convertPixel(h: 50))
            make.leading.equalToSuperview().offset(convertPixel(w: 20))
            make.trailing.equalToSuperview().offset(-convertPixel(w: 20))
            make.height.equalTo(convertPixel(h: 52))
        }
        versionTipLabel.snp.makeConstraints { make in
            make.bottomMargin.equalTo(contentView).offset(-12)
            make.leading.trailing.equalTo(contentView)
            make.height.equalTo(30)
        }
    }
    
    func bindInteraction() {
        loginButton.addTarget(self, action: #selector(loginBtnClick), for: .touchUpInside)
        accountTextField.delegate = self
        accountTextField.leftView = leftAccountTFContainerView
        accountTextField.leftViewMode = .always
    }
    
    // MARK: - Actions
    
    @objc private func loginBtnClick() {
        currentTextField?.resignFirstResponder()
        guard let userName = accountTextField.text, !userName.isEmpty else { return }
        loginButton.isEnabled = false
        onLoginButtonTapped?()
        DispatchQueue.main.asyncAfter(deadline: .now() + 4.0) { [weak self] in
            self?.loginButton.isEnabled = true
        }
    }
    
    @objc private func keyboardFrameChange(noti: Notification) {
        guard let info = noti.userInfo,
              let value = info[UIResponder.keyboardFrameEndUserInfoKey] as? CGRect,
              let superview = loginButton.superview else { return }
        let converted = superview.convert(loginButton.frame, to: self)
        if value.intersects(converted) {
            transform = CGAffineTransform(translationX: 0, y: -converted.maxY + value.minY)
        }
    }
    
    // MARK: - Helpers
    
    private func createTextField(_ placeholder: String) -> UITextField {
        let textField = UITextField(frame: .zero)
        textField.backgroundColor = ThemeStore.shared.colorTokens.bgColorOperate
        textField.font = ThemeStore.shared.typographyTokens.Regular16
        textField.textColor = ThemeStore.shared.colorTokens.textColorPrimary
        textField.attributedPlaceholder = NSAttributedString(
            string: placeholder,
            attributes: [
                .font: ThemeStore.shared.typographyTokens.Regular16,
                .foregroundColor: ThemeStore.shared.colorTokens.textColorDisable,
            ]
        )
        return textField
    }
    
    private func getMainLogoStr() -> String {
        guard let language = TUIGlobalization.getPreferredLanguage() else {
            return "main_english_logo"
        }
        if language.contains("zh-Hans") {
            return "main_simplified_chinese_logo"
        } else if language.contains("zh-Hant") {
            return "main_traditional_chinese_logo"
        } else {
            return "main_english_logo"
        }
    }
}

// MARK: - UITextFieldDelegate

extension DebugConfigView: UITextFieldDelegate {
    func textFieldDidBeginEditing(_ textField: UITextField) {
        if let last = currentTextField {
            last.resignFirstResponder()
        }
        currentTextField = textField
        textField.becomeFirstResponder()
    }
    
    func textFieldDidEndEditing(_ textField: UITextField) {
        textField.resignFirstResponder()
        currentTextField = nil
        UIView.animate(withDuration: 0.3) {
            self.transform = .identity
        }
        onUserNameChanged?(textField.text ?? "")
    }
    
    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        textField.resignFirstResponder()
        return true
    }
    
    func textField(_ textField: UITextField, shouldChangeCharactersIn range: NSRange, replacementString string: String) -> Bool {
        let maxCount = 11
        guard let textFieldText = textField.text,
              let rangeOfTextToReplace = Range(range, in: textFieldText) else { return false }
        let substringToReplace = textFieldText[rangeOfTextToReplace]
        let count = textFieldText.count - substringToReplace.count + string.count
        let res = count <= maxCount
        if res {
            loginButton.isEnabled = count > 0
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) { [weak self] in
                self?.onUserNameChanged?(textField.text ?? "")
            }
        }
        return res
    }
}
