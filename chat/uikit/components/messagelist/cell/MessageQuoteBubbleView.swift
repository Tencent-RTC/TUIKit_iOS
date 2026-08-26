import UIKit
import SnapKit
import Kingfisher
import AtomicXCore

final class MessageQuoteBubbleView: UIView {
    var onTap: (() -> Void)?

    private static let cornerRadius = CGFloat(RadiusScheme.smallRadius)

    private static let contentPadding = CGFloat(SpacingScheme.smallSpacing)

    private static let contentTextTopSpacing: CGFloat = 2

    private static let thumbnailSize: CGFloat = 36

    private static let thumbnailTopSpacing: CGFloat = 6

    private static let thumbnailCornerRadius = CGFloat(RadiusScheme.tipsRadius)

    private static let senderMaxLines = 1

    private static let contentMaxLines = 2

    private static let emojiToFontSizeRatio: CGFloat = 1.5

    private static let emojiVerticalOffsetRatio: CGFloat = -0.2

    private let senderLabel = UILabel()

    private let contentLabel = UILabel()

    private let thumbnailContainer = UIView()

    private let thumbnailView = UIImageView()

    private let videoOverlayLabel = UILabel()

    // MARK: - Init

    init() {
        super.init(frame: .zero)
        constructViewHierarchy()
        activateConstraints()
        setupViewStyle()
        bindInteraction()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    // MARK: - Bind

    func bind(quoteInfo: MessageQuoteInfo) {
        let display = MessageQuoteDisplayResolver.resolve(quoteInfo: quoteInfo)

        let senderShown = !display.senderName.isEmpty
        senderLabel.isHidden = !senderShown
        senderLabel.text = senderShown
            ? String(format: LocalizedChatString("QuoteSenderFormat"), display.senderName)
            : nil

        let thumbnailShown = display.thumbnail != nil
        if let thumbnail = display.thumbnail {
            contentLabel.isHidden = true
            contentLabel.text = nil
            bindThumbnail(thumbnail)
        } else {
            thumbnailContainer.isHidden = true
            thumbnailView.kf.cancelDownloadTask()
            thumbnailView.image = nil
            contentLabel.isHidden = false
            bindContentText(display)
        }
        relayoutContent(senderShown: senderShown, thumbnailShown: thumbnailShown)
    }

    // MARK: - Private

    private func constructViewHierarchy() {
        addSubview(senderLabel)
        addSubview(contentLabel)
        addSubview(thumbnailContainer)
        thumbnailContainer.addSubview(thumbnailView)
        thumbnailContainer.addSubview(videoOverlayLabel)
    }

    private func activateConstraints() {
        senderLabel.snp.makeConstraints { make in
            make.top.equalToSuperview().offset(Self.contentPadding)
            make.leading.equalToSuperview().offset(Self.contentPadding)
            make.trailing.equalToSuperview().offset(-Self.contentPadding)
        }
        thumbnailView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }
        videoOverlayLabel.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }
    }

    private func setupViewStyle() {
        let colors = ChatUIKitTheme.colors
        backgroundColor = colors.bgColorBubbleReciprocal
        layer.cornerRadius = Self.cornerRadius
        clipsToBounds = true

        senderLabel.font = FontScheme.caption3Bold
        senderLabel.textColor = colors.textColorSecondary
        senderLabel.numberOfLines = Self.senderMaxLines
        senderLabel.lineBreakMode = .byTruncatingTail

        contentLabel.font = FontScheme.caption3Regular
        contentLabel.textColor = colors.textColorSecondary
        contentLabel.numberOfLines = Self.contentMaxLines
        contentLabel.lineBreakMode = .byTruncatingTail

        thumbnailContainer.backgroundColor = colors.bgColorBubbleReciprocal
        thumbnailContainer.layer.cornerRadius = Self.thumbnailCornerRadius
        thumbnailContainer.clipsToBounds = true

        thumbnailView.contentMode = .scaleAspectFill
        thumbnailView.clipsToBounds = true

        videoOverlayLabel.text = "▶"
        videoOverlayLabel.textAlignment = .center
        videoOverlayLabel.font = FontScheme.caption1Regular
        videoOverlayLabel.textColor = colors.textColorAntiPrimary
    }

    private func bindInteraction() {
        isUserInteractionEnabled = true
        addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(handleTap)))
    }

    @objc private func handleTap() {
        onTap?()
    }

    private func relayoutContent(senderShown: Bool, thumbnailShown: Bool) {
        contentLabel.snp.remakeConstraints { make in
            if senderShown {
                make.top.equalTo(senderLabel.snp.bottom).offset(Self.contentTextTopSpacing)
            } else {
                make.top.equalToSuperview().offset(Self.contentPadding)
            }
            make.leading.equalToSuperview().offset(Self.contentPadding)
            make.trailing.equalToSuperview().offset(-Self.contentPadding)
            if !thumbnailShown {
                make.bottom.equalToSuperview().offset(-Self.contentPadding)
            }
        }
        if thumbnailShown {
            thumbnailContainer.snp.remakeConstraints { make in
                if senderShown {
                    make.top.equalTo(senderLabel.snp.bottom).offset(Self.thumbnailTopSpacing)
                } else {
                    make.top.equalToSuperview().offset(Self.contentPadding)
                }
                make.leading.equalToSuperview().offset(Self.contentPadding)
                make.trailing.lessThanOrEqualToSuperview().offset(-Self.contentPadding)
                make.width.height.equalTo(Self.thumbnailSize)
                make.bottom.equalToSuperview().offset(-Self.contentPadding)
            }
        } else {
            thumbnailContainer.snp.removeConstraints()
        }
    }

    private func bindContentText(_ display: MessageQuoteDisplayData) {
        if display.shouldRenderEmoji {
            contentLabel.attributedText = emojiAttributedString(from: display.contentText)
        } else {
            contentLabel.text = display.contentText
        }
    }

    private func emojiAttributedString(from text: String) -> NSAttributedString {
        let source = EmojiManager.shared.createAttributedStringFromEmojiCodes(from: text)
        let mutable = NSMutableAttributedString(attributedString: source)
        let fullRange = NSRange(location: 0, length: mutable.length)
        let emojiSize = FontScheme.caption3Regular.pointSize * Self.emojiToFontSizeRatio
        let colors = ChatUIKitTheme.colors
        mutable.enumerateAttribute(.attachment, in: fullRange, options: []) { value, range, _ in
            if let attachment = value as? NSTextAttachment {
                attachment.bounds = CGRect(
                    x: 0,
                    y: emojiSize * Self.emojiVerticalOffsetRatio,
                    width: emojiSize,
                    height: emojiSize
                )
            } else {
                mutable.addAttribute(.font, value: FontScheme.caption3Regular, range: range)
                mutable.addAttribute(.foregroundColor, value: colors.textColorSecondary, range: range)
            }
        }
        return mutable
    }

    private func bindThumbnail(_ thumbnail: MessageQuoteThumbnail) {
        thumbnailContainer.isHidden = false
        videoOverlayLabel.isHidden = !thumbnail.isVideo

        if !thumbnail.path.hasPrefix("http"),
           FileManager.default.fileExists(atPath: thumbnail.path),
           let image = UIImage(contentsOfFile: thumbnail.path) {
            thumbnailView.kf.cancelDownloadTask()
            thumbnailView.image = image
            return
        }
        if let url = URL(string: thumbnail.path) {
            thumbnailView.kf.setImage(with: url)
        }
    }
}

// MARK: - Display Policy (对齐 Android MessageQuoteDisplayPolicy)

struct MessageQuoteDisplayData {
    let senderName: String
    let contentText: String
    var thumbnail: MessageQuoteThumbnail? = nil
    var isStatusText: Bool = false
    var isPartial: Bool = false
    var shouldRenderEmoji: Bool = false
}

struct MessageQuoteThumbnail {
    let path: String
    let isVideo: Bool
}

enum MessageQuoteDisplayResolver {

    private static let secondsPerMinute = 60

    static func resolve(quoteInfo: MessageQuoteInfo) -> MessageQuoteDisplayData {
        let senderName = resolveSenderName(quoteInfo)
        let payload = quoteInfo.messagePayload

        if quoteInfo.status == .revoked {
            return MessageQuoteDisplayData(
                senderName: senderName,
                contentText: LocalizedChatString("ReferenceOriginMessageRevoke"),
                isStatusText: true
            )
        }

        if payload == nil {
            return MessageQuoteDisplayData(
                senderName: senderName,
                contentText: "...",
                isPartial: true
            )
        }

        if quoteInfo.status == .deleted {
            return MessageQuoteDisplayData(
                senderName: senderName,
                contentText: LocalizedChatString("ReferenceOriginMessageDeleted"),
                isStatusText: true
            )
        }

        return MessageQuoteDisplayData(
            senderName: senderName,
            contentText: resolveContentText(payload!),
            thumbnail: resolveThumbnail(payload!),
            shouldRenderEmoji: isTextPayload(payload!)
        )
    }

    private static func resolveSenderName(_ quoteInfo: MessageQuoteInfo) -> String {
        let sender = quoteInfo.sender
        if let remark = sender.friendRemark, !remark.isEmpty { return remark }
        if let nameCard = sender.nameCard, !nameCard.isEmpty { return nameCard }
        if let nickname = sender.nickname, !nickname.isEmpty { return nickname }
        return sender.userID
    }

    private static func resolveContentText(_ payload: MessagePayload) -> String {
        switch payload {
        case .text(let text):
            return text.text
        case .image:
            return LocalizedChatString("MessageTypeImage")
        case .video:
            return LocalizedChatString("MessageTypeVideo")
        case .audio(let audio):
            return resolveAudioText(audio)
        case .file(let file):
            if let name = file.fileName, !name.isEmpty { return name }
            return LocalizedChatString("MessageTypeFile")
        case .face:
            return LocalizedChatString("MessageTypeAnimateEmoji")
        case .custom(let custom):
            if let desc = custom.description, !desc.isEmpty { return desc }
            return LocalizedChatString("MessageTipsUnsupportCustomMessage")
        case .merged(let merged):
            if !merged.title.isEmpty { return merged.title }
            return LocalizedChatString("MessageTypeMergedHistory")
        default:
            return LocalizedChatString("MessageTipsUnsupportCustomMessage")
        }
    }

    private static func resolveAudioText(_ payload: AudioMessagePayload) -> String {
        let voiceLabel = LocalizedChatString("MessageTypeVoice")
        let duration = payload.audioDuration
        guard duration > 0 else { return voiceLabel }
        let minutes = duration / secondsPerMinute
        let seconds = duration % secondsPerMinute
        let durationText = minutes > 0
            ? String(format: "%d:%02d\"", minutes, seconds)
            : "\(seconds)\""
        return "\(voiceLabel) \(durationText)"
    }

    private static func resolveThumbnail(_ payload: MessagePayload) -> MessageQuoteThumbnail? {
        switch payload {
        case .image(let image):
            let path = firstNonEmpty(image.thumbImagePath, image.thumbImageURL,
                                     image.originalImagePath, image.originalImageURL)
            return path.map { MessageQuoteThumbnail(path: $0, isVideo: false) }
        case .video(let video):
            let path = firstNonEmpty(video.videoSnapshotPath, video.videoSnapshotURL)
            return path.map { MessageQuoteThumbnail(path: $0, isVideo: true) }
        default:
            return nil
        }
    }

    private static func isTextPayload(_ payload: MessagePayload) -> Bool {
        if case .text = payload { return true }
        return false
    }

    private static func firstNonEmpty(_ candidates: String?...) -> String? {
        for candidate in candidates {
            if let value = candidate, !value.isEmpty { return value }
        }
        return nil
    }
}
