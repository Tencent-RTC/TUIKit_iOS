//
//  CallingLocalized.swift
//  AppAssembly
//

import Foundation
import AtomicX

// MARK: Calling

private let CallingLocalizeTableName = "CallingLocalized"

func CallingLocalize(_ key: String, _ args: CVarArg...) -> String {
    return BundleLoader.moduleLocalized(
        key: key,
        in: AppAssemblyBundle.bundle,
        tableName: CallingLocalizeTableName,
        arguments: args
    )
}
