//
//  GuideLocalized.swift
//  AppAssembly
//

import Foundation
import AtomicX

private let guideLocalizedTableName = "GuideLocalized"

func GuideLocalize(_ key: String, _ args: CVarArg...) -> String {
    return BundleLoader.moduleLocalized(
        key: key,
        in: AppAssemblyBundle.bundle,
        tableName: guideLocalizedTableName,
        arguments: args
    )
}
