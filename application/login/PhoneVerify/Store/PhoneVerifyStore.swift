//
//  PhoneVerifyStore.swift
//  login
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
    
    // MARK: - Dependencies
    
    private let networkService = LoginNetworkService()
    private let captchaService = CaptchaService()
    private var countdownTimer: Timer?
    private var logoutCancellable: AnyCancellable?
    
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
    
    func updatePhoneNumber(_ phone: String) {
        state.phoneNumber = phone
    }
    
    func updateVerifyCode(_ code: String) {
        state.verifyCode = code
    }
    
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
                self.state.toastMessage = LoginLocalize("V2.Live.LinkMicNew.verificationcodesent")
                self.startCountdown()
            } failed: { [weak self] error in
                guard let self = self else { return }
                self.state.toastMessage = error.message
            }
        } failed: { [weak self] errorMessage in
            guard let self = self else { return }
            self.state.isLoading = false
            self.state.toastMessage = errorMessage
        } cancelled: { [weak self] in
            guard let self = self else { return }
            self.state.isLoading = false
        }
    }
    
    func login() {
        let phone = state.regionCode + state.phoneNumber
        let code = state.verifyCode
        let sessionId = state.sessionId
        
        guard !sessionId.isEmpty else {
            state.toastMessage = LoginLocalize("V2.Live.LoginMock.sendtheverificatcode")
            return
        }
        
        state.isFullScreenLoading = true
        state.fullScreenLoadingMessage = LoginLocalize("Demo.TRTC.Login.loading")
        
        networkService.loginByPhone(phone: phone, sessionId: sessionId, code: code) { [weak self] result in
            guard let self = self else { return }
            self.state.isFullScreenLoading = false
            switch result {
            case .success(let loginResult):
                self.resultSubject.send(.success(loginResult))
            case .failure(let error):
                self.state.toastMessage = error.message
            }
        }
    }
    
    func switchToIOA() {
        onSwitchToIOA?()
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
