//
//  RoomDataReporter.swift
//  TUIRoomKit
//
//  Created on 2026/11/24.
//  Copyright © 2026 Tencent. All rights reserved.
//

import AtomicXCore

class RoomDataReporter {
    fileprivate static let frameworkValue = 1
    fileprivate static let componentValue = 18
    fileprivate static let languageValue = 3
    
    static func reportComponent() {
        let jsonStr = """
            {
                "api":"LoginModule.setFramework",
                "params":{
                    "framework":\(frameworkValue),
                    "component":\(componentValue),
                    "language":\(languageValue)
                }
            }
        """
        RoomStore.shared.callExperimentalAPI(jsonStr: jsonStr, completion: nil)
    }
}
