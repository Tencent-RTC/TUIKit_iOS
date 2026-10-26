import AtomicXCore
import Foundation
import ImSDK_Plus

enum AgentWelcomeInserter {
    static func insertIfConversationEmpty(_ agent: AIAssistantAgent, onDone: @escaping () -> Void) {
        guard !agent.welcome.isEmpty else {
            finish(onDone)
            return
        }
        let store = MessageListStore.create(conversationID: agent.conversationID)
        store.loadMessages { result in
            switch result {
            case .success:
                let hasHistory = store.state.value.messageList.contains { message in
                    !RobotControlMessages.isControlMessage(message)
                }
                if hasHistory {
                    finish(onDone)
                } else {
                    insertLocal(agent: agent, onDone: onDone)
                }
            case .failure:
                finish(onDone)
            }
        }
    }

    private static func insertLocal(agent: AIAssistantAgent, onDone: @escaping () -> Void) {
        guard let message = V2TIMManager.sharedInstance().createTextMessage(text: agent.welcome) else {
            finish(onDone)
            return
        }
        V2TIMManager.sharedInstance().insertC2CMessageToLocalStorage(
            msg: message,
            to: agent.imUserId,
            sender: agent.imUserId,
            succ: {
                finish(onDone)
            },
            fail: { _, _ in
                finish(onDone)
            }
        )
    }

    private static func finish(_ onDone: @escaping () -> Void) {
        if Thread.isMainThread {
            onDone()
        } else {
            DispatchQueue.main.async(execute: onDone)
        }
    }
}
