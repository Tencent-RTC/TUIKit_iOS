import Foundation
import AtomicXCore

enum ContactDisplayNameFormatter {

    static func name(for contact: ContactInfo) -> String {
        if let remark = contact.friendRemark, !remark.isEmpty {
            return remark
        }
        if let nickname = contact.nickname, !nickname.isEmpty {
            return nickname
        }
        return contact.userID
    }

    static func name(for group: GroupInfo) -> String {
        if let groupName = group.groupName, !groupName.isEmpty {
            return groupName
        }
        return group.groupID
    }

    static func name(for application: FriendApplicationInfo) -> String {
        if let title = application.title, !title.isEmpty {
            return title
        }
        return application.userID
    }

    static func name(for application: GroupApplicationInfo) -> String {
        if let nickname = application.fromUserNickname, !nickname.isEmpty {
            return nickname
        }
        if let fromUser = application.fromUser, !fromUser.isEmpty {
            return fromUser
        }
        return application.applicationID
    }
}
