import Foundation
import Combine
import AtomicXCore

final class ConversationListViewModel {
    @Published private(set) var conversationList: [ConversationInfo] = []

    @Published private(set) var initialLoadFinished = false

    private let store: ConversationListStore

    private var cancellables = Set<AnyCancellable>()

    // MARK: - Init

    init(store: ConversationListStore = ConversationListStore.create()) {
        self.store = store
        subscribeState()
    }

    // MARK: - Business Actions (forwarded to core store)

    func loadConversations(completion: (() -> Void)? = nil) {
        store.loadConversations(option: ConversationLoadOption()) { _ in
            DispatchQueue.main.async {
                self.initialLoadFinished = true
                completion?()
            }
        }
    }

    func deleteConversation(_ conversation: ConversationInfo) {
        store.deleteConversation(conversationID: conversation.conversationID, completion: nil)
    }

    func pinConversation(_ conversation: ConversationInfo, pin: Bool) {
        store.pinConversation(conversationID: conversation.conversationID, pin: pin, completion: nil)
    }

    func clearHistory(_ conversation: ConversationInfo) {
        store.clearConversationMessages(conversationID: conversation.conversationID, completion: nil)
    }

    func clearUnreadCount(_ conversation: ConversationInfo) {
        store.clearConversationUnreadCount(conversationID: conversation.conversationID, completion: nil)
        store.markConversation(
            conversationIDList: [conversation.conversationID],
            markType: .unread,
            enable: false,
            completion: nil
        )
    }

    func markAsRead(_ conversation: ConversationInfo) {
        clearUnreadCount(conversation)
    }

    func markAsUnread(_ conversation: ConversationInfo) {
        store.markConversation(
            conversationIDList: [conversation.conversationID],
            markType: .unread,
            enable: true,
            completion: nil
        )
    }

    func muteConversation(_ conversation: ConversationInfo, mute: Bool) {
        store.setReceiveMessageOpt(
            conversationID: conversation.conversationID,
            opt: mute ? .notNotify : .receive,
            completion: nil
        )
    }

    // MARK: - Derived Helpers

    func isUnread(_ conversation: ConversationInfo) -> Bool {
        return conversation.unreadCount > 0 || conversation.conversationMarkList.contains(.unread)
    }

    private func subscribeState() {
        store.state
            .subscribe(StatePublisherSelector(keyPath: \ConversationListState.conversationList))
            .map { Self.sanitize($0) }
            .receive(on: DispatchQueue.main)
            .sink { [weak self] list in
                self?.conversationList = list
            }
            .store(in: &cancellables)
    }

    private static func sanitize(_ list: [ConversationInfo]) -> [ConversationInfo] {
        var seenConversationIDs = Set<String>()
        var result: [ConversationInfo] = []
        for conversation in list where !conversation.conversationID.isEmpty {
            if seenConversationIDs.insert(conversation.conversationID).inserted {
                result.append(conversation)
            }
        }
        return result
    }
}
