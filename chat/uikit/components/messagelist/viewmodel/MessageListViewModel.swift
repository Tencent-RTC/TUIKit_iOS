import Foundation
import Combine
import AtomicXCore

final class MessageListViewModel {
    private static let groupIDPrefixLength = 6

    private static let locateMessagePageCount = 10

    private static let initialLoadPageCount = 20

    private static let latestLoadPageCount = 20

    private static let aroundMessagePageCount = 20

    private static let timeGroupingInterval: TimeInterval = 300

    let conversationID: String

    let config: MessageListConfigProtocol & MessageActionConfigProtocol

    let locateMessage: MessageInfo?

    @Published private(set) var messageList: [MessageInfo] = []

    @Published private(set) var hasMoreOlderMessage: Bool = false

    @Published private(set) var hasMoreNewerMessage: Bool = false

    @Published private(set) var isMultiSelectMode: Bool = false

    @Published private(set) var selectedMessageIDs: Set<String> = []

    @Published private(set) var processingAuxiliaryTextIDs: Set<String> = []

    @Published private(set) var hiddenAuxiliaryTextIDs: Set<String> = []

    var messageEventPublisher: AnyPublisher<MessageEvent, Never> {
        store.messageEventPublisher.eraseToAnyPublisher()
    }

    var messageListStore: MessageListStore { store }

    var currentUserID: String? {
        let uid = LoginStore.shared.state.value.loginUserInfo?.userID
        return (uid?.isEmpty == false) ? uid : nil
    }

    var isGroupChat: Bool { conversationID.hasPrefix("group_") }

    var groupID: String { isGroupChat ? String(conversationID.dropFirst(Self.groupIDPrefixLength)) : conversationID }

    private let store: MessageListStore

    private let conversationStore: ConversationListStore

    private var cancellables = Set<AnyCancellable>()

    private var storeMessages: [MessageInfo] = []

    private var processingMessages: [MessageInfo] = []

    private var lastVisiblePlaceholderSignatures: [String] = []

    // MARK: - Init

    init(conversationID: String,
         config: MessageListConfigProtocol & MessageActionConfigProtocol = ChatMessageListConfig(),
         locateMessage: MessageInfo? = nil,
         conversationStore: ConversationListStore = ConversationListStore.create()) {
        self.conversationID = conversationID
        self.config = config
        self.locateMessage = locateMessage
        self.conversationStore = conversationStore
        self.store = MessageListStore.create(conversationID: conversationID)
        subscribeState()
    }

    // MARK: - Load (分页拉取，对齐声明式 fetchMessages / loadMoreOlder / loadMoreNewer)

    func fetchInitialMessages(completion: (() -> Void)? = nil) {
        var option = MessageLoadOption()
        if let locate = locateMessage, !locate.msgID.isEmpty {
            option.cursor = locate
            option.direction = .both
            option.pageCount = Self.locateMessagePageCount
        } else {
            option.direction = .older
            option.pageCount = Self.initialLoadPageCount
        }
        store.loadMessages(option: option) { [weak self] result in
            DispatchQueue.main.async {
                self?.logIfFailed(result, action: "fetchInitialMessages")
                completion?()
            }
        }
    }

    func loadOlderMessages(completion: (() -> Void)? = nil) {
        store.loadOlderMessages { [weak self] result in
            DispatchQueue.main.async {
                self?.logIfFailed(result, action: "loadOlderMessages")
                completion?()
            }
        }
    }

    func loadNewerMessages(completion: (() -> Void)? = nil) {
        store.loadNewerMessages { [weak self] result in
            DispatchQueue.main.async {
                self?.logIfFailed(result, action: "loadNewerMessages")
                completion?()
            }
        }
    }

    func reloadLatestMessages(completion: ((Bool) -> Void)? = nil) {
        var option = MessageLoadOption()
        option.direction = .older
        option.pageCount = Self.latestLoadPageCount
        store.loadMessages(option: option) { [weak self] result in
            DispatchQueue.main.async {
                self?.logIfFailed(result, action: "reloadLatestMessages")
                if case .success = result {
                    completion?(true)
                } else {
                    completion?(false)
                }
            }
        }
    }

    func loadMessagesAroundMessage(_ message: MessageInfo, completion: (() -> Void)? = nil) {
        guard !message.msgID.isEmpty || (message.sequence ?? 0) > 0 else { completion?(); return }
        var option = MessageLoadOption()
        option.cursor = message
        option.direction = .both
        option.pageCount = Self.aroundMessagePageCount
        store.loadMessages(option: option) { [weak self] result in
            DispatchQueue.main.async {
                self?.logIfFailed(result, action: "loadMessagesAroundMessage")
                completion?()
            }
        }
    }

    func loadOlderMessagesUntilSequence(_ sequence: Int64,
                                        maxLoadCount: Int,
                                        completion: (() -> Void)? = nil) {
        if messageList.contains(where: { $0.sequence == sequence }) || maxLoadCount <= 0 || !hasMoreOlderMessage {
            completion?()
            return
        }
        loadOlderMessages { [weak self] in
            guard let self = self else { completion?(); return }
            self.loadOlderMessagesUntilSequence(sequence, maxLoadCount: maxLoadCount - 1, completion: completion)
        }
    }

    func fetchGroupAtInfoList(completion: @escaping ([GroupAtInfo]) -> Void) {
        guard isGroupChat else { completion([]); return }
        let handler = GroupAtInfoFetchHandler { atInfoList in
            DispatchQueue.main.async { completion(atInfoList) }
        }
        conversationStore.getConversationInfo(conversationID: conversationID, completion: handler)
    }

    func isQuotedOriginalUnreachable(_ quoteInfo: MessageQuoteInfo) -> Bool {
        if quoteInfo.status == .revoked { return true }
        if quoteInfo.status == .deleted, quoteInfo.messagePayload == nil { return true }
        return false
    }

    // MARK: - Reaction (乐观更新：先本地插入/移除 chip，失败回滚，server 推送后以服务端数据为准)

    func toggleReaction(message: MessageInfo, reactionID: String) {
        guard !reactionID.isEmpty, !message.msgID.isEmpty else { return }
        guard let index = messageList.firstIndex(where: { $0.msgID == message.msgID }) else { return }
        let current = messageList[index]
        let isAdd = !(current.reactionList.first(where: { $0.reactionID == reactionID })?.reactedByMyself ?? false)

        let snapshot = current.reactionList
        var optimistic = current
        optimistic.reactionList = makeOptimisticReactionList(from: current.reactionList, reactionID: reactionID, add: isAdd)
        messageList[index] = optimistic

        let actionStore = MessageActionStore.create(message: current)
        let completion: (Result<Void, ErrorInfo>) -> Void = { [weak self] result in
            guard let self = self else { return }
            if case .failure = result {
                DispatchQueue.main.async {
                    guard let idx = self.messageList.firstIndex(where: { $0.msgID == message.msgID }) else { return }
                    self.messageList[idx].reactionList = snapshot
                }
            }
        }
        if isAdd {
            actionStore.addReaction(reactionID: reactionID, completion: completion)
        } else {
            actionStore.removeReaction(reactionID: reactionID, completion: completion)
        }
    }

    // MARK: - Delete / Forward / Read Receipt (转发给核心 store)

    func deleteMessages(_ messages: [MessageInfo], completion: (() -> Void)? = nil) {
        guard !messages.isEmpty else { completion?(); return }
        store.deleteMessages(messageList: messages) { [weak self] result in
            DispatchQueue.main.async {
                self?.logIfFailed(result, action: "deleteMessages")
                if case .success = result { completion?() }
            }
        }
    }

    func forwardMessages(_ messages: [MessageInfo],
                         option: ForwardMessageOption,
                         toConversationID targetConversationID: String,
                         completion: @escaping (Bool) -> Void) {
        store.forwardMessages(messageList: messages, option: option, conversationID: targetConversationID) { [weak self] result in
            DispatchQueue.main.async {
                self?.logIfFailed(result, action: "forwardMessages")
                if case .success = result { completion(true) } else { completion(false) }
            }
        }
    }

    func makeMergedForwardInfo(messages: [MessageInfo]) -> MergedForwardInfo {
        var info = MergedForwardInfo()
        info.title = MessageListHelper.generateMergedTitle(messages: messages, conversationID: conversationID)
        info.abstractList = MessageListHelper.generateAbstractList(messages: messages)
        info.compatibleText = "Merged messages"
        return info
    }

    func syncConversationAsRead() {
        clearConversationUnreadCount()
        conversationStore.markConversation(
            conversationIDList: [conversationID],
            markType: .unread,
            enable: false,
            completion: nil
        )
    }

    func clearConversationUnreadCount() {
        conversationStore.clearConversationUnreadCount(conversationID: conversationID, completion: nil)
    }

    func sendReadReceipts(for messages: [MessageInfo]) {
        let receiptMessages = messages.filter { !$0.isSentBySelf && $0.needReadReceipt }
        guard !receiptMessages.isEmpty else { return }
        store.sendMessageReadReceipts(messageList: receiptMessages, completion: nil)
    }

    func resendMessage(_ message: MessageInfo) {
        guard let payload = Self.sendPayload(from: message) else { return }
        var option = SendMessageOption()
        option.needReadReceipt = message.needReadReceipt
        option.atUserList = message.atUserList.isEmpty ? nil : message.atUserList
        option.isExtensionEnabled = message.isExtensionEnabled
        option.offlinePushInfo = message.offlinePushInfo
        store.deleteMessages(messageList: [message]) { _ in }
        let inputStore = MessageInputStore.create(conversationID: conversationID)
        inputStore.sendMessage(payload: payload, option: option) { [weak self] result in
            DispatchQueue.main.async {
                self?.logIfFailed(result, action: "resendMessage")
            }
        }
    }

    // MARK: - Multi-Select (对齐声明式 MultiSelectManager)

    private(set) var multiSelectAnchorMessageID: String?

    func enterMultiSelectMode(initialMessageID: String?) {
        if let id = initialMessageID, !id.isEmpty {
            selectedMessageIDs.insert(id)
            multiSelectAnchorMessageID = id
        }
        isMultiSelectMode = true
    }

    func exitMultiSelectMode() {
        isMultiSelectMode = false
        selectedMessageIDs.removeAll()
        multiSelectAnchorMessageID = nil
    }

    func toggleSelection(_ message: MessageInfo) {
        let msgID = message.msgID
        guard !msgID.isEmpty else { return }
        if selectedMessageIDs.contains(msgID) {
            selectedMessageIDs.remove(msgID)
        } else {
            selectedMessageIDs.insert(msgID)
        }
    }

    func isSelected(_ message: MessageInfo) -> Bool {
        return !message.msgID.isEmpty && selectedMessageIDs.contains(message.msgID)
    }

    func getSelectedMessages() -> [MessageInfo] {
        return messageList.filter { !$0.msgID.isEmpty && selectedMessageIDs.contains($0.msgID) }
    }

    // MARK: - Auxiliary Text (语音转文字 / 翻译，对齐 Android MessageListViewModel)

    func convertVoiceToText(_ message: MessageInfo) {
        let msgID = message.msgID
        guard !msgID.isEmpty else { return }
        guard !processingAuxiliaryTextIDs.contains(msgID) else { return }
        hiddenAuxiliaryTextIDs.remove(msgID)
        processingAuxiliaryTextIDs.insert(msgID)
        let actionStore = MessageActionStore.create(message: message)
        actionStore.convertVoiceToText(language: "") { [weak self] result in
            DispatchQueue.main.async {
                guard let self = self else { return }
                self.processingAuxiliaryTextIDs.remove(msgID)
                if case .failure = result {
                    WindowToastManager.shared.error(LocalizedChatString("ConvertToTextFailed"))
                }
            }
        }
    }

    func translateTextMessage(_ message: MessageInfo) {
        let msgID = message.msgID
        guard !msgID.isEmpty else { return }
        guard !processingAuxiliaryTextIDs.contains(msgID) else { return }
        guard case .text(let payload) = message.messagePayload else { return }
        let text = payload.text
        guard !text.isEmpty else { return }
        hiddenAuxiliaryTextIDs.remove(msgID)
        processingAuxiliaryTextIDs.insert(msgID)
        let targetLanguage = AppBuilderConfig.shared.translateTargetLanguage.isEmpty
            ? "en" : AppBuilderConfig.shared.translateTargetLanguage
        let actionStore = MessageActionStore.create(message: message)
        actionStore.translateText(sourceTextList: [text], sourceLanguage: nil, targetLanguage: targetLanguage) { [weak self] result in
            DispatchQueue.main.async {
                guard let self = self else { return }
                self.processingAuxiliaryTextIDs.remove(msgID)
                if case .failure = result {
                    WindowToastManager.shared.error(LocalizedChatString("TranslateFailed"))
                }
            }
        }
    }

    func auxiliaryTextState(for message: MessageInfo) -> AuxiliaryTextDisplayState {
        let msgID = message.msgID
        guard !msgID.isEmpty else { return .hidden }
        if hiddenAuxiliaryTextIDs.contains(msgID) { return .hidden }
        let isProcessing = processingAuxiliaryTextIDs.contains(msgID)
        if isProcessing { return .loading }
        switch message.messagePayload {
        case .audio(let payload):
            if let asrText = payload.asrText, !asrText.isEmpty {
                return .text(content: asrText, footer: nil)
            }
        case .text(let payload):
            if let translatedText = payload.translatedText, !translatedText.isEmpty {
                let targetLanguage = AppBuilderConfig.shared.translateTargetLanguage.isEmpty
                    ? "en" : AppBuilderConfig.shared.translateTargetLanguage
                let displayText = translatedText[targetLanguage] ?? translatedText.values.first ?? ""
                if !displayText.isEmpty {
                    return .text(content: displayText, footer: LocalizedChatString("TranslateDefaultTips"))
                }
            }
        default:
            break
        }
        return .hidden
    }

    // MARK: - Time Grouping (对齐声明式 getMessageTimeString：300s 聚合窗口)

    func messageTimeString(at index: Int) -> String? {
        guard index >= 0, index < messageList.count else { return nil }
        let message = messageList[index]
        guard let messageDate = Self.date(from: message.timestamp) else { return nil }
        switch MessageCellRegistry.shared.renderKind(for: message) {
        case .systemTip, .revoked:
            return nil
        default:
            break
        }
        if index == 0 {
            return DateHelper.convertDateToMessageTimeStr(messageDate)
        }
        let previous = messageList[index - 1]
        guard let previousDate = Self.date(from: previous.timestamp) else { return nil }
        if messageDate.timeIntervalSince(previousDate) > Self.timeGroupingInterval {
            return DateHelper.convertDateToMessageTimeStr(messageDate)
        }
        return nil
    }

    // MARK: - Private Helpers

    private func subscribeState() {
        store.state
            .subscribe(StatePublisherSelector(keyPath: \MessageListState.messageList))
            .receive(on: DispatchQueue.main)
            .sink { [weak self] list in
                self?.storeMessages = list
                self?.mergeMessageList()
            }
            .store(in: &cancellables)

        AlbumPickerPlaceholderStore.shared.placeholdersByConversation
            .receive(on: DispatchQueue.main)
            .sink { [weak self] placeholdersByConversation in
                guard let self = self else { return }
                self.processingMessages = placeholdersByConversation[self.conversationID] ?? []

                guard self.visiblePlaceholderSignatures() != self.lastVisiblePlaceholderSignatures else { return }
                self.mergeMessageList()
            }
            .store(in: &cancellables)

        store.state
            .subscribe(StatePublisherSelector(keyPath: \MessageListState.hasOlderMessages))
            .receive(on: DispatchQueue.main)
            .sink { [weak self] value in self?.hasMoreOlderMessage = value }
            .store(in: &cancellables)

        store.state
            .subscribe(StatePublisherSelector(keyPath: \MessageListState.hasNewerMessages))
            .receive(on: DispatchQueue.main)
            .sink { [weak self] value in self?.hasMoreNewerMessage = value }
            .store(in: &cancellables)
    }

    private func mergeMessageList() {
        let visiblePlaceholders = self.visiblePlaceholders()
        lastVisiblePlaceholderSignatures = visiblePlaceholders.map { placeholderSignature($0) }
        guard !visiblePlaceholders.isEmpty else {
            messageList = storeMessages
            return
        }
        messageList = storeMessages + visiblePlaceholders
    }

    private func visiblePlaceholders() -> [MessageInfo] {
        guard !processingMessages.isEmpty else { return [] }
        let sentMediaPaths = Set(storeMessages.compactMap { AlbumPickerPlaceholderStore.localMediaPath(of: $0) })
        guard !sentMediaPaths.isEmpty else { return processingMessages }
        return processingMessages.filter { placeholder in
            guard let mediaPath = AlbumPickerPlaceholderStore.localMediaPath(of: placeholder) else { return true }
            return !sentMediaPaths.contains(mediaPath)
        }
    }

    private func placeholderSignature(_ message: MessageInfo) -> String {
        let mediaPath = AlbumPickerPlaceholderStore.localMediaPath(of: message) ?? ""
        let thumbnailPath: String
        switch message.messagePayload {
        case .video(let payload): thumbnailPath = payload.videoSnapshotPath ?? ""
        case .image(let payload): thumbnailPath = payload.largeImagePath ?? ""
        default: thumbnailPath = ""
        }
        return "\(message.msgID)|\(thumbnailPath)|\(mediaPath)|\(message.uploadMediaProgress)"
    }

    private func visiblePlaceholderSignatures() -> [String] {
        return visiblePlaceholders().map { placeholderSignature($0) }
    }

    private func makeOptimisticReactionList(from list: [MessageReaction], reactionID: String, add: Bool) -> [MessageReaction] {
        var list = list
        guard let index = list.firstIndex(where: { $0.reactionID == reactionID }) else {
            if add {
                var reaction = MessageReaction(reactionID: reactionID)
                reaction.reactedByMyself = true
                reaction.totalUserCount = 1
                if let me = selfUserProfile() { reaction.partialUserList = [me] }
                list.append(reaction)
            }
            return list
        }

        var reaction = list[index]
        if add, !reaction.reactedByMyself {
            reaction.reactedByMyself = true
            reaction.totalUserCount += 1

            if let me = selfUserProfile() { reaction.partialUserList.append(me) }
        } else if !add, reaction.reactedByMyself {
            reaction.reactedByMyself = false
            reaction.totalUserCount = max(reaction.totalUserCount - 1, 0)
            if let myID = currentUserID { reaction.partialUserList.removeAll { $0.userID == myID } }
        }

        if reaction.totalUserCount <= 0 {
            list.remove(at: index)
        } else {
            list[index] = reaction
        }
        return list
    }

    private func selfUserProfile() -> UserProfile? {
        return LoginStore.shared.state.value.loginUserInfo
    }

    private static func date(from timestamp: Int64?) -> Date? {
        guard let timestamp = timestamp else { return nil }
        return Date(timeIntervalSince1970: TimeInterval(timestamp))
    }

    private static func sendPayload(from message: MessageInfo) -> SendMessagePayload? {
        guard let payload = message.messagePayload else { return nil }
        switch payload {
        case .text(let text):
            return .text(TextSendMessagePayload(text: text.text))
        case .custom(let custom):
            return .custom(CustomSendMessagePayload(
                customData: custom.customData,
                description: custom.description,
                extensionInfo: custom.extensionInfo
            ))
        case .image(let image):
            guard let imagePath = image.originalImagePath else { return nil }
            return .image(ImageSendMessagePayload(
                imagePath: imagePath,
                imageWidth: image.originalImageWidth,
                imageHeight: image.originalImageHeight
            ))
        case .audio(let audio):
            guard let audioPath = audio.audioPath else { return nil }
            return .audio(AudioSendMessagePayload(audioFilePath: audioPath, duration: audio.audioDuration))
        case .video(let video):
            guard let videoPath = video.videoPath,
                  let snapshotPath = video.videoSnapshotPath else { return nil }
            return .video(VideoSendMessagePayload(
                videoFilePath: videoPath,
                videoType: video.videoType ?? "mp4",
                duration: video.videoDuration,
                snapshotPath: snapshotPath,
                snapshotWidth: video.videoSnapshotWidth,
                snapshotHeight: video.videoSnapshotHeight
            ))
        case .file(let file):
            guard let filePath = file.filePath else { return nil }
            return .file(FileSendMessagePayload(
                filePath: filePath,
                fileName: file.fileName ?? URL(fileURLWithPath: filePath).lastPathComponent,
                fileSize: file.fileSize
            ))
        case .face(let face):
            return .face(FaceSendMessagePayload(index: face.faceIndex, data: face.faceData ?? ""))
        case .tips, .merged, .stream:
            return nil
        }
    }

    private func logIfFailed(_ result: Result<Void, ErrorInfo>, action: String) {
        if case .failure(let error) = result {
            print("MessageListViewModel: \(action) failed: \(error.code), \(error.message)")
        }
    }
}

private final class GroupAtInfoFetchHandler: GetConversationInfoCompletionHandler {
    private let onResult: ([GroupAtInfo]) -> Void

    init(onResult: @escaping ([GroupAtInfo]) -> Void) {
        self.onResult = onResult
    }

    func onSuccess(conversationInfo: ConversationInfo) {
        onResult(conversationInfo.groupAtInfoList ?? [])
    }

    func onFailure(code: Int, desc: String) {
        onResult([])
    }
}
