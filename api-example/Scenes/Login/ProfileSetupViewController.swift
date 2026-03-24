import UIKit
import SnapKit
import Toast_Swift
import AtomicXCore
import Kingfisher

/**
 * Business scenario: profile setup page
 *
 * This page is shown after a successful login when the user's nickname is empty, guiding the user to set a nickname and avatar.
 *
 * APIs involved:
 * - LoginStore.shared.setSelfInfo(userProfile:completion:) - Sets profile information
 * - LoginStore.shared.state.value.loginUserInfo - Gets the current user information
 *
 * Interaction details:
 * - The nickname field is initialized with a random English name that the user can freely edit
 * - One of five preset avatar URLs is randomly selected by default, and the user can tap to switch avatars
 * - A "Skip" button is shown on the right side of the navigation bar so the user can skip profile setup and go directly to the feature list
 * - Tapping the "Done" button submits the nickname and avatar to the server
 */
class ProfileSetupViewController: UIViewController {

    // MARK: - Constants

    /// Preset avatar URL list
    private let avatarURLs: [String] = [
        "https://liteav.sdk.qcloud.com/app/res/picture/voiceroom/avatar/user_avatar1.png",
        "https://liteav.sdk.qcloud.com/app/res/picture/voiceroom/avatar/user_avatar2.png",
        "https://liteav.sdk.qcloud.com/app/res/picture/voiceroom/avatar/user_avatar3.png",
        "https://liteav.sdk.qcloud.com/app/res/picture/voiceroom/avatar/user_avatar4.png",
        "https://liteav.sdk.qcloud.com/app/res/picture/voiceroom/avatar/user_avatar5.png",
    ]

    /// Preset random nickname list
    private let randomNicknames: [String] = [
        "Alex", "Jordan", "Taylor", "Morgan", "Casey",
        "Riley", "Avery", "Quinn", "Harper", "Skyler",
    ]

    // MARK: - Properties

    /// The index of the currently selected avatar
    private var selectedAvatarIndex: Int = 0

    // MARK: - UI Components

    private let headerLabel: UILabel = {
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
        label.numberOfLines = 0
        return label
    }()

    /// Large preview of the currently selected avatar
    private let selectedAvatarView: UIImageView = {
        let imageView = UIImageView()
        imageView.contentMode = .scaleAspectFill
        imageView.clipsToBounds = true
        imageView.layer.cornerRadius = 50
        imageView.layer.borderWidth = 3
        imageView.layer.borderColor = UIColor.systemBlue.cgColor
        imageView.backgroundColor = .systemGray5
        return imageView
    }()

    /// Avatar selector (five selectable avatars arranged horizontally)
    private lazy var avatarStackView: UIStackView = {
        let stack = UIStackView()
        stack.axis = .horizontal
        stack.spacing = 12
        stack.alignment = .center
        stack.distribution = .equalSpacing
        return stack
    }()

    /// Nickname text field
    private let nicknameTextField: UITextField = {
        let textField = UITextField()
        textField.borderStyle = .roundedRect
        textField.autocapitalizationType = .none
        textField.autocorrectionType = .no
        textField.clearButtonMode = .whileEditing
        textField.font = .systemFont(ofSize: 16)
        return textField
    }()

    /// Random nickname button (dice icon on the right side of the text field)
    private lazy var randomNicknameButton: UIButton = {
        let button = UIButton(type: .system)
        let config = UIImage.SymbolConfiguration(pointSize: 18, weight: .medium)
        button.setImage(UIImage(systemName: "dice.fill", withConfiguration: config), for: .normal)
        button.addTarget(self, action: #selector(randomNicknameTapped), for: .touchUpInside)
        return button
    }()

    /// Done button
    private let confirmButton: UIButton = {
        let button = UIButton(type: .system)
        button.titleLabel?.font = .systemFont(ofSize: 16, weight: .semibold)
        button.backgroundColor = .systemBlue
        button.setTitleColor(.white, for: .normal)
        button.layer.cornerRadius = 8
        return button
    }()

    // MARK: - Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        setupActions()
        updateLocalizedText()
        randomizeDefaults()
    }

    // MARK: - Setup

    private func setupUI() {
        view.backgroundColor = .systemBackground

        // Navigation bar - Skip button
        let skipButton = UIBarButtonItem(
            title: "profile.skip".localized,
            style: .plain,
            target: self,
            action: #selector(skipTapped)
        )
        navigationItem.rightBarButtonItem = skipButton
        navigationItem.hidesBackButton = true

        // Add subviews
        view.addSubview(headerLabel)
        view.addSubview(subtitleLabel)
        view.addSubview(selectedAvatarView)
        view.addSubview(avatarStackView)
        view.addSubview(nicknameTextField)
        view.addSubview(randomNicknameButton)
        view.addSubview(confirmButton)

        // Layout
        headerLabel.snp.makeConstraints { make in
            make.top.equalTo(view.safeAreaLayoutGuide).offset(40)
            make.leading.trailing.equalToSuperview().inset(24)
        }

        subtitleLabel.snp.makeConstraints { make in
            make.top.equalTo(headerLabel.snp.bottom).offset(8)
            make.leading.trailing.equalToSuperview().inset(24)
        }

        selectedAvatarView.snp.makeConstraints { make in
            make.top.equalTo(subtitleLabel.snp.bottom).offset(32)
            make.centerX.equalToSuperview()
            make.width.height.equalTo(100)
        }

        avatarStackView.snp.makeConstraints { make in
            make.top.equalTo(selectedAvatarView.snp.bottom).offset(20)
            make.centerX.equalToSuperview()
            make.height.equalTo(48)
        }

        // Create five avatar options
        for (index, _) in avatarURLs.enumerated() {
            let avatarButton = createAvatarOptionButton(index: index)
            avatarStackView.addArrangedSubview(avatarButton)
        }

        nicknameTextField.snp.makeConstraints { make in
            make.top.equalTo(avatarStackView.snp.bottom).offset(32)
            make.leading.equalToSuperview().offset(24)
            make.trailing.equalTo(randomNicknameButton.snp.leading).offset(-8)
            make.height.equalTo(44)
        }

        randomNicknameButton.snp.makeConstraints { make in
            make.centerY.equalTo(nicknameTextField)
            make.trailing.equalToSuperview().offset(-24)
            make.width.height.equalTo(44)
        }

        confirmButton.snp.makeConstraints { make in
            make.top.equalTo(nicknameTextField.snp.bottom).offset(32)
            make.leading.trailing.equalToSuperview().inset(24)
            make.height.equalTo(48)
        }
    }

    private func updateLocalizedText() {
        navigationItem.title = "profile.title".localized
        headerLabel.text = "profile.header".localized
        subtitleLabel.text = "profile.subtitle".localized
        nicknameTextField.placeholder = "profile.nickname.placeholder".localized
        confirmButton.setTitle("profile.confirm".localized, for: .normal)
    }

    private func setupActions() {
        confirmButton.addTarget(self, action: #selector(confirmTapped), for: .touchUpInside)

        let tapGesture = UITapGestureRecognizer(target: self, action: #selector(dismissKeyboard))
        tapGesture.cancelsTouchesInView = false
        view.addGestureRecognizer(tapGesture)
    }

    /// Randomly initialize the default nickname and avatar
    private func randomizeDefaults() {
        // Random nickname
        let randomName = randomNicknames.randomElement() ?? "User"
        nicknameTextField.text = randomName

        // Random avatar
        selectedAvatarIndex = Int.random(in: 0..<avatarURLs.count)
        updateSelectedAvatar()
    }

    // MARK: - Avatar Selection

    private func createAvatarOptionButton(index: Int) -> UIButton {
        let button = UIButton(type: .custom)
        button.tag = index
        button.layer.cornerRadius = 22
        button.clipsToBounds = true
        button.layer.borderWidth = 2
        button.layer.borderColor = UIColor.clear.cgColor
        button.backgroundColor = .systemGray5

        button.snp.makeConstraints { make in
            make.width.height.equalTo(44)
        }

        // Load the avatar image
        if let url = URL(string: avatarURLs[index]) {
            button.kf.setImage(with: url, for: .normal)
            button.imageView?.contentMode = .scaleAspectFill
        }

        button.addTarget(self, action: #selector(avatarOptionTapped(_:)), for: .touchUpInside)
        return button
    }

    @objc private func avatarOptionTapped(_ sender: UIButton) {
        selectedAvatarIndex = sender.tag
        updateSelectedAvatar()
    }

    /// Update the highlighted state of the selected avatar and the large avatar preview
    private func updateSelectedAvatar() {
        // Update the highlight state of the selection frame
        for case let button as UIButton in avatarStackView.arrangedSubviews {
            if button.tag == selectedAvatarIndex {
                button.layer.borderColor = UIColor.systemBlue.cgColor
                button.transform = CGAffineTransform(scaleX: 1.1, y: 1.1)
            } else {
                button.layer.borderColor = UIColor.clear.cgColor
                button.transform = .identity
            }
        }

        // Update the large avatar preview
        if let url = URL(string: avatarURLs[selectedAvatarIndex]) {
            selectedAvatarView.kf.setImage(with: url)
        }
    }

    // MARK: - Actions

    @objc private func skipTapped() {
        navigateToFeatureList()
    }

    @objc private func randomNicknameTapped() {
        nicknameTextField.text = randomNicknames.randomElement() ?? "User"
    }

    @objc private func confirmTapped() {
        dismissKeyboard()

        guard let nickname = nicknameTextField.text, !nickname.trimmingCharacters(in: .whitespaces).isEmpty else {
            view.makeToast("profile.error.emptyNickname".localized)
            return
        }

        saveSelfInfo(nickname: nickname.trimmingCharacters(in: .whitespaces),
                     avatarURL: avatarURLs[selectedAvatarIndex])
    }

    @objc private func dismissKeyboard() {
        view.endEditing(true)
    }

    // MARK: - Save Info

    private func saveSelfInfo(nickname: String, avatarURL: String) {
        setLoading(true)

        let userID = LoginStore.shared.state.value.loginUserInfo?.userID ?? ""
        var profile = UserProfile(userID: userID, nickname: nickname, avatarURL: avatarURL)
        profile.nickname = nickname
        profile.avatarURL = avatarURL

        LoginStore.shared.setSelfInfo(userProfile: profile) { [weak self] result in
            guard let self = self else { return }
            DispatchQueue.main.async {
                self.setLoading(false)
                switch result {
                case .success:
                    self.view.makeToast("profile.status.saved".localized) { _ in
                        self.navigateToFeatureList()
                    }
                case .failure(let error):
                    self.view.makeToast(String(format: "profile.error.saveFailed".localized, error.message))
                }
            }
        }
    }

    // MARK: - Navigation

    private func navigateToFeatureList() {
        let featureListVC = FeatureListViewController()
        navigationController?.setViewControllers([featureListVC], animated: true)
    }

    // MARK: - UI Helpers

    private func setLoading(_ loading: Bool) {
        confirmButton.isEnabled = !loading
        confirmButton.setTitle(loading ? "" : "profile.confirm".localized, for: .normal)
        navigationItem.rightBarButtonItem?.isEnabled = !loading

        if loading {
            view.makeToastActivity(.center)
        } else {
            view.hideToastActivity()
        }
    }


}
