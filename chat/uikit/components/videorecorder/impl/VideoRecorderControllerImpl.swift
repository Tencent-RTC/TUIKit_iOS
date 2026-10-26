import UIKit

final class VideoRecorderControllerImpl: PageImplementation {
    private let recordMode: RecordMode

    private static let minZoom: CGFloat = 1.0

    private static let maxZoom: CGFloat = 5.0

    private static let millisecondsPerSecond: Float = 1000

    private static let edgePanProgressThreshold: CGFloat = 0.5

    private static let edgePanVelocityThreshold: CGFloat = 1000

    private let settings: VideoRecorderSettings
    private let recordFilePath: String
    private let onVideoCaptured: (String?, Int, String?) -> Void
    private let onPhotoCaptured: (String?) -> Void
    private var didFinishCapture = false

    private let recordCore: VideoRecordCore

    private let encodeConfig: VideoRecorderEncodeConfig

    private lazy var ctrlView = VideoRecorderControlView(frame: view.bounds, settings: settings)

    private lazy var videoPlayerView = VideoRecorderPreviewView()

    private var edgePanGesture: UIScreenEdgePanGestureRecognizer?

    private var recorderResult: VideoRecordResult?

    private var zoom: CGFloat = 1.0

    private var originNavgationBarHidden = false

    private var isUsingFrontCamera: Bool

    private var recordDuration: Float = 0

    private let minDurationSeconds: Float

    private let maxDurationSeconds: Float

    init(config: VideoRecorderConfig?,
         onVideoCaptured: @escaping (String?, Int, String?) -> Void,
         onPhotoCaptured: @escaping (String?) -> Void) {
        let settings = VideoRecorderSettings(config: config)
        self.settings = settings
        recordMode = settings.recordMode
        self.onVideoCaptured = onVideoCaptured
        self.onPhotoCaptured = onPhotoCaptured
        recordFilePath = VideoRecorderMediaFiles.makeVideoPath()
        isUsingFrontCamera = settings.isDefaultFrontCamera
        minDurationSeconds = Float(settings.minDurationMs) / Self.millisecondsPerSecond
        maxDurationSeconds = Float(settings.maxDurationMs) / Self.millisecondsPerSecond
        encodeConfig = VideoRecorderEncodeConfig(videoQuality: settings.videoQuality.rawValue)
        if let ugcRecordCore = UGCReflectVideoRecordCore.create() {
            recordCore = ugcRecordCore
        } else {
            print("Because it does not rely on the LiteAV module, the UGC video recorder cannot be used. Instead, the system video recorder can be used. For more details, please refer to the relevant documentation")
            recordCore = SystemVideoRecordCore()
        }
        super.init()
    }

    func viewDidLoad() {
        initUI()
    }

    func viewWillAppear(_ animated: Bool) {
        startPreview()
        if let navigationController = navigationController {
            originNavgationBarHidden = navigationController.isNavigationBarHidden
            navigationController.isNavigationBarHidden = true
        }
        NotificationCenter.default.addObserver(self, selector: #selector(appDidBecomeActive),
                                               name: UIApplication.didBecomeActiveNotification, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(appWillResignActive),
                                               name: UIApplication.willResignActiveNotification, object: nil)
    }

    func viewWillDisappear(_ animated: Bool) {
        recordCore.stopCameraPreview()
        ctrlView.flashState = false
        navigationController?.isNavigationBarHidden = originNavgationBarHidden
        NotificationCenter.default.removeObserver(self)
    }

    private func initUI() {
        view.backgroundColor = .black

        ctrlView.delegate = self
        view.addSubview(ctrlView)

        view.addSubview(videoPlayerView)
        videoPlayerView.isHidden = true
        videoPlayerView.delegate = self

        startPreview()
        addEdgePanGesture()

        let pinchRecognizer = UIPinchGestureRecognizer(target: self, action: #selector(onPinch(_:)))
        ctrlView.addGestureRecognizer(pinchRecognizer)
    }

    private func startPreview() {
        let config: [String: Any] = [
            "videoResolution": encodeConfig.getVideoRecordResolution().rawValue,
            "videoFPS": encodeConfig.fps,
            "videoBitratePIN": encodeConfig.bitrate,
            "minDuration": minDurationSeconds,
            "maxDuration": maxDurationSeconds,
            "frontCamera": isUsingFrontCamera
        ]

        setAspectRatio()
        recordCore.startCameraCustom(config, preview: ctrlView.previewView)
    }

    @objc private func appDidBecomeActive() {
        videoPlayerView.resume()
        startPreview()
    }

    @objc private func appWillResignActive() {
        recordCore.stopCameraPreview()
        videoPlayerView.pause()
        ctrlView.flashState = false
    }

    private func presentSimpleAlert(title: String, message: String, onOk: (() -> Void)?) {
        let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)
        let defaultAction = UIAlertAction(title: "OK", style: .default) { _ in
            onOk?()
        }
        alert.addAction(defaultAction)
        present(alert, animated: true)
    }

    private func takePhoto() {
        recordCore.snapshot { [weak self] image in
            print("take photo complete")
            self?.privewPhoto(image)
            self?.ctrlView.flashState = false
        }
    }

    private func privewPhoto(_ image: UIImage?) {
        guard let image, let owner else { return }
        VideoRecorderPhotoEditBridge.present(
            from: owner,
            image: image,
            onConfirm: { [weak self] editedImage in
                self?.completeCapture(videoPath: nil, image: editedImage, durationMs: 0)
            },
            onCancel: {}
        )
    }

    private func completeCapture(videoPath: String?, image: UIImage?, durationMs: Int) {
        guard !didFinishCapture else { return }
        didFinishCapture = true
        dismiss(animated: true)
        if let videoPath {
            onVideoCaptured(videoPath, durationMs, VideoRecorderMediaFiles.thumbnailPath(for: videoPath))
        } else if let image {
            onPhotoCaptured(VideoRecorderMediaFiles.saveImage(image))
        } else {
            onPhotoCaptured(nil)
        }
    }

    private func setAspectRatio() {
        switch ctrlView.aspectRatio {
        case .ratio3x4:
            recordCore.setAspectRatio(.ratio3x4)
        case .ratio9x16:
            recordCore.setAspectRatio(.ratio9x16)
        default:
            break
        }
    }

    @objc private func onPinch(_ recognizer: UIPinchGestureRecognizer) {
        zoom = min(max(zoom * recognizer.scale, Self.minZoom), Self.maxZoom)
        recognizer.scale = 1
        recordCore.setZoom(zoom)
    }

    private func removeEdgePanGesture() {
        if let edgePanGesture = edgePanGesture {
            view.removeGestureRecognizer(edgePanGesture)
            self.edgePanGesture = nil
        }
    }

    private func addEdgePanGesture() {
        let gesture = UIScreenEdgePanGestureRecognizer(target: self, action: #selector(handleEdgePanGesture(_:)))
        gesture.edges = .left
        view.addGestureRecognizer(gesture)
        edgePanGesture = gesture
    }

    @objc private func handleEdgePanGesture(_ gesture: UIScreenEdgePanGestureRecognizer) {
        guard gesture.state == .ended || gesture.state == .cancelled else { return }
        let translation = gesture.translation(in: view)
        let velocity = gesture.velocity(in: view)
        let xProgress = abs(translation.x / view.bounds.width)
        let yProgress = abs(translation.y / view.bounds.height)
        if xProgress > Self.edgePanProgressThreshold || velocity.x > Self.edgePanVelocityThreshold
            || yProgress > Self.edgePanProgressThreshold || velocity.y > Self.edgePanVelocityThreshold {
            completeCapture(videoPath: nil, image: nil, durationMs: 0)
        }
    }
}

extension VideoRecorderControllerImpl: VideoRecorderControlViewDelegate {
    func recordControlViewOnAspectChange() {
        setAspectRatio()
    }

    func recordControlViewOnCameraSwicth(_ isUsingFrontCamera: Bool) {
        recordCore.switchCamera(isUsingFrontCamera)
        self.isUsingFrontCamera = isUsingFrontCamera
    }

    func recordControlViewOnExit() {
        recordCore.stopCameraPreview()
        ctrlView.flashState = false
        completeCapture(videoPath: nil, image: nil, durationMs: 0)
    }

    func recordControlViewOnFlashStateChange(_ flashState: Bool) {
        recordCore.toggleTorch(flashState)
    }

    func recordControlViewOnRecordStart() {
        recordCore.recordDelegate = self
        let result = recordCore.startRecord(recordFilePath)
        print("record start. res = \(result)")
        recordDuration = 0
    }

    func recordControlViewOnRecordFinish() {
        recordCore.stopRecord()
        ctrlView.flashState = false
    }

    func recordControlViewPhoto() {
        takePhoto()
    }
}

extension VideoRecorderControllerImpl: VideoRecorderCoreListener {
    func onRecordProgress(_ milliSecond: Int) {
        if milliSecond == 0 {
            return
        }

        recordDuration = Float(milliSecond) / Self.millisecondsPerSecond
        ctrlView.setProgress(recordDuration / maxDurationSeconds, duration: recordDuration)
        if recordDuration >= maxDurationSeconds {
            recordCore.stopRecord()
            ctrlView.flashState = false
        }
    }

    func onRecordComplete(_ result: VideoRecordResult) {
        recordCore.deleteTempFile()
        if result.retCode == .failed {
            let title = LocalizedChatString("record_failed")
            presentSimpleAlert(title: title, message: "") { [weak self] in
                self?.startPreview()
            }
            return
        }

        print("on record complete record duration: \(recordDuration)")
        if recordDuration < minDurationSeconds {
            if recordMode == .videoPhotoMix {
                takePhoto()
            }
            return
        }

        recorderResult = result
        videoPlayerView.isHidden = false
        videoPlayerView.frame = view.frame
        ctrlView.isHidden = true
        videoPlayerView.play(result.videoPath)
    }
}

extension VideoRecorderControllerImpl: VideoRecorderPreviewViewDelegate {
    func previewAccept(_ videoPath: String?, image: UIImage?) {
        completeCapture(videoPath: videoPath, image: image, durationMs: Int(recordDuration * Self.millisecondsPerSecond))
    }

    func previewCancel() {
        print("VideoPreviewViewDelegate cancle")
        videoPlayerView.isHidden = true
        ctrlView.isHidden = false
    }
}
