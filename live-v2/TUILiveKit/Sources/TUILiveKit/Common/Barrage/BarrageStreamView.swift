import Kingfisher
import UIKit
import SnapKit

final class BarrageStreamView: UIView {
    static let defaultWidthRatio: CGFloat = 0.8

    var onVisibleContentHeightChanged: ((CGFloat) -> Void)?

    struct Message: Equatable {
        let id: String
        let userName: String
        let content: String
        let level: Int
        let isHost: Bool
        let gift: LiveGiftComment?

        init(
            id: String,
            userName: String,
            content: String,
            level: Int,
            isHost: Bool = false,
            gift: LiveGiftComment? = nil
        ) {
            self.id = id
            self.userName = userName
            self.content = content
            self.level = level
            self.isHost = isHost
            self.gift = gift
        }
    }

    private enum Constants {
        static let maximumMessageCount = 100
        static let bottomThreshold: CGFloat = 8
        static let topFadeHeight: CGFloat = 22
    }

    private let scrollViewport = UIView()
    private let scrollView = UIScrollView()
    private let contentView = UIView()
    private let stackView = UIStackView()
    private let newMessageButton = UIButton(type: .system)
    private let fadeMask = CAGradientLayer()
    private var messages: [Message] = []
    private var rowsByID: [String: UIView] = [:]
    private var maximumRowWidth: CGFloat = 0
    private var unreadCount = 0
    private var isFollowingLatest = true
    private var isUserScrolling = false
    private var isClampingBottom = false
    private var scrollRequest = 0
    private var lastViewportSize = CGSize.zero
    private var lastVisibleContentHeight: CGFloat = -1

    override init(frame: CGRect) {
        super.init(frame: frame)
        configureUI()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        updateRowWidth()
        let viewportChanged = scrollView.bounds.size != lastViewportSize
        lastViewportSize = scrollView.bounds.size
        fadeMask.frame = scrollViewport.bounds
        let fadeEnd = min(0.5, Constants.topFadeHeight / max(1, scrollViewport.bounds.height))
        fadeMask.locations = [0, NSNumber(value: Double(fadeEnd)), 1]
        if viewportChanged, isFollowingLatest, !messages.isEmpty {
            scheduleScrollToLatest(animated: false)
        }
        notifyVisibleContentHeightIfNeeded()
    }

    func bind(_ messages: [Message]) {
        let nextMessages = Array(messages.suffix(Constants.maximumMessageCount))
        guard nextMessages != self.messages else { return }

        let wasEmpty = self.messages.isEmpty
        let wasFollowingLatest = isFollowingLatest
        let addedCount = numberOfNewMessages(from: self.messages, to: nextMessages)
        let latestIsHost = nextMessages.last?.isHost == true
        let visibleAnchor = wasFollowingLatest ? nil : captureVisibleAnchor()
        self.messages = nextMessages
        isHidden = nextMessages.isEmpty
        synchronizeRows(with: nextMessages)
        layoutIfNeeded()
        notifyVisibleContentHeightIfNeeded()

        if wasEmpty || wasFollowingLatest || latestIsHost {
            isFollowingLatest = true
            unreadCount = 0
            scheduleScrollToLatest(animated: !wasEmpty)
        } else if addedCount > 0 {
            restoreVisibleAnchor(visibleAnchor)
            unreadCount += addedCount
        }
        updateNewMessageButton()
    }

    private func updateRowWidth() {
        guard bounds.width > 0 else { return }
        let width = max(17, bounds.width)
        guard abs(width - maximumRowWidth) > 0.5 else { return }
        maximumRowWidth = width
        let anchor = isFollowingLatest ? nil : captureVisibleAnchor()
        let wasUserScrolling = isUserScrolling
        isUserScrolling = false
        synchronizeRows(with: messages)
        for row in rowsByID.values {
            (row as? LiveMessageRow)?.updateMaximumWidth(width)
            (row as? GiftCommentRow)?.updateMaximumWidth(width)
        }
        layoutIfNeeded()
        if isFollowingLatest {
            scheduleScrollToLatest(animated: false)
        } else {
            restoreVisibleAnchor(anchor)
            isUserScrolling = wasUserScrolling
        }
        notifyVisibleContentHeightIfNeeded()
    }

    func prepareForReuse() {
        scrollRequest += 1
        messages = []
        rowsByID.removeAll()
        stackView.arrangedSubviews.forEach { row in
            stackView.removeArrangedSubview(row)
            row.removeFromSuperview()
        }
        unreadCount = 0
        isFollowingLatest = true
        isUserScrolling = false
        isClampingBottom = false
        lastVisibleContentHeight = -1
        scrollView.setContentOffset(.zero, animated: false)
        newMessageButton.isHidden = true
        isHidden = true
    }

    private func configureUI() {
        isHidden = true
        clipsToBounds = true

        scrollViewport.clipsToBounds = true
        addSubview(scrollViewport)

        scrollView.alwaysBounceVertical = false
        scrollView.bounces = true
        scrollView.contentInsetAdjustmentBehavior = .never
        scrollView.showsVerticalScrollIndicator = false
        scrollView.delegate = self
        scrollViewport.addSubview(scrollView)

        fadeMask.colors = [UIColor.clear.cgColor, UIColor.black.cgColor, UIColor.black.cgColor]
        fadeMask.startPoint = CGPoint(x: 0.5, y: 0)
        fadeMask.endPoint = CGPoint(x: 0.5, y: 1)
        scrollViewport.layer.mask = fadeMask

        scrollView.addSubview(contentView)

        stackView.axis = .vertical
        stackView.alignment = .leading
        stackView.spacing = 2
        contentView.addSubview(stackView)

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

        scrollViewport.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }
        scrollView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }
        contentView.snp.makeConstraints { make in
            make.edges.equalTo(scrollView.contentLayoutGuide)
            make.width.equalTo(scrollView.frameLayoutGuide)
            make.height.greaterThanOrEqualTo(scrollView.frameLayoutGuide)
        }
        stackView.snp.makeConstraints { make in
            make.leading.equalToSuperview()
            make.trailing.lessThanOrEqualToSuperview()
            make.top.greaterThanOrEqualToSuperview().offset(Constants.topFadeHeight)
            make.bottom.equalToSuperview()
        }
        newMessageButton.snp.makeConstraints { make in
            make.leading.bottom.equalToSuperview()
            make.height.equalTo(26)
        }
    }

    private var isNearBottom: Bool {
        scrollView.contentSize.height - scrollView.contentOffset.y - scrollView.bounds.height
            <= Constants.bottomThreshold
    }

    private func numberOfNewMessages(from previous: [Message], to next: [Message]) -> Int {
        guard !previous.isEmpty else { return 0 }
        let maximumOverlap = min(previous.count, next.count)
        for overlap in stride(from: maximumOverlap, through: 1, by: -1) {
            if previous.suffix(overlap).map(\.id).elementsEqual(next.prefix(overlap).map(\.id)) {
                return next.count - overlap
            }
        }
        return 0
    }

    private func scrollToLatest(animated: Bool) {
        guard !messages.isEmpty else { return }
        layoutIfNeeded()
        scrollView.layoutIfNeeded()
        contentView.layoutIfNeeded()
        let contentHeight = max(scrollView.contentSize.height, contentView.bounds.height)
        let offsetY = max(0, contentHeight - scrollView.bounds.height)
        scrollView.setContentOffset(CGPoint(x: 0, y: offsetY), animated: animated)
        isFollowingLatest = true
        unreadCount = 0
        updateNewMessageButton()
    }

    private func scheduleScrollToLatest(animated: Bool) {
        isUserScrolling = false
        scrollRequest += 1
        let request = scrollRequest
        DispatchQueue.main.async { [weak self] in
            guard let self, self.scrollRequest == request, self.isFollowingLatest else { return }
            self.scrollToLatest(animated: animated)
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.32) { [weak self] in
            guard let self, self.scrollRequest == request, self.isFollowingLatest else { return }
            self.scrollToLatest(animated: false)
        }
    }

    private func updateNewMessageButton() {
        newMessageButton.isHidden = unreadCount == 0
        newMessageButton.setTitle(
            LiveKitResources.localizedFormat("tuilivekit.pusher.living.new_messages", unreadCount),
            for: .normal
        )
    }

    @objc private func handleNewMessageButton() {
        isFollowingLatest = true
        unreadCount = 0
        updateNewMessageButton()
        scheduleScrollToLatest(animated: true)
    }

    private func synchronizeRows(with messages: [Message]) {
        guard maximumRowWidth > 0 else { return }
        let validIDs = Set(messages.map(\.id))
        rowsByID.keys.filter { !validIDs.contains($0) }.forEach { id in
            rowsByID.removeValue(forKey: id)?.removeFromSuperview()
        }

        stackView.arrangedSubviews.forEach { stackView.removeArrangedSubview($0) }
        messages.forEach { message in
            let row: UIView
            if let gift = message.gift {
                if let existing = rowsByID[message.id] as? GiftCommentRow,
                   existing.comment == gift {
                    row = existing
                } else {
                    rowsByID[message.id]?.removeFromSuperview()
                    let giftRow = GiftCommentRow(comment: gift, maximumWidth: maximumRowWidth)
                    giftRow.onSizeChanged = { [weak self] in
                        guard let self else { return }
                        self.setNeedsLayout()
                        if self.isFollowingLatest {
                            self.scheduleScrollToLatest(animated: false)
                        }
                    }
                    row = giftRow
                    rowsByID[message.id] = row
                }
            } else if let existing = rowsByID[message.id] as? LiveMessageRow,
                      existing.message == message {
                row = existing
            } else {
                rowsByID[message.id]?.removeFromSuperview()
                row = LiveMessageRow(message: message, maximumWidth: maximumRowWidth)
                rowsByID[message.id] = row
            }
            stackView.addArrangedSubview(row)
        }
    }

    private func notifyVisibleContentHeightIfNeeded() {
        let rows = stackView.arrangedSubviews
        let rowsHeight = rows.reduce(CGFloat.zero) { partialResult, row in
            let intrinsicHeight = row.intrinsicContentSize.height
            let height = intrinsicHeight == UIView.noIntrinsicMetric
                ? row.bounds.height
                : intrinsicHeight
            return partialResult + max(0, height)
        }
        let gapsHeight = CGFloat(max(0, rows.count - 1)) * stackView.spacing
        let visibleContentHeight = min(bounds.height, rowsHeight + gapsHeight)
        guard abs(visibleContentHeight - lastVisibleContentHeight) > 0.5 else { return }
        lastVisibleContentHeight = visibleContentHeight
        onVisibleContentHeightChanged?(visibleContentHeight)
    }

    private struct VisibleAnchor {
        let id: String
        let offset: CGFloat
    }

    private func captureVisibleAnchor() -> VisibleAnchor? {
        layoutIfNeeded()
        let visibleTop = scrollView.contentOffset.y
        for message in messages {
            guard let row = rowsByID[message.id] else { continue }
            let rowTop = row.convert(row.bounds, to: contentView).minY
            let rowBottom = row.convert(row.bounds, to: contentView).maxY
            if rowBottom >= visibleTop {
                return VisibleAnchor(id: message.id, offset: rowTop - visibleTop)
            }
        }
        return nil
    }

    private func restoreVisibleAnchor(_ anchor: VisibleAnchor?) {
        guard let anchor, let row = rowsByID[anchor.id] else { return }
        layoutIfNeeded()
        let rowTop = row.convert(row.bounds, to: contentView).minY
        let maximumOffset = max(0, scrollView.contentSize.height - scrollView.bounds.height)
        scrollView.contentOffset.y = min(maximumOffset, max(0, rowTop - anchor.offset))
    }
}

extension BarrageStreamView: UIScrollViewDelegate {
    func scrollViewWillBeginDragging(_ scrollView: UIScrollView) {
        scrollRequest += 1
        isUserScrolling = true
    }

    func scrollViewDidScroll(_ scrollView: UIScrollView) {
        clampBottomIfNeeded()
        guard isUserScrolling else { return }
        updateFollowingState()
    }

    func scrollViewDidEndDragging(_ scrollView: UIScrollView, willDecelerate decelerate: Bool) {
        updateFollowingState()
        if !decelerate { isUserScrolling = false }
    }

    func scrollViewDidEndDecelerating(_ scrollView: UIScrollView) {
        updateFollowingState()
        isUserScrolling = false
    }

    private func updateFollowingState() {
        isFollowingLatest = isNearBottom
        guard isFollowingLatest else { return }
        unreadCount = 0
        updateNewMessageButton()
    }

    private func clampBottomIfNeeded() {
        guard !isClampingBottom else { return }
        let maximumY = max(0, scrollView.contentSize.height - scrollView.bounds.height)
        guard scrollView.contentOffset.y > maximumY else { return }
        isClampingBottom = true
        scrollView.contentOffset.y = maximumY
        isClampingBottom = false
    }
}

private final class LiveMessageRow: UIView {
    private static let messageFont = LiveCommentRowStyle.font
    private static let lineHeight: CGFloat = 17
    private static let contentCharacterLimit = 200

    let message: BarrageStreamView.Message
    private let messageLabel = UILabel()
    private var rowSize = CGSize.zero
    private var verticalInset: CGFloat = 2

    init(message: BarrageStreamView.Message, maximumWidth: CGFloat) {
        self.message = message
        super.init(frame: .zero)
        messageLabel.numberOfLines = 0
        messageLabel.lineBreakMode = .byCharWrapping
        messageLabel.accessibilityLabel = "\(message.userName)：\(Self.displayContent(message.content))"
        measure(maximumWidth: maximumWidth)
        configureUI()
    }

    func updateMaximumWidth(_ width: CGFloat) {
        measure(maximumWidth: width)
        snp.updateConstraints { make in make.size.equalTo(rowSize) }
        messageLabel.snp.updateConstraints { make in
            make.top.bottom.equalToSuperview().inset(verticalInset)
        }
        invalidateIntrinsicContentSize()
    }

    private func measure(maximumWidth: CGFloat) {
        let text = Self.makeText(for: message)
        messageLabel.attributedText = text
        let textWidth = min(max(1, maximumWidth - LiveCommentRowStyle.horizontalInsets), ceil(text.size().width))
        let textRect = text.boundingRect(
            with: CGSize(width: max(1, textWidth), height: .greatestFiniteMagnitude),
            options: [.usesLineFragmentOrigin, .usesFontLeading],
            context: nil
        )
        let textHeight = ceil(textRect.height)
        verticalInset = textHeight > Self.lineHeight + 0.5 ? 1 : 2
        rowSize = CGSize(width: textWidth + LiveCommentRowStyle.horizontalInsets, height: max(21, textHeight + verticalInset * 2))
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func configureUI() {
        backgroundColor = LiveCommentRowStyle.background
        layer.cornerRadius = LiveCommentRowStyle.cornerRadius

        addSubview(messageLabel)

        snp.makeConstraints { make in
            make.size.equalTo(rowSize)
        }
        messageLabel.snp.makeConstraints { make in
            make.leading.trailing.equalToSuperview().inset(LiveCommentRowStyle.horizontalInset)
            make.top.bottom.equalToSuperview().inset(verticalInset)
        }
    }

    override var intrinsicContentSize: CGSize {
        rowSize
    }

    private static func makeText(for message: BarrageStreamView.Message) -> NSAttributedString {
        let text = NSMutableAttributedString()
        let levelBadge = LevelBadgeView(level: message.level)
        text.append(badgeAttachment(
            view: levelBadge,
            badgeSize: levelBadge.intrinsicContentSize,
            trailingSpacing: 4,
            clipsToBadgeShape: true
        ))
        if message.isHost {
            text.append(badgeAttachment(
                view: LiveHostBadgeView(),
                badgeSize: CGSize(width: 29, height: 15),
                trailingSpacing: 4
            ))
        }
        text.append(NSAttributedString(
            string: "\(LiveCommentRowStyle.displayUserName(message.userName))：",
            attributes: [
                .font: messageFont,
                .foregroundColor: LiveTheme.Color.nickname,
            ]
        ))
        text.append(NSAttributedString(
            string: Self.displayContent(message.content),
            attributes: [
                .font: messageFont,
                .foregroundColor: MessageListStyle.messageForeground,
            ]
        ))
        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.lineBreakMode = .byCharWrapping
        paragraphStyle.minimumLineHeight = lineHeight
        paragraphStyle.maximumLineHeight = lineHeight
        paragraphStyle.lineSpacing = 0
        text.addAttribute(
            .paragraphStyle,
            value: paragraphStyle,
            range: NSRange(location: 0, length: text.length)
        )
        return text
    }

    private static func displayContent(_ raw: String) -> String {
        guard raw.count > contentCharacterLimit else { return raw }
        return String(raw.prefix(contentCharacterLimit)) + "..."
    }

    fileprivate static func badgeAttachment(
        view: UIView,
        badgeSize: CGSize,
        trailingSpacing: CGFloat,
        clipsToBadgeShape: Bool = false
    ) -> NSAttributedString {
        let imageSize = CGSize(width: badgeSize.width + trailingSpacing, height: badgeSize.height)
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
            if clipsToBadgeShape {
                UIBezierPath(roundedRect: view.bounds, cornerRadius: badgeSize.height / 2).addClip()
            }
            view.layer.render(in: context.cgContext)
            context.cgContext.restoreGState()
            if clipsToBadgeShape, borderWidth > 0, let borderColor {
                let border = UIBezierPath(
                    roundedRect: view.bounds.insetBy(dx: borderWidth / 2, dy: borderWidth / 2),
                    cornerRadius: (badgeSize.height - borderWidth) / 2
                )
                UIColor(cgColor: borderColor).setStroke()
                border.lineWidth = borderWidth
                border.stroke()
            }
        }
        let attachment = NSTextAttachment()
        attachment.image = image
        let verticalOffset = (messageFont.capHeight - badgeSize.height) / 2
        attachment.bounds = CGRect(
            x: 0,
            y: verticalOffset,
            width: imageSize.width,
            height: imageSize.height
        )
        return NSAttributedString(attachment: attachment)
    }
}

private final class LiveHostBadgeView: UIView {
    override init(frame: CGRect) {
        super.init(frame: frame)

        backgroundColor = MessageListStyle.hostBadgeBackground
        layer.cornerRadius = 7.5
        layer.borderWidth = 0.5
        layer.borderColor = MessageListStyle.hostBadgeBorder.cgColor
        layer.shadowColor = LiveTheme.Color.brandDeepBlue.withAlphaComponent(0.26).cgColor
        layer.shadowOpacity = 1
        layer.shadowOffset = CGSize(width: 0, height: 1)
        layer.shadowRadius = 4

        let label = UILabel()
        label.text = LiveKitResources.localizedString("tuilivekit.common.host")
        label.textColor = .white
        label.font = LiveHostBadgeViewTypography.labelFont
        label.textAlignment = .center
        addSubview(label)

        label.snp.makeConstraints { make in
            make.leading.trailing.equalToSuperview()
            make.top.bottom.equalToSuperview().inset(2)
        }
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}

// Styles owned by this component or feature. Values preserve the existing design.
enum LiveCommentRowStyle {
    static let background: UIColor = LiveTheme.Color.controlBase.withAlphaComponent(0.34)
    static let font: UIFont = UIFont.systemFont(ofSize: 13, weight: .semibold)
    static let cornerRadius: CGFloat = 9
    static let horizontalInset: CGFloat = 8
    static let horizontalInsets: CGFloat = 16

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

private enum LiveHostBadgeViewTypography {
    static let labelFont: UIFont = UIFont.systemFont(ofSize: 8.5, weight: .bold)
}

final class GiftCommentRow: UIView {
    let comment: LiveGiftComment
    var onSizeChanged: (() -> Void)?

    private let messageLabel = UILabel()
    private let giftImageView = UIImageView()
    private var maximumWidth: CGFloat
    private var rowSize = CGSize.zero
    private var showsGiftImage: Bool
    private let levelAttachment: NSAttributedString

    init(comment: LiveGiftComment, maximumWidth: CGFloat) {
        self.comment = comment
        self.maximumWidth = maximumWidth
        showsGiftImage = !comment.giftIconURL.isEmpty
        let badge = LevelBadgeView(level: comment.senderLevel)
        levelAttachment = LiveMessageRow.badgeAttachment(
            view: badge,
            badgeSize: badge.intrinsicContentSize,
            trailingSpacing: 4,
            clipsToBadgeShape: true
        )
        super.init(frame: .zero)
        configureUI()
        loadImage()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    deinit {
        Task { @MainActor [giftImageView] in
            giftImageView.kf.cancelDownloadTask()
        }
    }

    override var intrinsicContentSize: CGSize { rowSize }

    func updateMaximumWidth(_ width: CGFloat) {
        guard maximumWidth != width else { return }
        maximumWidth = width
        updateTextAndSize()
    }

    private var senderName: String {
        let name = comment.senderName.isEmpty ? comment.senderID : comment.senderName
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
        snp.makeConstraints { make in make.size.equalTo(rowSize) }
        messageLabel.snp.makeConstraints { make in
            make.leading.trailing.equalToSuperview().inset(LiveCommentRowStyle.horizontalInset)
            make.top.bottom.equalToSuperview().inset(3)
        }
        accessibilityLabel = "\(senderName) \(LiveKitResources.localizedString("tuilivekit.common.gift.sent")) \(comment.giftName) ×\(comment.count)"
    }

    private func measure() {
        let text = NSMutableAttributedString(attributedString: levelAttachment)
        func append(_ value: String, color: UIColor, font: UIFont = LiveCommentRowStyle.font) {
            text.append(NSAttributedString(string: value, attributes: [.font: font, .foregroundColor: color]))
        }
        append(LiveCommentRowStyle.displayUserName(senderName), color: LiveTheme.Color.nickname)
        append(" " + LiveKitResources.localizedString("tuilivekit.common.gift.sent") + " ", color: GiftCommentStyle.actionForeground)
        append(comment.giftName + " ", color: GiftCommentStyle.giftForeground)
        if showsGiftImage {
            let attachment = NSTextAttachment()
            attachment.image = giftImageView.image
            attachment.bounds = CGRect(x: 0, y: (LiveCommentRowStyle.font.capHeight - 22) / 2, width: 22, height: 22)
            text.append(NSAttributedString(attachment: attachment))
            append(" ", color: GiftCommentStyle.giftForeground)
        }
        append("×\(comment.count)", color: GiftCommentStyle.giftForeground, font: GiftCommentStyle.countFont)
        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.lineBreakMode = .byCharWrapping
        paragraphStyle.minimumLineHeight = 22
        text.addAttribute(.paragraphStyle, value: paragraphStyle, range: NSRange(location: 0, length: text.length))
        messageLabel.attributedText = text
        let textWidth = min(max(1, maximumWidth - LiveCommentRowStyle.horizontalInsets), ceil(text.size().width))
        let rect = text.boundingRect(
            with: CGSize(width: textWidth, height: .greatestFiniteMagnitude),
            options: [.usesLineFragmentOrigin, .usesFontLeading],
            context: nil
        )
        rowSize = CGSize(width: textWidth + LiveCommentRowStyle.horizontalInsets, height: max(28, ceil(rect.height) + 6))
    }

    private func updateTextAndSize() {
        let previousSize = rowSize
        measure()
        snp.updateConstraints { make in make.size.equalTo(rowSize) }
        invalidateIntrinsicContentSize()
        if rowSize != previousSize { onSizeChanged?() }
    }

    private func loadImage() {
        guard showsGiftImage else { return }
        giftImageView.kf.setImage(with: URL(string: comment.giftIconURL)) { [weak self] result in
            if case .failure(let error) = result, error.isNotCurrentTask || error.isTaskCancelled { return }
            guard let self else { return }
            self.showsGiftImage = (try? result.get().image) != nil
            self.updateTextAndSize()
        }
    }
}

// Styles owned by this component or feature. Values preserve the existing design.
private enum GiftCommentStyle {
    static let actionForeground: UIColor = UIColor(red: 1, green: 0.957, blue: 0.812, alpha: 1)
    static let giftForeground: UIColor = UIColor(red: 1, green: 0.906, blue: 0.639, alpha: 1)
    static let countFont: UIFont = UIFont.systemFont(ofSize: 13, weight: .bold)
}
