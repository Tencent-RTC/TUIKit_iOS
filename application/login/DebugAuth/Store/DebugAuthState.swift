//
//  DebugAuthState.swift
//  login
//
//  Debug 登录状态定义
//

import Foundation

public struct DebugAuthState {
    /// 用户名
    public var userName: String = ""
    /// 是否正在加载
    public var isLoading: Bool = false
    /// 登录按钮是否可用
    public var isLoginEnabled: Bool = true
    /// 是否需要注册（新用户无昵称）
    public var needsRegister: Bool = false
    /// 注册页：当前头像 URL
    public var avatarURL: String = ""
    /// 注册页：昵称
    public var nickName: String = ""
}
