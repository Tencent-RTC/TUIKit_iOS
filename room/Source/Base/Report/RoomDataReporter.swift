//
//  RoomDataReporter.swift
//  TUIRoomKit
//
//  Created on 2026/2/24.
//  Copyright © 2026 Tencent. All rights reserved.
//

import RTCRoomEngine

class RoomDataReporter {
    fileprivate static let frameworkValue = 1
    fileprivate static let componentValue = 18
    fileprivate static let languageValue = 3
    
    static func setFramework() {
        let jsonStr = """
            {
                "api":"setFramework",
                "params":{
                    "framework":\(frameworkValue),
                    "component":\(componentValue),
                    "language":\(languageValue)
                }
            }
        """
        TUIRoomEngine.sharedInstance().callExperimentalAPI(jsonStr: jsonStr) { _ in
        }
    }
}
