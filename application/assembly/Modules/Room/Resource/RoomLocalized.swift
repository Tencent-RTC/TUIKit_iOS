//
//  RoomLocalized.swift
//  AppAssembly
//

import Foundation
import AtomicX

func RoomLocalize(_ key: String, _ args: CVarArg...) -> String {
    return BundleLoader.moduleLocalized(
        key: key,
        in: AppAssemblyBundle.bundle,
        tableName: "RoomLocalized",
        arguments: args
    )
}
