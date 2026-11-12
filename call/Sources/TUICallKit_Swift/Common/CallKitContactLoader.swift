import AtomicXCore
import UIKit

enum CallKitContactLoader {
    static func load(userIDs: [String], onProfile: @escaping (String, String?, UIImage?) -> Void) {
        guard !userIDs.isEmpty else { return }
        ContactStore.shared.getContactInfo(userIDList: userIDs, completion: Handler(onProfile: onProfile))
    }

    private final class Handler: GetContactInfoCompletionHandler {
        private let onProfile: (String, String?, UIImage?) -> Void

        init(onProfile: @escaping (String, String?, UIImage?) -> Void) {
            self.onProfile = onProfile
        }

        func onSuccess(contactInfoList: [ContactInfo]) {
            for info in contactInfoList {
                let nickname = info.nickname
                let onProfile = self.onProfile
                CallKitAvatarLoader.image(from: info.avatarURL) { image in
                    onProfile(info.userID, nickname, image)
                }
            }
        }

        func onFailure(code: Int, desc: String) {
            CallKitLog.error("getContactInfo failed: code=\(code) desc=\(desc)")
        }
    }
}
