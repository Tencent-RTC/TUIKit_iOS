import Foundation
import UIKit
import AlbumPicker
import AlbumPickerCore
import AtomicXCore

final class AlbumPickerMediaSendCoordinator {
    static let shared = AlbumPickerMediaSendCoordinator()

    private var activeSessions: [String: AlbumPickerSendSession] = [:]

    private var isPickerVisible = false

    func showAlbumPicker(conversationID: String,
                         enableReadReceipt: Bool,
                         config: ChatMessageInputConfig = ChatMessageInputConfig()) {
        if conversationID.isEmpty || isPickerVisible {
            return
        }
        guard let presenter = Self.topMostViewController() else { return }
        AlbumPickerCoreTheme.shared.currentPrimaryColor = TUIChatKitTheme.colors.buttonColorPrimaryDefault
        AlbumPickerCoreLanguage.shared.current = .chatKitCurrent

        let pickerController = UIViewController()
        pickerController.modalPresentationStyle = .fullScreen

        let session = AlbumPickerSendSession(
            conversationID: conversationID,
            enableReadReceipt: enableReadReceipt,
            pickerController: pickerController,
            onPickerDismissed: { [weak self] in
                self?.isPickerVisible = false
            },
            onCompleted: { [weak self] finishedSession in
                self?.activeSessions.removeValue(forKey: finishedSession.sessionID)
            }
        )
        activeSessions[session.sessionID] = session

        let albumView = AlbumPickerView()
        albumView.delegate = session
        albumView.initialize(config: Self.makeConfig(from: config), theme: Self.makeTheme())
        pickerController.view = albumView

        isPickerVisible = true
        presenter.present(pickerController, animated: true)
    }

    private init() {}

    private static func makeConfig(from inputConfig: ChatMessageInputConfig) -> AlbumPickerConfig {
        var config = AlbumPickerConfig(
            maxSelectionCount: inputConfig._albumMaxSelectionCount,
            style: .likeWeChat,
            mediaFilter: mediaFilter(from: inputConfig._albumMediaFilter),
            language: .chatKitCurrent,
            compressQuality: compressQuality(from: inputConfig._albumCompressQuality)
        )
        config.maxOutputFileSizeInMB = inputConfig._albumMaxVideoOutputSizeInMB
        config.maxVideoDurationInSeconds = inputConfig._albumMaxVideoDurationInSeconds
        return config
    }

    private static func mediaFilter(from filter: MessageInputAlbumMediaFilter) -> AlbumPickerMediaFilter {
        switch filter {
        case .imageOnly: return .imageOnly
        case .videoOnly: return .videoOnly
        case .imageAndVideo: return .imageAndVideo
        }
    }

    private static func compressQuality(from quality: MessageInputAlbumCompressQuality) -> AlbumPickerCompressQuality {
        switch quality {
        case .standard: return .standard
        case .high: return .high
        }
    }

    private static func makeTheme() -> AlbumPickerTheme {
        let colors = TUIChatKitTheme.colors
        return AlbumPickerTheme(
            currentPrimaryColor: colors.buttonColorPrimaryDefault
        )
    }

    private static func topMostViewController() -> UIViewController? {
        let window = UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .flatMap { $0.windows }
            .first(where: { $0.isKeyWindow }) ?? UIApplication.shared.windows.first
        var controller = window?.rootViewController
        while let presented = controller?.presentedViewController {
            controller = presented
        }
        return controller
    }
}

private final class AlbumPickerSendSession: NSObject, AlbumPickerDelegate {
    let sessionID = UUID().uuidString

    private struct PlaceholderState {
        let placeholderID: String
        var thumbnailPath: String?
        var isThumbnailFinal: Bool
        var thumbnailSize: CGSize
        var mediaPath: String?
        var progress: Int
    }

    private let conversationID: String
    private let enableReadReceipt: Bool

    private let inputStore: MessageInputStore

    private weak var pickerController: UIViewController?

    private let onPickerDismissed: () -> Void

    private let onCompleted: (AlbumPickerSendSession) -> Void

    private var placeholderStates: [String: PlaceholderState] = [:]

    private var sentMediaIDs: Set<UInt64> = []

    private var pendingText: String?

    private var didSendPendingText = false

    private var isFinished = false

    init(conversationID: String,
         enableReadReceipt: Bool,
         pickerController: UIViewController,
         onPickerDismissed: @escaping () -> Void,
         onCompleted: @escaping (AlbumPickerSendSession) -> Void) {
        self.conversationID = conversationID
        self.enableReadReceipt = enableReadReceipt
        self.inputStore = MessageInputStore.create(conversationID: conversationID)
        self.pickerController = pickerController
        self.onPickerDismissed = onPickerDismissed
        self.onCompleted = onCompleted
        super.init()
    }

    func onPickConfirm(pickedAlbumMedias: [AlbumMedia], textMessage: String?) {
        pendingText = textMessage
        for media in pickedAlbumMedias {
            insertPlaceholder(for: media)
        }
        dismissPicker()
    }

    func onMediaProcessing(albumMedia: AlbumMedia, progress: Float, error: Bool) {
        if error {
            markSendFailed(albumMedia)
            return
        }
        if progress < Self.completedProgress {
            updatePlaceholderProgress(for: albumMedia, progress: progress)
            return
        }
        if let path = albumMedia.mediaPath, !path.isEmpty {
            sendOnce(albumMedia) { [weak self] in
                self?.sendMedia(albumMedia, path: path)
            }
            return
        }
        markSendFailed(albumMedia)
    }

    func onMediaProcessed() {
        sendPendingTextIfNeeded()
        finish()
    }

    func onCancel() {
        finish()
    }

    private func insertPlaceholder(for media: AlbumMedia) {
        let placeholderID = Self.makePlaceholderID(sessionID: sessionID, mediaID: media.id)
        let initialSize = AlbumPickerMediaSendCoordinator.placeholderSize(for: media)
        placeholderStates[placeholderID] = PlaceholderState(
            placeholderID: placeholderID,
            thumbnailPath: nil,
            isThumbnailFinal: false,
            thumbnailSize: initialSize,
            mediaPath: nil,
            progress: 0
        )
        applyPlaceholder(for: media)
        requestThumbnail(for: media)
    }

    private func requestThumbnail(for media: AlbumMedia) {
        let placeholderID = Self.makePlaceholderID(sessionID: sessionID, mediaID: media.id)
        AlbumPickerMediaSendCoordinator.thumbnail(for: media) { [weak self] path, size, isFinal in
            guard let self = self else { return }
            guard var state = self.placeholderStates[placeholderID] else { return }

            if state.isThumbnailFinal { return }
            if let path = path { state.thumbnailPath = path }
            if size.width > 0, size.height > 0 { state.thumbnailSize = size }

            state.isThumbnailFinal = isFinal && path != nil
            self.placeholderStates[placeholderID] = state
            self.applyPlaceholder(for: media)
        }
    }

    private func updatePlaceholderProgress(for media: AlbumMedia, progress: Float) {
        let placeholderID = Self.makePlaceholderID(sessionID: sessionID, mediaID: media.id)
        guard var state = placeholderStates[placeholderID] else { return }
        let percent = Self.toPercent(progress)
        if percent - state.progress < Self.progressUpdateStep {
            return
        }
        state.progress = percent
        placeholderStates[placeholderID] = state
        applyPlaceholder(for: media)
    }

    private func applyPlaceholder(for media: AlbumMedia) {
        let placeholderID = Self.makePlaceholderID(sessionID: sessionID, mediaID: media.id)
        guard let state = placeholderStates[placeholderID] else { return }
        MessageListHelper.addPlaceholder(
            conversationID: conversationID,
            info: MessagePlaceholderInfo(
                placeholderID: state.placeholderID,
                mediaKind: media.mediaType == .video ? .video : .image,
                thumbnailPath: state.thumbnailPath,
                thumbnailSize: state.thumbnailSize,
                mediaPath: state.mediaPath,
                videoDuration: Self.durationInSeconds(media.duration),
                progress: state.progress
            )
        )
    }

    private func markPlaceholderSending(for media: AlbumMedia, path: String) {
        let placeholderID = Self.makePlaceholderID(sessionID: sessionID, mediaID: media.id)
        guard var state = placeholderStates[placeholderID] else { return }
        state.mediaPath = path
        placeholderStates[placeholderID] = state
        applyPlaceholder(for: media)
    }
private func sendOnce(_ media: AlbumMedia, _ send: @escaping () -> Void) {
        if sentMediaIDs.insert(media.id).inserted {
            send()
        }
    }

    private func sendMedia(_ media: AlbumMedia, path: String) {
        let placeholderID = Self.makePlaceholderID(sessionID: sessionID, mediaID: media.id)
        let state = placeholderStates[placeholderID]
        let reusableSnapshotPath = (state?.isThumbnailFinal == true ? state?.thumbnailPath : nil)
            ?? media.videoThumbnailPath
        markPlaceholderSending(for: media, path: path)
        switch media.mediaType {
        case .video:
            sendVideoMessage(path, snapshotPath: reusableSnapshotPath ?? "", media: media)
        case .image:
            inputStore.sendMessage(payload: .image(makeImagePayload(imagePath: path)), option: makeSendOption(), completion: nil)
        }
    }

    private func makeSendOption() -> SendMessageOption {
        var option = SendMessageOption()
        option.needReadReceipt = enableReadReceipt
        return option
    }

    private func makeImagePayload(imagePath: String) -> ImageSendMessagePayload {
        var payload = ImageSendMessagePayload(imagePath: imagePath)
        if let image = UIImage(contentsOfFile: imagePath) {
            payload.imageWidth = Int(image.size.width)
            payload.imageHeight = Int(image.size.height)
        }
        return payload
    }

    private func sendVideoMessage(_ videoPath: String, snapshotPath: String, media: AlbumMedia) {
        var snapshotWidth = 0
        var snapshotHeight = 0
        if let image = UIImage(contentsOfFile: snapshotPath) {
            snapshotWidth = Int(image.size.width)
            snapshotHeight = Int(image.size.height)
        }
        let payload = VideoSendMessagePayload(
            videoFilePath: videoPath,
            videoType: "mp4",
            duration: Self.durationInSeconds(media.duration),
            snapshotPath: snapshotPath,
            snapshotWidth: snapshotWidth,
            snapshotHeight: snapshotHeight
        )
        inputStore.sendMessage(payload: .video(payload), option: makeSendOption(), completion: nil)
    }

    private func markSendFailed(_ media: AlbumMedia) {
        if sentMediaIDs.insert(media.id).inserted {
            removePlaceholder(for: media)
            WindowToastManager.shared.error(LocalizedChatString("TUIGroupNoteSendFail"))
        }
    }

    private func removePlaceholder(for media: AlbumMedia) {
        let placeholderID = Self.makePlaceholderID(sessionID: sessionID, mediaID: media.id)
        guard let state = placeholderStates.removeValue(forKey: placeholderID) else { return }
        MessageListHelper.removePlaceholder(conversationID: conversationID, placeholderID: state.placeholderID)
    }

    private func sendPendingTextIfNeeded() {
        if let text = pendingText, !text.isEmpty, !didSendPendingText {
            didSendPendingText = true
            inputStore.sendMessage(payload: .text(TextSendMessagePayload(text: text)), option: makeSendOption(), completion: nil)
        }
    }

    private func dismissPicker() {
        if let controller = pickerController {
            pickerController = nil
            controller.dismiss(animated: true)
            onPickerDismissed()
        }
    }

    private func finish() {
        if isFinished {
            return
        }
        isFinished = true
        dismissPicker()
        cleanupPlaceholders()
        onCompleted(self)
    }

    private func cleanupPlaceholders() {
        let states = placeholderStates.values
        placeholderStates.removeAll()

        for state in states where state.mediaPath == nil {
            MessageListHelper.removePlaceholder(conversationID: conversationID, placeholderID: state.placeholderID)
        }
        let sendingIDs = states.filter { $0.mediaPath != nil }.map { $0.placeholderID }
        if sendingIDs.isEmpty {
            return
        }
        let targetConversationID = conversationID
        DispatchQueue.main.asyncAfter(deadline: .now() + Self.placeholderCleanupDelay) {
            for placeholderID in sendingIDs {
                MessageListHelper.removePlaceholder(conversationID: targetConversationID, placeholderID: placeholderID)
            }
        }
    }

    private static func makePlaceholderID(sessionID: String, mediaID: UInt64) -> String {
        return "\(placeholderIDPrefix)\(sessionID)_\(mediaID)"
    }

    private static func toPercent(_ progress: Float) -> Int {
        let clamped = min(max(progress, 0), completedProgress)
        return Int((clamped * progressPercentScale).rounded())
    }

    private static func durationInSeconds(_ seconds: Int64) -> Int {
        if seconds <= 0 {
            return 0
        }
        return Int(seconds)
    }

    private static let completedProgress: Float = 1.0
    private static let progressPercentScale: Float = 100
    private static let progressUpdateStep = 5
    private static let placeholderCleanupDelay: TimeInterval = 3
    private static let placeholderIDPrefix = "album_picker_processing_"
}

extension AlbumPickerCoreLanguage.Language {
    static var chatKitCurrent: AlbumPickerCoreLanguage.Language {
        let language = LanguageHelper.getCurrentLanguage()
        if language.hasPrefix("ar") { return .ar }
        if language.hasPrefix("zh-Hant") { return .zhHant }
        if language.hasPrefix("zh") { return .zhHans }
        if language.hasPrefix("en") { return .en }
        return .system
    }
}
