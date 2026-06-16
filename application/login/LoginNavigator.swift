//
//  LoginNavigator.swift
//  login
//

import UIKit
import Combine
import Toast_Swift
#if LOGIN_FULL
import ITLogin
#endif

final class LoginNavigator: NSObject {
    
    private let navigationController = UINavigationController()
    private let completion: (Result<LoginResult, LoginError>) -> Void
    
    var onLoginModeChanged: ((LoginMode) -> Void)?

    var onEnvironmentChanged: ((ServerEnvironment) -> Void)?

    var onPrivacyAgreed: ((_ isAgree: Bool) -> Void)?
    
    private var cancellables = Set<AnyCancellable>()
    private var hasFinished = false
    private let networkService = LoginNetworkService()
    private var currentMode: LoginMode = .phoneVerify
    
    init(completion: @escaping (Result<LoginResult, LoginError>) -> Void) {
        self.completion = completion
    }
    
    func buildViewController(mode: LoginMode) -> UIViewController {
        LoginLogger.Login.info("LoginNavigator.buildViewController mode=\(mode)")
        currentMode = mode
        navigationController.setNavigationBarHidden(true, animated: false)
        navigationController.modalPresentationStyle = .fullScreen
        navigationController.presentationController?.delegate = self
        
        if mode != .menu {
            onLoginModeChanged?(mode)
        }
        
        switch mode {
        case .phoneVerify:
            pushPhoneVerify(animated: false)
        case .emailVerify:
            pushEmailVerify(animated: false)
        case .ioaAuth:
            pushIOAAuth(animated: false)
        case .inviteCode:
            pushInviteCode(animated: false)
        case .debugAuth:
            pushDebugAuthDirect(animated: false)
        case .menu:
            pushDevLoginMenu(animated: false)
        }

        #if !RTCUBE_OVERSEAS && !RTCUBE_LAB && !OPEN_SOURCE
        DispatchQueue.main.async { [weak self] in
            self?.showPrivacyAlertIfNeeded()
        }
        #endif

        return navigationController
    }
    
    // MARK: - PhoneVerify
    
    func pushPhoneVerify(animated: Bool = true) {
        let store = PhoneVerifyStore()
        store.onSwitchToIOA = { [weak self] in
            self?.pushIOAAuth()
        }
        subscribeStoreResult(store.resultPublisher)
        
        let vc = UIViewController()
        let view = PhoneVerifyView(store: store)
        view.navigationController = navigationController
        vc.view = view
        showViewController(vc, animated: animated)
    }
    
    // MARK: - EmailVerify
    
    func pushEmailVerify(animated: Bool = true) {
        let store = EmailVerifyStore()
        store.onSwitchToIOA = { [weak self] in
            self?.pushIOAAuth()
        }
        store.onNavigateToInviteCode = { [weak self] email in
            self?.pushInviteCode(emailAddress: email)
        }
        subscribeStoreResult(store.resultPublisher)
        
        let vc = UIViewController()
        let view = EmailVerifyView(store: store)
        view.navigationController = navigationController
        vc.view = view
        showViewController(vc, animated: animated)
    }
    
    // MARK: - IOAAuth

    func pushIOAAuth(animated: Bool = true) {
        #if LOGIN_FULL
        let resultBridge = PassthroughSubject<Result<LoginResult, LoginError>, Never>()
        subscribeStoreResult(resultBridge.eraseToAnyPublisher())

        let ioaVC = IOAAuthViewController { [weak self] result in
            switch result {
            case .success(let loginResult):
                resultBridge.send(.success(loginResult))
            case .failure:
                break
            case .cancelled:
                if self?.navigationController.viewControllers.count ?? 0 <= 1 {
                    self?.finish(result: .failure(.cancelled))
                }
            }
        }

        IOAAuthManager.shared.activeIOAViewController = ioaVC
        navigationController.present(ioaVC, animated: animated)
        #endif
    }

    #if LOGIN_FULL
    func handleIOATicket(_ ticket: String) {
        IOAAuthManager.shared.activeIOAViewController?.handleTicket(ticket)
    }
    #endif
    
    // MARK: - InviteCode
    
    func pushInviteCode(emailAddress: String? = nil, animated: Bool = true) {
        let store = InviteCodeStore(emailAddress: emailAddress)
        store.onBack = { [weak self] in
            self?.pop()
        }
        subscribeStoreResult(store.resultPublisher)
        
        let vc = UIViewController()
        let view = InviteCodeView(store: store)
        vc.view = view
        showViewController(vc, animated: animated)
    }
    
    // MARK: - DebugAuth
    
    private func pushDevLoginMenu(animated: Bool = true) {
        let menuVC = DevLoginMenuViewController()
        menuVC.onSelectMode = { [weak self] selectedMode in
            guard let self = self else { return }
            LoginLogger.Login.info("LoginNavigator.devMenu.onSelectMode \(selectedMode) (currentMode \(self.currentMode) -> \(selectedMode))")
            self.currentMode = selectedMode
            self.onLoginModeChanged?(selectedMode)
            switch selectedMode {
            case .phoneVerify:
                self.pushPhoneVerify()
            case .emailVerify:
                self.pushEmailVerify()
            case .ioaAuth:
                self.pushIOAAuth()
            case .inviteCode:
                self.pushInviteCode()
            case .debugAuth:
                self.pushDebugAuthDirect()
            default:
                break
            }
        }
        menuVC.onEnvironmentChanged = { [weak self] env in
            self?.onEnvironmentChanged?(env)
        }
        showViewController(menuVC, animated: animated)
    }
    
    private func pushDebugAuthDirect(animated: Bool = true) {
        LoginLogger.Login.info("LoginNavigator.pushDebugAuthDirect")
        let store = LoginEntry.shared.debugAuthStore
        store.onNeedsRegister = { [weak self] in
            guard let self = self else { return }
            self.pushDebugRegister(store: store)
        }
        subscribeStoreResult(store.resultPublisher)

        let vc = UIViewController()
        let view = DebugAuthView(store: store)
        vc.view = view
        showViewController(vc, animated: animated)
    }

    func pushDebugAuthWithCredentials(_ credentials: HiddenConfigCredentials) {
        let store = LoginEntry.shared.debugAuthStore
        store.updateUserName(credentials.userId)
        store.onNeedsRegister = { [weak self] in
            guard let self = self else { return }
            self.pushDebugRegister(store: store)
        }
        subscribeStoreResult(store.resultPublisher)

        let vc = UIViewController()
        let debugAuthView = DebugAuthView(store: store)
        debugAuthView.isUserIdEditable = false
        debugAuthView.onBack = { [weak self] in
            self?.pop()
        }
        vc.view = debugAuthView
        navigationController.pushViewController(vc, animated: true)

        store.loginWithCredentials(credentials)
    }
    
    // MARK: - DebugRegister
    
    private func pushDebugRegister(store: DebugAuthStore) {
        LoginLogger.Login.info("LoginNavigator.pushDebugRegister")
        let vc = UIViewController()
        vc.title = LoginLocalize("login_profile_title")
        let registerView = RegisterView()
        registerView.setAvatarURL(store.state.avatarURL)
        
        registerView.onRegisterButtonTapped = { [weak store] nickName, _ in
            store?.register(nickName: nickName)
        }
        registerView.onHeadImageTapped = { [weak self, weak registerView] in
            guard let self = self else { return }
            let viewModel = AvatarViewModel()
            let alertView = AvatarListAlertView(viewModel: viewModel)
            alertView.didClickConfirmBtn = { [weak store, weak registerView] in
                guard let selectedModel = viewModel.currentSelectAvatarModel else { return }
                store?.updateAvatar(selectedModel.url)
                registerView?.setAvatarURL(selectedModel.url)
            }
            if let window = self.navigationController.view.window {
                window.addSubview(alertView)
                alertView.snp.makeConstraints { make in
                    make.edges.equalToSuperview()
                }
                alertView.show()
            }
        }
        
        vc.view = registerView
        navigationController.pushViewController(vc, animated: true)
    }
    
    private func pushRegister(pendingResult: LoginResult) {
        LoginLogger.Login.info("LoginNavigator.pushRegister mode=\(currentMode) userId=\(pendingResult.userModel.userId)")
        let vc = UIViewController()
        vc.title = LoginLocalize("login_profile_title")
        let registerView = RegisterView()
        
        registerView.onRegisterButtonTapped = { [weak self] nickName, avatarURL in
            guard let self = self else { return }
            self.performRegister(nickName: nickName, avatarURL: avatarURL, pendingResult: pendingResult)
        }
        
        registerView.onHeadImageTapped = { [weak self, weak registerView] in
            guard let self = self else { return }
            let viewModel = AvatarViewModel()
            let alertView = AvatarListAlertView(viewModel: viewModel)
            alertView.didClickConfirmBtn = { [weak registerView] in
                guard let selectedModel = viewModel.currentSelectAvatarModel else { return }
                registerView?.setAvatarURL(selectedModel.url)
            }
            if let window = self.navigationController.view.window {
                window.addSubview(alertView)
                alertView.snp.makeConstraints { make in
                    make.edges.equalToSuperview()
                }
                alertView.show()
            }
        }
        
        vc.view = registerView
        navigationController.pushViewController(vc, animated: true)
    }
    
    private func performRegister(nickName: String, avatarURL: String, pendingResult: LoginResult) {
        LoginLogger.Login.info("LoginNavigator.performRegister begin mode=\(currentMode) nickName.len=\(nickName.count) avatarEmpty=\(avatarURL.isEmpty)")
        networkService.updateUserName(name: nickName) { [weak self] result in
            guard let self = self else { return }
            switch result {
            case .success:
                let latestUser: UserModel
                if let rawUser = LoginManager.shared.getCurrentUser() {
                    latestUser = UserModel(
                        userId: rawUser.userId,
                        token: rawUser.token,
                        userSig: rawUser.userSig,
                        phone: rawUser.phone,
                        email: rawUser.email,
                        name: rawUser.name,
                        avatar: rawUser.avatar
                    )
                } else {
                    latestUser = UserModel(
                        userId: pendingResult.userModel.userId,
                        token: pendingResult.userModel.token,
                        userSig: pendingResult.userModel.userSig,
                        phone: pendingResult.userModel.phone,
                        email: pendingResult.userModel.email,
                        name: nickName,
                        avatar: avatarURL.isEmpty ? pendingResult.userModel.avatar : avatarURL
                    )
                }
                let updatedResult = LoginResult(userModel: latestUser, mode: currentMode)

                if let topView = self.navigationController.topViewController?.view {
                    topView.makeToast(LoginLocalize("login_profile_toast_register_success"))
                }
                LoginLogger.Login.info("LoginNavigator.performRegister SUCCESS userId=\(latestUser.userId) -> finish")
                self.finish(result: .success(updatedResult))
            case .failure(let error):
                if let topView = self.navigationController.topViewController?.view {
                    topView.makeToast(error.message)
                }
                LoginLogger.Login.warn("LoginNavigator.performRegister FAILED error=\(error.message), pop after 1s")
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) { [weak self] in
                    self?.navigationController.popViewController(animated: true)
                }
            }
        }
    }
    
    // MARK: - LanguageSelect
    
    private func rebuildCurrentLoginPage() {
        cancellables.removeAll()
        
        navigationController.setNavigationBarHidden(true, animated: false)
        
        switch currentMode {
        case .phoneVerify:
            rebuildPhoneVerify()
        case .emailVerify:
            rebuildEmailVerify()
        case .debugAuth:
            rebuildDebugAuth()
        case .menu:
            rebuildDebugMenu()
        case .ioaAuth, .inviteCode:
            navigationController.popViewController(animated: true)
        }
    }
    
    private func rebuildPhoneVerify() {
        let store = PhoneVerifyStore()
        store.onSwitchToIOA = { [weak self] in
            self?.pushIOAAuth()
        }
        subscribeStoreResult(store.resultPublisher)
        
        let vc = UIViewController()
        let view = PhoneVerifyView(store: store)
        view.navigationController = navigationController
        vc.view = view
        navigationController.setViewControllers([vc], animated: false)
    }
    
    private func rebuildEmailVerify() {
        let store = EmailVerifyStore()
        store.onSwitchToIOA = { [weak self] in
            self?.pushIOAAuth()
        }
        store.onNavigateToInviteCode = { [weak self] email in
            self?.pushInviteCode(emailAddress: email)
        }
        subscribeStoreResult(store.resultPublisher)
        
        let vc = UIViewController()
        let view = EmailVerifyView(store: store)
        view.navigationController = navigationController
        vc.view = view
        navigationController.setViewControllers([vc], animated: false)
    }
    
    private func rebuildDebugAuth() {
        let store = DebugAuthStore()
        store.onNeedsRegister = { [weak self] in
            guard let self = self else { return }
            self.pushDebugRegister(store: store)
        }
        subscribeStoreResult(store.resultPublisher)
        
        let vc = UIViewController()
        let view = DebugAuthView(store: store)
        vc.view = view
        navigationController.setViewControllers([vc], animated: false)
    }
    
    private func rebuildDebugMenu() {
        let menuVC = DevLoginMenuViewController()
        menuVC.onSelectMode = { [weak self] selectedMode in
            guard let self = self else { return }
            LoginLogger.Login.info("LoginNavigator.rebuildDebugMenu.onSelectMode \(selectedMode) (currentMode \(self.currentMode) -> \(selectedMode))")
            self.currentMode = selectedMode
            self.onLoginModeChanged?(selectedMode)
            switch selectedMode {
            case .phoneVerify:
                self.pushPhoneVerify()
            case .emailVerify:
                self.pushEmailVerify()
            case .ioaAuth:
                self.pushIOAAuth()
            case .inviteCode:
                self.pushInviteCode()
            case .debugAuth:
                self.pushDebugAuthDirect()
            default: break
            }
        }
        menuVC.onEnvironmentChanged = { [weak self] env in
            self?.onEnvironmentChanged?(env)
        }
        navigationController.setViewControllers([menuVC], animated: false)
    }
    
    private func showViewController(_ vc: UIViewController, animated: Bool) {
        if navigationController.viewControllers.isEmpty {
            navigationController.setViewControllers([vc], animated: false)
        } else {
            navigationController.pushViewController(vc, animated: animated)
        }
    }
    
    func pop(animated: Bool = true) {
        navigationController.popViewController(animated: animated)
    }

    private static let privacyAgreedKey = "com.rtcube.login.privacyAlertAgreed"

    private func showPrivacyAlertIfNeeded() {
        guard !UserDefaults.standard.bool(forKey: Self.privacyAgreedKey) else { return }
        guard let topVC = navigationController.topViewController else { return }
        let alertView = FirstLaunchPrivacyAlertView(superVC: navigationController)
        alertView.didClickConfirmBtn = { [weak self] in
            UserDefaults.standard.set(true, forKey: LoginNavigator.privacyAgreedKey)
            self?.onPrivacyAgreed?(true)
        }
        alertView.didClickCancelBtn = { [weak self] in
            self?.onPrivacyAgreed?(false)
        }
        topVC.view.addSubview(alertView)
        alertView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }
    }
    
    private func subscribeStoreResult(_ publisher: AnyPublisher<Result<LoginResult, LoginError>, Never>) {
        publisher
            .first()
            .receive(on: RunLoop.main)
            .sink { [weak self] result in
                guard let self = self else { return }
                switch result {
                case .success(let loginResult):
                    LoginLogger.Login.info("LoginNavigator.subscribeStoreResult success userId=\(loginResult.userModel.userId) mode=\(currentMode)")
                    self.handleLoginSuccessWithRegistrationCheck(loginResult: loginResult)
                case .failure(let error):
                    LoginLogger.Login.warn("LoginNavigator.subscribeStoreResult failure error=\(error)")
                    self.finish(result: result)
                }
            }
            .store(in: &cancellables)
    }
    
    private func handleLoginSuccessWithRegistrationCheck(loginResult: LoginResult) {
        if case .debugAuth = currentMode {
            LoginLogger.Login.info("LoginNavigator.handleLoginSuccess debugAuth -> finish (skip register check)")
            finish(result: .success(loginResult))
            return
        }

        if loginResult.userModel.avatar.isEmpty {
            LoginLogger.Login.info("LoginNavigator.handleLoginSuccess avatar empty mode=\(currentMode) -> pushRegister")
            pushRegister(pendingResult: loginResult)
        } else {
            LoginLogger.Login.info("LoginNavigator.handleLoginSuccess mode=\(currentMode) -> finish")
            finish(result: .success(loginResult))
        }
    }
    
    private func finish(result: Result<LoginResult, LoginError>) {
        guard !hasFinished else {
            LoginLogger.Login.info("LoginNavigator.finish ignored (already finished)")
            return
        }
        hasFinished = true
        switch result {
        case .success(let loginResult):
            LoginLogger.Login.info("LoginNavigator.finish SUCCESS userId=\(loginResult.userModel.userId) mode=\(loginResult.loginMode)")
        case .failure(let error):
            LoginLogger.Login.warn("LoginNavigator.finish FAILURE error=\(error)")
        }
        completion(result)
    }
}

extension LoginNavigator: UIAdaptivePresentationControllerDelegate {
    func presentationControllerDidDismiss(_ presentationController: UIPresentationController) {
        LoginLogger.Login.info("LoginNavigator.presentationControllerDidDismiss -> finish(.cancelled)")
        finish(result: .failure(.cancelled))
    }
}
