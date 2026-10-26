import Foundation

final class VideoRecorderEncodeConfig {
    private static let videoQualityLow = 1

    private static let videoQualityMedium = 2

    private static let videoQualityHigh = 3

    private static let lowBitrate = 1000

    private static let mediumBitrate = 3000

    private static let highBitrate = 5000

    private static let normalFps = 25

    private static let highFps = 30

    var fps: Int

    var bitrate: Int

    private let videoQuality: Int

    convenience init() {
        self.init(videoQuality: Self.videoQualityMedium)
    }

    init(videoQuality: Int) {
        switch videoQuality {
        case Self.videoQualityLow:
            bitrate = Self.lowBitrate
            fps = Self.normalFps
        case Self.videoQualityHigh:
            bitrate = Self.highBitrate
            fps = Self.highFps
        default:
            bitrate = Self.mediumBitrate
            fps = Self.normalFps
        }
        self.videoQuality = videoQuality
    }

    func getVideoEditCompressed() -> VideoRecordCompressed {
        return videoQuality == Self.videoQualityHigh ? .compressed1080P : .compressed720P
    }

    func getVideoRecordResolution() -> VideoRecordResolution {
        return videoQuality == Self.videoQualityHigh ? .resolution1080x1920 : .resolution720x1280
    }
}
