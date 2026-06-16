//
//  MineLocalized.swift
//  mine
//
//  Mine 模块国际化辅助函数 — 底层统一使用 AtomicX BundleLoader.moduleLocalized
//

import Foundation
import AtomicX

// MARK: - Mine 本地化

private let MineLocalizeTableName = "MineLocalized"

/// Mine 模块本地化便捷函数
func MineLocalize(_ key: String, _ args: CVarArg...) -> String {
    return BundleLoader.moduleLocalized(
        key: key,
        in: Bundle.main,
        tableName: MineLocalizeTableName,
        arguments: args
    )
}
