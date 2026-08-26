import AtomicXCore
import UIKit

public enum UserProfileRouter {

    private static var pendingRouteKeys = Set<String>()

    public static func open(
        userID: String,
        from source: UIViewController,
        onSendMessageClick: (() -> Void)? = nil,
        onContactDelete: (() -> Void)? = nil
    ) {
        if isFriendInMemory(userID: userID) {
            push(
                from: source,
                destination: makeC2CPage(
                    userID: userID,
                    onSendMessageClick: onSendMessageClick,
                    onContactDelete: onContactDelete
                )
            )
            return
        }
        let routeKey = "\(ObjectIdentifier(source)):\(userID)"
        guard !pendingRouteKeys.contains(routeKey) else { return }
        pendingRouteKeys.insert(routeKey)
        ContactStore.shared.loadFriends { result in
            switch result {
            case .success:
                DispatchQueue.main.async {
                    pendingRouteKeys.remove(routeKey)
                    routeByLoadedFriendList(
                        userID: userID,
                        from: source,
                        onSendMessageClick: onSendMessageClick,
                        onContactDelete: onContactDelete
                    )
                }
            case .failure:
                fallbackToContactInfo(
                    userID: userID,
                    from: source,
                    routeKey: routeKey,
                    onSendMessageClick: onSendMessageClick,
                    onContactDelete: onContactDelete
                )
            }
        }
    }

    // MARK: - Private

    private static func isFriendInMemory(userID: String) -> Bool {
        return ContactStore.shared.state.value.friendList.contains(where: { $0.userID == userID })
    }

    private static func routeByLoadedFriendList(
        userID: String,
        from source: UIViewController,
        onSendMessageClick: (() -> Void)?,
        onContactDelete: (() -> Void)?
    ) {
        if isFriendInMemory(userID: userID) {
            push(
                from: source,
                destination: makeC2CPage(
                    userID: userID,
                    onSendMessageClick: onSendMessageClick,
                    onContactDelete: onContactDelete
                )
            )
        } else {
            push(from: source, destination: AddContactViewController(userID: userID))
        }
    }

    private static func fallbackToContactInfo(
        userID: String,
        from source: UIViewController,
        routeKey: String,
        onSendMessageClick: (() -> Void)?,
        onContactDelete: (() -> Void)?
    ) {
        ContactStore.shared.getContactInfo(
            userIDList: [userID],
            completion: UserProfileRouteContactInfoHandler(
                onSuccess: { contactInfoList in
                    DispatchQueue.main.async {
                        pendingRouteKeys.remove(routeKey)
                        let contactInfo = contactInfoList.first
                        if contactInfo?.isFriend == true {
                            push(
                                from: source,
                                destination: makeC2CPage(
                                    userID: userID,
                                    onSendMessageClick: onSendMessageClick,
                                    onContactDelete: onContactDelete
                                )
                            )
                        } else {
                            push(
                                from: source,
                                destination: AddContactViewController(userID: userID, contactInfo: contactInfo)
                            )
                        }
                    }
                },
                onFailure: { _, _ in
                    DispatchQueue.main.async {
                        pendingRouteKeys.remove(routeKey)
                        push(from: source, destination: AddContactViewController(userID: userID))
                    }
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

    private static func push(from source: UIViewController, destination: UIViewController) {
        destination.hidesBottomBarWhenPushed = true
        if let navigationController = source.navigationController {
            navigationController.pushViewController(destination, animated: true)
        } else {
            source.present(destination, animated: true)
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
