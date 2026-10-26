import AtomicXCore
import Foundation

public enum RobotConversationActivator {
    static let activateAction = "activateRobotConversation"
    static let activateDescription = "activate robot conversation"

    private static let sendDelay: TimeInterval = 1
    private static let robotUserIDs = ["@RBT#demo"]
    private static var scheduled = false

    public static func scheduleActivation() {
        guard !scheduled else { return }
        scheduled = true
        DispatchQueue.main.asyncAfter(deadline: .now() + sendDelay) {
            robotUserIDs.forEach { activateConversation($0) }
        }
    }

    private static func activateConversation(_ robotUserID: String) {
        let store = MessageInputStore.create(conversationID: "c2c_\(robotUserID)")
        var option = SendMessageOption()
        option.onlineUserOnly = true
        let payload = CustomSendMessagePayload(
            customData: "{\"action\":\"\(activateAction)\"}",
            description: activateDescription,
            extensionInfo: nil
        )
        store.sendMessage(payload: .custom(payload), option: option, completion: nil)
    }
}
