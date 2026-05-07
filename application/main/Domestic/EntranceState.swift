//
//  EntranceState.swift
//  main
//

import Foundation
import AppAssembly

struct EntranceState {
    var modules: [ResolvedModule] = []

    var isReportViewVisible: Bool = false

    var userAvatarURL: String = ""

    var isNeedFaceAuth: Bool = false
}
