//
//  LoginResult.swift
//  login
//
//  登录结果模型（对外可见）
//

import Foundation

/// 登录成功后返回的结果
public struct LoginResult {
    /// 用户数据
    public let userModel: UserModel
    
    public let loginMode: LoginMode
    
    public init(userModel: UserModel, mode: LoginMode) {
        self.userModel = userModel
        self.loginMode = mode
    }
}
