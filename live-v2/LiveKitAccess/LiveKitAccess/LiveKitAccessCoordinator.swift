import AtomicXCore
import Combine
import TUILiveKit
import UIKit

final class LiveKitAccessCoordinator {
    private enum Constants {
        static let cachedUserIDKey = "livekit.access.loginUserID"
        static let avatarURLs = [
            "https://liteav.sdk.qcloud.com/app/res/picture/voiceroom/avatar/user_avatar1.png",
            "https://liteav.sdk.qcloud.com/app/res/picture/voiceroom/avatar/user_avatar2.png",
            "https://liteav.sdk.qcloud.com/app/res/picture/voiceroom/avatar/user_avatar3.png",
            "https://liteav.sdk.qcloud.com/app/res/picture/voiceroom/avatar/user_avatar4.png",
            "https://liteav.sdk.qcloud.com/app/res/picture/voiceroom/avatar/user_avatar5.png",
        ]
        static let nicknameKeys = [
            "livekit_access.user_name.1",
            "livekit_access.user_name.2",
            "livekit_access.user_name.3",
            "livekit_access.user_name.4",
            "livekit_access.user_name.5",
        ]
        static let profileWaitTimeout: TimeInterval = 5
        static let demoLoginSuccess = 1302
        static let demoClickLive = 1119
    }

    private var loginUserID: String

    private let window: UIWindow
    private let navigationController = RootNavigationController()
    private var cancellables = Set<AnyCancellable>()
    private var profileCancellable: AnyCancellable?

    init(window: UIWindow) {
        self.window = window
        self.loginUserID = Self.loadUserID()
    }

    private static func loadUserID() -> String {
        let defaults = UserDefaults.standard
        if let cached = defaults.string(forKey: Constants.cachedUserIDKey), !cached.isEmpty {
            return cached
        }
        let generated = String(Int.random(in: 1_000_000...9_999_999))
        defaults.set(generated, forKey: Constants.cachedUserIDKey)
        return generated
    }

    func start() {
        window.rootViewController = navigationController
        navigationController.navigationBar.prefersLargeTitles = false
        observeLoginEvents()
        showLogin()
    }

    private func observeLoginEvents() {
        LoginStore.shared.loginEventPublisher
            .receive(on: DispatchQueue.main)
            .sink { [weak self] event in
                switch event {
                case .kickedOffline:
                    self?.handleAccountKickedOffline()
                case .loginExpired:
                    self?.showLogin(message: NSLocalizedString("livekit_access.login.expired", comment: ""))
                @unknown default:
                    self?.showLogin(message: NSLocalizedString("livekit_access.login.state_changed", comment: ""))
                }
            }
            .store(in: &cancellables)
    }

    private func handleAccountKickedOffline() {
        let message = NSLocalizedString("livekit_access.login.kicked_offline", comment: "")
        if let pusher = navigationController.topViewController as? PusherViewController {
            // Let the component display its interrupted-session summary first.
            // Its existing exit action returns here instead of an invalid list.
            pusher.onExitAfterAccountInvalidation = { [weak self] in
                self?.showLogin(message: message)
            }
        } else {
            showLogin(message: message)
        }
    }

    private func login(userID: String, from controller: LoginViewController) {
        loginUserID = userID
        UserDefaults.standard.set(userID, forKey: Constants.cachedUserIDKey)
        let userSig = GenerateTestUserSig.genTestUserSig(userID)
        guard GenerateTestUserSig.SDKAPPID > 0,
              !userID.isEmpty,
              !userSig.isEmpty else {
            LiveToast.show(NSLocalizedString("livekit_access.login.missing_config", comment: ""))
            return
        }

        controller.setLoading(true)
        LoginStore.shared.login(
            sdkAppID: GenerateTestUserSig.SDKAPPID,
            userID: userID,
            userSig: userSig
        ) { [weak self, weak controller] result in
            DispatchQueue.main.async {
                switch result {
                case .success:
                    KeyMetrics.reportAtomicMetrics(Constants.demoLoginSuccess)
                    self?.ensureSelfInfo(userID: userID, from: controller)
                case .failure(let error):
                    controller?.setLoading(false)
                    guard controller?.viewIfLoaded?.window != nil else { return }
                    LiveToast.show(String(
                        format: NSLocalizedString("livekit_access.login.failed", comment: ""),
                        locale: Locale.current,
                        Int(error.code),
                        error.message
                    ))
                }
            }
        }
    }

    private func ensureSelfInfo(userID: String, from controller: LoginViewController?) {
        waitForLoginUserInfo { [weak self, weak controller] loginUserInfo in
            let nickname = loginUserInfo?.nickname ?? ""
            let avatarURL = loginUserInfo?.avatarURL ?? ""
            if nickname.isEmpty || avatarURL.isEmpty {
                self?.setSelfInfo(
                    userID: userID,
                    needsNickname: nickname.isEmpty,
                    needsAvatarURL: avatarURL.isEmpty,
                    from: controller
                )
            } else {
                controller?.setLoading(false)
                self?.showLiveList()
            }
        }
    }

    private func waitForLoginUserInfo(_ completion: @escaping (UserProfile?) -> Void) {
        func isReady(_ profile: UserProfile?) -> Bool {
            guard let profile else { return false }
            return !profile.userID.isEmpty
        }
        if isReady(LoginStore.shared.state.value.loginUserInfo) {
            completion(LoginStore.shared.state.value.loginUserInfo)
            return
        }
        var hasFinished = false
        let finish: (UserProfile?) -> Void = { [weak self] profile in
            guard !hasFinished else { return }
            hasFinished = true
            self?.profileCancellable = nil
            completion(profile)
        }

        profileCancellable = LoginStore.shared.state.subscribe()
            .receive(on: DispatchQueue.main)
            .sink { state in
                guard isReady(state.loginUserInfo) else { return }
                finish(state.loginUserInfo)
            }
        DispatchQueue.main.asyncAfter(deadline: .now() + Constants.profileWaitTimeout) {
            finish(LoginStore.shared.state.value.loginUserInfo)
        }
    }

    private func setSelfInfo(
        userID: String,
        needsNickname: Bool,
        needsAvatarURL: Bool,
        from controller: LoginViewController?
    ) {
        let nicknameKey = Constants.nicknameKeys.randomElement() ?? Constants.nicknameKeys[0]
        let userProfile = UserProfile(
            userID: userID,
            nickname: needsNickname ? NSLocalizedString(nicknameKey, comment: "") : nil,
            avatarURL: needsAvatarURL ? Constants.avatarURLs.randomElement() : nil
        )
        LoginStore.shared.setSelfInfo(userProfile: userProfile) { [weak self, weak controller] result in
            DispatchQueue.main.async {
                controller?.setLoading(false)
                switch result {
                case .success:
                    self?.showLiveList()
                case .failure(let error):
                    self?.showLiveList()
                }
            }
        }
    }

    private func showLogin(message: String? = nil) {
        let controller = LoginViewController(userID: loginUserID)
        controller.onLogin = { [weak self, weak controller] userID in
            guard let self, let controller else { return }
            self.login(userID: userID, from: controller)
        }
        navigationController.setViewControllers([controller], animated: false)
        if let message {
            DispatchQueue.main.async {
                LiveToast.show(message)
            }
        }
    }

    private func showLiveList() {
        KeyMetrics.reportAtomicMetrics(Constants.demoClickLive)
        let controller = WaterfallViewController()
        navigationController.setViewControllers([controller], animated: false)
    }

}

private final class RootNavigationController: UINavigationController {
    override var childForStatusBarStyle: UIViewController? {
        topViewController
    }
}
