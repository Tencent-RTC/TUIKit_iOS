//
//  LoginError.swift
//  login
//

import Foundation

public enum LoginError: Error {
    case cancelled
    
    case networkError(message: String)
    
    case verifyCodeFailed(message: String)
    
    case loginFailed(code: Int, message: String)
    
    case tokenExpired
    
    case ioaAuthFailed(message: String)
    
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
