//
//  LoginError.swift
//  login
//
//  登录错误枚举（对外可见）
//

import Foundation

/// 登录错误类型
public enum LoginError: Error {
    /// 用户取消登录
    case cancelled
    
    /// 网络错误
    case networkError(message: String)
    
    /// 验证码发送失败
    case verifyCodeFailed(message: String)
    
    /// 登录失败（服务端返回错误）
    case loginFailed(code: Int, message: String)
    
    /// Token 过期或无效
    case tokenExpired
    
    /// iOA 登录失败
    case ioaAuthFailed(message: String)
    
    /// 未知错误
    case unknown(message: String)
    
    public var message: String {
        switch self {
        case .cancelled:
            return LoginLocalize("login_user_cancelled")
        case .networkError(let message):
            return message
        case .verifyCodeFailed(let message):
            return message
        case .loginFailed(_, let message):
            return message
        case .tokenExpired:
            return LoginLocalize("login_token_expired")
        case .ioaAuthFailed(let message):
            return message
        case .unknown(let message):
            return message
        }
    }
}
