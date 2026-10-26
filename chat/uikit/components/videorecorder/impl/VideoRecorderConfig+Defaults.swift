extension VideoRecorderConfig {
    static let defaultMinDurationMs = 2000
    static let defaultMaxDurationMs = 15000

    public convenience init(
        recordMode: RecordMode? = nil,
        videoQuality: VideoQuality? = nil,
        minDurationMs: Int? = nil,
        maxDurationMs: Int? = nil,
        isDefaultFrontCamera: Bool? = nil,
        isSupportTorch: Bool? = nil,
        isSupportAspect: Bool? = nil
    ) {
        self.init()
        self.userRecordMode = recordMode
        self.userVideoQuality = videoQuality
        self.userMinDurationMs = minDurationMs
        self.userMaxDurationMs = maxDurationMs
        self.userIsDefaultFrontCamera = isDefaultFrontCamera
        self.userIsSupportTorch = isSupportTorch
        self.userIsSupportAspect = isSupportAspect
    }

    public var recordMode: RecordMode {
        get { userRecordMode ?? .videoPhotoMix }
        set { userRecordMode = newValue }
    }

    public var videoQuality: VideoQuality {
        get { userVideoQuality ?? .medium }
        set { userVideoQuality = newValue }
    }

    public var minDurationMs: Int {
        get { userMinDurationMs ?? Self.defaultMinDurationMs }
        set { userMinDurationMs = newValue }
    }

    public var maxDurationMs: Int {
        get { userMaxDurationMs ?? Self.defaultMaxDurationMs }
        set { userMaxDurationMs = newValue }
    }

    public var isDefaultFrontCamera: Bool {
        get { userIsDefaultFrontCamera ?? false }
        set { userIsDefaultFrontCamera = newValue }
    }

    public var isSupportTorch: Bool {
        get { userIsSupportTorch ?? true }
        set { userIsSupportTorch = newValue }
    }

    public var isSupportAspect: Bool {
        get { userIsSupportAspect ?? true }
        set { userIsSupportAspect = newValue }
    }
}

struct VideoRecorderSettings {
    let recordMode: RecordMode
    let videoQuality: VideoQuality
    let minDurationMs: Int
    let maxDurationMs: Int
    let isDefaultFrontCamera: Bool
    let isSupportTorch: Bool
    let isSupportAspect: Bool

    init(config: VideoRecorderConfig?) {
        let config = config ?? VideoRecorderConfig(recordMode: nil)
        let maxDuration = config.maxDurationMs > 0 ? config.maxDurationMs : VideoRecorderConfig.defaultMaxDurationMs
        let minDuration = config.minDurationMs > 0 ? config.minDurationMs : VideoRecorderConfig.defaultMinDurationMs
        self.maxDurationMs = Int(Int32(clamping: maxDuration))
        self.minDurationMs = min(Int(Int32(clamping: minDuration)), self.maxDurationMs)
        recordMode = config.recordMode
        videoQuality = config.videoQuality
        isDefaultFrontCamera = config.isDefaultFrontCamera
        isSupportTorch = config.isSupportTorch
        isSupportAspect = config.isSupportAspect
    }
}
