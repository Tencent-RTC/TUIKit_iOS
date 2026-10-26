import TUIChatKit
import Foundation

internal enum DemoCallMenuBadge {
    private static let clickedKeyPrefix = "message_input_call_red_dot_clicked_"

    internal static func addUnreadBadgeIfNeeded(
        to action: MessageInputMenuAction,
        sdkAppID: Int32
    ) -> MessageInputMenuAction {
        guard shouldShowBadge(sdkAppID: sdkAppID, actionID: action.ID) else { return action }
        var decoratedAction = action
        decoratedAction.showRedDot = true
        decoratedAction.onClick = {
            markActionUsed(sdkAppID: sdkAppID, actionID: action.ID)
            action.onClick()
        }
        return decoratedAction
    }

    private static func shouldShowBadge(sdkAppID: Int32, actionID: String) -> Bool {
        guard sdkAppID > 0 else { return false }
        return !UserDefaults.standard.bool(forKey: storageKey(sdkAppID: sdkAppID, actionID: actionID))
    }

    private static func markActionUsed(sdkAppID: Int32, actionID: String) {
        guard sdkAppID > 0 else { return }
        UserDefaults.standard.set(true, forKey: storageKey(sdkAppID: sdkAppID, actionID: actionID))
    }

    private static func storageKey(sdkAppID: Int32, actionID: String) -> String {
        return "\(clickedKeyPrefix)\(sdkAppID)\(actionID)"
    }
}
