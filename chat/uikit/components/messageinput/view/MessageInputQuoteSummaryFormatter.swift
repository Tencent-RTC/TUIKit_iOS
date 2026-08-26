import Foundation
import AtomicXCore

enum MessageInputQuoteSummaryFormatter {

    static func format(message: MessageInfo) -> String {
        guard let payload = message.messagePayload else {
            return ""
        }
        switch payload {
        case .text(let textPayload):
            return EmojiManager.shared.createLocalizedStringFromEmojiCodes(textPayload.text)
        case .image:
            return LocalizedChatString("MessageTypeImage")
        case .video:
            return LocalizedChatString("MessageTypeVideo")
        case .audio:
            return LocalizedChatString("MessageTypeVoice")
        case .file(let filePayload):
            return filePayload.fileName ?? LocalizedChatString("MessageTypeFile")
        case .merged:
            return LocalizedChatString("MessageTypeMerged")
        case .face(let facePayload):
            return facePayload.faceData ?? LocalizedChatString("MessageTypeCustom")
        case .custom:
            return LocalizedChatString("MessageTypeCustom")
        case .tips:
            return ""
        case .stream:
            return LocalizedChatString("MessageTypeCustom")
        }
    }
}
