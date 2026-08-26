import Foundation
import AVFoundation
import Photos
import UIKit
import AlbumPicker

extension AlbumPickerMediaSendCoordinator {
    private static let thumbnailDirectoryName = "album_picker_processing_thumbnail"

    private static let thumbnailMaxPixel: CGFloat = 720

    private static let thumbnailCompressionQuality: CGFloat = 0.8

    private static let snapshotTimescale: CMTimeScale = 60

    static func thumbnail(for media: AlbumMedia,
                          onUpdate: @escaping (String?, CGSize, Bool) -> Void) {
        if let path = localThumbnailPath(for: media), let image = readImage(at: path) {
            onUpdate(path, image.size, true)
            return
        }
        if media.mediaType == .video, let videoPath = media.mediaPath, isReadableFile(videoPath) {
            DispatchQueue.global().async {
                let path = writeThumbnail(makeVideoSnapshot(videoPath: videoPath), mediaID: media.id)
                let image = path.flatMap { readImage(at: $0) }
                runOnMain { onUpdate(path, image?.size ?? pixelSize(of: media.asset), path != nil) }
            }
            return
        }
        if media.mediaType == .image, let imagePath = media.mediaPath, isReadableFile(imagePath) {
            if let image = readImage(at: imagePath) {
                onUpdate(imagePath, image.size, true)
                return
            }
            onUpdate(nil, .zero, true)
            return
        }
        requestAssetThumbnail(for: media, onUpdate: onUpdate)
    }

    static func placeholderSize(for media: AlbumMedia) -> CGSize {
        if media.mediaType == .video {
            if let asset = media.asset, asset.pixelWidth > 0, asset.pixelHeight > 0 {
                return CGSize(width: asset.pixelWidth, height: asset.pixelHeight)
            }
            return .zero
        }
        if let path = media.mediaPath, isReadableFile(path), let image = readImage(at: path) {
            return image.size
        }
        return .zero
    }

    private static func localThumbnailPath(for media: AlbumMedia) -> String? {
        if media.mediaType == .video {
            if let path = media.videoThumbnailPath, isReadableFile(path) {
                return path
            }
            return nil
        }
        if let path = media.mediaPath, isReadableFile(path) {
            return path
        }
        return nil
    }

    private static func requestAssetThumbnail(for media: AlbumMedia,
                                              onUpdate: @escaping (String?, CGSize, Bool) -> Void) {
        let fallbackSize = pixelSize(of: media.asset)
        guard let asset = media.asset else {
            onUpdate(nil, fallbackSize, true)
            return
        }
        let options = PHImageRequestOptions()
        options.isNetworkAccessAllowed = true
        options.deliveryMode = .opportunistic
        options.resizeMode = .fast
        let targetSize = CGSize(width: thumbnailMaxPixel, height: thumbnailMaxPixel)
        PHImageManager.default().requestImage(
            for: asset,
            targetSize: targetSize,
            contentMode: .aspectFit,
            options: options
        ) { image, info in
            let isDegraded = (info?[PHImageResultIsDegradedKey] as? NSNumber)?.boolValue ?? false
            guard let image = image else {
                if !isDegraded { onUpdate(nil, fallbackSize, true) }
                return
            }
            DispatchQueue.global().async {
                let path = writeThumbnail(image, mediaID: media.id, isPreview: isDegraded)
                let size = (path.flatMap { readImage(at: $0) }?.size) ?? fallbackSize
                runOnMain { onUpdate(path, size, path != nil && !isDegraded) }
            }
        }
    }

    private static func makeVideoSnapshot(videoPath: String) -> UIImage? {
        let asset = AVAsset(url: URL(fileURLWithPath: videoPath))
        let generator = AVAssetImageGenerator(asset: asset)
        generator.appliesPreferredTrackTransform = true
        guard let cgImage = try? generator.copyCGImage(
            at: CMTime(seconds: 0, preferredTimescale: snapshotTimescale),
            actualTime: nil
        ) else {
            return nil
        }
        return UIImage(cgImage: cgImage)
    }

    private static func writeThumbnail(_ image: UIImage?, mediaID: UInt64, isPreview: Bool = false) -> String? {
        let fileName = isPreview ? "\(mediaID)_preview.jpg" : "\(mediaID).jpg"
        guard let image = image,
              let data = image.jpegData(compressionQuality: thumbnailCompressionQuality),
              let destination = makeTemporaryFileURL(
                  directory: thumbnailDirectoryName,
                  fileName: fileName
              ) else {
            return nil
        }
        guard (try? data.write(to: destination, options: .atomic)) != nil else { return nil }
        return destination.path
    }

    private static func pixelSize(of asset: PHAsset?) -> CGSize {
        guard let asset = asset, asset.pixelWidth > 0, asset.pixelHeight > 0 else { return .zero }
        return CGSize(width: asset.pixelWidth, height: asset.pixelHeight)
    }

    private static func readImage(at path: String) -> UIImage? {
        guard isReadableFile(path), let image = UIImage(contentsOfFile: path),
              image.size.width > 0, image.size.height > 0 else {
            return nil
        }
        return image
    }

    private static func isReadableFile(_ path: String?) -> Bool {
        guard let path = path, !path.isEmpty else { return false }
        return FileManager.default.fileExists(atPath: path)
    }

    private static func makeTemporaryFileURL(directory: String, fileName: String) -> URL? {
        let directoryURL = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent(directory)
        guard (try? FileManager.default.createDirectory(
            at: directoryURL,
            withIntermediateDirectories: true
        )) != nil else {
            return nil
        }
        let fileURL = directoryURL.appendingPathComponent(fileName)
        if FileManager.default.fileExists(atPath: fileURL.path) {
            try? FileManager.default.removeItem(at: fileURL)
        }
        return fileURL
    }

    private static func runOnMain(_ action: @escaping () -> Void) {
        if Thread.isMainThread {
            action()
        } else {
            DispatchQueue.main.async(execute: action)
        }
    }
}
