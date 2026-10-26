import AtomicXCore
import AVFoundation
import UIKit

final class VideoRecorderMediaFiles {
    private static let imageCompressionQuality: CGFloat = 0.8

    static func makeVideoPath() -> String {
        return makePath(messageType: .video, extension: "mov")
    }

    static func saveImage(_ image: UIImage) -> String? {
        guard let data = image.jpegData(compressionQuality: imageCompressionQuality) else { return nil }
        let path = makePath(messageType: .image, extension: "png")
        do {
            try data.write(to: URL(fileURLWithPath: path), options: .atomic)
            return path
        } catch {
            return nil
        }
    }

    static func thumbnailPath(for videoPath: String) -> String? {
        let generator = AVAssetImageGenerator(asset: AVAsset(url: URL(fileURLWithPath: videoPath)))
        generator.appliesPreferredTrackTransform = true
        guard let image = try? generator.copyCGImage(at: CMTime(seconds: 0, preferredTimescale: 60), actualTime: nil) else {
            return nil
        }
        return saveImage(UIImage(cgImage: image))
    }

    private static func makePath(messageType: MessageType, extension fileExtension: String) -> String {
        let path = ChatUtil.generateMediaPath(messageType: messageType, withExtension: fileExtension)
        let directory = (path as NSString).deletingLastPathComponent
        try? FileManager.default.createDirectory(atPath: directory, withIntermediateDirectories: true)
        return path
    }
}
