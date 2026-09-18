//
//  String+Extension.swift
//  Pods
//
//  Created by ssc on 2025/8/29.
//

import Foundation

extension String {
    var atomicLocalized: String {
        return BundleLoader.moduleLocalized(key: self, in: atomicXBundle, tableName: AtomicXLocalizeTableName)
    }

    //MARK: Replace String
   func atomicLocalized(replaces: CVarArg...) -> String {
        return BundleLoader.moduleLocalized(key: self,
                                            in: atomicXBundle,
                                            tableName: AtomicXLocalizeTableName,
                                            arguments: replaces)
    }
}

let AtomicXLocalizeTableName = "AtomicXLocalized"
