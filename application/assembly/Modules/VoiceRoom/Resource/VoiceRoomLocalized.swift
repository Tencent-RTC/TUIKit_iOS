//
//  VoiceRoomLocalized.swift
//  AppAssembly
//
//  VoiceRoom 模块本地化辅助函数
//

import Foundation
import AtomicX

/// VoiceRoom 模块本地化便捷函数
func VoiceRoomLocalize(_ key: String, _ args: CVarArg...) -> String {
    return BundleLoader.moduleLocalized(
        key: key,
        in: AppAssemblyBundle.bundle,
        tableName: "VoiceRoomLocalized",
        arguments: args
    )
}
