//
//  TokenCacheManager.swift
//  login
//

import Foundation

struct TokenCacheManager {
    
    static func getCachedCredentials() -> (userId: String, token: String)? {
        guard let user = LoginManager.shared.getCurrentUser(),
              !user.userId.isEmpty,
              !user.token.isEmpty else {
            return nil
        }
        return (userId: user.userId, token: user.token)
    }
    
    static func clearCache() {
        LoginManager.shared.removeLoginCache()
    }
}
