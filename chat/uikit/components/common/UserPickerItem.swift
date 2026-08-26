import UIKit

struct UserPickerItem: Identifiable {
    public var id: String { userID }
    public let userID: String
    public let avatarURL: String?
    public let title: String
    let subtitle: String?
    let isDisabled: Bool
    init(
        userID: String,
        avatarURL: String? = nil,
        title: String,
        subtitle: String? = nil,
        isDisabled: Bool = false
    ) {
        self.userID = userID
        self.avatarURL = avatarURL
        self.title = title
        self.subtitle = subtitle
        self.isDisabled = isDisabled
    }
}
