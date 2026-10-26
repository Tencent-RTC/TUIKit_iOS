import Foundation

/// 机器人会话状态机，对齐 Android ChatbotConversationReducer。
enum ChatbotConversationState: Equatable {
    case idle
    case waiting(requestTimestampSeconds: Int64)
    case streaming(messageID: String, msgKey: String)
}

enum ChatbotConversationEvent {
    case textMessageSent(timestampSeconds: Int64)
    case botMessageReceived(messageID: String, data: ChatbotMessageData)
    case historyRestored(messageID: String?, data: ChatbotMessageData?)
    case cleared
}

enum ChatbotConversationReducer {
    static func reduce(_ current: ChatbotConversationState, _ event: ChatbotConversationEvent) -> ChatbotConversationState {
        switch event {
        case .textMessageSent(let timestampSeconds):
            return .waiting(requestTimestampSeconds: timestampSeconds)
        case .botMessageReceived(let messageID, let data):
            return reduceMessage(current, messageID: messageID, data: data)
        case .historyRestored(let messageID, let data):
            if let messageID = messageID,
               let data = data,
               data.source == .flow,
               !data.isFinished {
                return .streaming(messageID: messageID, msgKey: data.msgKey)
            }
            return .idle
        case .cleared:
            return .idle
        }
    }

    private static func reduceMessage(_ current: ChatbotConversationState, messageID: String, data: ChatbotMessageData) -> ChatbotConversationState {
        switch data.source {
        case .flow:
            return data.isFinished ? .idle : .streaming(messageID: messageID, msgKey: data.msgKey)
        case .error:
            return .idle
        case .interrupt, .unknown:
            return current
        }
    }
}

extension ChatbotMessageData {
    var isVisualResponse: Bool {
        return source == .flow || source == .error
    }
}
