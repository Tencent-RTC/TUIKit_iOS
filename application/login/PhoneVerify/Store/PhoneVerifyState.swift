//
//  PhoneVerifyState.swift
//  login
//
//  手机号登录状态定义
//

import Foundation

public struct PhoneVerifyState {
    /// 手机号（不含区号）
    public var phoneNumber: String = ""
    /// 区号（默认 +86）
    public var regionCode: String = "+86"
    /// 验证码
    public var verifyCode: String = ""
    /// 验证码 sessionId
    public var sessionId: String = ""
    /// 是否正在加载
    public var isLoading: Bool = false
    /// 倒计时剩余秒数（0 表示未在倒计时）
    public var countdownSeconds: Int = 0
    /// 全屏 loading 消息
    public var fullScreenLoadingMessage: String = ""
    /// 是否显示全屏 loading
    public var isFullScreenLoading: Bool = false
}
