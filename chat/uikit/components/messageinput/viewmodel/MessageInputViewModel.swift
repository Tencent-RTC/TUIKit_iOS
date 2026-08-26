import Foundation
import AVFoundation
import UIKit
import AtomicXCore

final class MessageInputViewModel {
    private static let groupConversationPrefix = "group_"

    private static let pushDescriptionMaxLength: Int = 50

    private static let groupChatTypeValue: Int = 2

    private static let c2cChatTypeValue: Int = 1

    let conversationID: String

    let config: MessageInputConfigProtocol

    var onSendFailure: ((String) -> Void)?

    var isGroupChat: Bool {
        return conversationID.hasPrefix(Self.groupConversationPrefix)
    }

    var groupID: String {
        return isGroupChat ? String(conversationID.dropFirst(Self.groupConversationPrefix.count)) : conversationID
    }

    private let store: MessageInputStore

    private let conversationStore = ConversationListStore.create()

    private var conversationInfo: ConversationInfo?

    // MARK: - Init

    init(conversationID: String, config: MessageInputConfigProtocol = ChatMessageInputConfig()) {
        self.conversationID = conversationID
        self.config = config
        self.store = MessageInputStore.create(conversationID: conversationID)
        fetchConversationInfo()
    }

    // MARK: - Send

    func sendTextMessage(_ text: String, mentionList: [MentionInfo] = [], quotedMessage: MessageInfo? = nil) {
        var option = createSendMessageOption(
            pushDescription: EmojiManager.shared.createLocalizedStringFromEmojiCodes(text)
        )
        if !mentionList.isEmpty {
            option.atUserList = mentionList.map { $0.userID }
        }
        if let quoted = quotedMessage {
            option.quotedMessage = quoted
        }
        store.sendMessage(payload: .text(TextSendMessagePayload(text: text)), option: option) { [weak self] result in
            self?.handleSendResult(result)
        }
    }

    func sendImageMessage(_ imagePath: String) {
        var payload = ImageSendMessagePayload(imagePath: imagePath)
        if let image = UIImage(contentsOfFile: imagePath) {
            payload.imageWidth = Int(image.size.width)
            payload.imageHeight = Int(image.size.height)
        }
        store.sendMessage(
            payload: .image(payload),
            option: createSendMessageOption(pushDescription: LocalizedChatString("MessageTypeImage"))
        ) { [weak self] result in
            self?.handleSendResult(result)
        }
    }

    func sendVideoMessage(_ videoPath: String, snapshotPath: String) {
        var snapshotWidth = 0
        var snapshotHeight = 0
        if let image = UIImage(contentsOfFile: snapshotPath) {
            snapshotWidth = Int(image.size.width)
            snapshotHeight = Int(image.size.height)
        }
        let durationInSeconds = CMTimeGetSeconds(AVAsset(url: URL(fileURLWithPath: videoPath)).duration)
        let payload = VideoSendMessagePayload(
            videoFilePath: videoPath,
            videoType: "mp4",
            duration: Int(durationInSeconds),
            snapshotPath: snapshotPath,
            snapshotWidth: snapshotWidth,
            snapshotHeight: snapshotHeight
        )
        store.sendMessage(
            payload: .video(payload),
            option: createSendMessageOption(pushDescription: LocalizedChatString("MessageTypeVideo"))
        ) { [weak self] result in
            self?.handleSendResult(result)
        }
    }

    func sendFileMessage(_ filePath: String, fileName: String, fileSize: Int) {
        let payload = FileSendMessagePayload(filePath: filePath, fileName: fileName, fileSize: fileSize)
        store.sendMessage(
            payload: .file(payload),
            option: createSendMessageOption(pushDescription: LocalizedChatString("MessageTypeFile"))
        ) { [weak self] result in
            self?.handleSendResult(result)
        }
    }

    func sendFaceMessage(groupIndex: Int, faceData: String, quotedMessage: MessageInfo? = nil) {
        let payload = FaceSendMessagePayload(index: groupIndex, data: faceData)
        var option = createSendMessageOption(pushDescription: LocalizedChatString("MessageTypeAnimateEmoji"))
        if let quoted = quotedMessage {
            option.quotedMessage = quoted
        }
        store.sendMessage(payload: .face(payload), option: option) { [weak self] result in
            self?.handleSendResult(result)
        }
    }

    func sendVoiceMessage(_ voicePath: String, duration: Int) {
        let payload = AudioSendMessagePayload(audioFilePath: voicePath, duration: duration)
        store.sendMessage(
            payload: .audio(payload),
            option: createSendMessageOption(pushDescription: LocalizedChatString("MessageTypeVoice"))
        ) { [weak self] result in
            self?.handleSendResult(result)
        }
    }

    func convertLocalAudioToText(filePath: String, onCompleted: @escaping (String?) -> Void) {
        AiMediaProcessManager.convertLocalAudioToText(
            filePath: filePath,
            onSuccess: { text in
                DispatchQueue.main.async { onCompleted(text) }
            },
            onFailure: { [weak self] _, _ in
                DispatchQueue.main.async {
                    self?.notifySendFailure(LocalizedChatString("ConvertToTextFailed"))
                    onCompleted(nil)
                }
            }
        )
    }

    // MARK: - Draft

    func loadDraft(completion: @escaping (String?) -> Void) {
        conversationStore.getConversationInfo(
            conversationID: conversationID,
            completion: DraftConversationInfoHandler(
                onSuccess: { conversation in
                    DispatchQueue.main.async { completion(conversation.draft) }
                },
                onFailure: { _, _ in
                    DispatchQueue.main.async { completion(nil) }
                }
            )
        )
    }

    func saveDraft(_ text: String?) {
        let normalized = (text?.isEmpty == false) ? text : nil
        conversationStore.setConversationDraft(conversationID: conversationID, draft: normalized, completion: nil)
    }

    func clearDraft() {
        conversationStore.setConversationDraft(conversationID: conversationID, draft: nil, completion: nil)
    }

    // MARK: - Private

    private func fetchConversationInfo() {
        conversationStore.getConversationInfo(
            conversationID: conversationID,
            completion: DraftConversationInfoHandler(
                onSuccess: { [weak self] info in self?.conversationInfo = info },
                onFailure: { _, _ in }
            )
        )
    }

    private func handleSendResult(_ result: Result<Void, ErrorInfo>) {
        switch result {
        case .success:
            break
        case .failure(let error):
            notifySendFailure(Self.failureReason(from: error))
        }
    }

    private func notifySendFailure(_ reason: String) {
        if Thread.isMainThread {
            onSendFailure?(reason)
        } else {
            DispatchQueue.main.async { [weak self] in
                self?.onSendFailure?(reason)
            }
        }
    }

    private static func failureReason(from error: ErrorInfo) -> String {
        return LocalizedChatString("TUIGroupNoteSendFail")
    }

    private func createSendMessageOption(pushDescription: String) -> SendMessageOption {
        var option = SendMessageOption()
        option.needReadReceipt = config.enableReadReceipt
        option.offlinePushInfo = createOfflinePushInfo(pushDescription: pushDescription)
        return option
    }

    private func createOfflinePushInfo(pushDescription: String) -> OfflinePushInfo {
        let loginUserInfo = LoginStore.shared.state.value.loginUserInfo
        let selfUserId = loginUserInfo?.userID ?? ""
        let selfName = loginUserInfo?.nickname ?? selfUserId
        let chatName = conversationInfo?.title?.isEmpty == false ? conversationInfo?.title : nil
        let senderNickName = isGroupChat ? (chatName ?? groupID) : selfName

        let description = trimPushDescription(pushDescription)
        let ext = createOfflinePushExtJson(
            senderId: isGroupChat ? groupID : selfUserId,
            senderNickName: senderNickName,
            faceUrl: loginUserInfo?.avatarURL,
            content: description
        )

        var pushInfo = OfflinePushInfo()
        pushInfo.title = senderNickName
        pushInfo.description = description
        pushInfo.extensionInfo = [
            "ext": ext,
            "AndroidOPPOChannelID": "tuikit",
            "AndroidHuaWeiCategory": "IM",
            "AndroidVIVOCategory": "IM",
            "AndroidHonorImportance": "NORMAL",
            "AndroidMeizuNotifyType": 1,
            "iOSInterruptionLevel": "time-sensitive",
            "enableIOSBackgroundNotification": false
        ]
        return pushInfo
    }

    private func trimPushDescription(_ text: String, maxLength: Int = MessageInputViewModel.pushDescriptionMaxLength) -> String {
        let normalized = text.trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: "\n", with: " ")
            .replacingOccurrences(of: "\r", with: " ")
        return normalized.count <= maxLength ? normalized : String(normalized.prefix(maxLength))
    }

    private func createOfflinePushExtJson(
        senderId: String,
        senderNickName: String,
        faceUrl: String?,
        content: String?
    ) -> String {
        var entity: [String: Any] = [
            "sender": senderId,
            "nickname": senderNickName,
            "chatType": isGroupChat ? Self.groupChatTypeValue : Self.c2cChatTypeValue,
            "version": 1,
            "action": 1
        ]
        if let content = content, !content.isEmpty {
            entity["content"] = content
        }
        if let faceUrl = faceUrl {
            entity["faceUrl"] = faceUrl
        }
        let extDict: [String: Any] = [
            "entity": entity,
            "timPushFeatures": ["fcmPushType": 0, "fcmNotificationType": 0]
        ]
        if let jsonData = try? JSONSerialization.data(withJSONObject: extDict, options: []),
           let jsonString = String(data: jsonData, encoding: .utf8) {
            return jsonString
        }
        return "{}"
    }
}

// MARK: - GetConversationInfoCompletionHandler

private final class DraftConversationInfoHandler: GetConversationInfoCompletionHandler {
    private let onSuccessBlock: (ConversationInfo) -> Void

    private let onFailureBlock: (Int, String) -> Void

    init(onSuccess: @escaping (ConversationInfo) -> Void, onFailure: @escaping (Int, String) -> Void) {
        self.onSuccessBlock = onSuccess
        self.onFailureBlock = onFailure
    }

    func onSuccess(conversationInfo: ConversationInfo) {
        onSuccessBlock(conversationInfo)
    }

    func onFailure(code: Int, desc: String) {
        onFailureBlock(code, desc)
    }
}
