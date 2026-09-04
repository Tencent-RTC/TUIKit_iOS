import UIKit
import SnapKit
import Kingfisher
import AtomicXCore

final class MessageVideoContentView: UIView, MessageContentView {
    private static let maxSize: CGFloat = 200

    private static let minSize: CGFloat = 80

    private static let cornerRadius = CGFloat(RadiusScheme.alertRadius)

    private static let playButtonSize: CGFloat = 44

    private static let durationChipRadius = CGFloat(RadiusScheme.tipsRadius)

    private static let durationChipMargin = CGFloat(SpacingScheme.smallSpacing)

    private static let durationChipInsets = UIEdgeInsets(top: 2, left: 6, bottom: 2, right: 6)

    private static let durationChipBackgroundAlpha: CGFloat = 0.4

    private var boundMsgID: String?

    private var hasTriggeredDownload = false

    private var boundMessage: MessageInfo?

    private var onMediaTap: ((MessageInfo) -> Void)?

    private let snapshotView = UIImageView()

    private let playIconView = UIImageView()

    private let durationLabel = PaddedLabel(insets: MessageVideoContentView.durationChipInsets)

    // MARK: - Init

    init() {
        super.init(frame: .zero)
        constructViewHierarchy()
        activateConstraints()
        setupViewStyle()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    // MARK: - MessageContentView

    func bind(message: MessageInfo, context: MessageContentContext) {
        if boundMsgID != message.msgID {
            hasTriggeredDownload = false
        }
        boundMsgID = message.msgID
        boundMessage = message
        onMediaTap = context.onMediaTap

        guard case .video(let payload) = message.messagePayload else {
            showPlaceholder()
            durationLabel.isHidden = true
            return
        }
        applyDuration(payload.videoDuration)
        updateDisplaySize(for: payload)
        loadSnapshot(payload: payload, message: message)
    }

    // MARK: - Private

    private func constructViewHierarchy() {
        addSubview(snapshotView)
        snapshotView.addSubview(playIconView)
        snapshotView.addSubview(durationLabel)
    }

    private func activateConstraints() {
        remakeSnapshotConstraints(size: CGSize(width: Self.maxSize, height: Self.maxSize))
        playIconView.snp.makeConstraints { make in
            make.center.equalToSuperview()
            make.width.height.equalTo(Self.playButtonSize)
        }
        durationLabel.snp.makeConstraints { make in
            make.trailing.bottom.equalToSuperview().inset(Self.durationChipMargin)
        }
    }

    private func remakeSnapshotConstraints(size: CGSize) {
        snapshotView.snp.remakeConstraints { make in
            make.edges.equalToSuperview()
            make.width.equalTo(size.width)
            make.height.equalTo(size.height)
        }
    }

    private func setupViewStyle() {
        snapshotView.contentMode = .scaleAspectFill
        snapshotView.clipsToBounds = true
        snapshotView.layer.cornerRadius = Self.cornerRadius
        snapshotView.isUserInteractionEnabled = true

        playIconView.contentMode = .scaleAspectFit
        if let playImage = AtomicXChatResources.image(named: "message_video_play_icon") {
            playIconView.image = playImage
        } else {
            playIconView.image = UIImage(systemName: "play.fill")
            playIconView.tintColor = .white
        }

        durationLabel.font = FontScheme.caption3Regular
        durationLabel.textColor = .white
        durationLabel.backgroundColor = UIColor(white: 0, alpha: Self.durationChipBackgroundAlpha)
        durationLabel.textAlignment = .center
        durationLabel.layer.cornerRadius = Self.durationChipRadius
        durationLabel.clipsToBounds = true
        durationLabel.layer.masksToBounds = true

        addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(handleMediaTap)))
    }

    @objc private func handleMediaTap() {
        guard let message = boundMessage else { return }

        guard message.status != .violation else { return }
        onMediaTap?(message)
    }

    private func updateDisplaySize(for payload: VideoMessagePayload) {
        let size = Self.displaySize(width: payload.videoSnapshotWidth, height: payload.videoSnapshotHeight)
        remakeSnapshotConstraints(size: size)
    }

    private static func displaySize(width: Int, height: Int) -> CGSize {
        guard width > 0, height > 0 else {
            return CGSize(width: maxSize, height: maxSize)
        }
        let ratio = CGFloat(width) / CGFloat(height)
        let unscaledWidth: CGFloat
        let unscaledHeight: CGFloat
        if ratio > 1 {
            unscaledWidth = maxSize
            unscaledHeight = maxSize / ratio
        } else {
            unscaledHeight = maxSize
            unscaledWidth = maxSize * ratio
        }
        let finalWidth = min(max(unscaledWidth, minSize), maxSize)
        let finalHeight = min(max(unscaledHeight, minSize), maxSize)
        return CGSize(width: finalWidth, height: finalHeight)
    }

    private func applyDuration(_ seconds: Int) {
        durationLabel.isHidden = false
        durationLabel.text = Self.formatDuration(seconds)
    }

    private func loadSnapshot(payload: VideoMessagePayload, message: MessageInfo) {
        if let path = payload.videoSnapshotPath,
           !path.isEmpty,
           FileManager.default.fileExists(atPath: path),
           let image = UIImage(contentsOfFile: path) {
            snapshotView.kf.cancelDownloadTask()
            snapshotView.image = image
            snapshotView.backgroundColor = .clear
            playIconView.isHidden = false
            return
        }
        if let urlString = payload.videoSnapshotURL,
           !urlString.isEmpty,
           let url = URL(string: urlString) {
            snapshotView.backgroundColor = TUIChatKitTheme.colors.bgColorBubbleReciprocal
            snapshotView.kf.setImage(with: url)
            playIconView.isHidden = false
            return
        }
        showPlaceholder()
        triggerDownloadIfNeeded(message: message)
    }

    private func showPlaceholder() {
        snapshotView.kf.cancelDownloadTask()
        snapshotView.image = nil
        snapshotView.backgroundColor = TUIChatKitTheme.colors.bgColorBubbleReciprocal
        playIconView.isHidden = false
    }

    private func triggerDownloadIfNeeded(message: MessageInfo) {
        guard !hasTriggeredDownload else { return }
        guard message.status != .sending else { return }
        hasTriggeredDownload = true
        MessageActionStore.create(message: message).downloadMedia(quality: .thumbnail) { _ in }
    }

    private static func formatDuration(_ seconds: Int) -> String {
        return DateHelper.formatDurationSeconds(seconds)
    }
}

private final class PaddedLabel: UILabel {
    override var intrinsicContentSize: CGSize {
        let size = super.intrinsicContentSize
        return CGSize(
            width: size.width + insets.left + insets.right,
            height: size.height + insets.top + insets.bottom
        )
    }

    private let insets: UIEdgeInsets

    init(insets: UIEdgeInsets) {
        self.insets = insets
        super.init(frame: .zero)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func drawText(in rect: CGRect) {
        super.drawText(in: rect.inset(by: insets))
    }
}
