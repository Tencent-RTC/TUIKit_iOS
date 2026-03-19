//
// Copyright (c) 2024 Tencent.
//
//  TEBeautyExtension.swift
//  TEBeautyKit
//
//  Created by jackyixue on 2024/7/15.
//  Converted to Swift by ssc on 2026/1/26.
//

import Foundation
import TUICore
import TEBeautyKit

@objc public class TEBeautyExtension: NSObject {

    @objc public static func register() {
        TUICore.registerExtension(
            String.TUICORE_TEBEAUTYEXTENSION_GETBEAUTYPANEL,
            object: TEBeautyService.shared
        )
        TUICore.registerService(
            String.TUICORE_TEBEAUTYSERVICE,
            object: TEBeautyService.shared
        )
    }

    @objc public static func setLicense(_ licenseUrl: String, key licenseKey: String, completion: ((_ code: Int, _ message: String?) -> Void)? = nil) {
        TEBeautyKit.setTELicense(licenseUrl, key: licenseKey) { code, message in
            completion?(code, message)
        }
    }
}

fileprivate extension String {
    static let TUICORE_TEBEAUTYEXTENSION_GETBEAUTYPANEL = "TUICore_TEBeautyExtension_GetBeautyPanel"
    static let TUICORE_TEBEAUTYEXTENSION_DESTROY_BEAUTYPANEL = "TUICore_TEBeautyExtension_Destroy_BeautyPanel"
    static let TUICORE_TEBEAUTYSERVICE = "TUICore_TEBeautyService"
}
