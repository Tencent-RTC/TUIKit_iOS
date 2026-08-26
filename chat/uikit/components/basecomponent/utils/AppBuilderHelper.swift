import Foundation

enum MessageAlignment: String, CaseIterable {
    case left
    case right
    case twoSided = "two-sided"
}

enum MessageAction: String, CaseIterable {
    case copy
    case recall

    case forward
    case delete

}

enum ConversationAction: String, CaseIterable {
    case delete
    case mute
    case pin
    case markUnread
    case clearHistory
}

enum GlobalAvatarShape: String, CaseIterable {
    case circular
    case square
    case rounded
}

public class AppBuilderConfig {
    public static let shared = AppBuilderConfig()
    var themeMode: ThemeMode = .system
    var primaryColor: String = "#1C66E5"
    var messageAlignment: MessageAlignment = .twoSided
    public var enableReadReceipt: Bool = false
    public var translateTargetLanguage: String = ""

    var messageActionList: [MessageAction] = [.copy, .recall, .delete]
    var enableCreateConversation: Bool = true
    var conversationActionList: [ConversationAction] = [.delete, .mute, .pin, .markUnread, .clearHistory]
    var hideSendButton: Bool = false

    var hideSearch: Bool = false
    var avatarShape: GlobalAvatarShape = .circular
    private init() {}
}

public class AppBuilderHelper {
    public static func setJsonPath(path: String) {
        guard let data = try? Data(contentsOf: URL(fileURLWithPath: path)),
              let json = try? JSONSerialization.jsonObject(with: data, options: []) as? [String: Any]
        else {
            return
        }
        parseConfig(from: json)
    }

    private static func parseConfig(from json: [String: Any]) {
        let config = AppBuilderConfig.shared
        if let theme = json["theme"] as? [String: Any] {
            if let modeString = theme["mode"] as? String,
               let mode = ThemeMode(rawValue: modeString)
            {
                config.themeMode = mode
            }
            if let primaryColor = theme["primaryColor"] as? String {
                config.primaryColor = primaryColor
            }
        }
        if let messageList = json["messageList"] as? [String: Any] {
            if let alignmentString = messageList["alignment"] as? String,
               let alignment = MessageAlignment(rawValue: alignmentString)
            {
                config.messageAlignment = alignment
            }
            if let enableReadReceipt = messageList["enableReadReceipt"] as? Bool {
                config.enableReadReceipt = enableReadReceipt
            }
            if let actionList = messageList["messageActionList"] as? [String] {
                config.messageActionList = actionList.compactMap { MessageAction(rawValue: $0) }
            }
        }
        if let conversationList = json["conversationList"] as? [String: Any] {
            if let enableCreateConversation = conversationList["enableCreateConversation"] as? Bool {
                config.enableCreateConversation = enableCreateConversation
            }
            if let actionList = conversationList["conversationActionList"] as? [String] {
                config.conversationActionList = actionList.compactMap { ConversationAction(rawValue: $0) }
            }
        }
        if let messageInput = json["messageInput"] as? [String: Any] {
            if let hideSendButton = messageInput["hideSendButton"] as? Bool {
                config.hideSendButton = hideSendButton
            }

        }
        if let search = json["search"] as? [String: Any] {
            if let hideSearch = search["hideSearch"] as? Bool {
                config.hideSearch = hideSearch
            }
        }
        if let avatar = json["avatar"] as? [String: Any] {
            if let shapeString = avatar["shape"] as? String,
               let shape = GlobalAvatarShape(rawValue: shapeString)
            {
                config.avatarShape = shape
            }
        }
    }
}
