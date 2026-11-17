import AtomicXCore
import UIKit

public enum UserProfileRouter {
    public static func openChat(
        userID: String,
        from source: UIViewController,
        animated: Bool = true,
        onOpenChat: @escaping (ContactInfo) -> Void
    ) {
        UserProfileRouterImpl.openChat(
            userID: userID,
            from: source,
            animated: animated,
            onOpenChat: onOpenChat
        )
    }

    public static func open(
        userID: String,
        from source: UIViewController,
        onSendMessageClick: (() -> Void)? = nil,
        onContactDelete: (() -> Void)? = nil
    ) {
        UserProfileRouterImpl.open(
            userID: userID,
            from: source,
            onSendMessageClick: onSendMessageClick,
            onContactDelete: onContactDelete
        )
    }
}
