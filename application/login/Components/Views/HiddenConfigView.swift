//
//  HiddenConfigView.swift
//  login
//
//

import UIKit
import SnapKit
import AtomicX

class HiddenConfigView: UIView {

    // MARK: - Callbacks

    var onConfirm: ((_ sdkAppID: String, _ userId: String, _ userSig: String) -> Void)?

    var onRestoreDefault: (() -> Void)?

    var onBack: (() -> Void)?

    var onScanQRCode: (() -> Void)?

    // MARK: - UI Components

    private lazy var headerView: LoginHeaderView = {
        let view = LoginHeaderView()
        return view
    }()

    private lazy var backButton: UIButton = {
        let button = UIButton(type: .system)
        if #available(iOS 13.0, *) {
            let config = UIImage.SymbolConfiguration(pointSize: 18, weight: .medium)
            button.setImage(UIImage(systemName: "chevron.left", withConfiguration: config), for: .normal)
        } else {
            button.setTitle("<", for: .normal)
            button.titleLabel?.font = UIFont.systemFont(ofSize: 20, weight: .medium)
        }
        button.tintColor = .white
        button.backgroundColor = UIColor.black.withAlphaComponent(0.3)
        button.layer.cornerRadius = 22
        button.clipsToBounds = true
        return button
    }()

    private lazy var contentView: UIView = {
        let view = UIView()
        view.backgroundColor = ThemeStore.shared.colorTokens.bgColorOperate
        return view
    }()

    private lazy var qrScanCard: UIView = {
        let view = UIView()
        view.backgroundColor = ThemeStore.shared.colorTokens.bgColorDefault
        view.layer.cornerRadius = ThemeStore.shared.borderRadius.radius12
        view.clipsToBounds = true
        return view
    }()

    private lazy var qrIconBgView: UIView = {
        let view = UIView()
        view.backgroundColor = ThemeStore.shared.colorTokens.buttonColorPrimaryDefault.withAlphaComponent(0.1)
        view.layer.cornerRadius = 18
        return view
    }()

    private lazy var qrIconImageView: UIImageView = {
        let iv = UIImageView()
        iv.contentMode = .center
        iv.tintColor = ThemeStore.shared.colorTokens.buttonColorPrimaryDefault
        if #available(iOS 13.0, *) {
            let config = UIImage.SymbolConfiguration(pointSize: 18, weight: .medium)
            iv.image = UIImage(systemName: "qrcode.viewfinder", withConfiguration: config)
        }
        return iv
    }()

    private lazy var qrTitleLabel: UILabel = {
        let label = UILabel()
        label.text = LoginLocalize("login_hidden_config_scan_qr")
        label.font = ThemeStore.shared.typographyTokens.Medium16
        label.textColor = ThemeStore.shared.colorTokens.textColorPrimary
        return label
    }()

    private lazy var qrSubtitleLabel: UILabel = {
        let label = UILabel()
        label.text = LoginLocalize("login_hidden_config_scan_qr_desc")
        label.font = ThemeStore.shared.typographyTokens.Regular12
        label.textColor = ThemeStore.shared.colorTokens.textColorTertiary
        return label
    }()

    private lazy var qrArrowImageView: UIImageView = {
        let iv = UIImageView()
        iv.contentMode = .center
        iv.tintColor = ThemeStore.shared.colorTokens.textColorDisable
        if #available(iOS 13.0, *) {
            let config = UIImage.SymbolConfiguration(pointSize: 12, weight: .medium)
            iv.image = UIImage(systemName: "chevron.right", withConfiguration: config)
        }
        return iv
    }()

    private lazy var sdkAppIDTextField: UITextField = {
        let textField = createStyledTextField(placeholder: "SDKAppID")
        textField.keyboardType = .numberPad
        return textField
    }()

    private lazy var userIdTextField: UITextField = {
        let textField = createStyledTextField(placeholder: "UserID")
        textField.keyboardType = .default
        return textField
    }()

    private lazy var userSigTextField: UITextField = {
        let textField = createStyledTextField(placeholder: "UserSig")
        textField.isSecureTextEntry = true
        textField.isUserInteractionEnabled = false
        return textField
    }()

    private lazy var confirmButton: UIButton = {
        let button = UIButton(type: .custom)
        button.setTitleColor(.white, for: .normal)
        button.setTitle(LoginLocalize("login_hidden_config_confirm_switch"), for: .normal)
        button.adjustsImageWhenHighlighted = false
        button.setBackgroundImage(ThemeStore.shared.colorTokens.buttonColorPrimaryDisabled.trans2Image(), for: .disabled)
        button.setBackgroundImage(ThemeStore.shared.colorTokens.buttonColorPrimaryDefault.trans2Image(), for: .normal)
        button.titleLabel?.font = ThemeStore.shared.typographyTokens.Medium18
        button.layer.shadowColor = ThemeStore.shared.colorTokens.buttonColorPrimaryDefault.cgColor
        button.layer.shadowOffset = CGSize(width: 0, height: 6)
        button.layer.shadowRadius = 16
        button.layer.shadowOpacity = 0.4
        button.clipsToBounds = true
        button.isEnabled = false
        return button
    }()

    private lazy var restoreDefaultButton: UIButton = {
        let button = UIButton(type: .system)
        button.setTitle(LoginLocalize("login_hidden_config_restore_default"), for: .normal)
        button.setTitleColor(ThemeStore.shared.colorTokens.buttonColorPrimaryDefault, for: .normal)
        button.titleLabel?.font = ThemeStore.shared.typographyTokens.Medium14
        return button
    }()

    private lazy var sdkAppIDLeftView: UIView = {
        return createLeftIconView(systemName: "number")
    }()

    private lazy var userIdLeftView: UIView = {
        return createLeftIconView(systemName: "person.fill")
    }()

    private lazy var userSigLeftView: UIView = {
        return createLeftIconView(systemName: "key.fill")
    }()

    // MARK: - Init

    override init(frame: CGRect) {
        super.init(frame: frame)
        backgroundColor = ThemeStore.shared.colorTokens.bgColorOperate
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    // MARK: - Lifecycle

    override func draw(_ rect: CGRect) {
        super.draw(rect)
        confirmButton.layer.cornerRadius = confirmButton.frame.height * 0.5
    }

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        super.touchesBegan(touches, with: event)
        window?.endEditing(true)
    }

    private var isViewReady = false
    override func didMoveToWindow() {
        super.didMoveToWindow()
        guard !isViewReady else { return }
        constructViewHierarchy()
        activateConstraints()
        bindInteraction()
        isViewReady = true
    }

    // MARK: - Setup

    private func constructViewHierarchy() {
        addSubview(headerView)
        addSubview(contentView)

        contentView.addSubview(qrScanCard)
        qrScanCard.addSubview(qrIconBgView)
        qrIconBgView.addSubview(qrIconImageView)
        qrScanCard.addSubview(qrTitleLabel)
        qrScanCard.addSubview(qrSubtitleLabel)
        qrScanCard.addSubview(qrArrowImageView)

        contentView.addSubview(sdkAppIDTextField)
        contentView.addSubview(userIdTextField)
        contentView.addSubview(userSigTextField)
        contentView.addSubview(confirmButton)
        contentView.addSubview(restoreDefaultButton)

        addSubview(backButton)
    }

    private func activateConstraints() {
        headerView.snp.makeConstraints { make in
            make.top.leading.trailing.equalToSuperview()
            make.height.equalTo(200 + statusBarHeight())
        }

        backButton.snp.makeConstraints { make in
            make.top.equalToSuperview().offset(statusBarHeight() + 8)
            make.leading.equalToSuperview().offset(16)
            make.width.height.equalTo(44)
        }

        contentView.snp.makeConstraints { make in
            make.top.equalTo(headerView.snp.bottom)
            make.leading.trailing.bottom.equalToSuperview()
        }

        qrScanCard.snp.makeConstraints { make in
            make.top.equalToSuperview().offset(convertPixel(h: 24))
            make.leading.equalToSuperview().offset(20)
            make.trailing.equalToSuperview().offset(-20)
            make.height.equalTo(64)
        }

        qrIconBgView.snp.makeConstraints { make in
            make.leading.equalToSuperview().offset(14)
            make.centerY.equalToSuperview()
            make.width.height.equalTo(36)
        }

        qrIconImageView.snp.makeConstraints { make in
            make.center.equalToSuperview()
            make.width.height.equalTo(20)
        }

        qrTitleLabel.snp.makeConstraints { make in
            make.leading.equalTo(qrIconBgView.snp.trailing).offset(12)
            make.top.equalToSuperview().offset(12)
            make.trailing.lessThanOrEqualTo(qrArrowImageView.snp.leading).offset(-8)
        }

        qrSubtitleLabel.snp.makeConstraints { make in
            make.leading.equalTo(qrTitleLabel)
            make.top.equalTo(qrTitleLabel.snp.bottom).offset(2)
            make.trailing.lessThanOrEqualTo(qrArrowImageView.snp.leading).offset(-8)
        }

        qrArrowImageView.snp.makeConstraints { make in
            make.trailing.equalToSuperview().offset(-14)
            make.centerY.equalToSuperview()
            make.width.height.equalTo(16)
        }

        sdkAppIDTextField.snp.makeConstraints { make in
            make.top.equalTo(qrScanCard.snp.bottom).offset(convertPixel(h: 24))
            make.leading.equalToSuperview().offset(convertPixel(w: 30))
            make.trailing.equalToSuperview().offset(-convertPixel(w: 30))
            make.height.equalTo(convertPixel(h: 57))
        }

        userIdTextField.snp.makeConstraints { make in
            make.top.equalTo(sdkAppIDTextField.snp.bottom).offset(convertPixel(h: 20))
            make.leading.trailing.height.equalTo(sdkAppIDTextField)
        }

        userSigTextField.snp.makeConstraints { make in
            make.top.equalTo(userIdTextField.snp.bottom).offset(convertPixel(h: 20))
            make.leading.trailing.height.equalTo(sdkAppIDTextField)
        }

        confirmButton.snp.makeConstraints { make in
            make.top.equalTo(userSigTextField.snp.bottom).offset(convertPixel(h: 40))
            make.leading.equalToSuperview().offset(convertPixel(w: 20))
            make.trailing.equalToSuperview().offset(-convertPixel(w: 20))
            make.height.equalTo(convertPixel(h: 52))
        }

        restoreDefaultButton.snp.makeConstraints { make in
            make.top.equalTo(confirmButton.snp.bottom).offset(16)
            make.centerX.equalToSuperview()
            make.height.equalTo(40)
        }
    }

    private func bindInteraction() {
        backButton.addTarget(self, action: #selector(backButtonTapped), for: .touchUpInside)
        confirmButton.addTarget(self, action: #selector(confirmButtonTapped), for: .touchUpInside)
        restoreDefaultButton.addTarget(self, action: #selector(restoreDefaultButtonTapped), for: .touchUpInside)

        sdkAppIDTextField.addTarget(self, action: #selector(textFieldChanged), for: .editingChanged)
        userIdTextField.addTarget(self, action: #selector(textFieldChanged), for: .editingChanged)
        userSigTextField.addTarget(self, action: #selector(textFieldChanged), for: .editingChanged)

        sdkAppIDTextField.leftView = sdkAppIDLeftView
        sdkAppIDTextField.leftViewMode = .always
        userIdTextField.leftView = userIdLeftView
        userIdTextField.leftViewMode = .always
        userSigTextField.leftView = userSigLeftView
        userSigTextField.leftViewMode = .always

        sdkAppIDTextField.delegate = self
        userIdTextField.delegate = self
        userSigTextField.delegate = self

        let qrTap = UITapGestureRecognizer(target: self, action: #selector(qrScanCardTapped))
        qrScanCard.addGestureRecognizer(qrTap)
    }

    // MARK: - Actions

    @objc private func backButtonTapped() {
        onBack?()
    }

    @objc private func confirmButtonTapped() {
        window?.endEditing(true)
        let sdkAppID = sdkAppIDTextField.text ?? ""
        let userId = userIdTextField.text ?? ""
        let userSig = userSigTextField.text ?? ""
        onConfirm?(sdkAppID, userId, userSig)
    }

    @objc private func restoreDefaultButtonTapped() {
        onRestoreDefault?()
    }

    @objc private func qrScanCardTapped() {
        onScanQRCode?()
    }

    @objc private func textFieldChanged() {
        updateConfirmButtonState()
    }

    // MARK: - State

    private func updateConfirmButtonState() {
        let sdkAppID = sdkAppIDTextField.text?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let userId = userIdTextField.text?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let userSig = userSigTextField.text?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let isValid = !sdkAppID.isEmpty && !userId.isEmpty && !userSig.isEmpty

        UIView.animate(withDuration: 0.3) {
            self.confirmButton.isEnabled = isValid
        }
    }

    // MARK: - Public

    func handleQRCodeResult(_ result: String) {
        if let data = result.data(using: .utf8),
           let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
            // sdkAppId
            if let sdkAppId = json["sdkAppId"] as? Int {
                sdkAppIDTextField.text = String(sdkAppId)
            } else if let sdkAppId = json["sdkAppId"] as? String {
                sdkAppIDTextField.text = sdkAppId
            }
            // userId
            if let userId = json["userId"] as? String {
                userIdTextField.text = userId
            }
            // userSig
            if let userSig = json["userSig"] as? String {
                userSigTextField.text = userSig
            }
        }
        updateConfirmButtonState()
    }

    // MARK: - Helpers

    private func createStyledTextField(placeholder: String) -> UITextField {
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
        textField.layer.borderWidth = 1.0
        textField.layer.borderColor = ThemeStore.shared.colorTokens.strokeColorPrimary.cgColor
        textField.layer.cornerRadius = 5.0
        textField.autocapitalizationType = .none
        textField.autocorrectionType = .no
        return textField
    }

    private func createLeftIconView(systemName: String) -> UIView {
        let iconSize: CGFloat = 20
        let horizontalPadding: CGFloat = 8
        let containerHeight: CGFloat = 24
        let containerWidth = iconSize + horizontalPadding * 2

        let view = UIView(frame: CGRect(x: 0, y: 0, width: containerWidth, height: containerHeight))
        let iconView = UIImageView(frame: CGRect(x: horizontalPadding, y: (containerHeight - iconSize) / 2, width: iconSize, height: iconSize))
        iconView.contentMode = .scaleAspectFit
        iconView.tintColor = ThemeStore.shared.colorTokens.textColorDisable
        if #available(iOS 13.0, *) {
            let config = UIImage.SymbolConfiguration(pointSize: 14, weight: .regular)
            iconView.image = UIImage(systemName: systemName, withConfiguration: config)
        }
        view.addSubview(iconView)
        return view
    }
}

// MARK: - UITextFieldDelegate

extension HiddenConfigView: UITextFieldDelegate {
    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        if textField == sdkAppIDTextField {
            userIdTextField.becomeFirstResponder()
        } else if textField == userIdTextField {
            userSigTextField.becomeFirstResponder()
        } else {
            textField.resignFirstResponder()
            if confirmButton.isEnabled {
                confirmButtonTapped()
            }
        }
        return true
    }
}
