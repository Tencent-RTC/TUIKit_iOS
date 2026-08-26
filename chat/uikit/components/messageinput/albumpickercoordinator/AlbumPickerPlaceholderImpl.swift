import AtomicXCore
import Combine
import Foundation
import UIKit

final class AlbumPickerPlaceholderStoreImpl {
    static let shared = AlbumPickerPlaceholderStoreImpl()

    @Published private(set) var placeholdersByConversation: [String: [MessageInfo]] = [:]

    private static let c2cConversationPrefix = "c2c_"

    private static let groupConversationPrefix = "group_"

    private static let defaultVideoType = "mp4"

    private static let maxProgress = 100

    func upsert(conversationID: String, info: MessagePlaceholderInfo) {
        runOnMainThread { [weak self] in
            guard let self = self else { return }
            var messages = self.placeholdersByConversation[conversationID] ?? []
            let existingIndex = messages.firstIndex(where: { $0.msgID == info.placeholderID })
            let timestamp = existingIndex
                .map { messages[$0].timestamp }
                .flatMap { $0 } ?? Int64(Date().timeIntervalSince1970)
            let message = Self.makePlaceholderMessage(
                conversationID: conversationID,
                info: info,
                timestamp: timestamp
            )
            guard let index = existingIndex else {
                messages.append(message)
                self.placeholdersByConversation[conversationID] = messages
                return
            }
            if Self.isEquivalent(messages[index], message) {
                return
            }
            messages[index] = message
            self.placeholdersByConversation[conversationID] = messages
        }
    }

    func remove(conversationID: String, placeholderID: String) {
        runOnMainThread { [weak self] in
            guard let self = self else { return }
            var messages = self.placeholdersByConversation[conversationID] ?? []
            guard messages.contains(where: { $0.msgID == placeholderID }) else { return }
            messages.removeAll { $0.msgID == placeholderID }
            if messages.isEmpty {
                self.placeholdersByConversation.removeValue(forKey: conversationID)
            } else {
                self.placeholdersByConversation[conversationID] = messages
            }
        }
    }

    static func localMediaPath(of message: MessageInfo) -> String? {
        switch message.messagePayload {
        case .image(let payload):
            return payload.originalImagePath?.isEmpty == false ? payload.originalImagePath : nil
        case .video(let payload):
            return payload.videoPath?.isEmpty == false ? payload.videoPath : nil
        default:
            return nil
        }
    }

    private init() {}

    private static func makePlaceholderMessage(conversationID: String,
                                               info: MessagePlaceholderInfo,
                                               timestamp: Int64) -> MessageInfo {
        let loginUserInfo = LoginStore.shared.state.value.loginUserInfo
        var sender = MessageSenderInfo()
        sender.userID = loginUserInfo?.userID ?? ""
        sender.avatarURL = loginUserInfo?.avatarURL
        sender.nickname = loginUserInfo?.nickname

        let isGroup = conversationID.hasPrefix(groupConversationPrefix)
        let targetID: String
        if isGroup {
            targetID = String(conversationID.dropFirst(groupConversationPrefix.count))
        } else if conversationID.hasPrefix(c2cConversationPrefix) {
            targetID = String(conversationID.dropFirst(c2cConversationPrefix.count))
        } else {
            targetID = conversationID
        }

        var message = MessageInfo()
        message.msgID = info.placeholderID
        message.status = .sending
        message.timestamp = timestamp
        message.from = sender
        message.to = targetID
        message.isSentBySelf = true
        message.conversationType = isGroup ? .group : .c2c
        message.messageType = info.mediaKind == .video ? .video : .image
        message.messagePayload = makePlaceholderPayload(info: info)
        message.uploadMediaProgress = min(max(info.progress, 0), maxProgress)
        return message
    }

    private static func makePlaceholderPayload(info: MessagePlaceholderInfo) -> MessagePayload {
        let width = Int(info.thumbnailSize.width.rounded())
        let height = Int(info.thumbnailSize.height.rounded())
        if info.mediaKind == .video {
            var payload = VideoMessagePayload()
            payload.videoSnapshotPath = info.thumbnailPath
            payload.videoSnapshotWidth = width
            payload.videoSnapshotHeight = height
            payload.videoType = defaultVideoType
            payload.videoDuration = info.videoDuration
            payload.videoPath = info.mediaPath
            return .video(payload)
        }
        var payload = ImageMessagePayload()
        payload.largeImagePath = info.thumbnailPath
        payload.originalImagePath = info.mediaPath
        payload.originalImageWidth = width
        payload.originalImageHeight = height
        return .image(payload)
    }

    private static func isEquivalent(_ lhs: MessageInfo, _ rhs: MessageInfo) -> Bool {
        if lhs.uploadMediaProgress != rhs.uploadMediaProgress {
            return false
        }
        if localMediaPath(of: lhs) != localMediaPath(of: rhs) {
            return false
        }
        return thumbnailDescriptor(of: lhs) == thumbnailDescriptor(of: rhs)
    }

    private static func thumbnailDescriptor(of message: MessageInfo) -> String? {
        switch message.messagePayload {
        case .video(let payload):
            return "\(payload.videoSnapshotPath ?? "")_\(payload.videoSnapshotWidth)x\(payload.videoSnapshotHeight)"
        case .image(let payload):
            return "\(payload.largeImagePath ?? "")_\(payload.originalImageWidth)x\(payload.originalImageHeight)"
        default:
            return nil
        }
    }

    private func runOnMainThread(_ action: @escaping () -> Void) {
        if Thread.isMainThread {
            action()
        } else {
            DispatchQueue.main.async(execute: action)
        }
    }
}
