import Foundation
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

    private static let callIconWidth: CGFloat = 12

    private static let callIconSpacing: CGFloat = 4

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

        let abstract = MessageDisplayHelper.getMessageAbstract(conversation.lastMessage)
        result.append(makeAttr(atTag, error, font))
        appendUnreadPrefixIfNeeded(to: result, conversation: conversation, countUnit: countUnit, color: secondary, font: font)
        if !abstract.isEmpty, let mediaType = callMediaType(of: conversation.lastMessage) {
            result.append(callIconAttr(mediaType, color: secondary, font: font))
        }
        result.append(emojiRenderedAttr(abstract, color: secondary, font: font))
        return result
    }

    // MARK: - Private

    private static func appendUnreadPrefixIfNeeded(to result: NSMutableAttributedString,
                                                   conversation: ConversationInfo,
                                                   countUnit: String,
                                                   color: UIColor,
                                                   font: UIFont) {
        guard conversation.receiveOption != .receive, conversation.unreadCount > 0 else {
            return
        }
        result.append(makeAttr("[\(conversation.unreadCount)\(countUnit)] ", color, font))
    }

    private static func callMediaType(of message: MessageInfo?) -> CallStreamMediaType? {
        guard let message = message,
              message.messageType == .custom,
              message.status != .revoked,
              message.status != .violation,
              let model = CallMessageParser.parse(message),
              model.streamMediaType != .unknown else {
            return nil
        }
        return model.streamMediaType
    }

    private static func callIconAttr(_ mediaType: CallStreamMediaType, color: UIColor, font: UIFont) -> NSAttributedString {
        guard let source = callIconImage(for: mediaType), source.size.width > 0 else {
            return NSAttributedString()
        }
        let width = callIconWidth
        let height = width * source.size.height / source.size.width
        let attachment = NSTextAttachment()
        attachment.image = source.withTintColor(color, renderingMode: .alwaysOriginal)
        let center = (font.ascender + font.descender) / 2
        attachment.bounds = CGRect(x: 0, y: center - height / 2, width: width, height: height)
        let result = NSMutableAttributedString(attachment: attachment)
        result.append(callIconSpacerAttr())
        return result
    }

    private static func callIconImage(for mediaType: CallStreamMediaType) -> UIImage? {
        let name = mediaType == .voice ? "message_call_audio" : "message_call_video"
        guard let source = AtomicXChatResources.image(named: name) else {
            return nil
        }
        guard mediaType == .video else {
            return source
        }
        return horizontallyFlippedImage(source)
    }

    private static func horizontallyFlippedImage(_ image: UIImage) -> UIImage {
        guard let cgImage = image.cgImage else {
            return image.withHorizontallyFlippedOrientation()
        }
        let rawImage = UIImage(cgImage: cgImage, scale: image.scale, orientation: .up)
        let format = UIGraphicsImageRendererFormat()
        format.scale = image.scale
        format.opaque = false
        return UIGraphicsImageRenderer(size: rawImage.size, format: format).image { context in
            context.cgContext.translateBy(x: rawImage.size.width, y: 0)
            context.cgContext.scaleBy(x: -1, y: 1)
            rawImage.draw(in: CGRect(origin: .zero, size: rawImage.size))
        }
    }

    private static func callIconSpacerAttr() -> NSAttributedString {
        let spacer = NSTextAttachment()
        spacer.bounds = CGRect(x: 0, y: 0, width: callIconSpacing, height: 0)
        return NSAttributedString(attachment: spacer)
    }

    private static func emojiRenderedAttr(_ text: String, color: UIColor, font: UIFont) -> NSAttributedString {
        guard text.contains("[TUIEmoji_") else {
            return makeAttr(text, color, font)
        }
        return EmojiManager.shared.createStyledAttributedString(fromEmojiCodes: text, font: font, textColor: color)
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
