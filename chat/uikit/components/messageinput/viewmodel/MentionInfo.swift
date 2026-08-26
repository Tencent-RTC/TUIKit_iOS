import Foundation

struct MentionInfo {
    static let atAllUserID = "__kImSDK_MesssageAtALL__"

    public let userID: String

    public let displayName: String

    var startIndex: Int

    let length: Int

    var isAtAll: Bool {
        return userID == Self.atAllUserID
    }

    var endIndex: Int {
        return startIndex + length
    }

    var mentionText: String {
        return "@\(displayName) "
    }

    init(userID: String, displayName: String, startIndex: Int, length: Int) {
        self.userID = userID
        self.displayName = displayName
        self.startIndex = startIndex
        self.length = length
    }

    public static func create(userID: String, displayName: String, atPosition: Int) -> MentionInfo {
        let mentionText = "@\(displayName) "
        return MentionInfo(
            userID: userID,
            displayName: displayName,
            startIndex: atPosition,
            length: mentionText.count
        )
    }
}
