import AtomicXCore
import Foundation
import UIKit

extension MessageInfo {
    var contentText: String? {
        if case .text(let payload) = messagePayload {
            return payload.text
        }
        return nil
    }

    var imageInfo: (image: UIImage?, size: CGSize?) {
        guard case .image(let payload) = messagePayload else {
            return (nil, nil)
        }
        let size = CGSize(width: payload.originalImageWidth, height: payload.originalImageHeight)
        if let imagePath = payload.originalImagePath, let image = UIImage(contentsOfFile: imagePath) {
            return (image, size)
        }
        return (nil, size)
    }

    var videoInfo: (snapshot: UIImage?, duration: Int?) {
        guard case .video(let payload) = messagePayload else {
            return (nil, nil)
        }
        if let snapshotPath = payload.videoSnapshotPath {
            return (UIImage(contentsOfFile: snapshotPath), payload.videoDuration)
        } else {
            return (nil, payload.videoDuration)
        }
    }
}
