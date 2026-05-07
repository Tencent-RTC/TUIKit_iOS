//
//  ResolvedModule.swift
//  main
//

import Foundation
import AppAssembly

struct ResolvedModule {
    let config: ModuleConfig

    var badgeCount: UInt64 = 0

    var isVisible: Bool = true

    weak var provider: ModuleProvider?
}
