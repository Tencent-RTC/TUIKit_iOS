//
//  PrivacyLocalized.swift
//  privacy
//

import Foundation
import AtomicX

private let PrivacyLocalizeTableName = "PrivacyLocalized"

func PrivacyLocalize(_ key: String, _ args: CVarArg...) -> String {
    return BundleLoader.moduleLocalized(
        key: key,
        in: Bundle.main,
        tableName: PrivacyLocalizeTableName,
        arguments: args
    )
}
