import AtomicXCore
import ChatUIKit
import RTCRoomEngine
import SnapKit
import TUICallKit_Swift
import UIKit

final class DemoLoginManager {
    static let shared = DemoLoginManager()

    static let localSdkAppID = ""

    static let localSecretKey = ""

    private(set) var currentUserID = ""

    func login(sdkAppID: Int32, userID: String, userSig: String, completion: @escaping (Bool, String?) -> Void) {
        LoginStore.shared.login(sdkAppID: sdkAppID, userID: userID, userSig: userSig) { [weak self] result in
            DispatchQueue.main.async {
                switch result {
                case .success:
                    self?.currentUserID = userID
                    self?.initCallEngine(sdkAppID: sdkAppID, userID: userID, userSig: userSig)
                    completion(true, nil)
                case .failure(let error):
                    completion(false, "\(LocalizedChatString("LoginFailed")): \(error.code), \(error.message)")
                }
            }
        }
    }

    private func initCallEngine(sdkAppID: Int32, userID: String, userSig: String) {
        TUICallEngine.createInstance().`init`(sdkAppID, userId: userID, userSig: userSig) {
            TUICallEngine.createInstance().enableMultiDeviceAbility(enable: true) {
            } fail: { code, message in
                print("[Login] enableMultiDeviceAbility failed: \(code), \(message ?? "")")
            }
            TUICallKit.createInstance().enableIncomingBanner(enable: true)
        } fail: { code, message in
            print("[Login] initCallEngine failed: \(code), \(message ?? "")")
        }
    }

    func logout(completion: @escaping (Bool) -> Void) {
        UserDefaults.standard.set("", forKey: LoginPersist.loginUser)
        UserDefaults.standard.set("", forKey: LoginPersist.loginType)
        LoginStore.shared.logout(completion: { [weak self] result in
            DispatchQueue.main.async {
                switch result {
                case .success:
                    self?.currentUserID = ""
                    completion(true)
                case .failure:
                    completion(false)
                }
            }
        })
    }
}

private enum LoginPersist {
    static let loginUser = "LoginUser"
    static let loginType = "LoginType"
    static let loginTypeLocal = "local"
}

final class AutoLoginViewController: UIViewController {
    static let didFailNotification = Notification.Name("DemoAutoLoginDidFailNotification")

    static var hasSavedCredentials: Bool {
        let type = UserDefaults.standard.string(forKey: LoginPersist.loginType) ?? ""
        let userID = UserDefaults.standard.string(forKey: LoginPersist.loginUser) ?? ""
        return type == LoginPersist.loginTypeLocal && !userID.isEmpty
    }

    private let loadingIndicator = UIActivityIndicatorView(style: .large)

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = ChatUIKitTheme.colors.bgColorOperate
        view.addSubview(loadingIndicator)
        loadingIndicator.snp.makeConstraints { make in
            make.center.equalToSuperview()
        }
        loadingIndicator.startAnimating()
        performAutoLogin()
    }

    private func performAutoLogin() {
        let type = UserDefaults.standard.string(forKey: LoginPersist.loginType) ?? ""
        let userID = UserDefaults.standard.string(forKey: LoginPersist.loginUser) ?? ""
        if type == LoginPersist.loginTypeLocal, !userID.isEmpty, let appID = Int32(DemoLoginManager.localSdkAppID) {
            let userSig = GenerateTestUserSig.genTestUserSig(userID: userID, sdkAppID: Int(appID), secretKey: DemoLoginManager.localSecretKey)
            performLogin(sdkAppID: appID, userID: userID, userSig: userSig, extraSave: nil)
            return
        }
        handleFailure()
    }

    private func performLogin(sdkAppID: Int32, userID: String, userSig: String, extraSave: (() -> Void)?) {
        DemoLoginManager.shared.login(sdkAppID: sdkAppID, userID: userID, userSig: userSig) { [weak self] success, _ in
            guard let self = self else { return }
            if success {
                extraSave?()
            } else {
                self.handleFailure()
            }
        }
    }

    private func handleFailure() {
        UserDefaults.standard.set("", forKey: LoginPersist.loginUser)
        UserDefaults.standard.set("", forKey: LoginPersist.loginType)
        NotificationCenter.default.post(name: Self.didFailNotification, object: nil)
    }
}
