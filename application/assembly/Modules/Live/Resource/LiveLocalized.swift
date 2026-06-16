//
//  LiveLocalized.swift
//  AppAssembly
//
//  Live 模块本地化辅助函数
//

import Foundation
import AtomicX

/// Live 模块本地化便捷函数
func LiveLocalize(_ key: String, _ args: CVarArg...) -> String {
    return BundleLoader.moduleLocalized(
        key: key,
        in: AppAssemblyBundle.bundle,
        tableName: "LiveLocalized",
        arguments: args
    )
}
