//
//  LoginConfig.swift
//  login
//
//  登录模块专属配置（值类型，不可变）
//
//  由 LoginEntry.initialize() 一次性构建，模块内部通过 LoginEntry.shared.config 只读访问。
//  外部不应直接构造此类型——所有配置统一经过 LoginEntry 入口注册。
//

import Foundation

/// 登录模块专属配置
///
/// 设计要点：
///   - `struct` 值类型，创建后不可修改（所有属性均为 `let`）
///   - 消除全局可变静态变量，避免隐式依赖和线程安全问题
public struct LoginConfig: Equatable {
    /// 服务端基础 URL — 拼接各登录接口地址
    public let httpBaseUrl: String
    
    /// 是否使用正式后台服务（true = 正式服务，false = 本地调试）
    /// 影响 sdkAppId 的获取方式（HttpLogicRequest）
    public let isSetupService: Bool
    
    /// 本地调试用 SDKAPPID（仅 isSetupService == false 时生效）
    public let sdkAppId: Int
    
    /// aPaaS 应用 ID — 登录接口请求参数
    public let apaasAppId: String
    
    /// 用于本地生成 UserSig 的密钥（仅 Debug 登录使用）
    ///
    /// **安全说明**：此密钥仅用于调试包的 Debug 登录，
    /// 正式登录方式（Phone/Email/IOA）的 UserSig 由后端签发，不需要此字段。
    public let secretKey: String
    
    /// 默认配置（所有字段为空/零值）
    public static let `default` = LoginConfig(
        httpBaseUrl: "",
        isSetupService: true,
        sdkAppId: 0,
        apaasAppId: "",
        secretKey: ""
    )
    
    /// 返回一个替换了 httpBaseUrl 的新配置副本
    public func withBaseUrl(_ newBaseUrl: String) -> LoginConfig {
        LoginConfig(
            httpBaseUrl: newBaseUrl,
            isSetupService: isSetupService,
            sdkAppId: sdkAppId,
            apaasAppId: apaasAppId,
            secretKey: secretKey
        )
    }
}
