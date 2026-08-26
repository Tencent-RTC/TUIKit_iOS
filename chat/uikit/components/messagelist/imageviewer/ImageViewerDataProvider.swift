import Foundation
import AtomicXCore

final class ImageViewerDataProvider {
    private static let mediaPageCount = 5

    private static let imageElementType = 0

    private static let videoElementType = 1

    private(set) var mediaMessages: [MessageInfo] = []

    private let store: MessageListStore?

    private let currentMessage: MessageInfo

    private let fixedMediaMessages: [MessageInfo]?

    private var isLoadingOlder = false

    private var isLoadingNewer = false

    init(conversationID: String, currentMessage: MessageInfo) {
        self.store = MessageListStore.create(conversationID: conversationID)
        self.fixedMediaMessages = nil
        self.currentMessage = currentMessage
    }

    init(mediaMessages: [MessageInfo], currentMessage: MessageInfo) {
        self.store = nil
        self.fixedMediaMessages = mediaMessages
        self.currentMessage = currentMessage
    }

    // MARK: - Load

    func loadInitial(completion: @escaping ([ImageElement], Int) -> Void) {
        if let fixed = fixedMediaMessages {
            mediaMessages = fixed
            let elements = fixed.map { element(from: $0) }
            let index = fixed.firstIndex { $0.id == currentMessage.id } ?? 0
            DispatchQueue.main.async { completion(elements, index) }
            return
        }
        guard let store = store else { completion([], 0); return }
        var option = MessageLoadOption()
        option.direction = .both
        option.pageCount = Self.mediaPageCount
        option.cursor = currentMessage
        option.messageTypeList = [.image, .video]
        store.loadMessages(option: option) { [weak self] result in
            DispatchQueue.main.async {
                guard let self = self else { completion([], 0); return }
                if case .failure = result { completion([], 0); return }
                self.mediaMessages = self.currentMediaMessages()
                let elements = self.mediaMessages.map { self.element(from: $0) }
                let index = self.mediaMessages.firstIndex { $0.id == self.currentMessage.id } ?? 0
                completion(elements, index)
            }
        }
    }

    func loadMore(isOlder: Bool, completion: @escaping ([ImageElement]) -> Void) {
        guard let store = store else { completion([]); return }
        let hasMore = isOlder ? store.state.value.hasOlderMessages : store.state.value.hasNewerMessages
        let isLoading = isOlder ? isLoadingOlder : isLoadingNewer
        guard hasMore, !isLoading, !mediaMessages.isEmpty else { completion([]); return }
        if isOlder { isLoadingOlder = true } else { isLoadingNewer = true }

        var option = MessageLoadOption()
        option.direction = isOlder ? .older : .newer
        option.pageCount = Self.mediaPageCount
        option.cursor = isOlder ? mediaMessages.first : mediaMessages.last
        option.messageTypeList = [.image, .video]
        store.loadMessages(option: option) { [weak self] result in
            DispatchQueue.main.async {
                guard let self = self else { completion([]); return }
                if isOlder { self.isLoadingOlder = false } else { self.isLoadingNewer = false }
                if case .failure = result { completion([]); return }
                let latest = self.currentMediaMessages()
                let existingIDs = Set(self.mediaMessages.map { $0.id })
                let newMessages = latest.filter { !existingIDs.contains($0.id) }
                guard !newMessages.isEmpty else { completion([]); return }
                if isOlder {
                    self.mediaMessages = newMessages + self.mediaMessages
                } else {
                    self.mediaMessages = self.mediaMessages + newMessages
                }
                completion(newMessages.map { self.element(from: $0) })
            }
        }
    }

    // MARK: - Video Download

    func downloadVideo(at index: Int, completion: @escaping (String?) -> Void) {
        guard index >= 0, index < mediaMessages.count else { completion(nil); return }
        let message = mediaMessages[index]
        guard message.messageType == .video else { completion(nil); return }
        MessageActionStore.create(message: message).downloadMedia(quality: .standard) { [weak self] result in
            DispatchQueue.main.async {
                guard let self = self else { completion(nil); return }
                switch result {
                case .success:
                    if let store = self.store {
                        let updated = store.state.value.messageList.first { $0.id == message.id } ?? message
                        completion(Self.videoSource(from: updated))
                    } else {

                        completion(Self.videoSource(from: message))
                    }
                case .failure:
                    completion(nil)
                }
            }
        }
    }

    // MARK: - Helpers

    func element(from message: MessageInfo) -> ImageElement {
        if message.messageType == .image, case .image(let payload) = message.messagePayload {
            let source = Self.localFile(payload.originalImagePath, payload.largeImagePath, payload.thumbImagePath)
                ?? Self.nonEmpty(payload.originalImageURL, payload.largeImageURL, payload.thumbImageURL)
                ?? ""
            return ImageElement(type: Self.imageElementType, imagePath: source, videoPath: "")
        }
        if message.messageType == .video, case .video(let payload) = message.messagePayload {
            let snapshot = Self.localFile(payload.videoSnapshotPath)
                ?? Self.nonEmpty(payload.videoSnapshotURL)
                ?? ""
            let video = Self.videoSource(from: message)
            return ImageElement(type: Self.videoElementType, imagePath: snapshot, videoPath: video ?? "")
        }
        let isVideo = message.messageType == .video
        return ImageElement(type: isVideo ? Self.videoElementType : Self.imageElementType, imagePath: "", videoPath: "")
    }

    private func currentMediaMessages() -> [MessageInfo] {
        return store?.state.value.messageList.filter { $0.messageType == .image || $0.messageType == .video } ?? []
    }

    private static func videoSource(from message: MessageInfo) -> String? {
        guard case .video(let payload) = message.messagePayload else { return nil }
        return localFile(payload.videoPath) ?? nonEmpty(payload.videoURL)
    }

    private static func localFile(_ paths: String?...) -> String? {
        for case let path? in paths where !path.isEmpty && FileManager.default.fileExists(atPath: path) {
            return path
        }
        return nil
    }

    private static func nonEmpty(_ values: String?...) -> String? {
        for case let value? in values where !value.isEmpty {
            return value
        }
        return nil
    }
}
