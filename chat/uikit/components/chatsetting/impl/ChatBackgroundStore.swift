import Foundation

final class ChatBackgroundStore {
    static let shared = ChatBackgroundStore()

    static let didChangeNotification = Notification.Name("ChatBackgroundDidChangeNotification")

    static let conversationIDUserInfoKey = "conversationID"

    private static let keyPrefix = "chat_background::"

    private let defaults = UserDefaults.standard

    func imageURI(forConversationID conversationID: String) -> String? {
        return normalize(defaults.string(forKey: Self.keyPrefix + conversationID))
    }

    func setImageURI(_ uri: String?, forConversationID conversationID: String) {
        let key = Self.keyPrefix + conversationID
        if let normalized = normalize(uri) {
            defaults.set(normalized, forKey: key)
        } else {
            defaults.removeObject(forKey: key)
        }
        NotificationCenter.default.post(
            name: Self.didChangeNotification,
            object: nil,
            userInfo: [Self.conversationIDUserInfoKey: conversationID]
        )
    }

    private init() {}

    private func normalize(_ uri: String?) -> String? {
        guard let trimmed = uri?.trimmingCharacters(in: .whitespaces), !trimmed.isEmpty else {
            return nil
        }
        return trimmed
    }
}

struct ChatBackgroundPresetItem {
    let imageURI: String?
    let thumbnailURI: String?

    var isDefault: Bool {
        return imageURI == nil
    }
}

enum ChatBackgroundPresetProvider {

    private static let fullImageURLTemplate = "https://im.sdk.qcloud.com/download/tuikit-resource/conversation-backgroundImage/backgroundImage_%d_full.png"
    private static let thumbnailURLTemplate = "https://im.sdk.qcloud.com/download/tuikit-resource/conversation-backgroundImage/backgroundImage_%d.png"
    private static let presetCount = 7

    static func presetItems() -> [ChatBackgroundPresetItem] {
        var items = [ChatBackgroundPresetItem(imageURI: nil, thumbnailURI: nil)]
        for index in 1 ... presetCount {
            items.append(ChatBackgroundPresetItem(
                imageURI: String(format: fullImageURLTemplate, index),
                thumbnailURI: String(format: thumbnailURLTemplate, index)
            ))
        }
        return items
    }
}
