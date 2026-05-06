//
//  KeyMetrics.swift
//  TUILiveKit
//
//  Created by adamsfliu on 2024/6/13.
//

import Foundation
import ImSDK_Plus
import RTCRoomEngine
import AtomicXCore

public class KeyMetrics {
    private static let framework: Int = 1
    private static let language: Int = 3
    public static var componentType: Constants.ComponentType = .liveRoom
    
    static func reportFramework() {
        let apiParams: [String : Any] = [
            "api": "setFramework",
            "params": [
              "framework": framework,
              "component": componentType.rawValue,
              "language": language,
            ],
          ]
        callExperimentalAPI(params: apiParams)
    }
    
    public static func reportEventData(eventKey: Int) {
        let apiParams: [String: Any] = [
            "api": "KeyMetricsStats",
            "params": [
                "key": eventKey,
            ],
        ]
        callExperimentalAPI(params: apiParams)
    }
    
    static func reportEventData(event: Constants.DataReport.SGMetricsEvent) {
        reportEventData(eventKey: event.rawValue)
    }
    
    static func setComponent(_ component: Int) {
        let apiParams: [String: Any] = [
            "api": "component",
            "component": component,
        ]
        do {
            let jsonData = try JSONSerialization.data(withJSONObject: apiParams, options: [])
            if let jsonString = String(data: jsonData, encoding: .utf8) {
                LiveCoreView.callExperimentalAPI(jsonString)
            }
        } catch {
            LiveKitLog.error("\(#file)", "\(#line)", "setComponent: \(error.localizedDescription)")
        }
    }
    
    static func reportAtomicMetrics(platform: Int) {
        let param: [String: Any] = ["UIComponentType": platform]
        do {
            let jsonData = try JSONSerialization.data(withJSONObject: param, options: [])
            if let jsonString = String(data: jsonData, encoding: .utf8) {
                V2TIMManager.sharedInstance().callExperimentalAPI(api: "reportTUIFeatureUsage",
                                                                  param: jsonString as NSObject) { _ in
                } fail: { code, desc in
                    LiveKitLog.error("\(#file)", "\(#line)", "reportAtomicMetrics failed: \(code) \(desc ?? "")")
                }
            }
        } catch {
            LiveKitLog.error("\(#file)", "\(#line)", "reportAtomicMetrics: \(error.localizedDescription)")
        }
    }
    
    private static func callExperimentalAPI(params: [String : Any]) {
        do {
            let jsonData = try JSONSerialization.data(withJSONObject: params, options: .prettyPrinted)
            if let jsonString = String(data: jsonData, encoding: .utf8) {
                print(jsonString)
                TUIRoomEngine.sharedInstance().callExperimentalAPI(jsonStr: jsonString) { message in
                }
            } else {
                print("Error converting JSON data to string")
            }
        } catch {
            print("Error converting dictionary to JSON: \(error.localizedDescription)")
        }
    }
}
