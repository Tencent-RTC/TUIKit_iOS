//
//  KeyMetrics.swift
//  TUICallKit
//
//  Created by yukiwwwang on 2026/01/06.
//

import Foundation
import TUICore
import AtomicXCore

#if canImport(TXLiteAVSDK_TRTC)
import TXLiteAVSDK_TRTC
#elseif canImport(TXLiteAVSDK_Professional)
import TXLiteAVSDK_Professional
#endif

class KeyMetrics {
    private static let TAG = "KeyMetrics"
    private static let API_REPORT_ROOM_ENGINE_EVENT = "reportRoomEngineEvent"
    private static var lastReportedCallId: String = ""
    
    enum EventId: Int {
        case received = 171010
        case wakeup = 171011
    }
    
    static func countUV(eventId: EventId, callId: String) {
        let isDuplicateCall = (callId == lastReportedCallId) && !callId.isEmpty
        if eventId == .received && !callId.isEmpty {
            lastReportedCallId = callId
        }
        
        if isDuplicateCall && eventId == .received {
            Logger.info("\(TAG) skip duplicate report for callId: \(callId)")
            return
        }
        
        switch eventId {
        case .received:
            countEvent(eventId: eventId, callId: callId)
        case .wakeup:
            if callId == lastReportedCallId {
                return
            }
            lastReportedCallId = callId
            countEvent(eventId: eventId, callId: callId)
        }
    }
    
    static func reset() {
        lastReportedCallId = ""
    }
    
    static func flushMetrics() {
        var paramsJson: [String: Any] = [:]
        paramsJson["sdkAppId"] = TUILogin.getSdkAppID()
        paramsJson["report"] = "report"
        
        var jsonParams: [String: Any] = [:]
        jsonParams["api"] = "KeyMetricsStats"
        jsonParams["params"] = paramsJson
        
        if let jsonData = try? JSONSerialization.data(withJSONObject: jsonParams),
           let jsonString = String(data: jsonData, encoding: .utf8) {
            TRTCCloud.sharedInstance().callExperimentalAPI(jsonString)
        }
    }
    
    private static func countEvent(eventId: EventId, callId: String) {
        trackForKibana(eventId: eventId, callId: callId)
        trackForTRTC(eventId: eventId)
    }
    
    private static func trackForKibana(eventId: EventId, callId: String) {
        do {
            let extensionJson = buildExtensionJson(callId: callId)
            let extensionString = String(data: try JSONSerialization.data(withJSONObject: extensionJson), encoding: .utf8) ?? ""
            let payload = buildEventPayload(eventId: eventId, extensionMessage: extensionString)
            
            if let payloadData = try? JSONSerialization.data(withJSONObject: payload),
               let payloadString = String(data: payloadData, encoding: .utf8) {
                V2TIMManager.sharedInstance()?.callExperimentalAPI(api: API_REPORT_ROOM_ENGINE_EVENT,
                                                                   param: payloadString as NSObject,
                                                                   succ: {_ in
                    Logger.info("\(TAG) trackForKibana success: eventId=\(eventId)")
                }, fail: { code, desc in
                    Logger.error("\(TAG) trackForKibana failed: code=\(code), desc=\(desc ?? "")")
                })
            }
        } catch {
            Logger.error("\(TAG) trackForKibana exception: eventId=\(eventId), error=\(error)")
        }
    }
    
    private static func trackForTRTC(eventId: EventId) {
        var paramsJson: [String: Any] = [:]
        paramsJson["opt"] = "CountPV"
        paramsJson["key"] = eventId.rawValue
        paramsJson["withInstanceTrace"] = false
        paramsJson["version"] = TUICALL_VERSION
        
        var jsonParams: [String: Any] = [:]
        jsonParams["api"] = "KeyMetricsStats"
        jsonParams["params"] = paramsJson
        
        if let jsonData = try? JSONSerialization.data(withJSONObject: jsonParams),
           let jsonString = String(data: jsonData, encoding: .utf8) {
            TRTCCloud.sharedInstance().callExperimentalAPI(jsonString)
        }
        
        if TUILogin.getSdkAppID() > 0 {
            flushMetrics()
        }
    }
    
    private static func buildExtensionJson(callId: String) -> [String: Any] {
        var json: [String: Any] = [:]
        
        let activeCall = CallStore.shared.state.value.activeCall
        
        // Basic Info
        json[JsonKeys.callId] = callId
        json[JsonKeys.intRoomId] = Int(activeCall.roomId) ?? 0
        json[JsonKeys.strRoomId] = activeCall.roomId
        json[JsonKeys.uiKitVersion] = TUICALL_VERSION
        
        // Platform Info
        json[JsonKeys.platform] = "ios"
        json[JsonKeys.framework] = FrameworkConstants.framework
        json[JsonKeys.deviceBrand] = "Apple"
        json[JsonKeys.deviceModel] = getDeviceModel()
        json[JsonKeys.iosVersion] = UIDevice.current.systemVersion
        
        return json
    }
    
    private static func buildEventPayload(eventId: EventId, extensionMessage: String) -> [String: Any] {
        var json: [String: Any] = [:]
        json[JsonKeys.eventId] = eventId.rawValue
        json[JsonKeys.eventCode] = 0
        json[JsonKeys.eventResult] = 0
        json[JsonKeys.eventMessage] = TUICALL_VERSION
        json[JsonKeys.moreMessage] = ""
        json[JsonKeys.extensionMessage] = extensionMessage
        return json
    }
    
    private static func getDeviceModel() -> String {
        var systemInfo = utsname()
        uname(&systemInfo)
        let machineMirror = Mirror(reflecting: systemInfo.machine)
        let identifier = machineMirror.children.reduce("") { identifier, element in
            guard let value = element.value as? Int8, value != 0 else { return identifier }
            return identifier + String(UnicodeScalar(UInt8(value)))
        }
        return identifier
    }
    
    private struct JsonKeys {
        // Event Payload Keys
        static let eventId = "event_id"
        static let eventCode = "event_code"
        static let eventResult = "event_result"
        static let eventMessage = "event_message"
        static let moreMessage = "more_message"
        static let extensionMessage = "extension_message"
        
        // Basic Info Keys
        static let callId = "call_id"
        static let intRoomId = "int_room_id"
        static let strRoomId = "str_room_id"
        static let uiKitVersion = "ui_kit_version"
        
        // Platform Info Keys
        static let platform = "platform"
        static let framework = "framework"
        static let deviceBrand = "device_brand"
        static let deviceModel = "device_model"
        static let iosVersion = "ios_version"
        static let isForeground = "is_foreground"
        static let isScreenLocked = "is_screen_locked"
    }
}
