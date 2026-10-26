import Foundation

/// 机器人会话判定，对齐 Android ChatbotConversationPolicy。
enum ChatbotConversationPolicy {
    private static let chatbotIDPrefix = "@RBT#"

    static func isChatbotID(_ targetID: String?) -> Bool {
        return targetID?.hasPrefix(chatbotIDPrefix) == true
    }

    static func isChatbotConversation(_ conversationID: String?) -> Bool {
        return isChatbotID(targetID(conversationID))
    }

    static func targetID(_ conversationID: String?) -> String? {
        guard let conversationID = conversationID, !conversationID.isEmpty else {
            return nil
        }
        if conversationID.hasPrefix("c2c_") {
            return String(conversationID.dropFirst("c2c_".count))
        }
        if conversationID.hasPrefix("group_") {
            return String(conversationID.dropFirst("group_".count))
        }
        return nil
    }
}

/// 转发目标过滤：机器人会话不允许作为转发目标，对齐 Android ChatbotForwardTargetPolicy。
enum ChatbotForwardTargetPolicy {
    static func partition(_ conversationIDs: [String]) -> (allowed: [String], rejectedChatbot: [String]) {
        let rejected = conversationIDs.filter { ChatbotConversationPolicy.isChatbotConversation($0) }
        let allowed = conversationIDs.filter { !ChatbotConversationPolicy.isChatbotConversation($0) }
        return (allowed, rejected)
    }
}
