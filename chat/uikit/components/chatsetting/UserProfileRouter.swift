import UIKit

public enum UserProfileRouter {
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
