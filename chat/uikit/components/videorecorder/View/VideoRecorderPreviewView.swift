import AVFoundation
import SnapKit
import UIKit

protocol VideoRecorderPreviewViewDelegate: AnyObject {
    func previewAccept(_ videoPath: String?, image: UIImage?)
    func previewCancel()
}

final class VideoRecorderPreviewView: UIView {
    private static let functionButtonHeight: CGFloat = 28

    private static let buttonSendSize = CGSize(width: 72, height: 34)

    private static let stackHorizontalInset: CGFloat = 10

    private static let sendTrailingInset: CGFloat = 20

    private static let sendBottomInset: CGFloat = 25

    private static let sendCornerRadius: CGFloat = 5

    private static let cancelButtonSize = CGSize(width: 24, height: 24)

    private static let cancelTopInset: CGFloat = 10

    private static let cancelLeadingInset: CGFloat = 15

    private static let bottomBackgroundHeight: CGFloat = 100

    private static let bottomBackgroundCornerRadius: CGFloat = 8

    private static let bottomBackgroundAlpha: CGFloat = 0.05

    private static let quitProgressThreshold: CGFloat = 0.5

    private static let quitVelocityThreshold: CGFloat = 1000

    private static let quitAnimationDuration: TimeInterval = 0.3

    weak var delegate: VideoRecorderPreviewViewDelegate?

    private var videoPath: String?

    private var player: AVPlayer?

    private let imgView = UIImageView()

    private var edgePanGesture: UIScreenEdgePanGestureRecognizer?

    private var tapGesture: UITapGestureRecognizer?

    private let stkViewButtons = UIStackView()

    private let btnSend = UIButton(type: .system)

    private let btnCancel = UIButton(type: .custom)

    private var image: UIImage?

    private let bottomBackground = UIView()

    init() {
        super.init(frame: .zero)
        initUI()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func play(_ videoPath: String?) {
        if let player = player {
            player.pause()
            self.player = nil
        }
        self.videoPath = videoPath
        image = nil

        addPanGesture()
        imgView.isHidden = true

        guard let videoPath = videoPath else { return }
        let player = AVPlayer(url: URL(fileURLWithPath: videoPath))
        self.player = player

        let playerLayer = AVPlayerLayer(player: player)
        playerLayer.frame = bounds
        layer.addSublayer(playerLayer)

        NotificationCenter.default.addObserver(self, selector: #selector(playerItemDidReachEnd(_:)),
                                               name: .AVPlayerItemDidPlayToEndTime, object: player.currentItem)

        player.play()
        showOperationButton()
    }

    func pause() {
        player?.pause()
    }

    func resume() {
        player?.play()
    }

    func previewPhoto(_ image: UIImage?) {
        guard let image = image else { return }
        videoPath = nil
        self.image = image

        addPanGesture()
        imgView.image = image
        let aspect = image.size.height / image.size.width
        let imageViewHeight = Int(frame.size.width * aspect)
        let top = Int((frame.size.height - CGFloat(imageViewHeight)) / 2)
        imgView.isHidden = false
        imgView.snp.remakeConstraints { make in
            make.leading.trailing.equalToSuperview()
            make.top.equalToSuperview().offset(top)
            make.height.equalTo(imageViewHeight)
        }

        showOperationButton()
    }

    private func initUI() {
        backgroundColor = .black

        addSubview(imgView)
        imgView.isHidden = true

        initFuncitonBtnStackView()
        initSendAndCancelBtn()
        addBottomBackground()
    }

    private func initFuncitonBtnStackView() {
        addSubview(stkViewButtons)
        stkViewButtons.axis = .horizontal
        stkViewButtons.alignment = .center
        stkViewButtons.distribution = .equalSpacing

        stkViewButtons.snp.makeConstraints { make in
            make.leading.trailing.equalToSuperview().inset(Self.stackHorizontalInset)
            make.bottom.equalTo(safeAreaLayoutGuide.snp.bottom)
            make.height.equalTo(Self.functionButtonHeight)
        }
    }

    private func initSendAndCancelBtn() {
        if stkViewButtons.arrangedSubviews.isEmpty {
            stkViewButtons.removeFromSuperview()
            addSubview(btnSend)
            btnSend.snp.makeConstraints { make in
                make.size.equalTo(Self.buttonSendSize)
                make.trailing.equalToSuperview().offset(-Self.sendTrailingInset)
                make.bottom.equalToSuperview().offset(-Self.sendBottomInset)
            }
        } else {
            stkViewButtons.addArrangedSubview(btnSend)
            btnSend.snp.makeConstraints { make in
                make.size.equalTo(Self.buttonSendSize)
            }
        }

        btnSend.backgroundColor = VideoRecorderConfigInternal.sharedInstance().getThemeColor()
        btnSend.setTitleColor(.white, for: .normal)
        btnSend.layer.cornerRadius = Self.sendCornerRadius
        btnSend.setTitle(VideoRecorderCommon.localizedStringForKey("send"), for: .normal)
        btnSend.addTarget(self, action: #selector(onBtnSendClicked), for: .touchUpInside)

        addSubview(btnCancel)
        btnCancel.setImage(VideoRecorderCommon.bundleImageByName("return_arrow")?.imageFlippedForRightToLeftLayoutDirection(), for: .normal)
        btnCancel.addTarget(self, action: #selector(onBtnCancelClicked), for: .touchUpInside)
        btnCancel.snp.makeConstraints { make in
            make.size.equalTo(Self.cancelButtonSize)
            make.top.equalTo(safeAreaLayoutGuide.snp.top).offset(Self.cancelTopInset)
            make.leading.equalTo(safeAreaLayoutGuide.snp.leading).offset(Self.cancelLeadingInset)
        }
    }

    private func addBottomBackground() {
        bottomBackground.backgroundColor = UIColor(red: 0, green: 0, blue: 0, alpha: Self.bottomBackgroundAlpha)
        bottomBackground.layer.cornerRadius = Self.bottomBackgroundCornerRadius
        addSubview(bottomBackground)
        bottomBackground.snp.makeConstraints { make in
            make.height.equalTo(Self.bottomBackgroundHeight)
            make.bottom.leading.trailing.equalToSuperview()
        }
    }

    private func removePanGesture() {
        if let edgePanGesture = edgePanGesture {
            removeGestureRecognizer(edgePanGesture)
            self.edgePanGesture = nil
        }
        if let tapGesture = tapGesture {
            removeGestureRecognizer(tapGesture)
            self.tapGesture = nil
        }
    }

    private func addPanGesture() {
        if edgePanGesture == nil {
            let gesture = UIScreenEdgePanGestureRecognizer(target: self, action: #selector(handleEdgePanGesture(_:)))
            gesture.edges = .left
            addGestureRecognizer(gesture)
            edgePanGesture = gesture
        }
        if tapGesture == nil {
            let gesture = UITapGestureRecognizer(target: self, action: #selector(handleTap(_:)))
            addGestureRecognizer(gesture)
            tapGesture = gesture
        }
    }

    @objc private func handleEdgePanGesture(_ gesture: UIScreenEdgePanGestureRecognizer) {
        let translation = gesture.translation(in: self)
        switch gesture.state {
        case .changed:
            let progress = min(1.0, max(0.0, abs(translation.x / bounds.width)))
            transform = CGAffineTransform(translationX: progress * bounds.width, y: 0)
        case .ended, .cancelled:
            let velocity = gesture.velocity(in: self).x
            let progress = abs(translation.x / bounds.width)
            if progress > Self.quitProgressThreshold || velocity > Self.quitVelocityThreshold {
                UIView.animate(withDuration: Self.quitAnimationDuration, animations: {
                    self.transform = CGAffineTransform(translationX: self.bounds.width, y: 0)
                }, completion: { _ in
                    self.quit(false)
                })
            } else {
                UIView.animate(withDuration: Self.quitAnimationDuration) {
                    self.transform = .identity
                }
            }
        default:
            break
        }
    }

    @objc private func handleTap(_ sender: UITapGestureRecognizer) {
        btnSend.isHidden = !btnSend.isHidden
        btnCancel.isHidden = !btnCancel.isHidden
        bottomBackground.isHidden = !bottomBackground.isHidden
    }

    @objc private func playerItemDidReachEnd(_ notification: Notification) {
        player?.seek(to: .zero)
        player?.play()
    }

    @objc private func onBtnSendClicked() {
        quit(true)
    }

    @objc private func onBtnCancelClicked() {
        quit(false)
    }

    private func quit(_ accept: Bool) {
        removePanGesture()
        transform = .identity
        cleanupPlayer()
        if accept {
            delegate?.previewAccept(videoPath, image: image)
        } else {
            delegate?.previewCancel()
        }
    }

    private func showOperationButton() {
        bringSubviewToFront(bottomBackground)
        bringSubviewToFront(btnSend)
        bringSubviewToFront(btnCancel)
        btnSend.isHidden = false
        btnCancel.isHidden = false
        bottomBackground.isHidden = false
    }

    private func cleanupPlayer() {
        guard let player = player else { return }
        player.pause()
        layer.sublayers?.filter { $0 is AVPlayerLayer }.forEach { $0.removeFromSuperlayer() }
        self.player = nil
    }
}
