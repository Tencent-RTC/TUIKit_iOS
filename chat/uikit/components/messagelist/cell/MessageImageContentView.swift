import UIKit
import SnapKit
import Kingfisher
import AtomicXCore

final class MessageImageContentView: UIView, MessageContentView {
    private static let maxSize: CGFloat = 200

    private static let minSize: CGFloat = 80

    private static let cornerRadius = CGFloat(RadiusScheme.alertRadius)

    private static let placeholderIconSize: CGFloat = 40

    private var boundMsgID: String?

    private var hasTriggeredDownload = false

    private var boundMessage: MessageInfo?

    private var onMediaTap: ((MessageInfo) -> Void)?

    private let imageView = UIImageView()

    private let placeholderIcon = UIImageView()

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

        guard case .image(let payload) = message.messagePayload else {
            showPlaceholder()
            return
        }
        updateDisplaySize(for: payload)
        loadThumbnail(payload: payload, message: message)
    }

    // MARK: - Private

    private func constructViewHierarchy() {
        addSubview(imageView)
        imageView.addSubview(placeholderIcon)
    }

    private func activateConstraints() {
        remakeImageConstraints(size: CGSize(width: Self.maxSize, height: Self.maxSize))
        placeholderIcon.snp.makeConstraints { make in
            make.center.equalToSuperview()
            make.width.height.equalTo(Self.placeholderIconSize)
        }
    }

    private func remakeImageConstraints(size: CGSize) {
        imageView.snp.remakeConstraints { make in
            make.edges.equalToSuperview()
            make.width.equalTo(size.width)
            make.height.equalTo(size.height)
        }
    }

    private func setupViewStyle() {
        imageView.contentMode = .scaleAspectFill
        imageView.clipsToBounds = true
        imageView.layer.cornerRadius = Self.cornerRadius
        placeholderIcon.contentMode = .scaleAspectFit
        placeholderIcon.image = UIImage(systemName: "photo")
        placeholderIcon.tintColor = TUIChatKitTheme.colors.textColorSecondary
        isUserInteractionEnabled = true
        addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(handleMediaTap)))
    }

    @objc private func handleMediaTap() {
        guard let message = boundMessage else { return }

        guard message.status != .violation else { return }
        onMediaTap?(message)
    }

    private func updateDisplaySize(for payload: ImageMessagePayload) {
        let size = Self.displaySize(width: payload.originalImageWidth, height: payload.originalImageHeight)
        remakeImageConstraints(size: size)
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

    private func loadThumbnail(payload: ImageMessagePayload, message: MessageInfo) {
        if let path = payload.largeImagePath ?? payload.originalImagePath,
           !path.isEmpty,
           FileManager.default.fileExists(atPath: path),
           let image = UIImage(contentsOfFile: path) {
            imageView.kf.cancelDownloadTask()
            imageView.image = image
            placeholderIcon.isHidden = true
            imageView.backgroundColor = .clear
            return
        }
        if let urlString = payload.largeImageURL ?? payload.originalImageURL ?? payload.thumbImageURL,
           !urlString.isEmpty,
           let url = URL(string: urlString) {
            placeholderIcon.isHidden = true
            imageView.backgroundColor = TUIChatKitTheme.colors.bgColorBubbleReciprocal
            imageView.kf.setImage(with: url)
            return
        }
        showPlaceholder()
        triggerDownloadIfNeeded(message: message)
    }

    private func showPlaceholder() {
        imageView.kf.cancelDownloadTask()
        imageView.image = nil
        imageView.backgroundColor = TUIChatKitTheme.colors.bgColorBubbleReciprocal
        placeholderIcon.isHidden = false
    }

    private func triggerDownloadIfNeeded(message: MessageInfo) {
        guard !hasTriggeredDownload else { return }
        hasTriggeredDownload = true
        MessageActionStore.create(message: message).downloadMedia(quality: .standard) { _ in }
    }
}
