import AtomicXCore
import Foundation

enum RobotControlMessages {
    static let voiceEnterAction = "enterVoiceCall"
    static let voiceLeaveAction = "leaveVoiceCall"
    static let voiceSessionDescription = "voice call session"

    static func isControlMessage(_ message: MessageInfo) -> Bool {
        guard let payload = customPayload(of: message) else { return false }
        let description = payload.description?.trimmingCharacters(in: .whitespaces) ?? ""
        if description == RobotConversationActivator.activateDescription || description == voiceSessionDescription {
            return true
        }
        let action = customField(of: payload, name: "action")
        return action == RobotConversationActivator.activateAction
            || action == voiceEnterAction
            || action == voiceLeaveAction
    }

    private static func customPayload(of message: MessageInfo) -> CustomMessagePayload? {
        guard message.messageType == .custom,
              case .custom(let payload) = message.messagePayload else {
            return nil
        }
        return payload
    }

    private static func customField(of payload: CustomMessagePayload, name: String) -> String? {
        guard let data = payload.customData.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return nil
        }
        return json[name] as? String
    }
}
