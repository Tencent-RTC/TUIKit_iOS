import UIKit

public enum MessageInputActionIDs {
    public static let album = "messageInput.album"
    public static let takePhoto = "messageInput.takePhoto"
    public static let recordVideo = "messageInput.recordVideo"
    public static let file = "messageInput.file"
    public static let videoCall = "messageInput.videoCall"
    public static let audioCall = "messageInput.audioCall"
}

public typealias MessageInputActionCustomizer = (CustomEditor<MessageInputMenuAction>) -> Void

public struct MessageInputMenuAction: CustomItem {
    public var ID: String
    public let title: String
    public let iconName: String
    public let icon: UIImage?
    public var dangerous: Bool
    public var showRedDot: Bool
    public var onClick: () -> Void

    public init(ID: String,
                title: String,
                iconName: String,
                icon: UIImage? = nil,
                dangerous: Bool = false,
                showRedDot: Bool = false,
                onClick: @escaping () -> Void) {
        self.ID = ID
        self.title = title
        self.iconName = iconName
        self.icon = icon
        self.dangerous = dangerous
        self.showRedDot = showRedDot
        self.onClick = onClick
    }
}
