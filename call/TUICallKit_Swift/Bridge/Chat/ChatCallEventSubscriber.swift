//
//  ChatCallEventSubscriber.swift
//  TUICallKit
//
import AtomicXCore
import Foundation

public final class ChatCallEventSubscriber: NSObject {
    public static let shared = ChatCallEventSubscriber()

    private static let startCallEventName = Notification.Name("tuicallkit.startCall")
    private static let startJoinEventName = Notification.Name("tuicallkit.startJoin")
    private static let keyParticipantIDs = "participantIds"
    private static let keyMediaType = "mediaType"
    private static let keyChatGroupID = "chatGroupId"
    private static let keyTimeout = "timeout"
    private static let keyCallID = "callId"

    private var isSubscribed = false

    private override init() {
        super.init()
    }

    public func ensureSubscribed() {
        guard !isSubscribed else { return }
        isSubscribed = true
        NotificationCenter.default.addObserver(self,
                                               selector: #selector(handleStartCallEvent(_:)),
                                               name: Self.startCallEventName,
                                               object: nil)
        NotificationCenter.default.addObserver(self,
                                               selector: #selector(handleStartJoinEvent(_:)),
                                               name: Self.startJoinEventName,
                                               object: nil)
    }

    @objc private func handleStartCallEvent(_ notification: Notification) {
        guard let userInfo = notification.userInfo,
              let participantIDs = userInfo[Self.keyParticipantIDs] as? [String],
              !participantIDs.isEmpty else { return }
        let mediaType: CallMediaType = (userInfo[Self.keyMediaType] as? String) == "video" ? .video : .audio
        let chatGroupID = userInfo[Self.keyChatGroupID] as? String ?? ""
        let timeout = userInfo[Self.keyTimeout] as? Int ?? 30

        var callParams = CallParams()
        callParams.chatGroupId = chatGroupID
        callParams.timeout = timeout
        TUICallKit.createInstance().calls(userIdList: participantIDs, mediaType: mediaType, params: callParams, completion: nil)
    }

    
    @objc private func handleStartJoinEvent(_ notification: Notification) {
        guard let callID = notification.userInfo?[Self.keyCallID] as? String, !callID.isEmpty else { return }
        TUICallKit.createInstance().join(callId: callID, completion: nil)
    }
}
