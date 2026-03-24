import UIKit
import SnapKit
import Combine
import Toast_Swift
import AtomicXCore

/**
 * Business scenario: user login page
 *
 * APIs involved:
 * - LoginStore.shared.login() - SDK login
 * - LoginStore.shared.state - Login state observation
 * - LoginStore.shared.loginEventPublisher - Login event observation
 *
 * Only a User ID is required. The UserSig is generated locally (for debugging only).
 */
class LoginViewController: UIViewController {

    // MARK: - UI Components

    private let titleLabel: UILabel = {
        let label = UILabel()
        label.font = .systemFont(ofSize: 24, weight: .bold)
        label.textAlignment = .center
        return label
    }()

    private let subtitleLabel: UILabel = {
        let label = UILabel()
        label.font = .systemFont(ofSize: 14)
        label.textColor = .secondaryLabel
        label.textAlignment = .center
        return label
    }()

    private let userIDTextField: UITextField = {
        let textField = UITextField()
        textField.borderStyle = .roundedRect
        textField.autocapitalizationType = .none
        textField.autocorrectionType = .no
        textField.keyboardType = .numberPad
        return textField
    }()

    private let loginButton: UIButton = {
        let button = UIButton(type: .system)
        button.titleLabel?.font = .systemFont(ofSize: 16, weight: .semibold)
        button.backgroundColor = .systemBlue
        button.setTitleColor(.white, for: .normal)
        button.layer.cornerRadius = 8
        return button
    }()

    private let debugTipLabel: UILabel = {
        let label = UILabel()
        label.font = .systemFont(ofSize: 11)
        label.textColor = .tertiaryLabel
        label.textAlignment = .center
        label.numberOfLines = 0
        label.text = "UserSig 将由本地自动生成（仅调试模式）"
        return label
    }()

    // MARK: - Properties

    private var cancellables = Set<AnyCancellable>()
    
    /// The key used to cache the user ID locally
    private static let cachedUserIDKey = "CachedLoginUserID"

    // MARK: - Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        setupBindings()
        setupActions()
        updateLocalizedText()
        restoreCachedUserID()
    }

    // MARK: - Setup

    private func setupUI() {
        view.backgroundColor = .systemBackground
        navigationItem.title = "Login"

        // Language switch button
        let languageButton = UIBarButtonItem(
            image: UIImage(systemName: "globe"),
            style: .plain,
            target: self,
            action: #selector(switchLanguage)
        )
        navigationItem.rightBarButtonItem = languageButton

        view.addSubview(titleLabel)
        view.addSubview(subtitleLabel)
        view.addSubview(userIDTextField)
        view.addSubview(debugTipLabel)
        view.addSubview(loginButton)

        titleLabel.snp.makeConstraints { make in
            make.top.equalTo(view.safeAreaLayoutGuide).offset(60)
            make.leading.trailing.equalToSuperview().inset(24)
        }

        subtitleLabel.snp.makeConstraints { make in
            make.top.equalTo(titleLabel.snp.bottom).offset(8)
            make.leading.trailing.equalToSuperview().inset(24)
        }

        userIDTextField.snp.makeConstraints { make in
            make.top.equalTo(subtitleLabel.snp.bottom).offset(40)
            make.leading.trailing.equalToSuperview().inset(24)
            make.height.equalTo(44)
        }

        debugTipLabel.snp.makeConstraints { make in
            make.top.equalTo(userIDTextField.snp.bottom).offset(8)
            make.leading.trailing.equalToSuperview().inset(24)
        }

        loginButton.snp.makeConstraints { make in
            make.top.equalTo(debugTipLabel.snp.bottom).offset(24)
            make.leading.trailing.equalToSuperview().inset(24)
            make.height.equalTo(48)
        }
    }

    private func updateLocalizedText() {
        titleLabel.text = "login.title".localized
        subtitleLabel.text = "login.subtitle".localized
        userIDTextField.placeholder = "login.userID.placeholder".localized
        loginButton.setTitle("login.button".localized, for: .normal)
        debugTipLabel.text = "login.debug.tip".localized
    }

    private func setupBindings() {
        LoginStore.shared.state.subscribe()
            .sink { [weak self] loginState in
                DispatchQueue.main.async {
                    self?.updateLoginStatus(loginState.loginStatus)
                }
            }
            .store(in: &cancellables)

        LoginStore.shared.loginEventPublisher
            .receive(on: DispatchQueue.main)
            .sink { [weak self] event in
                self?.handleLoginEvent(event)
            }
            .store(in: &cancellables)
    }

    private func setupActions() {
        loginButton.addTarget(self, action: #selector(loginTapped), for: .touchUpInside)

        let tapGesture = UITapGestureRecognizer(target: self, action: #selector(dismissKeyboard))
        view.addGestureRecognizer(tapGesture)
    }

    // MARK: - Actions

    @objc private func switchLanguage() {
        LocalizedManager.shared.showLanguageSwitchAlert(in: self)
    }

    @objc private func loginTapped() {
        dismissKeyboard()

        guard let userID = userIDTextField.text, !userID.isEmpty else {
            showAlert(title: "common.error".localized, message: "login.error.emptyUserID".localized)
            return
        }

        performLogin(userID: userID)
    }

    @objc private func dismissKeyboard() {
        view.endEditing(true)
    }

    // MARK: - Login Logic

    private func performLogin(userID: String) {
        setLoading(true)
        
        // Automatically generate the UserSig
        let userSig = GenerateTestUserSig.genTestUserSig(identifier: userID)
        print("[Login] Generated UserSig: \(userSig)")
        
        LoginStore.shared.login(
            sdkAppID: Int32(SDKAPPID),
            userID: userID,
            userSig: userSig
        ) { [weak self] result in
            guard let self = self else { return }
            switch result {
            case .success():
                // Cache the user ID after a successful login so it can be auto-filled on the next cold start
                UserDefaults.standard.set(userID, forKey: LoginViewController.cachedUserIDKey)
                DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                    self.setLoading(false)
                    self.checkProfileAndNavigate()
                }
            case .failure(let err):
                self.setLoading(false)
                self.view.makeToast(err.message)
            }
        }
    }

    // MARK: - Status Handling

    private func updateLoginStatus(_ status: LoginStatus) {
        switch status {
        case .unlogin:
            self.view.makeToast("login.status.notLoggedIn".localized)
        case .logined:
            self.view.makeToast("login.status.loggedIn".localized)
        @unknown default:
            self.view.makeToast("Unknown status")
        }
    }

    private func handleLoginEvent(_ event: LoginEvent) {
        switch event {
        case .kickedOffline:
            showAlert(title: "common.warning".localized, message: "login.error.kickedOffline".localized)
        case .loginExpired:
            showAlert(title: "common.warning".localized, message: "login.error.loginExpired".localized)
        @unknown default:
            break
        }
    }

    // MARK: - Navigation

    /// After a successful login, check whether the nickname is empty to decide whether to navigate to the profile setup page or the feature list
    private func checkProfileAndNavigate() {
        let userInfo = LoginStore.shared.state.value.loginUserInfo
        let nickname = userInfo?.nickname ?? ""

        if nickname.isEmpty {
            // Nickname is empty -> navigate to the profile setup page
            let profileVC = ProfileSetupViewController()
            navigationController?.setViewControllers([profileVC], animated: true)
        } else {
            // Nickname is already set -> go directly to the feature list
            navigateToFeatureList()
        }
    }

    private func navigateToFeatureList() {
        let featureListVC = FeatureListViewController()
        navigationController?.setViewControllers([featureListVC], animated: true)
    }

    // MARK: - UI Helpers

    private func setLoading(_ loading: Bool) {
        loginButton.isEnabled = !loading
        loginButton.setTitle(loading ? "" : "login.button".localized, for: .normal)

        if loading {
            view.makeToastActivity(.center)
        } else {
            view.hideToastActivity()
        }
    }

    private func showAlert(title: String, message: String) {
        let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "common.confirm".localized, style: .default))
        present(alert, animated: true)
    }

    /// Restore the last logged-in user ID from the local cache and auto-fill it into the text field
    /// If no cache exists, generate and cache a random User ID to avoid multiple devices using the same ID
    private func restoreCachedUserID() {
        if let cachedUserID = UserDefaults.standard.string(forKey: LoginViewController.cachedUserIDKey),
           !cachedUserID.isEmpty {
            userIDTextField.text = cachedUserID
        } else {
            let randomUserID = generateRandomUserID()
            userIDTextField.text = randomUserID
            UserDefaults.standard.set(randomUserID, forKey: LoginViewController.cachedUserIDKey)
        }
    }

    /// Generate a random numeric User ID (9 random digits)
    /// This ID is also used as the host's room ID
    private func generateRandomUserID() -> String {
        let randomID = Int.random(in: 100_000_000...999_999_999)
        return String(randomID)
    }
}
