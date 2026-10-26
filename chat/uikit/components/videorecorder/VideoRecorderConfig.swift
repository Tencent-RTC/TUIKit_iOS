public class VideoRecorderConfig {
    // 录制模式与质量。
    public var userRecordMode: RecordMode? = nil
    public var userVideoQuality: VideoQuality? = nil

    // 录制时长，单位毫秒。
    public var userMinDurationMs: Int? = nil
    public var userMaxDurationMs: Int? = nil

    // 默认摄像头与可选功能。
    public var userIsDefaultFrontCamera: Bool? = nil
    public var userIsSupportTorch: Bool? = nil
    public var userIsSupportAspect: Bool? = nil
}

public enum RecordMode: Int {
    case videoPhotoMix = 0
    case photoOnly = 1
    case videoOnly = 2
}

public enum VideoQuality: Int {
    case low = 1
    case medium = 2
    case high = 3
}

public enum MediaType {
    case photo
    case video
}
