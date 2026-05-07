//
//  File.swift
//  RTCubeLab
//
//  Created by gg on 2026/3/31.
//

import ImSDK_Plus
import RTCRoomEngine
import TXLiteAVSDK_Professional

enum EnvironmentOperation {
    static func switchEnvironment(testEnv: Bool) {
        switchIMEnvironment(enableTest: testEnv)
        setNetEnv(isTestEnv: testEnv)
    }

    private static func switchIMEnvironment(enableTest: Bool) {
        var jsonObject = [String: Any]()
        jsonObject["api"] = "setTestEnvironment"
        var params = [String: Any]()
        params["enableRoomTestEnv"] = enableTest
        jsonObject["params"] = params

        if let jsonData = try? JSONSerialization.data(withJSONObject: jsonObject, options: []),
           let jsonString = String(data: jsonData, encoding: .utf8)
        {
            TUIRoomEngine.sharedInstance().callExperimentalAPI(jsonStr: jsonString) { _ in }
        }

        V2TIMManager.sharedInstance().callExperimentalAPI(
            api: "setTestEnvironment",
            param: NSNumber(value: enableTest)
        ) { _ in } fail: { _, _ in }
    }

    private static func setNetEnv(isTestEnv: Bool) {
        let setNetEnv: [String: Any] = [
            "api": "setNetEnv",
            "params": [
                "env": isTestEnv ? 1 : 0,
            ],
        ]
        callExperimentalAPI(json: setNetEnv)
    }

    @discardableResult
    private static func callExperimentalAPI(json: [String: Any]) -> String? {
        if let jsonData = try? JSONSerialization.data(withJSONObject: json, options: []),
           let jsonString = String(data: jsonData, encoding: .utf8)
        {
            return TRTCCloud.sharedInstance().callExperimentalAPI(jsonString)
        }
        return nil
    }
}
