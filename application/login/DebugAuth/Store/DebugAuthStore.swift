//
//  DebugAuthStore.swift
//  login
//

import Foundation
import Combine
import TUICore

class DebugAuthStore: LoginSubStore {
    
    // MARK: - State
    
    @Published private(set) var state = DebugAuthState()
    
    // MARK: - LoginSubStore
    
    private let resultSubject = PassthroughSubject<Result<LoginResult, LoginError>, Never>()
    var resultPublisher: AnyPublisher<Result<LoginResult, LoginError>, Never> {
        resultSubject.eraseToAnyPublisher()
    }
    
    // MARK: - Callbacks
    
    var onNeedsRegister: (() -> Void)?
    
    private var logoutCancellable: AnyCancellable?
    
    // MARK: - Init
    
    init() {
        logoutCancellable = subscribeLogout()
        if let userModel = ProfileManager.shared.getCurrentUser() {
            UserOverdueLogicManager.sharedManager().userOverdueState = .alreadyLogged
            state.userName = userModel.userId
        }
    }
    
    // MARK: - LoginSubStore
    
    func resetState() {
        state = DebugAuthState()
    }
    
    // MARK: - Public Methods
    
    func updateUserName(_ name: String) {
        state.userName = name
    }
    
    func login() {
        let phone = state.userName
        guard !phone.isEmpty else { return }
        
        state.isLoginEnabled = false
        state.isLoading = true
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 4.0) { [weak self] in
            self?.state.isLoginEnabled = true
        }
        
        let config = LoginEntry.shared.config
        guard let generator = LoginEntry.shared.userSigGenerator else {
            state.isLoading = false
            state.isLoginEnabled = true
            return
        }
        let userSig = generator(phone, config.sdkAppId, config.secretKey)
        
        ProfileManager.shared.login(phone: phone,
                                    name: "",
                                    token: userSig) { [weak self] in
            guard let self = self else { return }
            self.state.isLoading = false
            self.loginIM()
        }
    }
    
    func register(nickName: String) {
        state.isLoading = true
        
        ProfileManager.shared.synchronizUserInfo()
        ProfileManager.shared.setNickName(name: nickName) { [weak self] in
            guard let self = self else { return }
            let selector = NSSelectorFromString("getSelfUserInfo")
            if TUILogin.responds(to: selector) {
                TUILogin.perform(selector)
            }
            self.registerSuccess()
        } failed: { [weak self] err in
            guard let self = self else { return }
            self.state.isLoading = false
            self.state.toastMessage = err
        }
    }
    
    func updateAvatar(_ url: String) {
        ProfileManager.shared.curUserModel?.avatar = url
        state.avatarURL = url
    }
    
    // MARK: - Private
    
    private func loginIM() {
        guard let userID = ProfileManager.shared.curUserID() else { return }
        let userSig = ProfileManager.shared.curUserSig()
        
        if TUILogin.getUserID() != userID {
            ProfileManager.shared.curUserModel?.name = ""
        }
        
        ProfileManager.shared.IMLogin(sdkAppId: LoginEntry.shared.config.sdkAppId, userSig: userSig) { [weak self] in
            guard let self = self else { return }
            self.loginSuccess()
        } failed: { [weak self] error in
            guard let self = self else { return }
            self.state.toastMessage = LoginLocalize("LoginNetwork.ProfileManager.loginfailed")
            UserOverdueLogicManager.sharedManager().userOverdueState = .loggedAndOverdue
        }
    }
    
    private func loginSuccess() {
        if ProfileManager.shared.curUserModel?.name.count == 0 {
            let avatarURL = ProfileManager.shared.curUserModel?.avatar ?? ""
            let defaultAvatar = "https://liteav.sdk.qcloud.com/app/res/picture/voiceroom/avatar/user_avatar1.png"
            
            if avatarURL.isEmpty {
                ProfileManager.shared.curUserModel?.avatar = defaultAvatar
            }
            
            state.needsRegister = true
            state.avatarURL = ProfileManager.shared.curUserModel?.avatar ?? defaultAvatar
            onNeedsRegister?()
        } else {
            state.toastMessage = LoginLocalize("V2.Live.LinkMicNew.loginsuccess")
            buildAndEmitResult()
        }
    }
    
    private func registerSuccess() {
        state.isLoading = false
        state.toastMessage = LoginLocalize("Demo.TRTC.Login.registsuccess")
        ProfileManager.shared.localizeUserModel()
        ProfileManager.shared.synchronizUserInfo()
        buildAndEmitResult()
    }
    
    private func buildAndEmitResult() {
        guard let rawUser = ProfileManager.shared.curUserModel else {
            resultSubject.send(.failure(.unknown(message: "User data not found")))
            return
        }
        let user = UserModel(
            userId: rawUser.userId,
            token: rawUser.token,
            userSig: rawUser.userSig,
            phone: rawUser.phone,
            email: rawUser.email,
            name: rawUser.name,
            avatar: rawUser.avatar
        )
        let loginResult = LoginResult(userModel: user, mode: .debugAuth)
        
        resultSubject.send(.success(loginResult))
    }
}
