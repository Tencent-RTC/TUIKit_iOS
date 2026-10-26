import Foundation
import AtomicXCore
import Combine
import SnapKit
import UIKit

final class MessageInputView: UIView {
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
        return impl.typingPublisher
    }

    private let impl: MessageInputViewImpl

    override var intrinsicContentSize: CGSize {
        impl.intrinsicContentSize
    }

    init(conversationID: String,
         config: MessageInputConfigProtocol = ChatMessageInputConfig(),
         chatbotController: ChatbotConversationController? = nil) {
        impl = MessageInputViewImpl(conversationID: conversationID, config: config, chatbotController: chatbotController)
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
        impl.sendTypingStatus(hasContent: hasContent)
    }

    func invalidateTypingIndicator() {
        impl.invalidateTypingIndicator()
    }

    func cancelVoiceRecording() {
        impl.cancelVoiceRecording()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}
