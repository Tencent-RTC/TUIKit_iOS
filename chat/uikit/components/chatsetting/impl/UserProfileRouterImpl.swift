import AtomicXCore
import UIKit

enum UserProfileRouterImpl {

    private static var pendingRoutes: [ObjectIdentifier: UUID] = [:]

    static func openChat(
        userID: String,
        from source: UIViewController,
        animated: Bool = true,
        onOpenChat: @escaping (ContactInfo) -> Void
    ) {
        route(userID: userID, from: source, animated: animated) { _, contact in
            onOpenChat(contact)
        }
    }

    static func open(
        userID: String,
        from source: UIViewController,
        onSendMessageClick: (() -> Void)? = nil,
        onContactDelete: (() -> Void)? = nil
    ) {
        route(userID: userID, from: source) { source, _ in
            push(
                from: source,
                destination: makeC2CPage(
                    userID: userID,
                    onSendMessageClick: onSendMessageClick,
                    onContactDelete: onContactDelete
                )
            )
        }
    }

    private static func route(
        userID: String,
        from source: UIViewController,
        animated: Bool = true,
        onFriend: @escaping (UIViewController, ContactInfo) -> Void
    ) {
        guard Thread.isMainThread else {
            DispatchQueue.main.async { [weak source] in
                guard let source else { return }
                route(userID: userID, from: source, animated: animated, onFriend: onFriend)
            }
            return
        }
        guard !userID.isEmpty else { return }
        let routeKey = ObjectIdentifier(source)
        let token = UUID()
        pendingRoutes[routeKey] = token
        let navigationController = source.navigationController
        let hasNavigationController = navigationController != nil
        let finish: (ContactInfo?) -> Void = { [weak source, weak navigationController] contact in
            DispatchQueue.main.async {
                guard pendingRoutes[routeKey] == token else { return }
                pendingRoutes.removeValue(forKey: routeKey)
                guard let source else { return }
                if hasNavigationController {
                    guard let navigationController,
                          source.navigationController === navigationController,
                          navigationController.topViewController === source else { return }
                } else {
                    guard source.navigationController == nil else { return }
                }
                if let contact, contact.isFriend {
                    onFriend(source, contact)
                } else {
                    push(
                        from: source,
                        destination: AddContactViewController(userID: userID, contactInfo: contact),
                        animated: animated
                    )
                }
            }
        }
        ContactStore.shared.getContactInfo(
            userIDList: [userID],
            completion: UserProfileRouteContactInfoHandler(
                onSuccess: { contacts in
                    finish(contacts.first(where: { $0.userID == userID }))
                },
                onFailure: { _, _ in
                    finish(nil)
                }
            )
        )
    }

    private static func makeC2CPage(
        userID: String,
        onSendMessageClick: (() -> Void)?,
        onContactDelete: (() -> Void)?
    ) -> UIViewController {
        return C2CChatSettingViewController(
            userID: userID,
            onSendMessageClick: onSendMessageClick,
            onContactDelete: onContactDelete
        )
    }

    private static func push(from source: UIViewController, destination: UIViewController, animated: Bool = true) {
        destination.hidesBottomBarWhenPushed = true
        if let navigationController = source.navigationController {
            navigationController.pushViewController(destination, animated: animated)
        } else {
            source.present(destination, animated: animated)
        }
    }
}

private final class UserProfileRouteContactInfoHandler: GetContactInfoCompletionHandler {
    private let onSuccessBlock: ([ContactInfo]) -> Void

    private let onFailureBlock: (Int, String) -> Void

    init(onSuccess: @escaping ([ContactInfo]) -> Void, onFailure: @escaping (Int, String) -> Void) {
        self.onSuccessBlock = onSuccess
        self.onFailureBlock = onFailure
    }

    func onSuccess(contactInfoList: [ContactInfo]) {
        onSuccessBlock(contactInfoList)
    }

    func onFailure(code: Int, desc: String) {
        onFailureBlock(code, desc)
    }
}
