//
//  LoginLocalized.swift
//  login
//

import Foundation
import AtomicX

private let LoginLocalizeTableName = "LoginLocalized"

func LoginLocalize(_ key: String, _ args: CVarArg...) -> String {
    return BundleLoader.moduleLocalized(
        key: key,
        in: Bundle.loginResources,
        tableName: LoginLocalizeTableName,
        arguments: args
    )
}
