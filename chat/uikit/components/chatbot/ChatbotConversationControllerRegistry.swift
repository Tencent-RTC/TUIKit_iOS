import Foundation

/// 机器人会话控制器的引用计数注册表，对齐 Android ChatbotConversationControllerRegistry。
///
/// 同一会话可能被页面与输入框同时引用；引用归零且状态空闲时才真正销毁，
/// 避免返回会话时状态机被重建丢掉 streaming 状态。
final class ChatbotConversationControllerRegistry {
    private var entries: [String: Entry] = [:]
    private let lock = NSLock()
    private let controllerFactory: (String) -> ChatbotConversationController

    init(controllerFactory: @escaping (String) -> ChatbotConversationController = { ChatbotConversationController(conversationID: $0) }) {
        self.controllerFactory = controllerFactory
    }

    func acquire(_ conversationID: String, preferredController: ChatbotConversationController? = nil) -> ChatbotConversationController {
        lock.lock()
        defer { lock.unlock() }
        let entry = entries[conversationID] ?? {
            let created = Entry(controller: preferredController ?? controllerFactory(conversationID))
            entries[conversationID] = created
            return created
        }()
        entry.referenceCount += 1
        return entry.controller
    }

    func release(_ conversationID: String, controller: ChatbotConversationController) {
        lock.lock()
        defer { lock.unlock() }
        guard let entry = entries[conversationID], entry.controller === controller else { return }
        entry.referenceCount = max(entry.referenceCount - 1, 0)
        if entry.referenceCount == 0 && !entry.controller.isActive {
            entries.removeValue(forKey: conversationID)
        }
    }

    func clear(_ conversationID: String) {
        lock.lock()
        defer { lock.unlock() }
        guard let entry = entries[conversationID] else { return }
        entry.controller.clear()
        if entry.referenceCount == 0 {
            entries.removeValue(forKey: conversationID)
        }
    }

    private final class Entry {
        let controller: ChatbotConversationController
        var referenceCount: Int = 0

        init(controller: ChatbotConversationController) {
            self.controller = controller
        }
    }
}

enum ChatbotConversationControllers {
    private static let registry = ChatbotConversationControllerRegistry()

    static func acquire(_ conversationID: String) -> ChatbotConversationController {
        return registry.acquire(conversationID)
    }

    static func retain(_ conversationID: String, controller: ChatbotConversationController) -> ChatbotConversationController {
        return registry.acquire(conversationID, preferredController: controller)
    }

    static func release(_ conversationID: String, controller: ChatbotConversationController) {
        registry.release(conversationID, controller: controller)
    }

    static func clear(_ conversationID: String) {
        registry.clear(conversationID)
    }
}
