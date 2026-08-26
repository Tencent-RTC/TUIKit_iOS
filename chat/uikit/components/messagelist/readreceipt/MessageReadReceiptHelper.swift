import UIKit
import AtomicXCore

enum MessageReadReceiptDisplayState {
    case unread
    case read
    case allRead
}

enum MessageReadReceiptHelper {

    static func shouldShowReadReceipt(_ message: MessageInfo) -> Bool {
        return AppBuilderConfig.shared.enableReadReceipt
            && message.isSentBySelf
            && message.needReadReceipt
            && message.status == .sendSuccess
            && message.messageType != .tips
    }

    static func displayState(_ message: MessageInfo) -> MessageReadReceiptDisplayState {
        let receipt = message.readReceiptInfo
        if message.conversationType != .group {
            return receipt?.isPeerRead == true ? .read : .unread
        }
        if receipt != nil && (receipt?.unreadCount ?? 0) == 0 {
            return .allRead
        }
        if (receipt?.readCount ?? 0) > 0 {
            return .read
        }
        return .unread
    }

    static func receiptText(_ message: MessageInfo) -> String {
        switch displayState(message) {
        case .unread:
            return LocalizedChatString("MessageReadC2CUnRead")
        case .read:
            if message.conversationType != .group {
                return LocalizedChatString("MessageReadC2CRead")
            }
            let readCount = message.readReceiptInfo?.readCount ?? 0
            return "\(readCount) \(LocalizedChatString("MessageReadPartRead"))"
        case .allRead:
            return LocalizedChatString("MessageReadAllRead")
        }
    }

    static func displayName(for member: GroupMember) -> String {
        if let nameCard = member.nameCard, !nameCard.isEmpty { return nameCard }
        if let nickname = member.nickname, !nickname.isEmpty { return nickname }
        return member.userID
    }
}
