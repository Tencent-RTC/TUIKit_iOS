import TUILiveKit
import UIKit

final class LoginViewController: UIViewController, UITextFieldDelegate {
    private static let userIDMaxLength = 20
    private static let allowedUserIDCharacters = CharacterSet(
        charactersIn: "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789"
    )

    var onLogin: ((String) -> Void)?

    private let initialUserID: String
    private let userIDField = UITextField()
    private let loginButton = UIButton(type: .system)

    init(userID: String) {
        initialUserID = userID
        super.init(nibName: nil, bundle: nil)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = UIColor(red: 234 / 255, green: 241 / 255, blue: 251 / 255, alpha: 1)
        configureBackgroundDecoration()
        configureContent()
    }

    override var preferredStatusBarStyle: UIStatusBarStyle {
        .darkContent
    }

    func setLoading(_ isLoading: Bool) {
        loadViewIfNeeded()
        loginButton.isEnabled = !isLoading
    }

    private func configureBackgroundDecoration() {
        addDecoration(color: .white, size: 120, leading: -30, top: 20)
        addDecoration(
            color: UIColor(red: 245 / 255, green: 249 / 255, blue: 254 / 255, alpha: 1),
            size: 140,
            leading: 80,
            top: -40
        )
        addDecoration(color: .white, size: 90, trailing: 20, top: 60)
        addDecoration(
            color: UIColor(red: 245 / 255, green: 249 / 255, blue: 254 / 255, alpha: 1),
            size: 80,
            trailing: -60,
            top: 140
        )
    }

    private func addDecoration(
        color: UIColor,
        size: CGFloat,
        leading: CGFloat? = nil,
        trailing: CGFloat? = nil,
        top: CGFloat
    ) {
        let decoration = UIView()
        decoration.backgroundColor = color
        decoration.layer.cornerRadius = 16
        decoration.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(decoration)

        var constraints = [
            decoration.widthAnchor.constraint(equalToConstant: size),
            decoration.heightAnchor.constraint(equalToConstant: size),
            decoration.topAnchor.constraint(equalTo: view.topAnchor, constant: top),
        ]
        if let leading {
            constraints.append(decoration.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: leading))
        }
        if let trailing {
            constraints.append(decoration.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: trailing))
        }
        NSLayoutConstraint.activate(constraints)
    }

    private func configureContent() {
        let brandIcon = UIImageView(image: UIImage(named: "app_ic_cloud_brand"))
        brandIcon.contentMode = .scaleAspectFit
        brandIcon.translatesAutoresizingMaskIntoConstraints = false

        let brandLabel = UILabel()
        brandLabel.text = NSLocalizedString("livekit_access.brand", comment: "")
        brandLabel.textColor = UIColor(white: 26 / 255, alpha: 1)
        brandLabel.font = .boldSystemFont(ofSize: 24)

        let brandStack = UIStackView(arrangedSubviews: [brandIcon, brandLabel])
        brandStack.axis = .horizontal
        brandStack.alignment = .center
        brandStack.spacing = 10
        brandStack.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(brandStack)

        let phoneIcon = UIImageView(image: UIImage(named: "app_ic_phone"))
        phoneIcon.contentMode = .scaleAspectFit
        phoneIcon.translatesAutoresizingMaskIntoConstraints = false

        userIDField.text = initialUserID
        userIDField.placeholder = NSLocalizedString("livekit_access.user_id.placeholder", comment: "")
        userIDField.textColor = UIColor(white: 26 / 255, alpha: 1)
        userIDField.font = .systemFont(ofSize: 16)
        userIDField.autocorrectionType = .no
        userIDField.autocapitalizationType = .none
        userIDField.returnKeyType = .done
        userIDField.clearButtonMode = .whileEditing
        userIDField.delegate = self

        let inputStack = UIStackView(arrangedSubviews: [phoneIcon, userIDField])
        inputStack.axis = .horizontal
        inputStack.alignment = .center
        inputStack.spacing = 12
        inputStack.layoutMargins = UIEdgeInsets(top: 0, left: 16, bottom: 0, right: 16)
        inputStack.isLayoutMarginsRelativeArrangement = true
        // The row is positioned against the parent's safe area already. Keep
        // its fixed-height content margins independent of transient safe insets.
        inputStack.insetsLayoutMarginsFromSafeArea = false
        inputStack.backgroundColor = .white
        inputStack.layer.borderWidth = 1
        inputStack.layer.borderColor = UIColor(red: 51 / 255, green: 112 / 255, blue: 1, alpha: 1).cgColor
        inputStack.layer.cornerRadius = 8
        inputStack.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(inputStack)

        loginButton.setTitle(NSLocalizedString("livekit_access.login", comment: ""), for: .normal)
        loginButton.setTitleColor(.white, for: .normal)
        loginButton.titleLabel?.font = .systemFont(ofSize: 18)
        loginButton.backgroundColor = UIColor(red: 51 / 255, green: 112 / 255, blue: 1, alpha: 1)
        loginButton.layer.cornerRadius = 28
        loginButton.addTarget(self, action: #selector(login), for: .touchUpInside)
        loginButton.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(loginButton)

        NSLayoutConstraint.activate([
            brandIcon.widthAnchor.constraint(equalToConstant: 44),
            brandIcon.heightAnchor.constraint(equalToConstant: 44),
            brandStack.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            brandStack.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 100),

            phoneIcon.widthAnchor.constraint(equalToConstant: 20),
            phoneIcon.heightAnchor.constraint(equalToConstant: 20),
            inputStack.leadingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.leadingAnchor, constant: 24),
            inputStack.trailingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.trailingAnchor, constant: -24),
            inputStack.topAnchor.constraint(equalTo: brandStack.bottomAnchor, constant: 40),
            inputStack.heightAnchor.constraint(equalToConstant: 56),

            loginButton.leadingAnchor.constraint(equalTo: inputStack.leadingAnchor),
            loginButton.trailingAnchor.constraint(equalTo: inputStack.trailingAnchor),
            loginButton.topAnchor.constraint(equalTo: inputStack.bottomAnchor, constant: 24),
            loginButton.heightAnchor.constraint(equalToConstant: 56),
        ])
    }

    @objc private func login() {
        let userID = userIDField.text?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        guard !userID.isEmpty else {
            LiveToast.show(NSLocalizedString("livekit_access.user_id.required", comment: ""))
            return
        }
        onLogin?(userID)
    }

    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        textField.resignFirstResponder()
        return true
    }

    func textField(
        _ textField: UITextField,
        shouldChangeCharactersIn range: NSRange,
        replacementString string: String
    ) -> Bool {
        guard !string.isEmpty else {
            return true
        }
        guard string.unicodeScalars.allSatisfy({ Self.allowedUserIDCharacters.contains($0) }) else {
            return false
        }
        let currentText = textField.text ?? ""
        guard let textRange = Range(range, in: currentText) else {
            return false
        }
        let updatedText = currentText.replacingCharacters(in: textRange, with: string)
        return updatedText.count <= Self.userIDMaxLength
    }
}
