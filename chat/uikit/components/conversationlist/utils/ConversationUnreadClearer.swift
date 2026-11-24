import Foundation
import AtomicXCore

enum ConversationUnreadClearer {
    private static let unmarkBatchSize = 100

    static func clearConversationsUnread(
        store: ConversationListStore,
        conversations: [ConversationInfo],
        completion: CompletionClosure? = nil
    ) {
        clearUnread(
            store: store,
            conversationIDs: conversations.map { $0.conversationID },
            markedConversationIDs: conversations
                .filter { $0.conversationMarkList.contains(.unread) }
                .map { $0.conversationID },
            completion: completion
        )
    }

    static func clearUnread(
        store: ConversationListStore,
        conversationIDs: [String],
        markedConversationIDs: [String]? = nil,
        completion: CompletionClosure? = nil
    ) {
        let ids = unique(conversationIDs)
        guard !ids.isEmpty else {
            completion?(.success(()))
            return
        }
        let marked = unique(markedConversationIDs ?? ids)
        unmark(store: store, ids: marked, from: 0) {
            clearCounts(store: store, ids: ids, completion: completion)
        }
    }

    static func clearMessages(
        store: ConversationListStore,
        conversationID: String,
        hasUnreadMark: Bool = true,
        completion: CompletionClosure? = nil
    ) {
        store.clearConversationMessages(conversationID: conversationID) { result in
            completion?(result)
            if case .success = result {
                clearUnread(
                    store: store,
                    conversationIDs: [conversationID],
                    markedConversationIDs: hasUnreadMark ? [conversationID] : []
                )
            }
        }
    }

    private static func unique(_ ids: [String]) -> [String] {
        var seen = Set<String>()
        return ids.filter { !$0.isEmpty && seen.insert($0).inserted }
    }

    private static func unmark(store: ConversationListStore, ids: [String], from start: Int, done: @escaping () -> Void) {
        guard start < ids.count else {
            done()
            return
        }
        let end = min(start + unmarkBatchSize, ids.count)
        store.markConversation(
            conversationIDList: Array(ids[start..<end]),
            markType: .unread,
            enable: false
        ) { result in
            switch result {
            case .success:
                unmark(store: store, ids: ids, from: end, done: done)
            case .failure(let error):
                NSLog("[ConversationUnreadClearer] unmark unread conversations failed, code=\(error.code), desc=\(error.message)")
                done()
            }
        }
    }

    private static func clearCounts(store: ConversationListStore, ids: [String], completion: CompletionClosure?) {
        let group = DispatchGroup()
        let lock = NSLock()
        var failure: ErrorInfo?
        for id in ids {
            group.enter()
            store.clearConversationUnreadCount(conversationID: id) { result in
                if case .failure(let error) = result {
                    NSLog("[ConversationUnreadClearer] clear unread count failed, code=\(error.code), desc=\(error.message)")
                    lock.lock()
                    if failure == nil { failure = error }
                    lock.unlock()
                }
                group.leave()
            }
        }
        group.notify(queue: .main) {
            if let error = failure {
                completion?(.failure(error))
            } else {
                completion?(.success(()))
            }
        }
    }
}
