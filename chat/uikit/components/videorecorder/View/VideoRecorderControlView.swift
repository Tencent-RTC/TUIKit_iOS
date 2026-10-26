import SnapKit
import UIKit

enum VideoRecorderAspectRatio: Int {
    case ratio1x1
    case ratio3x4
    case ratio4x3
    case ratio9x16
    case ratio16x9
}

protocol VideoRecorderControlViewDelegate: AnyObject {
    func recordControlViewOnRecordStart()
    func recordControlViewOnRecordFinish()
    func recordControlViewPhoto()
    func recordControlViewOnFlashStateChange(_ flashState: Bool)
    func recordControlViewOnAspectChange()
    func recordControlViewOnExit()
    func recordControlViewOnCameraSwicth(_ isUsingFrontCamera: Bool)
}

final class VideoRecorderControlView: UIView {
    private static let btnStartRecordSize: CGFloat = 72

    private static let btnStartRecordGapBottom: CGFloat = 15

    private static let btnStartRecordDotSizeNormal: CGFloat = 56

    private static let btnStartRecordDotSizePressed: CGFloat = 20

    private static let btnStartRecordProgressSizeNormal: CGFloat = 72

    private static let btnStartRecordProgressSizePressed: CGFloat = 80

    private static let btnExitRecordSize = CGSize(width: 28, height: 28)

    private static let btnExitRecordGapToStartRecord: CGFloat = 55

    private static let btnCameraSwitchSize = CGSize(width: 28, height: 28)

    private static let btnCameraSwitchGapToStartRecord: CGFloat = 55

    private static let functionBtnToTop: CGFloat = 64

    private static let functionBtnToRight: CGFloat = 16

    private static let btnExtendFunctionIconSize = CGSize(width: 28, height: 28)

    private static let btnExtendFunctionIconTextGap: CGFloat = 4

    private static let btnExtendFunctionGap: CGFloat = 24

    private static let showDurationLabel = true

    private static let previewAspectRatio: CGFloat = 16.0 / 9.0

    private static let durationFontSize: CGFloat = 18

    private static let durationLabelGap: CGFloat = 8

    private static let tipFontSize: CGFloat = 16

    private static let tipBottomGap: CGFloat = 16

    private static let functionTitleFontSize: CGFloat = 12

    private static let secondsPerMinute: Float = 60

    var flashState = false {
        didSet {
            let imageName = flashState ? "flash_open" : "flash_close"
            btnFlash?.setImage(AtomicXChatResources.image(named: imageName), for: .normal)
            delegate?.recordControlViewOnFlashStateChange(flashState)
        }
    }

    var aspectRatio: VideoRecorderAspectRatio = .ratio9x16

    var isUsingFrontCamera = false

    private(set) var previewView = UIView()

    weak var delegate: VideoRecorderControlViewDelegate?

    private let btnRecord = VideoRecorderRecordButtonView()

    private let btnExitRecord = UIButton(type: .custom)

    private let btnCameraSwitch = UIButton(type: .custom)

    private var btnFlash: UIButton?

    private var btnAspect: UIButton?

    private var lastFuncitonBtn: UIButton?

    private let lbDuration = UILabel()

    private let lbTip = UILabel()

    private let recordMode: RecordMode
    private let settings: VideoRecorderSettings

    init(frame: CGRect, settings: VideoRecorderSettings) {
        self.settings = settings
        self.recordMode = settings.recordMode
        self.isUsingFrontCamera = settings.isDefaultFrontCamera
        super.init(frame: frame)
        initUI()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func setProgress(_ progress: Float, duration: Float) {
        btnRecord.progress = progress
        let minutes = Int(floor(duration / Self.secondsPerMinute))
        let seconds = Int(floor(duration - Float(minutes) * Self.secondsPerMinute))
        lbDuration.text = String(format: "%02d:%02d", minutes, seconds)
    }

    private func initUI() {
        addSubview(previewView)
        previewView.snp.makeConstraints { make in
            make.top.equalToSuperview()
            make.width.equalToSuperview()
            make.height.equalTo(previewView.snp.width).multipliedBy(Self.previewAspectRatio)
        }

        let bottomMaskView = UIView()
        addSubview(bottomMaskView)
        bottomMaskView.backgroundColor = .black

        initControlButtons()
        initFunctionButtons()

        addSubview(lbDuration)
        lbDuration.isHidden = true
        lbDuration.text = "00:00"
        lbDuration.font = UIFont.monospacedSystemFont(ofSize: Self.durationFontSize, weight: .medium)
        lbDuration.textColor = .white
        lbDuration.snp.makeConstraints { make in
            make.bottom.equalTo(btnRecord.snp.top).offset(-Self.durationLabelGap)
            make.centerX.equalTo(btnRecord)
        }

        bottomMaskView.snp.makeConstraints { make in
            make.leading.trailing.bottom.equalToSuperview()
            make.top.equalTo(lbDuration.snp.top).offset(-Self.durationLabelGap)
        }

        addSubview(lbTip)
        lbTip.text = recordTipText()
        lbTip.font = UIFont.systemFont(ofSize: Self.tipFontSize)
        lbTip.textColor = .white
        lbTip.snp.makeConstraints { make in
            make.bottom.lessThanOrEqualTo(previewView).offset(-Self.tipBottomGap)
            make.bottom.lessThanOrEqualTo(bottomMaskView.snp.top).offset(-Self.tipBottomGap)
            make.centerX.equalToSuperview()
        }
    }

    private func recordTipText() -> String {
        if recordMode == .videoPhotoMix {
            return LocalizedChatString("record_mode_mix_tip")
        }
        if recordMode == .photoOnly {
            return LocalizedChatString("record_mode_photo_tip")
        }
        return LocalizedChatString("record_mode_video_tip")
    }

    private func initControlButtons() {
        addSubview(btnRecord)
        btnRecord.dotSizeNormal = Self.btnStartRecordDotSizeNormal
        btnRecord.dotSizePressed = Self.btnStartRecordDotSizePressed
        btnRecord.progressSizeNormal = Self.btnStartRecordProgressSizeNormal
        btnRecord.progressSizePressed = Self.btnStartRecordProgressSizePressed
        btnRecord.isOnlySupportTakePhoto = recordMode != .photoOnly
        btnRecord.delegate = self
        setupCustomButton(btnExitRecord, image: AtomicXChatResources.image(named: "cross"), action: #selector(onBtnExitClick))
        setupCustomButton(btnCameraSwitch, image: AtomicXChatResources.image(named: "camera_switch"),
                          action: #selector(onBtnCameraSwitchClick))

        btnRecord.snp.makeConstraints { make in
            make.width.height.equalTo(Self.btnStartRecordSize)
            make.centerX.equalToSuperview()
            make.bottom.equalTo(safeAreaLayoutGuide.snp.bottom).offset(-Self.btnStartRecordGapBottom)
        }
        btnExitRecord.snp.makeConstraints { make in
            make.size.equalTo(Self.btnExitRecordSize)
            make.centerY.equalTo(btnRecord)
            make.trailing.equalTo(btnRecord.snp.leading).offset(-Self.btnExitRecordGapToStartRecord)
        }
        btnCameraSwitch.snp.makeConstraints { make in
            make.size.equalTo(Self.btnCameraSwitchSize)
            make.centerY.equalTo(btnRecord)
            make.leading.equalTo(btnRecord.snp.trailing).offset(Self.btnCameraSwitchGapToStartRecord)
        }
    }

    private func initFunctionButtons() {
        initTorchView()
        initAspectView()
    }

    private func initTorchView() {
        guard settings.isSupportTorch else { return }

        let button = newFunctionButton(image: AtomicXChatResources.image(named: "flash_close"),
                                       title: LocalizedChatString("flash"),
                                       action: #selector(onBtnFlashClick))
        button.snp.makeConstraints { make in
            make.trailing.equalToSuperview().offset(-Self.functionBtnToRight)
            make.top.equalToSuperview().offset(Self.functionBtnToTop)
        }
        btnFlash = button
        lastFuncitonBtn = button
    }

    private func initAspectView() {
        guard settings.isSupportAspect else { return }
        guard UGCReflectVideoRecordCore.create() != nil else { return }

        let button = newFunctionButton(image: AtomicXChatResources.image(named: "record_aspect_9_16"),
                                       title: LocalizedChatString("aspect"),
                                       action: #selector(onBtnAspectClick))
        makeFunctionButtonConstraints(button, below: lastFuncitonBtn)
        btnAspect = button
        lastFuncitonBtn = button
    }

    private func makeFunctionButtonConstraints(_ button: UIButton, below lastButton: UIButton?) {
        button.snp.makeConstraints { make in
            if let lastButton = lastButton {
                make.centerX.equalTo(lastButton)
                make.top.equalTo(lastButton.snp.bottom).offset(Self.btnExtendFunctionGap)
            } else {
                make.top.equalToSuperview().offset(Self.functionBtnToTop)
                make.trailing.equalToSuperview().offset(-Self.functionBtnToRight)
            }
        }
    }

    private func newFunctionButton(image: UIImage?, title: String, action: Selector) -> UIButton {
        let button = VideoRecorderIconLabelButtonView(type: .custom)
        button.setImage(image, for: .normal)
        let attributes: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: Self.functionTitleFontSize),
            .foregroundColor: UIColor.white
        ]
        button.setAttributedTitle(NSAttributedString(string: title, attributes: attributes), for: .normal)
        button.addTarget(self, action: action, for: .touchUpInside)
        button.iconSize = Self.btnExtendFunctionIconSize
        button.iconLabelGap = Self.btnExtendFunctionIconTextGap
        addSubview(button)
        return button
    }

    private func setupCustomButton(_ button: UIButton, image: UIImage?, action: Selector) {
        button.setImage(image, for: .normal)
        button.addTarget(self, action: action, for: .touchUpInside)
        addSubview(button)
    }

    private func setOperationButtonsHidden(_ hidden: Bool) {
        btnExitRecord.isHidden = hidden
        btnCameraSwitch.isHidden = hidden
        btnFlash?.isHidden = hidden
        btnAspect?.isHidden = hidden
    }

    @objc private func onBtnExitClick() {
        delegate?.recordControlViewOnExit()
    }

    @objc private func onBtnCameraSwitchClick() {
        if isUsingFrontCamera {
            isUsingFrontCamera = false
            btnFlash?.isEnabled = true
        } else {
            isUsingFrontCamera = true
            btnFlash?.isEnabled = false
            flashState = false
        }
        delegate?.recordControlViewOnCameraSwicth(isUsingFrontCamera)
    }

    @objc private func onBtnFlashClick() {
        if isUsingFrontCamera {
            return
        }
        flashState = !flashState
    }

    @objc private func onBtnAspectClick() {
        if aspectRatio == .ratio9x16 {
            aspectRatio = .ratio3x4
            btnAspect?.setImage(AtomicXChatResources.image(named: "record_aspect_3_4"), for: .normal)
        } else {
            aspectRatio = .ratio9x16
            btnAspect?.setImage(AtomicXChatResources.image(named: "record_aspect_9_16"), for: .normal)
        }
        delegate?.recordControlViewOnAspectChange()
    }
}

extension VideoRecorderControlView: VideoRecorderRecordButtonDelegate {
    func onRecordButtonLongPressBegan(_ button: VideoRecorderRecordButtonView) {
        if recordMode != .photoOnly {
            delegate?.recordControlViewOnRecordStart()
            lbDuration.isHidden = !Self.showDurationLabel
        } else {
            lbDuration.isHidden = true
        }
        lbTip.isHidden = true
        setOperationButtonsHidden(true)
    }

    func onRecordButtonLongPressEnded(_ button: VideoRecorderRecordButtonView) {
        if recordMode != .photoOnly {
            delegate?.recordControlViewOnRecordFinish()
        } else if recordMode != .videoOnly {
            delegate?.recordControlViewPhoto()
        }
        lbDuration.isHidden = true
        lbTip.isHidden = false
        setOperationButtonsHidden(false)
    }

    func onRecordButtonLongPressCancelled(_ button: VideoRecorderRecordButtonView) {
        if recordMode != .photoOnly {
            delegate?.recordControlViewOnRecordFinish()
        }
        lbDuration.isHidden = true
        lbTip.isHidden = false
        setOperationButtonsHidden(false)
    }

    func onRecordButtonTap(_ button: VideoRecorderRecordButtonView) {
        if recordMode != .videoOnly {
            delegate?.recordControlViewPhoto()
        }
    }
}
