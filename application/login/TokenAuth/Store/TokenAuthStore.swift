//
//  TokenAuthStore.swift
//  login
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
    }
}
