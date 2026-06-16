//
//  TokenCacheManager.swift
//  login
//
//  Token 缓存管理（UserDefaults 读写）
//

import Foundation

struct TokenCacheManager {
    
    /// 从缓存获取用户 Token 信息
    /// - Returns: 用户 userId 和 token 的元组，不存在时返回 nil
    static func getCachedCredentials() -> (userId: String, token: String)? {
        guard let user = LoginManager.shared.getCurrentUser(),
              !user.userId.isEmpty,
              !user.token.isEmpty else {
            return nil
        }
        return (userId: user.userId, token: user.token)
    }
    
    /// 清除缓存
    static func clearCache() {
        LoginManager.shared.removeLoginCache()
    }
}
