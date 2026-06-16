//
//  TokenAuthStore.swift
//  login
//
//  Token 自动登录 Store（无 UI）
//
//  旧版来源：TRTCLoginViewController.autoLogin(userModel:)
//

import Foundation
import Combine

class TokenAuthStore: LoginSubStore {
    
    // MARK: - LoginSubStore
    
    private let resultSubject = PassthroughSubject<Result<LoginResult, LoginError>, Never>()
    var resultPublisher: AnyPublisher<Result<LoginResult, LoginError>, Never> {
        resultSubject.eraseToAnyPublisher()
    }
    
    // MARK: - Dependencies
    
    private let networkService = LoginNetworkService()
    
    // MARK: - Public Methods
    
    /// 执行 Token 自动登录
    /// - Parameter originalMode: 上次登录成功时的登录方式，透传给网络层以保持 loginMode 一致性
    func performAutoLogin(originalMode: LoginMode) {
        guard let credentials = TokenCacheManager.getCachedCredentials() else {
            resultSubject.send(.failure(.tokenExpired))
            return
        }
        
        networkService.loginByToken(userId: credentials.userId, token: credentials.token, originalMode: originalMode) { [weak self] result in
            self?.resultSubject.send(result)
        }
    }
    
    // MARK: - LoginSubStore
    
    func resetState() {
        // Token 自动登录无 UI 状态，无需重置
    }
}
