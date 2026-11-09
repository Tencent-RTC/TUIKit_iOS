import AtomicXCore
import Combine
import UIKit

final class LoginViewController: UIViewController, LoginViewDelegate {
    var allowsAutomaticLogin = true
    private let rootView = LoginView()
    private var isLoggingIn = false
    private var requestID = UUID()
    private var profileSubscription: AnyCancellable?

    override func loadView() { view = rootView }

    override func viewDidLoad() {
        super.viewDidLoad()
        rootView.delegate = self
        let cached = UserDefaults.standard.string(forKey: "UserIdKey") ?? ""
        rootView.userIdTextField.text = cached
        if allowsAutomaticLogin, !cached.isEmpty, UserDefaults.standard.bool(forKey: "AutoLoginKey") { loginDelegate(userId: cached) }
    }

    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        requestID = UUID()
        profileSubscription = nil
        setLoading(false)
    }

    func loginDelegate(userId: String) {
        let userID = userId.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !isLoggingIn, !userID.isEmpty else { return }
        let signature = GenerateTestUserSig.genTestUserSig(identifier: userID)
        guard SDKAPPID > 0, !signature.isEmpty else {
            view.showAtomicToast(text: "SDKAppID / UserSig configuration is missing")
            return
        }
        setLoading(true)
        requestID = UUID()
        let request = requestID
        LoginStore.shared.login(sdkAppID: Int32(SDKAPPID), userID: userID, userSig: signature) { [weak self] result in
            DispatchQueue.main.async {
                guard let self, self.requestID == request else { return }
                switch result {
                case .success:
                    UserDefaults.standard.set(userID, forKey: "UserIdKey")
                    KeyMetrics.reportAtomicMetrics(1302)
                    self.awaitProfile(request: request)
                case .failure(let error):
                    self.setLoading(false)
                    self.view.showAtomicToast(text: error.message)
                }
            }
        }
    }

    private func awaitProfile(request: UUID) {
        profileSubscription = LoginStore.shared.state.subscribe()
            .receive(on: DispatchQueue.main)
            .sink { [weak self] state in
                guard let self, self.requestID == request, let profile = state.loginUserInfo, !profile.userID.isEmpty else { return }
                self.finishLogin(profile: profile, request: request)
            }
        DispatchQueue.main.asyncAfter(deadline: .now() + 5) { [weak self] in
            guard let self, self.requestID == request else { return }
            if let profile = LoginStore.shared.state.value.loginUserInfo, !profile.userID.isEmpty {
                self.finishLogin(profile: profile, request: request)
            } else {
                self.requestID = UUID()
                self.profileSubscription = nil
                self.setLoading(false)
                self.view.showAtomicToast(text: "Login profile timed out")
            }
        }
    }

    private func finishLogin(profile: UserProfile, request: UUID) {
        guard requestID == request else { return }
        requestID = UUID()
        profileSubscription = nil
        setLoading(false)
        if (profile.nickname ?? "").isEmpty {
            navigationController?.pushViewController(RegisterViewController(), animated: true)
        } else {
            (UIApplication.shared.delegate as? AppDelegate)?.showMainViewController()
        }
    }

    private func setLoading(_ loading: Bool) {
        isLoggingIn = loading
        rootView.setLoading(loading)
    }

    func testModeSwitchChanged(isOn: Bool) { view.showAtomicToast(text: "Not integrated yet".localized) }
    func autoLoginSwitchChanged(isOn: Bool) { UserDefaults.standard.set(isOn, forKey: "AutoLoginKey") }
}
