import UIKit

enum VideoRecordCompressed: Int {
    case compressed360P = 0
    case compressed480P = 1
    case compressed540P = 2
    case compressed720P = 3
    case compressed1080P = 4
}

enum VideoRecordResolution: Int {
    case resolution360x640 = 0
    case resolution540x960 = 1
    case resolution720x1280 = 2
    case resolution1080x1920 = 3
}

struct VideoRecordResultCode: RawRepresentable, Equatable {
    let rawValue: Int

    static let ok = VideoRecordResultCode(rawValue: 0)
    static let okInterrupt = VideoRecordResultCode(rawValue: 1)
    static let okUnreachMinDuration = VideoRecordResultCode(rawValue: 2)
    static let okBeyondMaxDuration = VideoRecordResultCode(rawValue: 3)
    static let failed = VideoRecordResultCode(rawValue: 1001)
}

enum VideoRecordAspectRatio: Int {
    case ratio3x4 = 0
    case ratio9x16 = 1
    case ratio1x1 = 2
    case ratio16x9 = 3
    case ratio4x3 = 4
}

final class VideoRecordResult {
    var retCode: VideoRecordResultCode = .ok

    var descMsg: String?

    var videoPath: String?

    var coverImage: UIImage?
}

protocol VideoRecorderCoreListener: AnyObject {
    func onRecordProgress(_ milliSecond: Int)
    func onRecordComplete(_ result: VideoRecordResult)
    func onRecordEvent(_ evt: [String: Any])
}

extension VideoRecorderCoreListener {
    func onRecordProgress(_ milliSecond: Int) {}

    func onRecordComplete(_ result: VideoRecordResult) {}

    func onRecordEvent(_ evt: [String: Any]) {}
}

final class VideoRecordCustomConfig {
    var videoResolution: VideoRecordResolution = .resolution360x640

    var videoFPS: Int = 0

    var videoBitratePIN: Int = 0

    var frontCamera: Bool = false

    var minDuration: Float = 0

    var maxDuration: Float = 0
}
