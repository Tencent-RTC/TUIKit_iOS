import TUIChatKit
import SnapKit
import UIKit

final class LocalLoginViewController: UIViewController {
    private static let iconSize: CGFloat = 60
    private static let fieldHeight: CGFloat = 48
    private static let fieldCornerRadius: CGFloat = 8
    private static let horizontalPadding: CGFloat = 32

    private let logoImageView = UIImageView()
    private let titleLabel = UILabel()
    private let subtitleLabel = UILabel()
    private let userIDField = UITextField()
    private let errorLabel = UILabel()
    private let loginButton = UIButton(type: .custom)
    private let loadingIndicator = UIActivityIndicatorView(style: .medium)
    private let closeButton = UIButton(type: .custom)

    private var isLoggingIn = false

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = TUIChatKitTheme.colors.bgColorOperate
        constructViewHierarchy()
        activateConstraints()
        setupViewStyle()
        bindInteraction()
        closeButton.isHidden = presentingViewController == nil
    }

    private func constructViewHierarchy() {
        view.addSubview(closeButton)
        view.addSubview(logoImageView)
        view.addSubview(titleLabel)
        view.addSubview(subtitleLabel)
        view.addSubview(userIDField)
        view.addSubview(errorLabel)
        view.addSubview(loginButton)
        loginButton.addSubview(loadingIndicator)
    }

    private func activateConstraints() {
        closeButton.snp.makeConstraints { make in
            make.top.equalTo(view.safeAreaLayoutGuide).offset(8)
            make.leading.equalToSuperview().offset(16)
            make.width.height.equalTo(32)
        }
        logoImageView.snp.makeConstraints { make in
            make.top.equalTo(view.safeAreaLayoutGuide).offset(40)
            make.centerX.equalToSuperview()
            make.width.height.equalTo(Self.iconSize)
        }
        titleLabel.snp.makeConstraints { make in
            make.top.equalTo(logoImageView.snp.bottom).offset(24)
            make.centerX.equalToSuperview()
        }
        subtitleLabel.snp.makeConstraints { make in
            make.top.equalTo(titleLabel.snp.bottom).offset(8)
            make.centerX.equalToSuperview()
        }
        userIDField.snp.makeConstraints { make in
            make.top.equalTo(subtitleLabel.snp.bottom).offset(36)
            make.leading.trailing.equalToSuperview().inset(Self.horizontalPadding)
            make.height.equalTo(Self.fieldHeight)
        }
        errorLabel.snp.makeConstraints { make in
            make.top.equalTo(userIDField.snp.bottom).offset(4)
            make.leading.trailing.equalToSuperview().inset(Self.horizontalPadding)
        }
        loginButton.snp.makeConstraints { make in
            make.top.equalTo(userIDField.snp.bottom).offset(36)
            make.leading.trailing.equalToSuperview().inset(Self.horizontalPadding)
            make.height.equalTo(Self.fieldHeight)
        }
        loadingIndicator.snp.makeConstraints { make in
            make.center.equalToSuperview()
        }
    }

    private func setupViewStyle() {
        let colors = TUIChatKitTheme.colors
        logoImageView.image = UIImage(systemName: "bubble.left.and.bubble.right.fill")
        logoImageView.tintColor = colors.buttonColorPrimaryDefault
        logoImageView.contentMode = .scaleAspectFit
        titleLabel.text = LocalizedChatString("AppTitle")
        titleLabel.font = .systemFont(ofSize: 34, weight: .bold)
        titleLabel.textColor = colors.textColorPrimary
        subtitleLabel.text = LocalizedChatString("AppSubtitle")
        subtitleLabel.font = .systemFont(ofSize: 15)
        subtitleLabel.textColor = colors.textColorTertiary
        userIDField.placeholder = LocalizedChatString("EnterUserID")
        userIDField.backgroundColor = colors.buttonColorSecondaryDefault
        userIDField.textColor = colors.textColorPrimary
        userIDField.layer.cornerRadius = Self.fieldCornerRadius
        userIDField.leftView = UIView(frame: CGRect(x: 0, y: 0, width: 16, height: 0))
        userIDField.leftViewMode = .always
        userIDField.rightView = UIView(frame: CGRect(x: 0, y: 0, width: 16, height: 0))
        userIDField.rightViewMode = .always
        userIDField.autocapitalizationType = .none
        userIDField.autocorrectionType = .no
        userIDField.returnKeyType = .done
        userIDField.delegate = self
        errorLabel.font = .systemFont(ofSize: 12)
        errorLabel.textColor = colors.textColorTertiary
        errorLabel.numberOfLines = 0
        loginButton.setTitle(LocalizedChatString("login"), for: .normal)
        loginButton.setTitleColor(colors.textColorButton, for: .normal)
        loginButton.titleLabel?.font = .systemFont(ofSize: 16, weight: .semibold)
        loginButton.layer.cornerRadius = Self.fieldCornerRadius
        loadingIndicator.color = colors.textColorButton
        loadingIndicator.hidesWhenStopped = true
        closeButton.setImage(UIImage(systemName: "xmark"), for: .normal)
        closeButton.tintColor = colors.textColorPrimary
        refreshLoginButtonState()
    }

    private func bindInteraction() {
        loginButton.addTarget(self, action: #selector(handleLoginTapped), for: .touchUpInside)
        closeButton.addTarget(self, action: #selector(handleCloseTapped), for: .touchUpInside)
        userIDField.addTarget(self, action: #selector(handleUserIDChanged), for: .editingChanged)
        let backgroundTap = UITapGestureRecognizer(target: self, action: #selector(handleBackgroundTapped))
        backgroundTap.cancelsTouchesInView = false
        view.addGestureRecognizer(backgroundTap)
    }

    private func refreshLoginButtonState() {
        let colors = TUIChatKitTheme.colors
        let enabled = !(userIDField.text ?? "").isEmpty && !isLoggingIn
        loginButton.isEnabled = enabled
        loginButton.backgroundColor = enabled ? colors.buttonColorPrimaryDefault : colors.buttonColorPrimaryDisabled
    }

    @objc private func handleUserIDChanged() {
        errorLabel.text = nil
        refreshLoginButtonState()
    }

    @objc private func handleBackgroundTapped() {
        view.endEditing(true)
    }

    @objc private func handleCloseTapped() {
        dismiss(animated: true)
    }

    @objc private func handleLoginTapped() {
        guard let appID = Int32(SDKAPPID), appID > 0 else {
            errorLabel.text = LocalizedChatString("InvalidSDKAppID")
            showConfigGuideAlert(errorMessage: nil)
            return
        }
        let userID = userIDField.text ?? ""
        let userSig = GenerateTestUserSig.genTestUserSig(userID: userID)
        isLoggingIn = true
        loginButton.setTitle(nil, for: .normal)
        loadingIndicator.startAnimating()
        refreshLoginButtonState()
        DemoLoginManager.shared.login(sdkAppID: appID, userID: userID, userSig: userSig) { [weak self] success, errorMessage in
            guard let self = self else { return }
            self.isLoggingIn = false
            self.loadingIndicator.stopAnimating()
            self.loginButton.setTitle(LocalizedChatString("login"), for: .normal)
            if success {
                UserDefaults.standard.set(userID, forKey: "LoginUser")
                UserDefaults.standard.set("local", forKey: "LoginType")
                self.dismiss(animated: true)
            } else {
                self.errorLabel.text = errorMessage
                self.showConfigGuideAlert(errorMessage: errorMessage)
            }
            self.refreshLoginButtonState()
        }
    }

    private func showConfigGuideAlert(errorMessage: String?) {
        let message = (errorMessage ?? LocalizedChatString("LoginFailed"))
            + "\n\n" + LocalizedChatString("LoginConfigGuide")
        let alert = UIAlertController(
            title: LocalizedChatString("LoginFailed"),
            message: message,
            preferredStyle: .alert
        )
        alert.addAction(UIAlertAction(title: LocalizedChatString("ViewDocument"), style: .default) { _ in
            guard let url = URL(string: "https://cloud.tencent.com/document/product/269/68228") else { return }
            UIApplication.shared.open(url)
        })
        alert.addAction(UIAlertAction(title: LocalizedChatString("Cancel"), style: .cancel))
        present(alert, animated: true)
    }
}

extension LocalLoginViewController: UITextFieldDelegate {
    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        textField.resignFirstResponder()
        return true
    }
}
