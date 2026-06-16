//
//  PrivacyLocalized.swift
//  privacy
//
//  Privacy 模块本地化便捷函数 — 底层统一使用 AtomicX BundleLoader.moduleLocalized
//

import Foundation
import AtomicX

// MARK: - Privacy 本地化

private let PrivacyLocalizeTableName = "PrivacyLocalized"

/// Privacy 模块本地化便捷函数
func PrivacyLocalize(_ key: String, _ args: CVarArg...) -> String {
    return BundleLoader.moduleLocalized(
        key: key,
        in: Bundle.main,
        tableName: PrivacyLocalizeTableName,
        arguments: args
    )
}
