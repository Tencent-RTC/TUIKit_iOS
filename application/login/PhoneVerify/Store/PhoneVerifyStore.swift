//
//  PhoneVerifyStore.swift
//  login
//
//  手机号登录 Store（业务逻辑）
//
//  旧版来源：TRTCLoginViewController 中手机登录逻辑
//

import Foundation
import Combine

public class PhoneVerifyStore: LoginSubStore {
    
    // MARK: - State
    
    @Published private(set) var state = PhoneVerifyState()
    
    // MARK: - LoginSubStore
    
    private let resultSubject = PassthroughSubject<Result<LoginResult, LoginError>, Never>()
    var resultPublisher: AnyPublisher<Result<LoginResult, LoginError>, Never> {
        resultSubject.eraseToAnyPublisher()
    }
    
    // MARK: - Events

    public let eventPublisher = PassthroughSubject<PhoneVerifyEvent, Never>()

    // MARK: - Toast Event

    private let toastSubject = PassthroughSubject<String, Never>()
    var toastPublisher: AnyPublisher<String, Never> { toastSubject.eraseToAnyPublisher() }
    
    // MARK: - Dependencies
    
    private let networkService = LoginNetworkService()
    private let captchaService = CaptchaService()
    private var countdownTimer: Timer?
    private var logoutCancellable: AnyCancellable?
    
    /// 切换到 iOA 登录的回调
    var onSwitchToIOA: (() -> Void)?
    
    // MARK: - Init
    
    init() {
        logoutCancellable = subscribeLogout()
    }
    
    deinit {
        countdownTimer?.invalidate()
    }
    
    // MARK: - LoginSubStore
    
    func resetState() {
        stopCountdown()
        state = PhoneVerifyState()
    }
    
    // MARK: - Public Methods
    
    /// 更新手机号
    func updatePhoneNumber(_ phone: String) {
        state.phoneNumber = phone
    }
    
    /// 更新验证码
    func updateVerifyCode(_ code: String) {
        state.verifyCode = code
    }
    
    /// 发送验证码（含人机验证）
    func sendVerifyCode() {
        let phone = state.regionCode + state.phoneNumber
        guard phone.count > 1 else { return }
        
        state.isLoading = true
        
        captchaService.verify { [weak self] captchaResult in
            guard let self = self else { return }
            self.state.isLoading = false
            self.networkService.sendSms(phone: phone, captcha: captchaResult) { [weak self] sessionId in
                guard let self = self else { return }
                self.state.sessionId = sessionId
                self.toastSubject.send(LoginLocalize("login_verify_code_sent"))
                self.startCountdown()
            } failed: { [weak self] error in
                guard let self = self else { return }
                self.toastSubject.send(error.message)
            }
        } failed: { [weak self] errorMessage in
            guard let self = self else { return }
            self.state.isLoading = false
            self.toastSubject.send(errorMessage)
        } cancelled: { [weak self] in
            guard let self = self else { return }
            self.state.isLoading = false
        }
    }
    
    /// 登录
    func login() {
        let phone = state.regionCode + state.phoneNumber
        let code = state.verifyCode
        let sessionId = state.sessionId

        guard !sessionId.isEmpty else {
            toastSubject.send(LoginLocalize("login_send_verify_code_required"))
            return
        }

        state.isFullScreenLoading = true
        state.fullScreenLoadingMessage = LoginLocalize("login_home_loading")

        networkService.loginByPhone(phone: phone, sessionId: sessionId, code: code) { [weak self] result in
            guard let self = self else { return }
            self.state.isFullScreenLoading = false
            switch result {
            case .success(let loginResult):
                self.resultSubject.send(.success(loginResult))
            case .failure(let error):
                let feedback = self.resolveLoginFailureFeedback(error)
                self.toastSubject.send(feedback.toastMessage)
                if feedback.clearVerifyCode {
                    self.state.verifyCode = ""
                }
                if feedback.resetSession {
                    self.stopCountdown()
                    self.state.sessionId = ""
                }
            }
        }
    }
    
    /// 切换到 iOA 登录
    func switchToIOA() {
        onSwitchToIOA?()
    }
    
    // MARK: - Error Resolution

    private struct LoginFailureFeedback {
        let toastMessage: String
        var clearVerifyCode: Bool = false
        var resetSession: Bool = false
    }

    /// 根据错误类型解析用户友好的反馈信息（对齐 v2 Android resolveLoginFailureFeedback）
    private func resolveLoginFailureFeedback(_ error: LoginError) -> LoginFailureFeedback {
        switch error {
        case .networkError(let message):
            return LoginFailureFeedback(toastMessage: resolveNetworkErrorMessage(message))

        case .tokenExpired:
            return LoginFailureFeedback(toastMessage: LoginLocalize("login_token_expired"))

        case .loginFailed(_, let message):
            if isVerifyCodeExpired(message) {
                return LoginFailureFeedback(
                    toastMessage: LoginLocalize("login_error_code_expired"),
                    clearVerifyCode: true,
                    resetSession: true
                )
            } else if isVerifyCodeInvalid(message) {
                return LoginFailureFeedback(
                    toastMessage: LoginLocalize("login_error_code_invalid"),
                    clearVerifyCode: true
                )
            } else {
                let fallback = message.isEmpty
                    ? LoginLocalize("login_error_login_failed")
                    : message
                return LoginFailureFeedback(toastMessage: fallback)
            }

        default:
            let fallback = error.message.isEmpty
                ? LoginLocalize("login_error_login_failed")
                : error.message
            return LoginFailureFeedback(toastMessage: fallback)
        }
    }

    /// 判断是否为验证码过期错误
    private func isVerifyCodeExpired(_ message: String) -> Bool {
        let lower = message.lowercased()
        return lower.contains("expired")
            || lower.contains("expire")
            || message.contains("过期")
            || message.contains("失效")
    }

    /// 判断是否为验证码错误
    private func isVerifyCodeInvalid(_ message: String) -> Bool {
        let lower = message.lowercased()
        let hasVerifyKeyword = message.contains("验证码")
            || lower.contains("verification code")
            || lower.contains("verify code")
        let hasInvalidKeyword = message.contains("错误")
            || lower.contains("invalid")
            || lower.contains("wrong")
            || lower.contains("error")
        return hasVerifyKeyword || (lower.contains("code") && hasInvalidKeyword)
    }

    /// 解析网络错误消息（超时 → 本地化提示）
    private func resolveNetworkErrorMessage(_ message: String) -> String {
        let lower = message.lowercased()
        if lower.contains("timeout") || lower.contains("timed out") || message.contains("超时") {
            return LoginLocalize("login_error_network_timeout")
        }
        return message
    }

    // MARK: - Countdown

    private func startCountdown() {
        stopCountdown()
        state.countdownSeconds = 60
        countdownTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            guard let self = self else { return }
            let current = self.state.countdownSeconds
            if current > 1 {
                self.state.countdownSeconds = current - 1
            } else {
                self.stopCountdown()
            }
        }
    }
    
    private func stopCountdown() {
        countdownTimer?.invalidate()
        countdownTimer = nil
        state.countdownSeconds = 0
    }
}

// MARK: - Events

public enum PhoneVerifyEvent {
    case showToast(message: String)
}
