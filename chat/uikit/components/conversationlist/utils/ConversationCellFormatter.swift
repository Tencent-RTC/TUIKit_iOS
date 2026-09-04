import UIKit
import AtomicXCore

extension ConversationInfo {
    var shouldShowDoNotDisturbIndicator: Bool {
        guard receiveOption == .notNotify else { return false }
        return groupType != .meeting
    }
}

enum ConversationSendStatusIndicator {
    case none
    case error
    case sending
}

enum ConversationCellFormatter {

    private static let unreadCountBadgeThreshold = 2

    // MARK: - Time

    static func timeText(for conversation: ConversationInfo) -> String? {
        guard let timestamp = conversation.lastMessage?.timestamp, timestamp > 0 else {
            return nil
        }
        return DateHelper.convertDateToYMDStr(Date(timeIntervalSince1970: TimeInterval(timestamp)))
    }

    // MARK: - Send Status

    static func sendStatus(for conversation: ConversationInfo) -> ConversationSendStatusIndicator {
        switch conversation.lastMessage?.status {
        case .sendFail, .violation:
            return .error
        case .sending:
            return .sending
        default:
            return .none
        }
    }

    // MARK: - Subtitle

    static func subtitleAttributedText(for conversation: ConversationInfo) -> NSAttributedString {
        let colors = TUIChatKitTheme.colors

        let font = FontScheme.caption2Regular
        let secondary = colors.textColorSecondary
        let error = colors.textColorError
        let countUnit = LocalizedChatString("MessageCount")
        let atTag = atTagText(for: conversation)
        let result = NSMutableAttributedString()

        if let draft = conversation.draft, !draft.isEmpty {
            appendUnreadPrefixIfNeeded(to: result, conversation: conversation, countUnit: countUnit, color: secondary, font: font)
            let draftLabel = LocalizedChatString("MessageTypeDraftFormat")
            result.append(makeAttr(atTag, error, font))
            result.append(makeAttr(draftLabel, error, font))
            result.append(emojiRenderedAttr(draft, color: secondary, font: font))
            return result
        }

        let finalText = finalSubtitleText(for: conversation, countUnit: countUnit)
        result.append(makeAttr(atTag, error, font))
        result.append(emojiRenderedAttr(finalText, color: secondary, font: font))
        return result
    }

    // MARK: - Private

    private static func appendUnreadPrefixIfNeeded(to result: NSMutableAttributedString,
                                                   conversation: ConversationInfo,
                                                   countUnit: String,
                                                   color: UIColor,
                                                   font: UIFont) {
        guard conversation.receiveOption == .notNotify, conversation.unreadCount >= unreadCountBadgeThreshold else {
            return
        }
        result.append(makeAttr("[\(conversation.unreadCount)\(countUnit)]", color, font))
    }

    private static func finalSubtitleText(for conversation: ConversationInfo, countUnit: String) -> String {
        let subtitle = MessageListHelper.getMessageAbstract(conversation.lastMessage)
        let stripped = strippingMentionBlocks(from: subtitle, message: conversation.lastMessage)
        if conversation.receiveOption == .notNotify, conversation.unreadCount >= unreadCountBadgeThreshold {
            return "[\(conversation.unreadCount)\(countUnit)] \(stripped)"
        }
        return stripped
    }

    private static func emojiRenderedAttr(_ text: String, color: UIColor, font: UIFont) -> NSAttributedString {
        guard text.contains("[TUIEmoji_") else {
            return makeAttr(text, color, font)
        }
        return EmojiManager.shared.createStyledAttributedString(fromEmojiCodes: text, font: font, textColor: color)
    }

    private static func strippingMentionBlocks(from text: String, message: MessageInfo?) -> String {
        guard let message = message,
              message.messageType == .text,
              !message.atUserList.isEmpty else {
            return text
        }
        return text.replacingOccurrences(of: "@[^\\s@]+\\s", with: "", options: .regularExpression)
    }

    private static func atTagText(for conversation: ConversationInfo) -> String {
        guard conversation.unreadCount > 0,
              conversation.conversationID.hasPrefix("group_"),
              let atInfoList = conversation.groupAtInfoList,
              !atInfoList.isEmpty else {
            return ""
        }

        var hasAtAll = false
        var hasAtMe = false
        for atInfo in atInfoList {
            switch atInfo.atType {
            case .atMe:
                hasAtMe = true
            case .atAll:
                hasAtAll = true
            case .atAllAtMe:
                hasAtAll = true
                hasAtMe = true
            }
        }

        var result = ""
        if hasAtAll {
            result += LocalizedChatString("MentionAtAllTag")
        }
        if hasAtMe {
            result += LocalizedChatString("MentionAtMeTag")
        }
        return result
    }

    private static func makeAttr(_ text: String, _ color: UIColor, _ font: UIFont) -> NSAttributedString {
        guard !text.isEmpty else {
            return NSAttributedString()
        }
        return NSAttributedString(string: text, attributes: [.foregroundColor: color, .font: font])
    }
}
