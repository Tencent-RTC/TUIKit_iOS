//
//  InviteCodeStore.swift
//  login
//

import Combine
import Foundation

class InviteCodeStore: LoginSubStore {
    // MARK: - State
    
    @Published private(set) var state = InviteCodeState()
    
    // MARK: - LoginSubStore
    
    private let resultSubject = PassthroughSubject<Result<LoginResult, LoginError>, Never>()
    var resultPublisher: AnyPublisher<Result<LoginResult, LoginError>, Never> {
        resultSubject.eraseToAnyPublisher()
    }

    // MARK: - Toast Event

    private let toastSubject = PassthroughSubject<String, Never>()
    var toastPublisher: AnyPublisher<String, Never> { toastSubject.eraseToAnyPublisher() }

    // MARK: - Dependencies
    
    private let networkService = LoginNetworkService()
    private var logoutCancellable: AnyCancellable?
    private var countdownTimer: Timer?
    
    var onBack: (() -> Void)?
    
    // MARK: - Init
    
    init(emailAddress: String? = nil) {
        state.emailAddress = emailAddress
        
        if let email = emailAddress {
            state.titleText = String.InvitationCode.checkYourEmail
            state.descriptionText = String.InvitationCode.enterCodeSentToEmail(email)
            state.showMarketingCheckbox = true
        } else {
            state.titleText = String.InvitationCode.enterInvitationCode
            state.descriptionText = String.InvitationCode.enterCodeToGetStarted
            state.showMarketingCheckbox = false
        }
        
        logoutCancellable = subscribeLogout()
    }
    
    deinit {
        stopCountdown()
    }
    
    // MARK: - LoginSubStore
    
    func resetState() {
        stopCountdown()
        state = InviteCodeState()
    }
    
    // MARK: - Public Methods
    
    func updateInviteCode(_ code: String) {
        state.inviteCode = code
    }
    
    func toggleTermsCheckbox() {
        state.isTermsAgreed.toggle()
        if state.isTermsAgreed {
            state.showAgreeCheckBubble = false
        }
    }
    
    func toggleMarketingCheckbox() {
        state.isMarketingAgreed.toggle()
    }
    
    func goBack() {
        onBack?()
    }
    
    func sendInvitationCodeIfNeeded() {
        guard let email = state.emailAddress else { return }
        sendInvitationCode(email: email)
        startCountdown()
    }
    
    func resendInvitationCode() {
        guard state.isResendEnabled, let email = state.emailAddress else { return }
        toastSubject.send(String.InvitationCode.resendingCode)
        clearErrorState()
        sendInvitationCode(email: email) { [weak self] in
            self?.startCountdown()
        } failed: { [weak self] code, _ in
            guard let self = self else { return }
            if code == 230 {
                self.toastSubject.send(LoginLocalize("login_email_too_many_requests"))
            } else {
                self.toastSubject.send(LoginLocalize("login_email_send_failed"))
            }
        }
    }
    
    func getStarted() {
        let code = state.inviteCode
        
        guard code.count == 6 else {
            toastSubject.send(String.InvitationCode.enterCompleteCode)
            return
        }
        
        guard state.isTermsAgreed else {
            state.showAgreeCheckBubble = true
            return
        }
        
        invitationCodeAuthLogin(code)
    }
    
    func clearErrorState() {
        state.isCodeInvalid = false
    }
    
    // MARK: - Private Methods
    
    private func sendInvitationCode(email: String,
                                    success: (() -> Void)? = nil,
                                    failed: ((Int32, String) -> Void)? = nil)
    {
        networkService.requestInvitationCode(email: email) { result in
            switch result {
            case .success:
                success?()
            case .failure(let error):
                if case .loginFailed(let code, let message) = error {
                    failed?(Int32(code), message)
                } else {
                    failed?(-1, error.message)
                }
            }
        }
    }
    
    private func invitationCodeAuthLogin(_ code: String) {
        state.isValidating = true
        
        if let email = state.emailAddress {
            networkService.needReceiveEmail(email: email, marketingStatus: state.isMarketingAgreed)
        }
        
        networkService.noneAuthLogin(invitationCode: code) { [weak self] result in
            guard let self = self else { return }
            self.state.isValidating = false
            switch result {
            case .success(let loginResult):
                self.resultSubject.send(.success(loginResult))
            case .failure(let error):
                self.handleValidationFailure()
                let message: String
                if case .loginFailed(let errorCode, _) = error {
                    if errorCode == kAppLoginServiceUserInviteCodeBeUsed {
                        message = LoginLocalize("login_invite_code_used")
                    } else if errorCode == kAppLoginServiceUserInviteIncorrect {
                        message = LoginLocalize("login_invite_code_invalid")
                    } else if errorCode == kAppLoginServiceUserInviteCodeExpire {
                        message = LoginLocalize("login_invite_code_expired")
                    } else {
                        message = error.message
                    }
                } else {
                    message = error.message
                }
                self.toastSubject.send(message)
            }
        }
    }
    
    private func handleValidationFailure() {
        state.isCodeInvalid = true
    }
    
    // MARK: - Countdown
    
    private func startCountdown() {
        stopCountdown()
        state.remainingSeconds = 59
        state.isResendEnabled = false
        
        countdownTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            guard let self = self else { return }
            if self.state.remainingSeconds > 1 {
                self.state.remainingSeconds -= 1
            } else {
                self.stopCountdown()
            }
        }
    }
    
    private func stopCountdown() {
        countdownTimer?.invalidate()
        countdownTimer = nil
        state.remainingSeconds = 0
        state.isResendEnabled = true
    }
}

// MARK: - State

public struct InviteCodeState {
    public var emailAddress: String?
    public var inviteCode: String = ""
    public var titleText: String = ""
    public var descriptionText: String = ""
    public var isValidating: Bool = false
    public var isCodeInvalid: Bool = false
    public var isTermsAgreed: Bool = false
    public var isMarketingAgreed: Bool = false
    public var showMarketingCheckbox: Bool = false
    public var showAgreeCheckBubble: Bool = false
    public var remainingSeconds: Int = 0
    public var isResendEnabled: Bool = false
}

// MARK: - String Constants

extension String {
    enum InvitationCode {
        // MARK: - Titles

        static var checkYourEmail: String { LoginLocalize("login_email_invite_code_title") }
        static var enterInvitationCode: String { LoginLocalize("login_invite_title") }
        
        // MARK: - Descriptions

        static func enterCodeSentToEmail(_ email: String) -> String {
            return LoginLocalizeReplace("login_email_invite_code_subtitle", email)
        }

        static var enterCodeToGetStarted: String { LoginLocalize("login_invite_subtitle") }
        
        // MARK: - Button Texts

        static var getStarted: String { LoginLocalize("login_email_invite_code_get_started") }
        static var validating: String { LoginLocalize("login_email_invite_code_verifying") }
        
        // MARK: - Error Messages

        static var enterCompleteCode: String { LoginLocalize("login_invite_enter_complete") }
        static var codeIncorrect: String { LoginLocalize("login_email_invite_code_error") }
        
        // MARK: - Resend Messages

        static var resendClickable: String { LoginLocalize("login_email_invite_code_resend_clickable") }
        static var clickToResend: String { LoginLocalize("login_email_invite_code_resend") }
        static func resendCountdown(_ seconds: Int) -> String {
            return LoginLocalizeReplace("login_email_invite_code_resend_countdown", "\(seconds)")
        }

        static func resendAfter(_ seconds: Int) -> String {
            return LoginLocalizeReplace("login_email_invite_code_resend_hint", "\(seconds)")
        }

        static var resendingCode: String { LoginLocalize("login_email_invite_code_resending") }
        
        // MARK: - Agreement Texts

        static var agreeToTermsText: String {
            return LoginLocalizeReplace(
                "login_invite_terms_agreement",
                termsOfService,
                privacyPolicy
            )
        }

        static var termsOfService: String { LoginLocalize("login_terms_of_service") }
        static var privacyPolicy: String { LoginLocalize("login_terms_privacy_policy") }
        static var marketingInfo: String { LoginLocalize("login_email_invite_code_marketing") }
    }
}
