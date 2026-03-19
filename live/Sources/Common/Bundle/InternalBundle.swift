//
//  InternalBundle.swift
//  TUIAudienceList
//
//  Created by gg on 2025/4/10.
//

import Foundation

var internalBundle: Bundle {
    return Bundle.liveBundle
}

func internalLocalized(_ key: String, replaces: CVarArg...) -> String {
    return .liveLocalizedReplace(key, replaces: replaces)
}

func internalImage(_ named: String, rtlFlipped: Bool = false) -> UIImage? {
    return .liveBundleImage(named, rtlFlipped: rtlFlipped)
}
