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
    
    private var cancellables = Set<AnyCancellable>()
    private var hasFinished = false
    private let networkService = LoginNetworkService()
    private var currentMode: LoginMode = .phoneVerify
    
    init(completion: @escaping (Result<LoginResult, LoginError>) -> Void) {
        self.completion = completion
    }
    
    func buildViewController(mode: LoginMode) -> UIViewController {
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
        let store = IOAAuthStore()
        store.onBack = { [weak self] in
            self?.pop()
        }
        subscribeStoreResult(store.resultPublisher)
        
        let vc = UIViewController()
        let view = IOAAuthView(store: store)
        vc.view = view
        showViewController(vc, animated: animated)
        #endif
    }
    
    #if LOGIN_FULL
    func handleIOATicket(_ ticket: String) {
        if let topView = navigationController.topViewController?.view as? IOAAuthView {
            topView.store.loginWithTicket(ticket)
            ITLogin.sharedInstance().dimissLoginView()
        }
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
    
    // MARK: - DebugRegister
    
    private func pushDebugRegister(store: DebugAuthStore) {
        let vc = UIViewController()
        vc.title = LoginLocalize("Demo.TRTC.Login.regist")
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
        let vc = UIViewController()
        vc.title = LoginLocalize("Demo.TRTC.Login.regist")
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
                    topView.makeToast(LoginLocalize("Demo.TRTC.Login.registsuccess"))
                }
                self.finish(result: .success(updatedResult))
            case .failure(let error):
                if let topView = self.navigationController.topViewController?.view {
                    topView.makeToast(error.message)
                }
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
    
    private func subscribeStoreResult(_ publisher: AnyPublisher<Result<LoginResult, LoginError>, Never>) {
        publisher
            .first()
            .receive(on: RunLoop.main)
            .sink { [weak self] result in
                guard let self = self else { return }
                switch result {
                case .success(let loginResult):
                    self.handleLoginSuccessWithRegistrationCheck(loginResult: loginResult)
                case .failure:
                    self.finish(result: result)
                }
            }
            .store(in: &cancellables)
    }
    
    private func handleLoginSuccessWithRegistrationCheck(loginResult: LoginResult) {
        if case .debugAuth = currentMode {
            finish(result: .success(loginResult))
            return
        }
        
        if loginResult.userModel.avatar.isEmpty {
            pushRegister(pendingResult: loginResult)
        } else {
            finish(result: .success(loginResult))
        }
    }
    
    private func finish(result: Result<LoginResult, LoginError>) {
        guard !hasFinished else { return }
        hasFinished = true
        completion(result)
    }
}

extension LoginNavigator: UIAdaptivePresentationControllerDelegate {
    func presentationControllerDidDismiss(_ presentationController: UIPresentationController) {
        finish(result: .failure(.cancelled))
    }
}
