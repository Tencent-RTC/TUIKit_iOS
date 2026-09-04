import Foundation

public enum MessageAlignment: String, CaseIterable {
    case left
    case right
    case twoSided = "two-sided"
}

enum MessageAction: String, CaseIterable {
    case copy
    case recall
    case quote
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

    private static let translateTargetLanguageKey = "com.atomicx.translateTargetLanguage"

    public var translateTargetLanguage: String {
        get {
            if let stored = UserDefaults.standard.string(forKey: Self.translateTargetLanguageKey), !stored.isEmpty {
                return stored
            }
            return Locale.current.languageCode ?? "en"
        }
        set {
            UserDefaults.standard.set(newValue, forKey: Self.translateTargetLanguageKey)
        }
    }

    var messageActionList: [MessageAction] = MessageAction.allCases
    var enableCreateConversation: Bool = true
    var conversationActionList: [ConversationAction] = [.delete, .mute, .pin, .markUnread, .clearHistory]
    var hideSendButton: Bool = false

    var hideSearch: Bool = false
    var avatarShape: GlobalAvatarShape = .rounded
    private init() {
        AppBuilderHelper.loadBundledConfig(into: self)
    }
}

public class AppBuilderHelper {
    static func loadBundledConfig(into config: AppBuilderConfig) {
        // bundle 中不存在 appConfig.json 属正常情况（接入方未提供），静默跳过
        guard let url = Bundle.main.url(forResource: "appConfig", withExtension: "json") else {
            return
        }
        do {
            let data = try Data(contentsOf: url)
            guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
                print("[AppBuilder] appConfig.json 解析失败：顶层结构不是字典")
                return
            }
            parseConfig(from: json, into: config)
        } catch {
            print("[AppBuilder] appConfig.json 加载失败: \(error.localizedDescription)")
        }
    }

    public static func setJsonPath(path: String) {
        do {
            let data = try Data(contentsOf: URL(fileURLWithPath: path))
            guard let json = try JSONSerialization.jsonObject(with: data, options: []) as? [String: Any] else {
                print("[AppBuilder] setJsonPath 解析失败：顶层结构不是字典, path=\(path)")
                return
            }
            parseConfig(from: json, into: AppBuilderConfig.shared)
        } catch {
            print("[AppBuilder] setJsonPath 加载失败: \(error.localizedDescription), path=\(path)")
        }
    }

    private static func parseConfig(from json: [String: Any], into config: AppBuilderConfig) {
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
