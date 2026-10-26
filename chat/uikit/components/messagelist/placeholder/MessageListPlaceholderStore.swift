import AtomicXCore
import Combine

final class MessageListPlaceholderStore {
    static let shared = MessageListPlaceholderStore()

    var placeholdersByConversation: AnyPublisher<[String: [MessageInfo]], Never> {
        impl.$placeholdersByConversation.eraseToAnyPublisher()
    }

    private let impl = MessageListPlaceholderStoreImpl.shared

    func upsert(conversationID: String, info: MessagePlaceholderInfo) {
        impl.upsert(conversationID: conversationID, info: info)
    }

    func remove(conversationID: String, placeholderID: String) {
        impl.remove(conversationID: conversationID, placeholderID: placeholderID)
    }

    static func localMediaPath(of message: MessageInfo) -> String? {
        return MessageListPlaceholderStoreImpl.localMediaPath(of: message)
    }

    private init() {}
}
