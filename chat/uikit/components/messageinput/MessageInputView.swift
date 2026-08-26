import AtomicXCore
import Combine
import SnapKit
import UIKit

public protocol MessageInputConfigProtocol {
    var isShowAudioRecorder: Bool { get }
    var isShowPhotoTaker: Bool { get }
    var isShowMore: Bool { get }
    var isShowSendButton: Bool { get }
    var isShowEmoji: Bool { get }
    var enableReadReceipt: Bool { get }
    var enableMention: Bool { get }
    var enableLongPressToTalk: Bool { get }
    var isShowVideoCall: Bool { get }
    var isShowAudioCall: Bool { get }
    var enableTyping: Bool { get }
    var actionCustomizer: MessageInputActionCustomizer? { get }
}

extension MessageInputConfigProtocol {
    public var isShowVideoCall: Bool { true }
    public var isShowAudioCall: Bool { true }
    public var enableTyping: Bool { true }
    public var actionCustomizer: MessageInputActionCustomizer? { nil }
}

public struct ChatMessageInputConfig: MessageInputConfigProtocol {
    public var isShowAudioRecorder: Bool {
        return userIsShowAudioRecorder ?? true
    }

    public var isShowPhotoTaker: Bool {
        return userIsShowPhotoTaker ?? true
    }

    public var isShowMore: Bool {
        return userIsShowMore ?? true
    }

    public var isShowSendButton: Bool {
        if let userIsShowSendButton = userIsShowSendButton {
            return userIsShowSendButton
        } else {
            return !AppBuilderConfig.shared.hideSendButton
        }
    }

    public var isShowEmoji: Bool {
        return userIsShowEmoji ?? true
    }

    public var enableReadReceipt: Bool {
        if let userEnableReadReceipt = userEnableReadReceipt {
            return userEnableReadReceipt
        } else {
            return AppBuilderConfig.shared.enableReadReceipt
        }
    }

    public var enableMention: Bool {
        return userEnableMention ?? true
    }

    public var enableLongPressToTalk: Bool {
        return userEnableLongPressToTalk ?? true
    }

    public var isShowVideoCall: Bool {
        return userIsShowVideoCall ?? true
    }

    public var isShowAudioCall: Bool {
        return userIsShowAudioCall ?? true
    }

    public var enableTyping: Bool {
        return userEnableTyping ?? true
    }

    public var actionCustomizer: MessageInputActionCustomizer? {
        return userActionCustomizer
    }

    private let userIsShowAudioRecorder: Bool?

    private let userIsShowPhotoTaker: Bool?

    private let userIsShowMore: Bool?

    private let userIsShowSendButton: Bool?

    private let userIsShowEmoji: Bool?

    private let userEnableReadReceipt: Bool?

    private let userEnableMention: Bool?

    private let userEnableLongPressToTalk: Bool?

    private let userIsShowVideoCall: Bool?

    private let userIsShowAudioCall: Bool?

    private let userEnableTyping: Bool?

    private let userActionCustomizer: MessageInputActionCustomizer?

    public init() {
        self.userIsShowAudioRecorder = nil
        self.userIsShowPhotoTaker = nil
        self.userIsShowMore = nil
        self.userIsShowSendButton = nil
        self.userIsShowEmoji = nil
        self.userEnableReadReceipt = nil
        self.userEnableMention = nil
        self.userEnableLongPressToTalk = nil
        self.userIsShowVideoCall = nil
        self.userIsShowAudioCall = nil
        self.userEnableTyping = nil
        self.userActionCustomizer = nil
    }

    public init(
        isShowAudioRecorder: Bool? = nil,
        isShowPhotoTaker: Bool? = nil,
        isShowMore: Bool? = nil,
        isShowSendButton: Bool? = nil,
        isShowEmoji: Bool? = nil,
        enableReadReceipt: Bool? = nil,
        enableMention: Bool? = nil,
        enableLongPressToTalk: Bool? = nil,
        isShowVideoCall: Bool? = nil,
        isShowAudioCall: Bool? = nil,
        enableTyping: Bool? = nil,
        actionCustomizer: MessageInputActionCustomizer? = nil
    ) {
        self.userIsShowAudioRecorder = isShowAudioRecorder
        self.userIsShowPhotoTaker = isShowPhotoTaker
        self.userIsShowMore = isShowMore
        self.userIsShowSendButton = isShowSendButton
        self.userIsShowEmoji = isShowEmoji
        self.userEnableReadReceipt = enableReadReceipt
        self.userEnableMention = enableMention
        self.userEnableLongPressToTalk = enableLongPressToTalk
        self.userIsShowVideoCall = isShowVideoCall
        self.userIsShowAudioCall = isShowAudioCall
        self.userEnableTyping = enableTyping
        self.userActionCustomizer = actionCustomizer
    }
}

public enum MessageInputActionIDs {
    public static let album = "messageInput.album"
    public static let takePhoto = "messageInput.takePhoto"
    public static let recordVideo = "messageInput.recordVideo"
    public static let file = "messageInput.file"
    public static let videoCall = "messageInput.videoCall"
    public static let audioCall = "messageInput.audioCall"
}

public typealias MessageInputActionCustomizer = (CustomEditor<MessageInputMenuAction>) -> Void

public struct MessageInputMenuAction: CustomItem {
    public var ID: String

    public let title: String

    public let iconName: String

    public let icon: UIImage?

    public var dangerous: Bool

    public let onClick: () -> Void

    public init(ID: String,
                title: String,
                iconName: String,
                icon: UIImage? = nil,
                dangerous: Bool = false,
                onClick: @escaping () -> Void) {
        self.ID = ID
        self.title = title
        self.iconName = iconName
        self.icon = icon
        self.dangerous = dangerous
        self.onClick = onClick
    }
}

final class MessageInputView: UIView {
    private static let c2cConversationPrefix = "c2c_"

    static let inputInteractNotification = NSNotification.Name("MessageInputInteract")

    static let voiceRecordStartNotification = NSNotification.Name("MessageInputVoiceRecordStart")

    static let typingMessageBusinessID = "user_typing_status"

    var bottomSafeAreaInset: CGFloat {
        get { impl.bottomSafeAreaInset }
        set { impl.bottomSafeAreaInset = newValue }
    }

    var onTypingContentChanged: ((Bool) -> Void)? {
        get { impl.onTypingContentChanged }
        set { impl.onTypingContentChanged = newValue }
    }

    var onSendFailure: ((String) -> Void)? {
        get { impl.onSendFailure }
        set { impl.onSendFailure = newValue }
    }

    var typingPublisher: AnyPublisher<Bool, Never>? {
        typingController?.typingPublisher
    }

    private let impl: MessageInputViewImpl

    private let typingController: TypingIndicatorController?

    override var intrinsicContentSize: CGSize {
        impl.intrinsicContentSize
    }

    init(conversationID: String, config: MessageInputConfigProtocol = ChatMessageInputConfig()) {
        impl = MessageInputViewImpl(conversationID: conversationID, config: config)
        if config.enableTyping, conversationID.hasPrefix(Self.c2cConversationPrefix) {
            let currentUserID = LoginStore.shared.state.value.loginUserInfo?.userID
            typingController = TypingIndicatorController(conversationID: conversationID, currentUserID: currentUserID)
        } else {
            typingController = nil
        }
        super.init(frame: .zero)
        setContentHuggingPriority(.required, for: .vertical)
        setContentCompressionResistancePriority(.required, for: .vertical)
        addSubview(impl)
        impl.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }
        impl.onIntrinsicContentSizeInvalidated = { [weak self] in
            self?.invalidateIntrinsicContentSize()
        }
        impl.onAnimateSuperviewLayout = { [weak self] in
            self?.superview?.layoutIfNeeded()
        }
    }

    func sendTypingStatus(hasContent: Bool) {
        typingController?.sendTypingStatus(hasContent: hasContent)
    }

    func invalidateTypingIndicator() {
        typingController?.invalidate()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}

struct MessagePlaceholderInfo {
    enum MediaKind {
        case image
        case video
    }

    let placeholderID: String

    let mediaKind: MediaKind

    let thumbnailPath: String?

    let thumbnailSize: CGSize

    let mediaPath: String?

    let videoDuration: Int

    let progress: Int

    init(placeholderID: String,
         mediaKind: MediaKind,
         thumbnailPath: String?,
         thumbnailSize: CGSize,
         mediaPath: String? = nil,
         videoDuration: Int = 0,
         progress: Int = 0) {
        self.placeholderID = placeholderID
        self.mediaKind = mediaKind
        self.thumbnailPath = thumbnailPath
        self.thumbnailSize = thumbnailSize
        self.mediaPath = mediaPath
        self.videoDuration = videoDuration
        self.progress = progress
    }
}

final class AlbumPickerPlaceholderStore {
    static let shared = AlbumPickerPlaceholderStore()

    var placeholdersByConversation: AnyPublisher<[String: [MessageInfo]], Never> {
        impl.$placeholdersByConversation.eraseToAnyPublisher()
    }

    private let impl = AlbumPickerPlaceholderStoreImpl.shared

    func upsert(conversationID: String, info: MessagePlaceholderInfo) {
        impl.upsert(conversationID: conversationID, info: info)
    }

    func remove(conversationID: String, placeholderID: String) {
        impl.remove(conversationID: conversationID, placeholderID: placeholderID)
    }

    static func localMediaPath(of message: MessageInfo) -> String? {
        return AlbumPickerPlaceholderStoreImpl.localMediaPath(of: message)
    }

    private init() {}
}
