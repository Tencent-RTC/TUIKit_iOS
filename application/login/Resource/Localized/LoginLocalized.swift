//
//  LoginLocalized.swift
//  login
//

import Foundation
import AtomicX

private let LoginLocalizeTableName = "LoginLocalized"

func LoginLocalize(_ key: String) -> String {
    return BundleLoader.moduleLocalized(
        key: key,
        in: Bundle.loginResources,
        tableName: LoginLocalizeTableName
    )
}

func LoginLocalizeReplace(_ key: String, _ xxx: String) -> String {
    return LoginLocalize(key).replacingOccurrences(of: "xxx", with: xxx)
}

func LoginLocalizeReplace(_ key: String, _ xxx: String, _ yyy: String) -> String {
    return LoginLocalizeReplace(key, xxx).replacingOccurrences(of: "yyy", with: yyy)
}

func LoginLocalizeReplace(_ key: String, _ xxx: String, _ yyy: String, _ zzz: String) -> String {
    return LoginLocalizeReplace(key, xxx, yyy).replacingOccurrences(of: "zzz", with: zzz)
}
