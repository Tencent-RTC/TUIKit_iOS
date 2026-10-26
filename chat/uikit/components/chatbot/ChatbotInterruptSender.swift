import Foundation
import ImSDK_Plus
import AtomicXCore

/// 打断动作抽象，对齐 Android ChatbotInterruptAction。
protocol ChatbotInterruptAction {
    /// 返回是否真正发起了一次打断（节流或参数不足时返回 false）。
    func send(messageID: String, fallbackMsgKey: String, completion: CompletionClosure?) -> Bool
}

/// 机器人控制信令的传输层，对齐 Android ChatbotControlMessageTransport。
protocol ChatbotControlMessageTransport {
    func send(conversationID: String, customData: String, completion: CompletionClosure?)
}

/// 按 msgKey 打断机器人的流式回复，对齐 Android ChatbotInterruptSender。
final class ChatbotInterruptSender: ChatbotInterruptAction {
    private let conversationID: String
    private let transport: ChatbotControlMessageTransport
    private let elapsedRealtime: () -> TimeInterval
    private var lastSentAt: TimeInterval?

    private static let sendInterval: TimeInterval = 1.0

    init(conversationID: String,
         transport: ChatbotControlMessageTransport = ImsdkChatbotControlMessageTransport(),
         elapsedRealtime: @escaping () -> TimeInterval = { ProcessInfo.processInfo.systemUptime }) {
        self.conversationID = conversationID
        self.transport = transport
        self.elapsedRealtime = elapsedRealtime
    }

    func send(messageID: String, fallbackMsgKey: String, completion: CompletionClosure?) -> Bool {
        if messageID.isEmpty && fallbackMsgKey.isEmpty {
            return false
        }
        let now = elapsedRealtime()
        if let lastSentAt = lastSentAt, now - lastSentAt < Self.sendInterval {
            return false
        }
        lastSentAt = now
        if messageID.isEmpty {
            sendWithMessageKey(fallbackMsgKey, completion: completion)
        } else {
            resolveMessageKeyAndSend(messageID: messageID, fallbackMsgKey: fallbackMsgKey, completion: completion)
        }
        return true
    }

    private func resolveMessageKeyAndSend(messageID: String, fallbackMsgKey: String, completion: CompletionClosure?) {
        V2TIMManager.sharedInstance().findMessages(messageIDList: [messageID], succ: { [weak self] messages in
            let messageKey = messages?.first.flatMap { Self.generateMessageKey($0) } ?? ""
            let resolved = messageKey.isEmpty ? fallbackMsgKey : messageKey
            self?.sendWithMessageKey(resolved, completion: completion)
        }, fail: { [weak self] code, desc in
            guard let self = self else { return }
            if !fallbackMsgKey.isEmpty {
                self.sendWithMessageKey(fallbackMsgKey, completion: completion)
            } else {
                completion?(.failure(ErrorInfo(code: Int(code), message: desc ?? "")))
            }
        })
    }

    private func sendWithMessageKey(_ msgKey: String, completion: CompletionClosure?) {
        guard !msgKey.isEmpty else {
            completion?(.failure(ErrorInfo(code: Int(ERR_INVALID_PARAMETERS.rawValue), message: "Chatbot message key is unavailable")))
            return
        }
        transport.send(
            conversationID: conversationID,
            customData: ChatbotMessageProtocol.createInterruptPayload(msgKey: msgKey),
            completion: completion
        )
    }

    /// msgKey 格式对齐旧版 TUIChat：seq_random_timestamp。
    private static func generateMessageKey(_ message: V2TIMMessage) -> String? {
        guard let timestamp = message.timestamp else { return nil }
        return String(format: "%llu_%llu_%.0f", message.seq, message.random, timestamp.timeIntervalSince1970)
    }
}

/// 打断信令走 ImSDK 直发：onlineUserOnly + 不计入 lastMessage / 未读数。
final class ImsdkChatbotControlMessageTransport: ChatbotControlMessageTransport {
    func send(conversationID: String, customData: String, completion: CompletionClosure?) {
        guard let data = customData.data(using: .utf8),
              let message = V2TIMManager.sharedInstance().createCustomMessage(data: data) else {
            completion?(.failure(ErrorInfo(code: Int(ERR_INVALID_PARAMETERS.rawValue), message: "Failed to create chatbot control message")))
            return
        }
        message.isExcludedFromLastMessage = true
        message.isExcludedFromUnreadCount = true
        V2TIMManager.sharedInstance().sendMessage(
            message: message,
            receiver: ChatUtil.getUserID(conversationID),
            groupID: ChatUtil.getGroupID(conversationID),
            priority: .PRIORITY_DEFAULT,
            onlineUserOnly: true,
            offlinePushInfo: nil,
            progress: nil,
            succ: {
                completion?(.success(()))
            },
            fail: { code, desc in
                completion?(.failure(ErrorInfo(code: Int(code), message: desc ?? "")))
            }
        )
    }
}
