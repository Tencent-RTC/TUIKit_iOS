//
//  MainLocalized.swift
//  main
//
//  国际化辅助函数 — 底层统一使用 AtomicX BundleLoader.moduleLocalized
//

import Foundation
import AtomicX

// MARK: - Main 本地化

private let MainLocalizeTableName = "MainLocalized"

/// Main 模块本地化便捷函数
func MainLocalize(_ key: String, _ args: CVarArg...) -> String {
    return BundleLoader.moduleLocalized(
        key: key,
        in: Bundle.main,
        tableName: MainLocalizeTableName,
        arguments: args
    )
}

// MARK: - String Extension for MainLocalize

extension String {
    /// 从 Main 模块本地化表中获取翻译
    ///
    /// 用法：`.mainLocalized("Demo.TRTC.Portal.Main.call")`
    static func mainLocalized(_ key: String) -> String {
        return MainLocalize(key)
    }
}
