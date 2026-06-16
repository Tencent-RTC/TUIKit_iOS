//
//  LiveLocalized.swift
//  AppAssembly
//

import Foundation
import AtomicX

func LiveLocalize(_ key: String, _ args: CVarArg...) -> String {
    return BundleLoader.moduleLocalized(
        key: key,
        in: AppAssemblyBundle.bundle,
        tableName: "LiveLocalized",
        arguments: args
    )
}
