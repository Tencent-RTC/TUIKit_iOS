import Kingfisher
import UIKit
import SnapKit

struct LiveInteractionLayout {
    static let noticeSpacing: CGFloat = 4
    static let welcomeHeight: CGFloat = 28

    let commentHeight: CGFloat
    let visibleCommentHeight: CGFloat?
    let welcomeBottomOffset: CGFloat
    let welcomeTop: CGFloat
    let giftNoticeBottom: CGFloat

    init(
        topBoundary: CGFloat?, bottom: CGFloat, defaultCommentHeight: CGFloat, contentHeight: CGFloat,
        isWelcomeVisible: Bool, giftNoticeHeight: CGFloat, safeBottom: CGFloat
    ) {
        commentHeight = topBoundary.map { max(0, bottom - $0) } ?? defaultCommentHeight
        let welcomeReservation = isWelcomeVisible ? Self.welcomeHeight + Self.noticeSpacing : 0
        let giftReservation = giftNoticeHeight > 0 ? giftNoticeHeight + Self.noticeSpacing : 0
        visibleCommentHeight = topBoundary.map { max(0, bottom - $0 - welcomeReservation - giftReservation) }
        let usedHeight = min(contentHeight, visibleCommentHeight ?? commentHeight)
        welcomeBottomOffset = -(usedHeight + Self.noticeSpacing)
        welcomeTop = bottom + welcomeBottomOffset - Self.welcomeHeight
        giftNoticeBottom = min(safeBottom, bottom - Self.noticeSpacing) - usedHeight - welcomeReservation
    }
}

final class BarrageStreamView: UIView {
    static let defaultWidthRatio: CGFloat = 0.8

    struct Message: Equatable {
        let id: String
        let userName: String
        let content: String
        let level: Int
        let isHost: Bool
        let gift: LiveGiftBarrage?
        let isSystemAnnouncement: Bool

        init(
            id: String, userName: String, content: String, level: Int, isHost: Bool = false,
            gift: LiveGiftBarrage? = nil, isSystemAnnouncement: Bool = false
        ) {
            self.id = id
            self.userName = userName
            self.content = content
            self.level = level
            self.isHost = isHost
            self.gift = gift
            self.isSystemAnnouncement = isSystemAnnouncement
        }
    }

    private enum Constants {
        static let maximumMessageCount = 100
        static let bottomThreshold: CGFloat = 8
        static let topFadeHeight: CGFloat = 22
        static let rowSpacing: CGFloat = 2
        static let newMessageButtonHeight: CGFloat = 26
    }

    private enum ScrollRequest: Equatable {
        case none
        case latest(animated: Bool)

        var isAnimated: Bool { self == .latest(animated: true) }
    }

    private struct RowGeometry {
        let id: String
        let frame: CGRect
    }

    private struct ReadingAnchor {
        let id: String
        let distanceFromBottom: CGFloat
    }

    var onContentHeightChanged: ((CGFloat) -> Void)?
    var onVisibleContentHeightChanged: ((CGFloat) -> Void)?
    private(set) var contentHeight: CGFloat = 0
    var visibleHeight: CGFloat { min(bounds.height, maximumVisibleHeight ?? bounds.height) }

    private let scrollViewport = UIView()
    private let scrollView = UIScrollView()
    private let contentView = UIView()
    private let newMessageButton = UIButton(type: .system)
    private let fadeMask = CAGradientLayer()
    private var messages: [Message] = []
    private var rowsByID: [String: UIView] = [:]
    private var rowGeometry: [RowGeometry] = []
    private var lastLayoutSize = CGSize.zero
    private var maximumVisibleHeight: CGFloat?
    private var lastVisibleHeight: CGFloat = 0
    private var lastReportedContentHeight: CGFloat = -1
    private var lastReportedVisibleHeight: CGFloat = -1
    private var needsContentLayout = true
    private var pendingScroll = ScrollRequest.none
    private var isApplyingLayout = false
    private var isFollowingLatest = true
    private var isUserScrolling = false
    private var unreadCount = 0

    override init(frame: CGRect) {
        super.init(frame: frame)
        configureUI()
    }

    @available(*, unavailable) required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    // Pusher reserves notice space by cropping the top. The scroll container and its bottom stay stationary.
    func setVisibleHeight(_ height: CGFloat?) {
        let resolved = height.map { max(0, $0) }
        guard maximumVisibleHeight != resolved else { return }
        maximumVisibleHeight = resolved
        setNeedsLayout()
    }

    override func point(inside point: CGPoint, with event: UIEvent?) -> Bool {
        let height = min(bounds.height, maximumVisibleHeight ?? bounds.height)
        return CGRect(x: 0, y: bounds.height - height, width: bounds.width, height: height).contains(point)
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        guard !isApplyingLayout, bounds.width > 0 else { return }
        let widthChanged = abs(bounds.width - lastLayoutSize.width) > 0.5
        let sizeChanged = bounds.size != lastLayoutSize
        let visibleHeight = min(bounds.height, maximumVisibleHeight ?? bounds.height)
        let visibilityChanged = abs(visibleHeight - lastVisibleHeight) > 0.5
        let reflowsContent = needsContentLayout || widthChanged
        guard reflowsContent || sizeChanged || visibilityChanged || pendingScroll != .none else { return }

        isApplyingLayout = true
        defer { isApplyingLayout = false }
        let oldOffset = scrollView.contentOffset.y
        let anchor = isFollowingLatest ? nil : readingAnchor()
        let scrollRequest = pendingScroll
        let animatesScroll = scrollRequest.isAnimated && !sizeChanged && !visibilityChanged && !widthChanged
        needsContentLayout = false
        pendingScroll = .none

        if reflowsContent { layoutMessageRows(widthChanged: widthChanged) }
        scrollViewport.frame = bounds
        scrollView.frame = scrollViewport.bounds
        let scrollHeight = contentHeight + Constants.topFadeHeight
        contentView.frame = CGRect(x: 0, y: 0, width: bounds.width, height: scrollHeight)
        scrollView.contentSize = contentView.bounds.size

        applyScrollPosition(
            scrollRequest, previousOffset: oldOffset, anchor: anchor, geometryChanged: reflowsContent || sizeChanged,
            visibleHeight: visibleHeight, animated: animatesScroll)
        applyViewportMask(visibleHeight: visibleHeight)
        lastLayoutSize = bounds.size
        lastVisibleHeight = visibleHeight
        updateNewMessageButton()
        reportContentHeights(visibleHeight: visibleHeight)
    }

    private func applyScrollPosition(
        _ request: ScrollRequest, previousOffset: CGFloat, anchor: ReadingAnchor?, geometryChanged: Bool,
        visibleHeight: CGFloat, animated: Bool
    ) {
        let clippedTop = bounds.height - visibleHeight
        // Negative latest offsets bottom-align short content without adding blank scrollable space.
        let latestOffset = scrollView.contentSize.height - bounds.height
        let topInset = max(clippedTop, -latestOffset)
        scrollView.contentInset = UIEdgeInsets(top: topInset, left: 0, bottom: 0, right: 0)
        var offset = previousOffset
        if request != .none || (isFollowingLatest && geometryChanged) {
            offset = latestOffset
        } else if geometryChanged {
            if let anchor, let row = rowGeometry.first(where: { $0.id == anchor.id }) {
                offset = row.frame.maxY - anchor.distanceFromBottom - bounds.height
            } else {
                // If all previously readable rows were evicted, expose the earliest remaining message.
                offset = -topInset
            }
        }
        offset = min(latestOffset, max(-topInset, offset))
        if abs(scrollView.contentOffset.y - offset) > 0.01 {
            scrollView.setContentOffset(CGPoint(x: 0, y: offset), animated: animated)
        }
    }

    private func applyViewportMask(visibleHeight: CGFloat) {
        let clippedTop = bounds.height - visibleHeight
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        fadeMask.frame = CGRect(x: 0, y: clippedTop, width: bounds.width, height: visibleHeight)
        let fadeEnd = min(0.5, Constants.topFadeHeight / max(1, visibleHeight))
        fadeMask.locations = [0, NSNumber(value: Double(fadeEnd)), 1]
        CATransaction.commit()
    }

    func bind(_ messages: [Message]) {
        let next = Array(messages.suffix(Constants.maximumMessageCount))
        guard next != self.messages else { return }
        let previousIDs = Set(self.messages.map(\.id))
        let added = next.filter { !previousIDs.contains($0.id) }
        let wasEmpty = self.messages.isEmpty
        let hasNewHostComment = next.last.map { $0.isHost && !previousIDs.contains($0.id) } ?? false
        self.messages = next
        isHidden = next.isEmpty
        needsContentLayout = true
        if wasEmpty || isFollowingLatest || hasNewHostComment {
            isFollowingLatest = true
            pendingScroll = .latest(animated: !wasEmpty && !added.isEmpty)
            unreadCount = 0
        } else {
            unreadCount += added.count
        }
        setNeedsLayout()
    }

    func prepareForReuse() {
        messages = []
        rowsByID.values.forEach { $0.removeFromSuperview() }
        rowsByID.removeAll()
        rowGeometry.removeAll()
        contentHeight = 0
        lastLayoutSize = .zero
        lastReportedContentHeight = -1
        lastReportedVisibleHeight = -1
        needsContentLayout = true
        pendingScroll = .none
        isFollowingLatest = true
        isUserScrolling = false
        unreadCount = 0
        newMessageButton.isHidden = true
        isHidden = true
        setNeedsLayout()
    }

    private func configureUI() {
        isHidden = true
        clipsToBounds = true
        scrollViewport.clipsToBounds = true
        addSubview(scrollViewport)
        scrollView.bounces = false
        scrollView.contentInsetAdjustmentBehavior = .never
        scrollView.showsVerticalScrollIndicator = false
        scrollView.delegate = self
        scrollViewport.addSubview(scrollView)
        scrollView.addSubview(contentView)
        fadeMask.colors = [UIColor.clear.cgColor, UIColor.black.cgColor, UIColor.black.cgColor]
        fadeMask.startPoint = CGPoint(x: 0.5, y: 0)
        fadeMask.endPoint = CGPoint(x: 0.5, y: 1)
        scrollViewport.layer.mask = fadeMask

        newMessageButton.isHidden = true
        newMessageButton.setTitleColor(.white, for: .normal)
        newMessageButton.titleLabel?.font = BarrageStreamViewTypography.newMessageButtonFont
        newMessageButton.backgroundColor = MessageListStyle.unreadBackground
        newMessageButton.layer.cornerRadius = 13
        newMessageButton.layer.borderWidth = 1
        newMessageButton.layer.borderColor = MessageListStyle.unreadBorder.cgColor
        newMessageButton.layer.shadowColor = UIColor.black.cgColor
        newMessageButton.layer.shadowOpacity = 0.38
        newMessageButton.layer.shadowOffset = CGSize(width: 0, height: 5)
        newMessageButton.layer.shadowRadius = 8
        newMessageButton.contentEdgeInsets = UIEdgeInsets(top: 0, left: 10, bottom: 0, right: 10)
        newMessageButton.addTarget(self, action: #selector(handleNewMessageButton), for: .touchUpInside)
        addSubview(newMessageButton)
    }

    private func layoutMessageRows(widthChanged: Bool) {
        let validIDs = Set(messages.map(\.id))
        for id in rowsByID.keys.filter({ !validIDs.contains($0) }) {
            rowsByID.removeValue(forKey: id)?.removeFromSuperview()
        }
        var nextGeometry: [RowGeometry] = []
        var y = Constants.topFadeHeight
        for message in messages {
            let row: UIView
            if let gift = message.gift {
                if let existing = rowsByID[message.id] as? GiftBarrageRow, existing.barrage == gift {
                    row = existing
                    if widthChanged { existing.updateMaximumWidth(bounds.width) }
                } else {
                    let giftRow = GiftBarrageRow(barrage: gift, maximumWidth: bounds.width)
                    giftRow.onSizeChanged = { [weak self] in
                        self?.needsContentLayout = true
                        self?.setNeedsLayout()
                    }
                    row = giftRow
                }
            } else if let existing = rowsByID[message.id] as? LiveMessageRow, existing.message == message {
                row = existing
                if widthChanged { existing.updateMaximumWidth(bounds.width) }
            } else {
                row = LiveMessageRow(message: message, maximumWidth: bounds.width)
            }
            if rowsByID[message.id] !== row {
                rowsByID[message.id]?.removeFromSuperview()
                rowsByID[message.id] = row
                contentView.addSubview(row)
            }
            let size = row.intrinsicContentSize
            let frame = CGRect(x: 0, y: y, width: min(bounds.width, max(0, size.width)), height: max(0, size.height))
            row.frame = frame
            nextGeometry.append(RowGeometry(id: message.id, frame: frame))
            y = frame.maxY + Constants.rowSpacing
        }
        rowGeometry = nextGeometry
        contentHeight = nextGeometry.last.map { $0.frame.maxY - Constants.topFadeHeight } ?? 0
    }

    private func readingAnchor() -> ReadingAnchor? {
        let visibleBottom = scrollView.contentOffset.y + lastLayoutSize.height
        let visibleTop = visibleBottom - lastVisibleHeight
        // Prefer a visible row that survives the 100-message trim; fall back to the nearest surviving row.
        let retainedIDs = Set(messages.map(\.id))
        let retainedRows = rowGeometry.filter { retainedIDs.contains($0.id) }
        let row =
            retainedRows.reversed().first { $0.frame.minY < visibleBottom && $0.frame.maxY > visibleTop }
            ?? retainedRows.first { $0.frame.maxY > visibleTop } ?? retainedRows.last
        return row.map { ReadingAnchor(id: $0.id, distanceFromBottom: $0.frame.maxY - visibleBottom) }
    }

    private func reportContentHeights(visibleHeight: CGFloat) {
        if abs(contentHeight - lastReportedContentHeight) > 0.5 {
            lastReportedContentHeight = contentHeight
            onContentHeightChanged?(contentHeight)
        }
        let usedHeight = min(visibleHeight, contentHeight)
        if abs(usedHeight - lastReportedVisibleHeight) > 0.5 {
            lastReportedVisibleHeight = usedHeight
            onVisibleContentHeightChanged?(usedHeight)
        }
    }

    private func updateNewMessageButton() {
        newMessageButton.isHidden = unreadCount == 0 || lastVisibleHeight < Constants.newMessageButtonHeight
        newMessageButton.setTitle(
            LiveKitResources.localizedFormat("tuilivekit.pusher.living.new_messages", unreadCount), for: .normal)
        newMessageButton.frame = CGRect(
            x: 0, y: bounds.height - Constants.newMessageButtonHeight,
            width: ceil(newMessageButton.intrinsicContentSize.width), height: Constants.newMessageButtonHeight)
    }

    @objc private func handleNewMessageButton() {
        isUserScrolling = false
        isFollowingLatest = true
        unreadCount = 0
        pendingScroll = .latest(animated: true)
        updateNewMessageButton()
        setNeedsLayout()
    }
}

extension BarrageStreamView: UIScrollViewDelegate {
    func scrollViewWillBeginDragging(_ scrollView: UIScrollView) {
        isUserScrolling = true
        pendingScroll = .none
    }

    func scrollViewDidScroll(_ scrollView: UIScrollView) {
        guard !isApplyingLayout, isUserScrolling else { return }
        updateFollowingState()
    }

    func scrollViewDidEndDragging(_ scrollView: UIScrollView, willDecelerate decelerate: Bool) {
        guard isUserScrolling else { return }
        updateFollowingState()
        if !decelerate { isUserScrolling = false }
    }

    func scrollViewDidEndDecelerating(_ scrollView: UIScrollView) {
        guard isUserScrolling else { return }
        updateFollowingState()
        isUserScrolling = false
    }

    private func updateFollowingState() {
        isFollowingLatest =
            scrollView.contentSize.height - scrollView.bounds.height - scrollView.contentOffset.y
            <= Constants.bottomThreshold
        if isFollowingLatest {
            unreadCount = 0
            updateNewMessageButton()
        }
    }
}

private final class LiveMessageRow: UIView {
    private static let messageFont = LiveCommentRowStyle.font
    private static let contentCharacterLimit = 200

    let message: BarrageStreamView.Message
    private let messageLabel = UILabel()
    private var rowSize = CGSize.zero
    private let verticalInset = LiveCommentRowStyle.verticalInset
    private let horizontalInset = LiveCommentRowStyle.horizontalInset

    init(message: BarrageStreamView.Message, maximumWidth: CGFloat) {
        self.message = message
        super.init(frame: .zero)
        messageLabel.numberOfLines = 0
        messageLabel.lineBreakMode = .byCharWrapping
        messageLabel.accessibilityLabel =
            message.isSystemAnnouncement
            ? message.content : "\(message.userName)：\(Self.displayContent(message.content))"
        measure(maximumWidth: maximumWidth)
        configureUI()
    }

    func updateMaximumWidth(_ width: CGFloat) {
        measure(maximumWidth: width)
        messageLabel.snp.updateConstraints { make in make.top.bottom.equalToSuperview().inset(verticalInset) }
        invalidateIntrinsicContentSize()
    }

    private func measure(maximumWidth: CGFloat) {
        let text = Self.makeText(for: message)
        messageLabel.attributedText = text
        let textWidth = min(max(1, maximumWidth - horizontalInset * 2), ceil(text.size().width))
        let textHeight = ceil(
            messageLabel.sizeThatFits(CGSize(width: max(1, textWidth), height: .greatestFiniteMagnitude)).height)
        rowSize = CGSize(width: textWidth + horizontalInset * 2, height: max(21, textHeight + verticalInset * 2))
    }

    @available(*, unavailable) required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    private func configureUI() {
        backgroundColor = LiveCommentRowStyle.background
        layer.cornerRadius = LiveCommentRowStyle.cornerRadius

        addSubview(messageLabel)

        messageLabel.snp.makeConstraints { make in
            make.leading.trailing.equalToSuperview().inset(horizontalInset)
            make.top.bottom.equalToSuperview().inset(verticalInset)
        }
    }

    override var intrinsicContentSize: CGSize { rowSize }

    private static func makeText(for message: BarrageStreamView.Message) -> NSAttributedString {
        if message.isSystemAnnouncement {
            let paragraphStyle = NSMutableParagraphStyle()
            paragraphStyle.lineBreakMode = .byCharWrapping
            return NSAttributedString(
                string: message.content,
                attributes: [
                    .font: messageFont, .foregroundColor: LiveTheme.Color.nickname, .paragraphStyle: paragraphStyle,
                ])
        }
        let text = NSMutableAttributedString()
        let levelBadge = LevelBadgeView(level: message.level)
        text.append(
            badgeAttachment(
                view: levelBadge, badgeSize: levelBadge.intrinsicContentSize, trailingSpacing: 4,
                clipsToBadgeShape: true, scale: 1.2, font: messageFont, centersInLine: true))
        if message.isHost { text.append(hostBadgeAttachment()) }
        text.append(
            NSAttributedString(
                string: "\(LiveCommentRowStyle.displayUserName(message.userName))：",
                attributes: [.font: messageFont, .foregroundColor: LiveTheme.Color.nickname]))
        text.append(
            NSAttributedString(
                string: Self.displayContent(message.content),
                attributes: [.font: messageFont, .foregroundColor: MessageListStyle.messageForeground]))
        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.lineBreakMode = .byCharWrapping
        let range = NSRange(location: 0, length: text.length)
        text.addAttribute(.font, value: messageFont, range: range)
        text.addAttribute(.paragraphStyle, value: paragraphStyle, range: range)
        return text
    }

    private static func displayContent(_ raw: String) -> String {
        guard raw.count > contentCharacterLimit else { return raw }
        return String(raw.prefix(contentCharacterLimit)) + "..."
    }

    private static func hostBadgeAttachment() -> NSAttributedString {
        let title = LiveKitResources.localizedString("tuilivekit.common.host") as NSString
        let attributes: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 10, weight: .bold), .foregroundColor: UIColor.white,
        ]
        let textSize = title.size(withAttributes: attributes)
        let badgeSize = CGSize(width: max(35, ceil(textSize.width) + 10), height: 18)
        let format = UIGraphicsImageRendererFormat.default()
        format.opaque = false
        let pixel = 1 / format.scale
        let imageSize = CGSize(width: badgeSize.width + 4, height: badgeSize.height)
        let image = UIGraphicsImageRenderer(size: imageSize, format: format).image { _ in
            // Draw at the final pixel scale; keep the outline inside the image to avoid clipped edges.
            let outline = UIBezierPath(
                roundedRect: CGRect(origin: .zero, size: badgeSize).insetBy(dx: pixel / 2, dy: pixel / 2),
                cornerRadius: (badgeSize.height - pixel) / 2)
            MessageListStyle.hostBadgeBackground.setFill()
            outline.fill()
            MessageListStyle.hostBadgeBorder.setStroke()
            outline.lineWidth = pixel
            outline.stroke()
            let origin = CGPoint(
                x: (((badgeSize.width - textSize.width) / 2) * format.scale).rounded() / format.scale,
                y: (((badgeSize.height - textSize.height) / 2) * format.scale).rounded() / format.scale)
            title.draw(at: origin, withAttributes: attributes)
        }
        let attachment = NSTextAttachment()
        attachment.image = image
        attachment.bounds = CGRect(
            x: 0, y: (messageFont.ascender + messageFont.descender - badgeSize.height) / 2, width: imageSize.width,
            height: imageSize.height)
        return NSAttributedString(attachment: attachment)
    }

    fileprivate static func badgeAttachment(
        view: UIView, badgeSize: CGSize, trailingSpacing: CGFloat, clipsToBadgeShape: Bool = false, scale: CGFloat = 1,
        font: UIFont = LiveCommentRowStyle.font, centersInLine: Bool = false
    ) -> NSAttributedString {
        let scaledBadgeSize = CGSize(width: badgeSize.width * scale, height: badgeSize.height * scale)
        let imageSize = CGSize(width: scaledBadgeSize.width + trailingSpacing, height: scaledBadgeSize.height)
        view.bounds = CGRect(origin: .zero, size: badgeSize)
        view.layoutIfNeeded()
        let format = UIGraphicsImageRendererFormat.default()
        format.opaque = false
        let borderWidth = view.layer.borderWidth
        let borderColor = view.layer.borderColor
        let shadowOpacity = view.layer.shadowOpacity
        if clipsToBadgeShape {
            // Inline images have no room for an outer glow. Draw the thin border
            // as an antialiased path instead of rasterizing CALayer's border.
            view.layer.shadowOpacity = 0
            view.layer.borderWidth = 0
        }
        defer {
            view.layer.shadowOpacity = shadowOpacity
            view.layer.borderWidth = borderWidth
        }
        let image = UIGraphicsImageRenderer(size: imageSize, format: format).image { context in
            context.cgContext.saveGState()
            context.cgContext.scaleBy(x: scale, y: scale)
            if clipsToBadgeShape {
                UIBezierPath(roundedRect: view.bounds, cornerRadius: badgeSize.height / 2).addClip()
            }
            view.layer.render(in: context.cgContext)
            if clipsToBadgeShape, borderWidth > 0, let borderColor {
                let border = UIBezierPath(
                    roundedRect: view.bounds.insetBy(dx: borderWidth / 2, dy: borderWidth / 2),
                    cornerRadius: (badgeSize.height - borderWidth) / 2)
                UIColor(cgColor: borderColor).setStroke()
                border.lineWidth = borderWidth
                border.stroke()
            }
            context.cgContext.restoreGState()
        }
        let attachment = NSTextAttachment()
        attachment.image = image
        let textCenter = centersInLine ? font.ascender + font.descender : font.capHeight
        let verticalOffset = (textCenter - scaledBadgeSize.height) / 2
        attachment.bounds = CGRect(x: 0, y: verticalOffset, width: imageSize.width, height: imageSize.height)
        return NSAttributedString(attachment: attachment)
    }
}

// Styles owned by this component or feature. Values preserve the existing design.
enum LiveCommentRowStyle {
    static let background: UIColor = LiveTheme.Color.controlBase.withAlphaComponent(0.34)
    static let font: UIFont = UIFont.systemFont(ofSize: 15, weight: .semibold)
    static let cornerRadius: CGFloat = 9
    static let verticalInset: CGFloat = 3
    static let horizontalInset: CGFloat = 6
    static let horizontalInsets: CGFloat = horizontalInset * 2

    static func displayUserName(_ raw: String) -> String {
        let name = raw.components(separatedBy: .newlines).joined(separator: " ")
        return name.count > 20 ? String(name.prefix(20)) + "…" : name
    }
}

private enum MessageListStyle {
    static let unreadBackground: UIColor = LiveTheme.Color.overlayBase.withAlphaComponent(0.96)
    static let unreadBorder: UIColor = UIColor(red: 0.61, green: 0.93, blue: 1, alpha: 0.34)
    static let messageForeground: UIColor = UIColor.white.withAlphaComponent(0.94)
    static let hostBadgeBackground: UIColor = UIColor(red: 0.196, green: 0.4, blue: 0.643, alpha: 1)
    static let hostBadgeBorder: UIColor = UIColor(red: 0.61, green: 0.93, blue: 1, alpha: 0.49)
}

private enum BarrageStreamViewTypography {
    static let newMessageButtonFont: UIFont = UIFont.systemFont(ofSize: 11, weight: .semibold)
}

final class GiftBarrageRow: UIView {
    let barrage: LiveGiftBarrage
    var onSizeChanged: (() -> Void)?

    private let messageLabel = UILabel()
    private let giftImageView = UIImageView()
    private var maximumWidth: CGFloat
    private var rowSize = CGSize.zero
    private var showsGiftImage: Bool
    private let levelAttachment: NSAttributedString

    init(barrage: LiveGiftBarrage, maximumWidth: CGFloat) {
        self.barrage = barrage
        self.maximumWidth = maximumWidth
        showsGiftImage = !barrage.giftIconURL.isEmpty
        let badge = LevelBadgeView(level: barrage.senderLevel)
        levelAttachment = LiveMessageRow.badgeAttachment(
            view: badge, badgeSize: badge.intrinsicContentSize, trailingSpacing: 4, clipsToBadgeShape: true, scale: 1.2,
            font: LiveCommentRowStyle.font, centersInLine: true)
        super.init(frame: .zero)
        configureUI()
        loadImage()
    }

    @available(*, unavailable) required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    deinit { Task { @MainActor [giftImageView] in giftImageView.kf.cancelDownloadTask() } }

    override var intrinsicContentSize: CGSize { rowSize }

    func updateMaximumWidth(_ width: CGFloat) {
        guard maximumWidth != width else { return }
        maximumWidth = width
        updateTextAndSize()
    }

    private var senderName: String {
        let name = barrage.senderName.isEmpty ? barrage.senderID : barrage.senderName
        return name.isEmpty ? LiveKitResources.localizedString("tuilivekit.common.viewer") : name
    }

    private func configureUI() {
        backgroundColor = LiveCommentRowStyle.background
        layer.cornerRadius = LiveCommentRowStyle.cornerRadius
        clipsToBounds = true
        messageLabel.numberOfLines = 0
        messageLabel.lineBreakMode = .byCharWrapping
        addSubview(messageLabel)
        measure()
        messageLabel.snp.makeConstraints { make in
            make.leading.trailing.equalToSuperview().inset(LiveCommentRowStyle.horizontalInset)
            make.top.bottom.equalToSuperview().inset(LiveCommentRowStyle.verticalInset)
        }
        accessibilityLabel =
            "\(senderName) \(LiveKitResources.localizedString("tuilivekit.common.gift.sent")) \(barrage.giftName) ×\(barrage.count)"
    }

    private func measure() {
        let text = NSMutableAttributedString(attributedString: levelAttachment)
        text.addAttribute(.font, value: LiveCommentRowStyle.font, range: NSRange(location: 0, length: text.length))
        func append(_ value: String, color: UIColor, font: UIFont = LiveCommentRowStyle.font) {
            text.append(NSAttributedString(string: value, attributes: [.font: font, .foregroundColor: color]))
        }
        append(LiveCommentRowStyle.displayUserName(senderName), color: LiveTheme.Color.nickname)
        if barrage.receiverName.isEmpty {
            append(" " + LiveKitResources.localizedString("tuilivekit.common.gift.sent") + " ", color: GiftBarrageStyle.actionForeground)
        } else {
            append(" " + LiveKitResources.localizedString("tuilivekit.common.gift.sent_to") + " ", color: GiftBarrageStyle.actionForeground)
            append(LiveCommentRowStyle.displayUserName(barrage.receiverName) + " ", color: LiveTheme.Color.nickname)
        }
        append(barrage.giftName + " ", color: GiftBarrageStyle.giftForeground)
        if showsGiftImage {
            let attachment = NSTextAttachment()
            attachment.image = giftImageView.image
            let font = LiveCommentRowStyle.font
            attachment.bounds = CGRect(x: 0, y: (font.ascender + font.descender - 22) / 2, width: 22, height: 22)
            text.append(NSAttributedString(attachment: attachment))
            text.addAttribute(.font, value: font, range: NSRange(location: text.length - 1, length: 1))
            append(" ", color: GiftBarrageStyle.giftForeground)
        }
        append("×\(barrage.count)", color: GiftBarrageStyle.giftForeground, font: GiftBarrageStyle.countFont)
        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.lineBreakMode = .byCharWrapping
        text.addAttribute(.paragraphStyle, value: paragraphStyle, range: NSRange(location: 0, length: text.length))
        messageLabel.attributedText = text
        let textWidth = min(max(1, maximumWidth - LiveCommentRowStyle.horizontalInsets), ceil(text.size().width))
        // Measure the entire attributed line, including the taller gift image attachment.
        let textHeight = ceil(
            messageLabel.sizeThatFits(CGSize(width: textWidth, height: .greatestFiniteMagnitude)).height)
        let contentHeight = max(showsGiftImage ? 22 : 18, textHeight)
        rowSize = CGSize(
            width: textWidth + LiveCommentRowStyle.horizontalInsets,
            height: contentHeight + LiveCommentRowStyle.verticalInset * 2)
    }

    private func updateTextAndSize() {
        let previousSize = rowSize
        measure()
        invalidateIntrinsicContentSize()
        if rowSize != previousSize { onSizeChanged?() }
    }

    private func loadImage() {
        guard showsGiftImage else { return }
        giftImageView.kf.setImage(with: URL(string: barrage.giftIconURL)) { [weak self] result in
            if case .failure(let error) = result, error.isNotCurrentTask || error.isTaskCancelled { return }
            guard let self else { return }
            self.showsGiftImage = (try? result.get().image) != nil
            self.updateTextAndSize()
        }
    }
}

// Styles owned by this component or feature. Values preserve the existing design.
private enum GiftBarrageStyle {
    static let actionForeground: UIColor = UIColor(red: 1, green: 0.957, blue: 0.812, alpha: 1)
    static let giftForeground: UIColor = UIColor(red: 1, green: 0.906, blue: 0.639, alpha: 1)
    static let countFont: UIFont = UIFont.systemFont(ofSize: 15, weight: .bold)
}
