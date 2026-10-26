import Foundation

extension RealtimeASRResponse {
    static let notificationKey = "onRecvRealtimeTranscriberResponse"

    init(dict: [String: Any]) {
        sessionID = dict["sessionID"] as? String ?? ""
        chunkIndex = (dict["chunkIndex"] as? NSNumber)?.intValue ?? 0
        isFinished = (dict["isFinished"] as? NSNumber)?.boolValue ?? false
        text = dict["text"] as? String ?? ""
    }
}

extension RealtimeASRSession {
    static let errStartTimeout: Int32 = RealtimeASRSessionImpl.errStartTimeout
}
