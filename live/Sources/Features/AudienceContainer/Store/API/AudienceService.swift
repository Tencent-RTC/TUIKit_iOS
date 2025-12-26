//
//  AudienceService.swift
//  TUILiveKit
//
//  Created by jeremiawang on 2024/11/19.
//

import RTCRoomEngine
#if canImport(TXLiteAVSDK_TRTC)
    import TXLiteAVSDK_TRTC
#elseif canImport(TXLiteAVSDK_Professional)
    import TXLiteAVSDK_Professional
#endif
import AtomicXCore

class AudienceService {
    let roomEngine: TUIRoomEngine
    let trtcCloud: TRTCCloud

    init() {
        self.roomEngine = TUIRoomEngine.sharedInstance()
        self.trtcCloud = roomEngine.getTRTCCloud()
    }
}

// MARK: - MediaAPI

extension AudienceService {
    func enableGravitySensor(enable: Bool) {
        roomEngine.enableGravitySensor(enable: enable)
    }
    
    func updateVideoQuality(_ quality: VideoQuality) {
        roomEngine.updateVideoQuality(quality.tuiType())
    }
    
    func setBeautyStyle(_ style: TXBeautyStyle) {
        trtcCloud.getBeautyManager().setBeautyStyle(style)
    }
    
    func switchPlaybackQuality(_ quality: VideoQuality) {
        var jsonObject = [String: Any]()
        jsonObject["api"] = "switchPlaybackQuality"
        var params = [String: Any]()
        params["quality"] = quality.tuiType().rawValue
        jsonObject["params"] = params
        guard let jsonData = try? JSONSerialization.data(withJSONObject: jsonObject, options: []),
              let jsonString = String(data: jsonData, encoding: .utf8)
        else {
            return
        }
        TUIRoomEngine.sharedInstance().callExperimentalAPI(jsonStr: jsonString) { msg in
            LiveKitLog.info("\(#file)", "\(#line)", "switchPlaybackQuality msg: \(msg)")
        }
    }
    
    func getMultiPlaybackQuality(roomId: String, completion: (([VideoQuality]) -> Void)? = nil) {
        var jsonObject = [String: Any]()
        jsonObject["api"] = "queryPlaybackQualityList"
        var params = [String: Any]()
        params["roomId"] = roomId
        jsonObject["params"] = params
        guard let jsonData = try? JSONSerialization.data(withJSONObject: jsonObject, options: []),
              let jsonString = String(data: jsonData, encoding: .utf8) else { return }
        TUIRoomEngine.sharedInstance().callExperimentalAPI(jsonStr: jsonString) { [weak self] msg in
            guard let self = self else { return }
            self.decodeQualityJsonString(msg, completion: completion)
        }
    }
    
    private func decodeQualityJsonString(_ jsonString: String, completion: (([VideoQuality]) -> Void)? = nil) {
        struct Response: Decodable {
            let code: Int
            let data: [Int32]
            let message: String
        }
        guard let jsonData = jsonString.data(using: .utf8),
              let response = try? JSONDecoder().decode(Response.self, from: jsonData)
        else {
            LiveKitLog.error("\(#file)", "\(#line)", "msg: \(jsonString)")
            return
        }
        var qualityList: [VideoQuality] = []
        for quality in response.data {
            if quality == TUIVideoQuality.quality1080P.rawValue {
                qualityList.append(.quality1080P)
            }
            if quality == TUIVideoQuality.quality720P.rawValue {
                qualityList.append(.quality720P)
            }
            if quality == TUIVideoQuality.quality540P.rawValue {
                qualityList.append(.quality540P)
            }
            if quality == TUIVideoQuality.quality360P.rawValue {
                qualityList.append(.quality360P)
            }
        }
        completion?(qualityList)
    }
}
