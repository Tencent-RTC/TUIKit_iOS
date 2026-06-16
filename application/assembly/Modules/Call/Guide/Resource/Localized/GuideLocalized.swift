//
//  GuideLocalized.swift
//  AppAssembly
//
//  Guide 模块 - 本地化辅助函数 — 底层统一使用 AtomicX BundleLoader.moduleLocalized

import Foundation
import AtomicX

private let guideLocalizedTableName = "CallingLocalized"

func GuideLocalize(_ key: String, _ args: CVarArg...) -> String {
    return BundleLoader.moduleLocalized(
        key: key,
        in: AppAssemblyBundle.bundle,
        tableName: guideLocalizedTableName,
        arguments: args
    )
}
