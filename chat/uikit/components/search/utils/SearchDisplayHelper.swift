import Foundation
import AtomicXCore

enum SearchDisplayHelper {

    static func friendDisplayName(_ friend: FriendSearchInfo) -> String {
        if let remark = friend.friendRemark, !remark.isEmpty {
            return remark
        }
        if let nickname = friend.userInfo?.nickname, !nickname.isEmpty {
            return nickname
        }
        return friend.userID
    }

    static func groupDisplayName(_ group: GroupSearchInfo) -> String {
        let name = group.groupName ?? ""
        return name.isEmpty ? group.groupID : name
    }
}
