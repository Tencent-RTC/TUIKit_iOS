//
//  VoiceRoomLocalized.swift
//  AppAssembly
//

import Foundation
import AtomicX

func VoiceRoomLocalize(_ key: String, _ args: CVarArg...) -> String {
    return BundleLoader.moduleLocalized(
        key: key,
        in: AppAssemblyBundle.bundle,
        tableName: "VoiceRoomLocalized",
        arguments: args
    )
}
