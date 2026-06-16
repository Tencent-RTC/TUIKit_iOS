//
//  LoginLocalized.swift
//  login
//
//  Login 模块本地化便捷函数
//  底层统一使用 AtomicX BundleLoader.moduleLocalized
//

import Foundation
import AtomicX

// MARK: - Login 专用

private let LoginLocalizeTableName = "LoginLocalized"

/// 登录模块本地化便捷函数
func LoginLocalize(_ key: String) -> String {
    return BundleLoader.moduleLocalized(
        key: key,
        in: Bundle.loginResources,
        tableName: LoginLocalizeTableName
    )
}

/// 登录模块本地化 — 替换 xxx
func LoginLocalizeReplace(_ key: String, _ xxx: String) -> String {
    return LoginLocalize(key).replacingOccurrences(of: "xxx", with: xxx)
}

/// 登录模块本地化 — 替换 xxx、yyy
func LoginLocalizeReplace(_ key: String, _ xxx: String, _ yyy: String) -> String {
    return LoginLocalizeReplace(key, xxx).replacingOccurrences(of: "yyy", with: yyy)
}

/// 登录模块本地化 — 替换 xxx、yyy、zzz
func LoginLocalizeReplace(_ key: String, _ xxx: String, _ yyy: String, _ zzz: String) -> String {
    return LoginLocalizeReplace(key, xxx, yyy).replacingOccurrences(of: "zzz", with: zzz)
}
