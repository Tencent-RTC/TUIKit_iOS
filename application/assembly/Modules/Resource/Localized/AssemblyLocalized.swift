//
//  AssemblyLocalized.swift
//  AppAssembly
//
//  国际化辅助函数 — 底层统一使用 AtomicX BundleLoader.moduleLocalized
//

import Foundation
import AtomicX

// MARK: - AppAssembly 本地化

private let AssemblyLocalizeTableName = "AssemblyLocalized"

/// AppAssembly 模块本地化便捷函数
func AssemblyLocalize(_ key: String, _ args: CVarArg...) -> String {
    return BundleLoader.moduleLocalized(
        key: key,
        in: AppAssemblyBundle.bundle,
        tableName: AssemblyLocalizeTableName,
        arguments: args
    )
}
