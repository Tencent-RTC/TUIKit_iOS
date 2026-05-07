//
//  LoginResult.swift
//  login
//

import Foundation

public struct LoginResult {
    public let userModel: UserModel
    
    public let loginMode: LoginMode
    
    public init(userModel: UserModel, mode: LoginMode) {
        self.userModel = userModel
        self.loginMode = mode
    }
}
