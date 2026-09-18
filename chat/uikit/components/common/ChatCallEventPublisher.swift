import Foundation

enum ChatCallEventPublisher {
    /// TUICallKit_Swift 的 ChatCallEventSubscriber 保持一致。
    static let startCallEventName = Notification.Name("tuicallkit.startCall")
    static let startJoinEventName = Notification.Name("tuicallkit.startJoin")

    static let keyParticipantIDs = "participantIds"
    static let keyMediaType = "mediaType"
    static let keyChatGroupID = "chatGroupId"
    static let keyTimeout = "timeout"
    static let keyCallID = "callId"

    static let defaultTimeoutSeconds = 30

    enum MediaType: String {
        case audio
        case video
    }

    /// 发布"发起通话"事件
    /// - Parameters:
    ///   - participantIDs: 被叫用户 ID 列表
    ///   - mediaType: 媒体类型（语音/视频）
    ///   - chatGroupID: 群聊场景下的群 ID，单聊传 nil
    ///   - timeout: 信令超时时间（秒）
    static func publishStartCall(
        participantIDs: [String],
        mediaType: MediaType,
        chatGroupID: String? = nil,
        timeout: Int = ChatCallEventPublisher.defaultTimeoutSeconds
    ) {
        guard !participantIDs.isEmpty else { return }
        var userInfo: [String: Any] = [
            keyParticipantIDs: participantIDs,
            keyMediaType: mediaType.rawValue,
            keyTimeout: timeout,
        ]
        if let chatGroupID = chatGroupID, !chatGroupID.isEmpty {
            userInfo[keyChatGroupID] = chatGroupID
        }
        NotificationCenter.default.post(name: startCallEventName, object: nil, userInfo: userInfo)
    }

    static func publishStartJoin(callID: String) {
        guard !callID.isEmpty else { return }
        NotificationCenter.default.post(
            name: startJoinEventName,
            object: nil,
            userInfo: [keyCallID: callID]
        )
    }
}
