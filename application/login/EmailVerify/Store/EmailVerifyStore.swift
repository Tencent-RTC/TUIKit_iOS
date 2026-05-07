//
//  EmailVerifyStore.swift
//  login
//

import Foundation
import Combine

public class EmailVerifyStore: LoginSubStore {
    
    // MARK: - State
    
    @Published private(set) var state = EmailVerifyState()
    
    // MARK: - LoginSubStore
    
    private let resultSubject = PassthroughSubject<Result<LoginResult, LoginError>, Never>()
    var resultPublisher: AnyPublisher<Result<LoginResult, LoginError>, Never> {
        resultSubject.eraseToAnyPublisher()
    }
    
    // MARK: - Dependencies
    
    private let networkService = LoginNetworkService()
    private var logoutCancellable: AnyCancellable?
    
    var onNavigateToInviteCode: ((_ email: String?) -> Void)?
    
    var onSwitchToIOA: (() -> Void)?
    
    // MARK: - Init
    
    init() {
        logoutCancellable = subscribeLogout()
    }
    
    // MARK: - LoginSubStore
    
    func resetState() {
        state = EmailVerifyState()
    }
    
    // MARK: - Public Methods
    
    func updateEmail(_ email: String) {
        state.email = email
    }
    
    func continueWithEmail() {
        let email = state.email.trimmingCharacters(in: .whitespacesAndNewlines)
        
        guard !email.isEmpty else {
            state.toastMessage = String.EmailLogin.enterEmailError
            return
        }
        
        guard isValidEmail(email) else {
            state.toastMessage = String.EmailLogin.validEmailError
            return
        }
        
        onNavigateToInviteCode?(email)
    }
    
    func navigateToInviteCodeDirectly() {
        onNavigateToInviteCode?(nil)
    }
    
    func switchToIOA() {
        onSwitchToIOA?()
    }
    
    // MARK: - Private
    
    private func isValidEmail(_ email: String) -> Bool {
        let emailRegEx = "[A-Z0-9a-z._%+-]+@[A-Za-z0-9.-]+\\.[A-Za-z]{2,64}"
        let emailPred = NSPredicate(format: "SELF MATCHES %@", emailRegEx)
        return emailPred.evaluate(with: email)
    }
}
