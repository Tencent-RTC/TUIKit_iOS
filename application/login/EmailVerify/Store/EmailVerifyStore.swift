//
//  EmailVerifyStore.swift
//  login
//
//  邮箱登录 Store（业务逻辑）
//
//  新版流程：输入邮箱 → 跳转邀请码页面
//  从 TRTCEmailLoginViewController 迁移
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

    // MARK: - Toast Event

    private let toastSubject = PassthroughSubject<String, Never>()
    var toastPublisher: AnyPublisher<String, Never> { toastSubject.eraseToAnyPublisher() }
    
    // MARK: - Dependencies
    
    private let networkService = LoginNetworkService()
    private var logoutCancellable: AnyCancellable?
    
    /// 跳转到邀请码页面的回调（带邮箱参数）
    var onNavigateToInviteCode: ((_ email: String?) -> Void)?
    
    /// 切换到 iOA 登录的回调
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
    
    /// 更新邮箱
    func updateEmail(_ email: String) {
        state.email = email
    }
    
    /// 点击 Continue 按钮 — 校验邮箱后跳转邀请码页面
    func continueWithEmail() {
        let email = state.email.trimmingCharacters(in: .whitespacesAndNewlines)
        
        guard !email.isEmpty else {
            toastSubject.send(String.EmailLogin.enterEmailError)
            return
        }

        guard isValidEmail(email) else {
            toastSubject.send(String.EmailLogin.validEmailError)
            return
        }
        
        onNavigateToInviteCode?(email)
    }
    
    /// 直接跳转邀请码页面（不带邮箱）
    func navigateToInviteCodeDirectly() {
        onNavigateToInviteCode?(nil)
    }
    
    /// 切换到 iOA 登录
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
