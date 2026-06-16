//
//  RoomLocalized.swift
//  AppAssembly
//
//  Room 模块本地化辅助函数
//

import Foundation
import AtomicX

/// Room 模块本地化便捷函数
func RoomLocalize(_ key: String, _ args: CVarArg...) -> String {
    return BundleLoader.moduleLocalized(
        key: key,
        in: AppAssemblyBundle.bundle,
        tableName: "RoomLocalized",
        arguments: args
    )
}
