import UIKit

/// 消息列表中的本地占位信息
public struct MessagePlaceholderInfo {
    public enum MediaKind {
        case image
        case video
    }

    public let placeholderID: String
    public let mediaKind: MediaKind
    public let thumbnailPath: String?
    public let thumbnailSize: CGSize
    public let mediaPath: String?
    public let videoDuration: Int
    public let progress: Int

    public init(placeholderID: String,
                mediaKind: MediaKind,
                thumbnailPath: String?,
                thumbnailSize: CGSize,
                mediaPath: String? = nil,
                videoDuration: Int = 0,
                progress: Int = 0) {
        self.placeholderID = placeholderID
        self.mediaKind = mediaKind
        self.thumbnailPath = thumbnailPath
        self.thumbnailSize = thumbnailSize
        self.mediaPath = mediaPath
        self.videoDuration = videoDuration
        self.progress = progress
    }
}

