//
//  MineLocalized.swift
//  mine
//

import Foundation
import AtomicX

private let MineLocalizeTableName = "MineLocalized"

func MineLocalize(_ key: String, _ args: CVarArg...) -> String {
    return BundleLoader.moduleLocalized(
        key: key,
        in: Bundle.main,
        tableName: MineLocalizeTableName,
        arguments: args
    )
}
