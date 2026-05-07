//
//  AssemblyLocalized.swift
//  AppAssembly
//

import Foundation
import AtomicX

private let AssemblyLocalizeTableName = "AssemblyLocalized"

func AssemblyLocalize(_ key: String, _ args: CVarArg...) -> String {
    return BundleLoader.moduleLocalized(
        key: key,
        in: AppAssemblyBundle.bundle,
        tableName: AssemblyLocalizeTableName,
        arguments: args
    )
}
