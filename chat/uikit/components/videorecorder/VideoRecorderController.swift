import UIKit

enum RecordMode: Int {
    case videoPhotoMix = 0
    case photoOnly = 1
    case videoOnly = 2
}

final class VideoRecorderController: UIViewController {
    private static let mixedRecordMode = 0

    private static let minZoom: CGFloat = 1.0

    private static let maxZoom: CGFloat = 5.0

    private static let millisecondsPerSecond: Float = 1000

    private static let edgePanProgressThreshold: CGFloat = 0.5

    private static let edgePanVelocityThreshold: CGFloat = 1000

    var recordFilePath: String?

    var resultCallback: ((String?, UIImage?, Int32) -> Void)?

    var photoPreviewOverride: ((VideoRecorderController, UIImage) -> Void)?

    private let recordCore: VideoRecordCore

    private let encodeConfig: VideoRecorderEncodeConfig

    private lazy var ctrlView = VideoRecorderControlView(frame: view.bounds)

    private lazy var videoPlayerView = VideoRecorderPreviewView()

    private var edgePanGesture: UIScreenEdgePanGestureRecognizer?

    private var recorderResult: VideoRecordResult?

    private var zoom: CGFloat = 1.0

    private var originNavgationBarHidden = false

    private var isUsingFrontCamera: Bool

    private var recordDuration: Float = 0

    private let minDurationSeconds: Float

    private let maxDurationSeconds: Float

    init() {
        let config = VideoRecorderConfigInternal.sharedInstance()
        isUsingFrontCamera = config.isDefaultFrontCamera()
        minDurationSeconds = Float(config.getMinRecordDurationMs()) / Self.millisecondsPerSecond
        maxDurationSeconds = Float(config.getMaxRecordDurationMs()) / Self.millisecondsPerSecond
        encodeConfig = VideoRecorderEncodeConfig(videoQuality: config.getVideoQuality())
        if let ugcRecordCore = UGCReflectVideoRecordCore.create() {
            recordCore = ugcRecordCore
        } else {
            print("Because it does not rely on the LiteAV module, the UGC video recorder cannot be used. Instead, the system video recorder can be used. For more details, please refer to the relevant documentation")
            recordCore = SystemVideoRecordCore()
        }
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        initUI()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
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

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
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
        if let photoPreviewOverride = photoPreviewOverride {
            if let image = image {
                photoPreviewOverride(self, image)
            }
            return
        }
        videoPlayerView.isHidden = false
        videoPlayerView.frame = view.frame
        videoPlayerView.previewPhoto(image)
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
            resultCallback?(nil, nil, 0)
        }
    }
}

extension VideoRecorderController: VideoRecorderControlViewDelegate {
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
        resultCallback?(nil, nil, 0)
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

extension VideoRecorderController: VideoRecorderCoreListener {
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
            let title = VideoRecorderCommon.localizedStringForKey("record_failed")
            presentSimpleAlert(title: title, message: "") { [weak self] in
                self?.startPreview()
            }
            return
        }

        print("on record complete record duration: \(recordDuration)")
        if recordDuration < minDurationSeconds {
            if VideoRecorderConfigInternal.sharedInstance().getRecordeMode() == Self.mixedRecordMode {
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

extension VideoRecorderController: VideoRecorderPreviewViewDelegate {
    func previewAccept(_ videoPath: String?, image: UIImage?) {
        resultCallback?(videoPath, image, Int32(recordDuration * Self.millisecondsPerSecond))
    }

    func previewCancel() {
        print("VideoPreviewViewDelegate cancle")
        videoPlayerView.isHidden = true
        ctrlView.isHidden = false
    }
}
