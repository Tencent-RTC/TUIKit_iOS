//
//  MainLocalized.swift
//  main
//

import Foundation
import AtomicX

private let MainLocalizeTableName = "MainLocalized"

func MainLocalize(_ key: String, _ args: CVarArg...) -> String {
    return BundleLoader.moduleLocalized(
        key: key,
        in: Bundle.main,
        tableName: MainLocalizeTableName,
        arguments: args
    )
}

// MARK: - String Extension for MainLocalize

extension String {
    static func mainLocalized(_ key: String) -> String {
        return MainLocalize(key)
    }
}
