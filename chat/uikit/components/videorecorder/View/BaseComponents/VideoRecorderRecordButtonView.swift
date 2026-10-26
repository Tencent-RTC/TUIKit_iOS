import UIKit

protocol VideoRecorderRecordButtonDelegate: AnyObject {
    func onRecordButtonTap(_ button: VideoRecorderRecordButtonView)
    func onRecordButtonLongPressBegan(_ button: VideoRecorderRecordButtonView)
    func onRecordButtonLongPressEnded(_ button: VideoRecorderRecordButtonView)
    func onRecordButtonLongPressCancelled(_ button: VideoRecorderRecordButtonView)
}

final class VideoRecorderRecordButtonView: UIView {
    private static let recordAnimeDuration: TimeInterval = 0.3

    private static let progressWidthNormal: CGFloat = 2

    private static let progressWidthPressed: CGFloat = 4

    var progress: Float = 0 {
        didSet {
            progressView.setProgress(CGFloat(progress), animated: true)
        }
    }

    var dotSizeNormal: CGFloat = 0

    var progressSizeNormal: CGFloat = 0

    var dotSizePressed: CGFloat = 0

    var progressSizePressed: CGFloat = 0

    var isOnlySupportTakePhoto = false

    weak var delegate: VideoRecorderRecordButtonDelegate?

    private let progressView = VideoRecorderCircleProgressView()

    private let dotView = UIView()

    private var pressed = false

    private let longPressRecognizer = UILongPressGestureRecognizer()

    override init(frame: CGRect) {
        super.init(frame: frame)
        initUI()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        layoutRecordButton()
    }

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        super.touchesBegan(touches, with: event)
        animeStartRecord()
    }

    override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?) {
        super.touchesCancelled(touches, with: event)
        animeStopRecord()
    }

    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        super.touchesEnded(touches, with: event)
        animeStopRecord()
    }

    private func initUI() {
        progressView.lineCap = .butt
        progressView.progressBgColor = VideoRecorderCommon.dynamicColor("record_btn_progress_bg_color", defaultColor: "#FFFFFF")
        progressView.progressColor = VideoRecorderConfigInternal.sharedInstance().getThemeColor()
        progressView.width = Self.progressWidthNormal
        addSubview(progressView)

        dotView.backgroundColor = VideoRecorderCommon.dynamicColor("record_btn_dot_color", defaultColor: "#FFFFFF")
        addSubview(dotView)

        let tapRecognizer = UITapGestureRecognizer(target: self, action: #selector(onTap(_:)))
        tapRecognizer.cancelsTouchesInView = false
        addGestureRecognizer(tapRecognizer)

        longPressRecognizer.addTarget(self, action: #selector(onLongPress(_:)))
        longPressRecognizer.cancelsTouchesInView = false
        longPressRecognizer.minimumPressDuration = Self.recordAnimeDuration
        addGestureRecognizer(longPressRecognizer)
        layoutRecordButton()
    }

    private func layoutRecordButton() {
        let dotSize = pressed ? dotSizePressed : dotSizeNormal
        var progressSize = pressed ? progressSizePressed : progressSizeNormal
        if isOnlySupportTakePhoto {
            progressSize = progressSizeNormal
        }

        let center = CGPoint(x: bounds.width / 2, y: bounds.height / 2)
        let length = min(bounds.width, bounds.height)
        progressView.center = center
        progressView.bounds = CGRect(x: 0, y: 0, width: length, height: length)
        progressView.transform = CGAffineTransform(scaleX: progressSize / length, y: progressSize / length)

        dotView.center = center
        dotView.bounds = CGRect(x: 0, y: 0, width: dotSize, height: dotSize)
        dotView.layer.cornerRadius = dotSize / 2
    }

    private func animeStartRecord() {
        progressView.width = Self.progressWidthPressed
        UIView.animate(withDuration: Self.recordAnimeDuration) {
            self.pressed = true
            self.layoutRecordButton()
        }
    }

    private func animeStopRecord() {
        progressView.width = Self.progressWidthNormal
        UIView.animate(withDuration: Self.recordAnimeDuration) {
            self.pressed = false
            self.layoutRecordButton()
        }
    }

    @objc private func onTap(_ recognizer: UITapGestureRecognizer) {
        delegate?.onRecordButtonTap(self)
    }

    @objc private func onLongPress(_ recognizer: UILongPressGestureRecognizer) {
        switch recognizer.state {
        case .began:
            delegate?.onRecordButtonLongPressBegan(self)
        case .ended:
            delegate?.onRecordButtonLongPressEnded(self)
        case .cancelled:
            animeStopRecord()
            delegate?.onRecordButtonLongPressCancelled(self)
        default:
            break
        }
    }
}
