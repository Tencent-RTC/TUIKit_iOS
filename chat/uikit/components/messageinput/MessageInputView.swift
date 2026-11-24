import Foundation
import AtomicXCore
import SnapKit
import UIKit

final class MessageInputView: UIView {
    static let inputInteractNotification = NSNotification.Name("MessageInputInteract")

    static let voiceRecordStartNotification = NSNotification.Name("MessageInputVoiceRecordStart")

    static let typingMessageBusinessID = "user_typing_status"

    private let impl: MessageInputViewImpl

    override var intrinsicContentSize: CGSize {
        impl.intrinsicContentSize
    }

    init(conversationID: String,
         config: ChatMessageInputConfig = ChatMessageInputConfig(),
         chatbotController: ChatbotConversationController? = nil,
         onSendFailure: ((String) -> Bool)? = nil,
         onPeerTypingChanged: ((Bool) -> Void)? = nil)
    {
        impl = MessageInputViewImpl(
            conversationID: conversationID,
            config: config,
            chatbotController: chatbotController,
            onSendFailure: onSendFailure,
            onPeerTypingChanged: onPeerTypingChanged
        )
        super.init(frame: .zero)
        constructViewHierarchy()
        activateConstraints()
        bindInteraction()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func cancelVoiceRecording() {
        impl.cancelVoiceRecording()
    }

    private func constructViewHierarchy() {
        addSubview(impl)
    }

    private func activateConstraints() {
        setContentHuggingPriority(.required, for: .vertical)
        setContentCompressionResistancePriority(.required, for: .vertical)
        impl.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }
    }

    private func bindInteraction() {
        impl.onIntrinsicContentSizeInvalidated = { [weak self] in
            self?.invalidateIntrinsicContentSize()
        }
        impl.onAnimateSuperviewLayout = { [weak self] in
            self?.superview?.layoutIfNeeded()
        }
    }
}
