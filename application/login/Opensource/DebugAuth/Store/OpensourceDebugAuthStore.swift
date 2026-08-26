//
//  OpensourceDebugAuthStore.swift
//  login
//

import Combine
import Foundation
import TUICore
import ImSDK_Plus

final class OpensourceDebugAuthStore: DebugAuthStoreProtocol {

    // MARK: - State

    @Published private(set) var state = DebugAuthState()
    var statePublisher: Published<DebugAuthState>.Publisher { $state }

    // MARK: - LoginSubStore

    private let resultSubject = PassthroughSubject<Result<LoginResult, LoginError>, Never>()
    var resultPublisher: AnyPublisher<Result<LoginResult, LoginError>, Never> {
        resultSubject.eraseToAnyPublisher()
    }

    // MARK: - Toast Event

    private let toastSubject = PassthroughSubject<String, Never>()
    var toastPublisher: AnyPublisher<String, Never> { toastSubject.eraseToAnyPublisher() }

    // MARK: - Callbacks

    var onNeedsRegister: (() -> Void)?

    private var logoutCancellable: AnyCancellable?

    static let cachedUserIdKey = "com.rtcube.login.debugAuth.cachedUserId"

    // MARK: - Init

    init() {
        logoutCancellable = subscribeLogout()
        if let cachedUserId = UserDefaults.standard.string(forKey: Self.cachedUserIdKey),
           !cachedUserId.isEmpty {
            state.userName = cachedUserId
            LoginLogger.Login.info("OpensourceDebugAuthStore.init restored cachedUserId=\(cachedUserId)")
        } else {
            LoginLogger.Login.info("OpensourceDebugAuthStore.init no cached user")
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

    func updateAvatar(_ url: String) {
        state.avatarURL = url
    }

    func login() {
        let userId = state.userName
        guard !userId.isEmpty else {
            LoginLogger.Login.warn("OpensourceDebugAuthStore.login userName empty, skipped")
            return
        }
        state.isLoginEnabled = false
        state.isLoading = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 4.0) { [weak self] in
            self?.state.isLoginEnabled = true
        }

        let cfg = LoginEntry.shared.config
        guard let generator = LoginEntry.shared.userSigGenerator else {
            LoginLogger.Login.warn("OpensourceDebugAuthStore.login userSigGenerator nil, skipped")
            state.isLoading = false
            state.isLoginEnabled = true
            return
        }
        let userSig = generator(userId, cfg.sdkAppId, cfg.secretKey)
        UserDefaults.standard.set(userId, forKey: Self.cachedUserIdKey)
        loginIM(userId: userId, userSig: userSig, sdkAppId: cfg.sdkAppId)
    }

    func loginWithCredentials(_ credentials: HiddenConfigCredentials) {
        state.userName = credentials.userId
        state.isLoginEnabled = false
        state.isLoading = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 4.0) { [weak self] in
            self?.state.isLoginEnabled = true
        }
        UserDefaults.standard.set(credentials.userId, forKey: Self.cachedUserIdKey)
        let sdkAppId = Int(credentials.sdkAppId) ?? LoginEntry.shared.config.sdkAppId
        loginIM(userId: credentials.userId, userSig: credentials.userSig, sdkAppId: sdkAppId)
    }

    func register(nickName: String) {
        state.isLoading = true
        let info = V2TIMUserFullInfo()
        info.nickName = nickName
        if !state.avatarURL.isEmpty {
            info.faceURL = state.avatarURL
        }
        V2TIMManager.sharedInstance().setSelfInfo(info: info, succ: { [weak self] in
            guard let self = self else { return }
            self.state.isLoading = false
            self.toastSubject.send(LoginLocalize("login_profile_toast_register_success"))
            self.emitResult(userId: self.state.userName, name: nickName, avatar: self.state.avatarURL)
        }, fail: { [weak self] _, desc in
            guard let self = self else { return }
            self.state.isLoading = false
            self.toastSubject.send(desc ?? "")
        })
    }

    // MARK: - Private

    private func loginIM(userId: String, userSig: String, sdkAppId: Int) {
        LoginLogger.Login.info("OpensourceDebugAuthStore.loginIM userId=\(userId) sdkAppId=\(sdkAppId)")
        TUILogin.login(Int32(sdkAppId), userID: userId, userSig: userSig) { [weak self] in
            guard let self = self else { return }
            self.state.isLoading = false
            self.fetchSelfInfo(userId: userId, userSig: userSig)
        } fail: { [weak self] code, msg in
            guard let self = self else { return }
            self.state.isLoading = false
            LoginLogger.Login.warn("OpensourceDebugAuthStore.loginIM FAILED code=\(code) msg=\(msg ?? "nil")")
            self.toastSubject.send(LoginLocalize("login_error_login_failed"))
            self.resultSubject.send(.failure(.loginFailed(code: Int(code), message: msg ?? "")))
        }
    }

    private func fetchSelfInfo(userId: String, userSig: String) {
        V2TIMManager.sharedInstance().getUsersInfo([userId], succ: { [weak self] infos in
            guard let self = self else { return }
            let info = infos?.first
            let name = info?.nickName ?? ""
            let avatar = info?.faceURL ?? ""
            if name.isEmpty {
                self.state.avatarURL = avatar.isEmpty
                    ? "https://liteav.sdk.qcloud.com/app/res/picture/voiceroom/avatar/user_avatar1.png"
                    : avatar
                self.state.needsRegister = true
                self.onNeedsRegister?()
            } else {
                self.toastSubject.send(LoginLocalize("login_status_success"))
                self.emitResult(userId: userId, name: name, avatar: avatar, userSig: userSig)
            }
        }, fail: { [weak self] code, msg in
            guard let self = self else { return }
            LoginLogger.Login.warn("OpensourceDebugAuthStore.fetchSelfInfo FAILED code=\(code) msg=\(msg ?? "nil")")
            self.toastSubject.send(LoginLocalize("login_error_login_failed"))
            self.resultSubject.send(.failure(.loginFailed(code: Int(code), message: msg ?? "")))
        })
    }

    private func emitResult(userId: String, name: String, avatar: String, userSig: String = "") {
        let user = UserModel(
            userId: userId,
            token: "",
            userSig: userSig,
            phone: userId,
            email: "",
            name: name,
            avatar: avatar
        )
        resultSubject.send(.success(LoginResult(userModel: user, mode: .debugAuth)))
    }

    static func clearCache() {
        UserDefaults.standard.removeObject(forKey: Self.cachedUserIdKey)
    }
}
