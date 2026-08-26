import UIKit

enum ReactionEmojiRenderer {

    static let quickEmojiCount = 6

    static func image(for reactionID: String) -> UIImage? {
        guard let emoji = EmojiManager.shared.getAllEmojis().first(where: { $0.name == reactionID }) else {
            return nil
        }
        return image(for: emoji)
    }

    static func image(for emoji: EmojiData) -> UIImage? {
        let attributed = EmojiManager.shared.createAttributedStringFromEmojiData(emoji)
        guard attributed.length > 0,
              let attachment = attributed.attribute(.attachment, at: 0, effectiveRange: nil) as? NSTextAttachment else {
            return nil
        }
        return attachment.image
    }

    static func quickEmojis() -> [EmojiData] {
        let all = EmojiManager.shared.getPickerEmojis()
        guard !all.isEmpty else { return [] }

        var result: [EmojiData] = []
        let recentIDs = EmojiManager.shared.getRecentEmojis(groupID: EmojiManager.shared.reactionGroupID())
        for id in recentIDs.prefix(quickEmojiCount) {
            if let emoji = all.first(where: { $0.name == id }) {
                result.append(emoji)
            }
        }
        if result.count < quickEmojiCount {
            for emoji in all {
                if result.count >= quickEmojiCount { break }
                if !result.contains(where: { $0.name == emoji.name }) {
                    result.append(emoji)
                }
            }
        }
        return Array(result.prefix(quickEmojiCount))
    }
}
