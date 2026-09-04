import UIKit
import SnapKit
import AtomicXCore

final class MessageBaseCell: UITableViewCell {
    var onAvatarTap: ((MessageInfo) -> Void)?

    var onAvatarLongPress: ((MessageInfo) -> Void)?

    var onResendRequested: ((MessageInfo) -> Void)?

    var onQuotePreviewTap: ((MessageInfo) -> Void)?

    var onBubbleLongPress: ((MessageInfo, CGRect) -> Void)?

    var onReactionBarTap: ((MessageInfo) -> Void)?

    var onAuxiliaryTextLongPress: ((MessageInfo, String, CGRect) -> Void)?

    var onReadReceiptTap: ((MessageInfo) -> Void)?

    internal let reactionBar = MessageReactionBarView()

    private static let avatarSize: CGFloat = 40

    private static let checkboxSize: CGFloat = 22

    private static let checkboxMarginEnd = CGFloat(SpacingScheme.iconIconSpacing)

    private static let statusIconSize: CGFloat = 14

    private static let sendingIndicatorScale: CGFloat = 0.6

    private static let statusSlotGap = CGFloat(SpacingScheme.smallSpacing)

    private static let timeVerticalMargin = CGFloat(SpacingScheme.contentSpacing)

    private static let nicknameBottomMargin = CGFloat(SpacingScheme.iconTextSpacing)

    private static let bubbleMinHeight: CGFloat = 40

    private static let reactionBarMaxWidth: CGFloat = UIScreen.main.bounds.width * 0.72

    private static let reactionBarTopInset: CGFloat = 2

    private static let reactionBarBottomInset: CGFloat = 6

    private static let reactionBarHorizontalInset = CGFloat(SpacingScheme.smallSpacing)

    private static let reactionBarCardTopInset = CGFloat(SpacingScheme.iconTextSpacing)

    private static let reactionBarCardBottomInset: CGFloat = 10

    private static let reactionBarCardHorizontalInset = CGFloat(SpacingScheme.iconIconSpacing)

    private static let reactionBarMediaTopInset: CGFloat = 6

    private static let mediaBubblePadding = CGFloat(SpacingScheme.iconTextSpacing)

    private static let mergedCardBorderWidth: CGFloat = 1

    private static let auxiliaryTextTopInset: CGFloat = 6

    private static let auxiliaryAudioTopInset: CGFloat = 10

    private static let violationTopInset: CGFloat = 2

    private static let quoteTopSpacing = CGFloat(SpacingScheme.iconTextSpacing)

    private static let quoteMaxWidth: CGFloat = UIScreen.main.bounds.width * 0.72


    private static let nicknameDetailTimeSpacing = CGFloat(SpacingScheme.iconTextSpacing)

    private var message: MessageInfo?

    private var contentKind: MessageContentKind?

    private var contentView0: MessageContentView?

    private var lastContext: MessageContentContext?

    private var normalBubbleColor: UIColor?

    private var activeBubbleAppearance: MessageBubbleAppearance?

    private var bubbleMinWidthConstraint: NSLayoutConstraint?

    private var bubbleMinHeightConstraint: NSLayoutConstraint?

    private var reactionBarMinWidthConstraint: Constraint?

    private var highlightGeneration = 0

    private let timeLabel = UILabel()

    private let bodyContainer = UIView()

    private let checkboxView = UIImageView()

    private let avatarView = ChatAvatarView()

    private let nicknameLabel = UILabel()

    private let detailTimeLabel = UILabel()

    private let statusImageView = UIImageView()

    private let sendingIndicator = UIActivityIndicatorView(style: .medium)

    private let bubbleColumn = UIView()

    private let quoteView = MessageQuoteBubbleView()

    private let contentContainer = MessageBubbleContainerView()

    private let highlightOverlayView = UIView()

    private let readReceiptLabel = UILabel()

    private lazy var readReceiptTapGesture = UITapGestureRecognizer(target: self, action: #selector(handleReadReceiptTap))

    private let auxiliaryTextBubbleView = MessageAuxiliaryTextBubbleView()

    private let violationLabel = UILabel()

    private var isMediaPayload: Bool {
        guard let payload = message?.messagePayload else { return false }
        switch payload {
        case .image, .video:
            return true
        default:
            return false
        }
    }

    private var isMergedPayload: Bool {
        guard let payload = message?.messagePayload else { return false }
        if case .merged = payload { return true }
        return false
    }

    private var shouldWrapMediaInBubble: Bool {
        return isMediaPayload && !reactionBar.isHidden
    }

    // MARK: - Init

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        LanguageHelper.applyLayoutDirection(to: self)
        constructViewHierarchy()
        setupViewStyle()
        bindInteraction()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    // MARK: - Configure

    func configure(message: MessageInfo,
                   contentKind: MessageContentKind,
                   timeString: String?,
                   context: MessageContentContext,
                   isMultiSelectMode: Bool,
                   isSelected: Bool,
                   auxiliaryTextState: AuxiliaryTextDisplayState = .hidden) {
        self.message = message
        self.lastContext = context
        installContentViewIfNeeded(kind: contentKind)
        contentView0?.bind(message: message, context: context)
        applyReadReceipt(message: message, context: context)
        applyQuote(message: message, isSupportQuote: context.config.isSupportQuote, isLeft: context.isLeft)

        applyTime(timeString, show: context.config.isShowTimeMessage)
        applyDetailTime(context.detailTimeText)
        applyAvatar(message: message, isLeft: context.isLeft, show: shouldShowAvatar(context: context))
        applyNickname(message: message, context: context)
        applyStatus(message: message)
        applyCheckbox(isMultiSelectMode: isMultiSelectMode, isSelected: isSelected)
        applyAuxiliaryText(message: message, state: auxiliaryTextState, isSelf: context.isSelf)
        applyReaction(message: message, context: context)
        applyViolation(message: message)

        rebuildLayout(context: context,
                      showAvatar: shouldShowAvatar(context: context),
                      showNickname: !nicknameLabel.isHidden,
                      showStatus: !statusImageView.isHidden || sendingIndicator.isAnimating || !readReceiptLabel.isHidden,
                      multiSelect: isMultiSelectMode)
    }

    func updateMultiSelectState(isMultiSelectMode: Bool, isSelected: Bool) {
        guard let context = lastContext else { return }
        applyCheckbox(isMultiSelectMode: isMultiSelectMode, isSelected: isSelected)
        rebuildLayout(context: context,
                      showAvatar: shouldShowAvatar(context: context),
                      showNickname: !nicknameLabel.isHidden,
                      showStatus: !statusImageView.isHidden || sendingIndicator.isAnimating || !readReceiptLabel.isHidden,
                      multiSelect: isMultiSelectMode)
    }

    func updateAuxiliaryTextState(state: AuxiliaryTextDisplayState) {
        guard let message = message, let context = lastContext else { return }
        applyAuxiliaryText(message: message, state: state, isSelf: context.isSelf)
        rebuildLayout(context: context,
                      showAvatar: shouldShowAvatar(context: context),
                      showNickname: !nicknameLabel.isHidden,
                      showStatus: !statusImageView.isHidden || sendingIndicator.isAnimating || !readReceiptLabel.isHidden,
                      multiSelect: false)
    }

    func updateReaction(message: MessageInfo) {
        guard let context = lastContext else { return }
        self.message = message
        applyReaction(message: message, context: context)
        rebuildLayout(context: context,
                      showAvatar: shouldShowAvatar(context: context),
                      showNickname: !nicknameLabel.isHidden,
                      showStatus: !statusImageView.isHidden || sendingIndicator.isAnimating || !readReceiptLabel.isHidden,
                      multiSelect: !checkboxView.isHidden)
    }

    // MARK: - Element Binding

    func updateMediaProgressIfNeeded(_ message: MessageInfo) {
        (contentView0 as? MessageFileContentView)?.updateProgress(message: message)
    }

    internal func playHighlightAnimation() {
        highlightGeneration += 1
        let generation = highlightGeneration
        let bubbleColor = normalBubbleColor ?? contentContainer.backgroundColor ?? .clear
        let spec = MessageBubbleStyler.highlightSpec(bubbleColor: bubbleColor, traitCollection: traitCollection)
        highlightOverlayView.layer.removeAllAnimations()
        highlightOverlayView.backgroundColor = spec.color
        highlightOverlayView.alpha = 0
        let segmentCount = MessageBubbleStyler.highlightFlashCount * 2
        let total = MessageBubbleStyler.highlightFlashDuration * TimeInterval(segmentCount)
        UIView.animateKeyframes(withDuration: total, delay: 0, options: []) {
            for index in 0..<segmentCount {
                let start = Double(index) / Double(segmentCount)
                UIView.addKeyframe(withRelativeStartTime: start, relativeDuration: 1 / Double(segmentCount)) {
                    self.highlightOverlayView.alpha = index % 2 == 0 ? spec.maxAlpha : 0
                }
            }
        } completion: { _ in
            guard self.highlightGeneration == generation else { return }
            self.highlightOverlayView.alpha = 0
        }
    }

    // MARK: - Reuse

    override func prepareForReuse() {
        super.prepareForReuse()
        timeLabel.text = nil
        nicknameLabel.text = nil
        detailTimeLabel.text = nil
        detailTimeLabel.isHidden = true
        statusImageView.image = nil
        sendingIndicator.stopAnimating()
        readReceiptLabel.isHidden = true
        readReceiptLabel.text = nil
        quoteView.isHidden = true
        auxiliaryTextBubbleView.isHidden = true
        auxiliaryTextBubbleView.reset()
        reactionBar.isHidden = true
        onAvatarTap = nil
        onAvatarLongPress = nil
        onResendRequested = nil
        onQuotePreviewTap = nil
        onBubbleLongPress = nil
        onReactionBarTap = nil
        onAuxiliaryTextLongPress = nil
        onReadReceiptTap = nil
        highlightGeneration += 1
        highlightOverlayView.layer.removeAllAnimations()
        highlightOverlayView.alpha = 0
    }

    private func constructViewHierarchy() {
        selectionStyle = .none
        contentView.addSubview(timeLabel)
        contentView.addSubview(bodyContainer)
        bodyContainer.addSubview(checkboxView)
        bodyContainer.addSubview(avatarView)
        bodyContainer.addSubview(nicknameLabel)
        bodyContainer.addSubview(detailTimeLabel)
        bodyContainer.addSubview(statusImageView)
        bodyContainer.addSubview(sendingIndicator)
        bodyContainer.addSubview(bubbleColumn)
        bodyContainer.addSubview(readReceiptLabel)
        bodyContainer.addSubview(auxiliaryTextBubbleView)
        bubbleColumn.addSubview(quoteView)
        bubbleColumn.addSubview(contentContainer)
        bodyContainer.addSubview(violationLabel)

        contentContainer.addSubview(reactionBar)
        highlightOverlayView.isUserInteractionEnabled = false
        contentContainer.addSubview(highlightOverlayView)
        highlightOverlayView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }
    }

    private func setupViewStyle() {
        backgroundColor = .clear
        contentView.backgroundColor = .clear
        timeLabel.textAlignment = .center
        timeLabel.font = FontScheme.caption2Regular
        timeLabel.textColor = TUIChatKitTheme.colors.textColorSecondary
        nicknameLabel.font = FontScheme.caption3Regular
        nicknameLabel.textColor = TUIChatKitTheme.colors.textColorSecondary
        detailTimeLabel.font = FontScheme.caption3Regular
        detailTimeLabel.textColor = TUIChatKitTheme.colors.textColorSecondary
        detailTimeLabel.isHidden = true
        statusImageView.contentMode = .scaleAspectFit
        statusImageView.tintColor = TUIChatKitTheme.colors.textColorError
        sendingIndicator.hidesWhenStopped = true
        sendingIndicator.transform = CGAffineTransform(scaleX: Self.sendingIndicatorScale, y: Self.sendingIndicatorScale)
        checkboxView.contentMode = .scaleAspectFit
        readReceiptLabel.font = FontScheme.caption3Regular
        readReceiptLabel.textColor = TUIChatKitTheme.colors.textColorSecondary
        readReceiptLabel.isHidden = true
        violationLabel.font = FontScheme.caption3Regular
        violationLabel.textColor = TUIChatKitTheme.colors.textColorError
        violationLabel.isHidden = true
    }

    private func bindInteraction() {
        avatarView.isUserInteractionEnabled = true
        avatarView.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(handleAvatarTap)))
        avatarView.addGestureRecognizer(UILongPressGestureRecognizer(target: self, action: #selector(handleAvatarLongPress)))
        statusImageView.isUserInteractionEnabled = true
        statusImageView.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(handleStatusTap)))
        quoteView.onTap = { [weak self] in
            guard let self = self, let message = self.message else { return }
            self.onQuotePreviewTap?(message)
        }
        contentContainer.isUserInteractionEnabled = true
        contentContainer.addGestureRecognizer(
            UILongPressGestureRecognizer(target: self, action: #selector(handleBubbleLongPress))
        )
        readReceiptLabel.isUserInteractionEnabled = true
        readReceiptLabel.addGestureRecognizer(readReceiptTapGesture)
        reactionBar.onTap = { [weak self] in
            guard let self = self, let message = self.message else { return }
            self.onReactionBarTap?(message)
        }
    }

    @objc private func handleBubbleLongPress(_ gesture: UILongPressGestureRecognizer) {
        NSLog("[LongPressDebug] cell gesture state=\(gesture.state.rawValue)")
        guard gesture.state == .began, let message = self.message else { return }
        guard let window = self.window else { return }
        let frameInWindow = contentContainer.convert(contentContainer.bounds, to: window)
        NSLog("[LongPressDebug] cell callback fire, onBubbleLongPress=\(onBubbleLongPress == nil ? "nil" : "set")")
        onBubbleLongPress?(message, frameInWindow)
    }

    private func applyReaction(message: MessageInfo, context: MessageContentContext) {
        let supportReaction = context.config.isSupportReaction
        if supportReaction, !message.reactionList.isEmpty {
            reactionBar.isHidden = false
            let maxRowWidth = Self.reactionBarMaxWidth - 2 * reactionBarLayoutInsets().horizontal
            reactionBar.bind(message: message, maxWidth: maxRowWidth, isLeft: context.isLeft)
        } else {
            reactionBar.isHidden = true
        }
    }

    private func reactionBarLayoutInsets() -> (contentPadding: CGFloat, top: CGFloat, bottom: CGFloat, horizontal: CGFloat) {
        if isMergedPayload {
            return (0, Self.reactionBarCardTopInset, Self.reactionBarCardBottomInset, Self.reactionBarCardHorizontalInset)
        }
        if isMediaPayload {
            if shouldWrapMediaInBubble {
                return (Self.mediaBubblePadding,
                        Self.reactionBarTopInset,
                        Self.mediaBubblePadding + Self.reactionBarBottomInset,
                        Self.mediaBubblePadding + Self.reactionBarHorizontalInset)
            }
            return (0, Self.reactionBarMediaTopInset, 0, 0)
        }
        return (0, Self.reactionBarTopInset, Self.reactionBarBottomInset, Self.reactionBarHorizontalInset)
    }

    private func applyViolation(message: MessageInfo) {
        if message.status == .violation {
            violationLabel.text = LocalizedChatString("MessageTypeSecurityStrikeInfo")
            violationLabel.isHidden = false
        } else {
            violationLabel.isHidden = true
        }
    }

    private func applyAuxiliaryText(message: MessageInfo, state: AuxiliaryTextDisplayState, isSelf: Bool) {
        switch state {
        case .hidden:
            auxiliaryTextBubbleView.isHidden = true
            auxiliaryTextBubbleView.reset()
        case .loading:
            auxiliaryTextBubbleView.isHidden = false
            auxiliaryTextBubbleView.bind(isSelf: isSelf, isLoading: true, contentText: nil, footerText: nil)
            auxiliaryTextBubbleView.onLongPress = nil
        case .text(let content, let footer):
            auxiliaryTextBubbleView.isHidden = false
            auxiliaryTextBubbleView.bind(isSelf: isSelf, isLoading: false, contentText: content, footerText: footer)
            auxiliaryTextBubbleView.onLongPress = { [weak self] in
                guard let self = self, let msg = self.message else { return }
                let anchorFrame = self.auxiliaryTextBubbleView.convert(self.auxiliaryTextBubbleView.bounds, to: nil)
                self.onAuxiliaryTextLongPress?(msg, content, anchorFrame)
            }
        }
    }

    private func applyReadReceipt(message: MessageInfo, context: MessageContentContext) {
        guard context.showsReadReceipt, MessageReadReceiptHelper.shouldShowReadReceipt(message) else {
            readReceiptLabel.isHidden = true
            readReceiptLabel.text = nil
            return
        }
        readReceiptLabel.text = MessageReadReceiptHelper.receiptText(message)
        readReceiptLabel.isHidden = false
        readReceiptTapGesture.isEnabled = !context.isMultiSelectMode
    }

    @objc private func handleReadReceiptTap() {
        guard let message = message, message.conversationType == .group else { return }
        onReadReceiptTap?(message)
    }

    private func installContentViewIfNeeded(kind: MessageContentKind) {
        guard contentKind != kind || contentView0 == nil else { return }
        contentView0?.removeFromSuperview()
        let view = MessageContentViewFactory.makeContentView(for: kind)
        contentContainer.insertSubview(view, belowSubview: highlightOverlayView)
        view.snp.makeConstraints { make in
            make.top.leading.trailing.equalToSuperview()
            make.height.greaterThanOrEqualTo(Self.bubbleMinHeight)
        }
        contentView0 = view
        contentKind = kind
    }

    private func applyBubbleContentInsets() {
        guard let contentView = contentView0 else { return }
        let insets = activeBubbleAppearance?.contentInsets ?? .zero
        contentView.snp.remakeConstraints { make in
            make.top.equalToSuperview().offset(insets.top)
            make.leading.equalToSuperview().offset(insets.left)
            make.trailing.equalToSuperview().offset(-insets.right)
            make.height.greaterThanOrEqualTo(Self.bubbleMinHeight)
        }
    }

    private func applyBubbleMinimumSize(_ size: MessageBubbleSize?) {
        bubbleMinWidthConstraint?.isActive = false
        bubbleMinHeightConstraint?.isActive = false
        bubbleMinWidthConstraint = nil
        bubbleMinHeightConstraint = nil
        if let width = size?.width {
            let constraint = contentContainer.widthAnchor.constraint(greaterThanOrEqualToConstant: width)
            constraint.isActive = true
            bubbleMinWidthConstraint = constraint
        }
        if let height = size?.height {
            let constraint = contentContainer.heightAnchor.constraint(greaterThanOrEqualToConstant: height)
            constraint.isActive = true
            bubbleMinHeightConstraint = constraint
        }
    }

    private func shouldShowAvatar(context: MessageContentContext) -> Bool {
        return context.isLeft ? context.config.isShowLeftAvatar : context.config.isShowRightAvatar
    }

    private func applyTime(_ timeString: String?, show: Bool) {
        if let timeString = timeString, show, !timeString.isEmpty {
            timeLabel.text = timeString
            timeLabel.isHidden = false
        } else {
            timeLabel.text = nil
            timeLabel.isHidden = true
        }
    }

    private func applyAvatar(message: MessageInfo, isLeft: Bool, show: Bool) {
        avatarView.isHidden = !show
        guard show else { return }
        let displayName = Self.senderDisplayName(of: message.from)
        avatarView.configure(avatarURL: message.from.avatarURL, fallbackName: displayName)
    }

    private static func senderDisplayName(of sender: MessageSenderInfo) -> String {
        if let nameCard = sender.nameCard, !nameCard.isEmpty { return nameCard }
        if let friendRemark = sender.friendRemark, !friendRemark.isEmpty { return friendRemark }
        if let nickname = sender.nickname, !nickname.isEmpty { return nickname }
        return sender.userID
    }

    private func applyNickname(message: MessageInfo, context: MessageContentContext) {
        let show = context.isSelf
            ? context.config.alignment != .twoSided
            : context.isGroupChat
        if show {
            nicknameLabel.text = Self.senderDisplayName(of: message.from)
            nicknameLabel.isHidden = false
        } else {
            nicknameLabel.text = nil
            nicknameLabel.isHidden = true
        }
    }

    private func applyDetailTime(_ text: String?) {
        detailTimeLabel.text = text
        detailTimeLabel.isHidden = text == nil
    }

    private func applyStatus(message: MessageInfo) {
        sendingIndicator.stopAnimating()
        statusImageView.isHidden = true
        switch message.status {
        case .sendFail, .violation:
            statusImageView.image = UIImage(systemName: "exclamationmark.circle.fill")
            statusImageView.isHidden = false
        case .sending:
            sendingIndicator.startAnimating()
        default:
            break
        }
    }

    private func applyQuote(message: MessageInfo, isSupportQuote: Bool, isLeft: Bool) {
        if isSupportQuote, let quoteInfo = message.quoteInfo, !quoteInfo.msgID.isEmpty {
            quoteView.isHidden = false
            quoteView.bind(quoteInfo: quoteInfo)
        } else {
            quoteView.isHidden = true
        }
        layoutBubbleColumnContent(showQuote: !quoteView.isHidden, isLeft: isLeft)
    }

    private func layoutBubbleColumnContent(showQuote: Bool, isLeft: Bool) {
        if showQuote {
            contentContainer.snp.remakeConstraints { make in
                make.top.equalToSuperview()
                make.width.equalTo(0).priority(.low)
                if isLeft {
                    make.leading.equalToSuperview()
                    make.trailing.lessThanOrEqualToSuperview()
                } else {
                    make.trailing.equalToSuperview()
                    make.leading.greaterThanOrEqualToSuperview()
                }
            }
            quoteView.snp.remakeConstraints { make in
                make.top.equalTo(contentContainer.snp.bottom).offset(Self.quoteTopSpacing)
                make.bottom.equalToSuperview()
                make.width.lessThanOrEqualTo(Self.quoteMaxWidth)
                make.width.equalTo(0).priority(.low)
                if isLeft {
                    make.leading.equalToSuperview()
                    make.trailing.lessThanOrEqualToSuperview()
                } else {
                    make.trailing.equalToSuperview()
                    make.leading.greaterThanOrEqualToSuperview()
                }
            }
        } else {
            quoteView.snp.removeConstraints()
            contentContainer.snp.remakeConstraints { make in
                make.edges.equalToSuperview()
            }
        }
    }

    private func applyCheckbox(isMultiSelectMode: Bool, isSelected: Bool) {
        checkboxView.isHidden = !isMultiSelectMode
        readReceiptTapGesture.isEnabled = !isMultiSelectMode
        guard isMultiSelectMode else { return }
        let colors = TUIChatKitTheme.colors
        if isSelected {
            checkboxView.image = UIImage(systemName: "checkmark.circle.fill")
            checkboxView.tintColor = colors.textColorLink
        } else {
            checkboxView.image = UIImage(systemName: "circle")
            checkboxView.tintColor = colors.textColorTertiary
        }
    }

    private func applyBubbleBackground(context: MessageContentContext) {
        let colors = TUIChatKitTheme.colors

        if isMergedPayload {
            activeBubbleAppearance = nil
            contentContainer.applyAppearance(background: nil, stroke: nil)
            contentContainer.customCornerRadii = nil
            let showReactions = !reactionBar.isHidden
            contentContainer.layer.mask = nil
            contentContainer.clipsToBounds = true
            contentContainer.isCustomMaskEnabled = false
            if showReactions {
                contentContainer.backgroundColor = colors.bgColorDialog
                contentContainer.layer.cornerRadius = CGFloat(RadiusScheme.alertRadius)
                contentContainer.layer.borderWidth = Self.mergedCardBorderWidth
                contentContainer.layer.borderColor = colors.strokeColorPrimary.cgColor
            } else {
                contentContainer.backgroundColor = .clear
                contentContainer.layer.cornerRadius = 0
                contentContainer.layer.borderWidth = 0
                contentContainer.layer.borderColor = nil
            }
            highlightOverlayView.layer.cornerRadius = CGFloat(RadiusScheme.alertRadius)
            (contentView0 as? MessageMergedContentView)?.setCardChromeHidden(showReactions)
            return
        }
        normalBubbleColor = context.isSelf ? colors.bgColorBubbleOwn : colors.bgColorBubbleReciprocal

        if isMediaPayload, !shouldWrapMediaInBubble {
            activeBubbleAppearance = nil
            contentContainer.applyAppearance(background: nil, stroke: nil)
            contentContainer.customCornerRadii = nil
            contentContainer.backgroundColor = .clear
            contentContainer.layer.mask = nil
            contentContainer.layer.cornerRadius = 0
            contentContainer.layer.borderWidth = 0
            contentContainer.layer.borderColor = nil
            contentContainer.clipsToBounds = true
            contentContainer.isCustomMaskEnabled = false
            highlightOverlayView.layer.cornerRadius = CGFloat(RadiusScheme.alertRadius)
            return
        }

        if let appearance = context.config.resolvedBubbleAppearance(isSelf: context.isSelf, isLeft: context.isLeft) {
            applyCustomBubbleAppearance(appearance, context: context)
            return
        }

        activeBubbleAppearance = nil
        contentContainer.applyAppearance(background: nil, stroke: nil)
        contentContainer.customCornerRadii = nil
        contentContainer.layer.cornerRadius = 0
        contentContainer.layer.borderWidth = 0
        contentContainer.layer.borderColor = nil

        contentContainer.isLeftBubble = context.isLeft
        contentContainer.isCustomMaskEnabled = true
        highlightOverlayView.layer.cornerRadius = 0
        MessageBubbleStyler.apply(to: contentContainer,
                                  isSelf: context.isSelf,
                                  isLeft: context.isLeft)
    }

    private func applyCustomBubbleAppearance(_ appearance: MessageBubbleAppearance, context: MessageContentContext) {
        activeBubbleAppearance = appearance
        contentContainer.applyAppearance(background: appearance.background, stroke: appearance.stroke)
        if case .color(let color) = appearance.background {
            normalBubbleColor = color
        }
        if let cornerRadius = appearance.cornerRadius {
            contentContainer.isCustomMaskEnabled = false
            contentContainer.layer.mask = nil
            contentContainer.customCornerRadii = (
                topLeft: cornerRadius.topLeft ?? MessageBubbleStyler.cornerRadius,
                topRight: cornerRadius.topRight ?? MessageBubbleStyler.cornerRadius,
                bottomLeft: cornerRadius.bottomLeft ?? MessageBubbleStyler.cornerRadius,
                bottomRight: cornerRadius.bottomRight ?? MessageBubbleStyler.cornerRadius
            )
        } else {
            contentContainer.customCornerRadii = nil
            contentContainer.isLeftBubble = context.isLeft
            contentContainer.isCustomMaskEnabled = true
        }
        contentContainer.clipsToBounds = true
        contentContainer.setNeedsLayout()
    }

    @objc private func handleAvatarTap() {
        guard let message = message, !message.isSentBySelf else { return }
        onAvatarTap?(message)
    }

    @objc private func handleAvatarLongPress(_ gesture: UILongPressGestureRecognizer) {
        guard gesture.state == .began, let message = message, !message.isSentBySelf else { return }
        onAvatarLongPress?(message)
    }

    @objc private func handleStatusTap() {
        guard let message = message, message.status == .sendFail else { return }
        onResendRequested?(message)
    }

    private func rebuildLayout(context: MessageContentContext,
                              showAvatar: Bool,
                              showNickname: Bool,
                              showStatus: Bool,
                              multiSelect: Bool) {
        applyBubbleBackground(context: context)
        applyBubbleContentInsets()
        applyBubbleMinimumSize(activeBubbleAppearance?.minimumSize)
        let hp = context.config.horizontalPadding
        let avatarSpacing = context.config.avatarSpacing
        let cellSpacing = context.config.cellSpacing
        let timeShown = !timeLabel.isHidden
        let statusReserve: CGFloat = showStatus ? (Self.statusIconSize + Self.statusSlotGap) : 0

        layoutHeader(timeShown: timeShown, cellSpacing: cellSpacing)
        layoutCheckbox(show: multiSelect, leadingInset: hp)

        if context.isLeft {
            layoutLeft(showAvatar: showAvatar, showNickname: showNickname, showStatus: showStatus,
                       multiSelect: multiSelect, hp: hp, avatarSpacing: avatarSpacing,
                       statusReserve: statusReserve)
        } else {
            layoutRight(showAvatar: showAvatar, showNickname: showNickname, showStatus: showStatus,
                        multiSelect: multiSelect, hp: hp, avatarSpacing: avatarSpacing,
                        statusReserve: statusReserve)
        }
    }

    private func layoutHeader(timeShown: Bool, cellSpacing: CGFloat) {
        let timeToBody = max(Self.timeVerticalMargin - cellSpacing, 0)
        timeLabel.snp.remakeConstraints { make in
            make.top.equalToSuperview().offset(timeShown ? Self.timeVerticalMargin : 0)
            make.centerX.equalToSuperview()
            if !timeShown { make.height.equalTo(0) }
        }
        bodyContainer.snp.remakeConstraints { make in
            make.top.equalTo(timeLabel.snp.bottom).offset(timeShown ? timeToBody : cellSpacing)
            make.leading.trailing.equalToSuperview()
            make.bottom.equalToSuperview().offset(-cellSpacing)
        }
    }

    private func layoutCheckbox(show: Bool, leadingInset: CGFloat) {
        guard show else {
            checkboxView.snp.removeConstraints()
            return
        }
        checkboxView.snp.remakeConstraints { make in
            make.leading.equalToSuperview().offset(leadingInset)
            make.centerY.equalTo(bubbleColumn)
            make.width.height.equalTo(Self.checkboxSize)
        }
    }

    private func layoutLeft(showAvatar: Bool, showNickname: Bool, showStatus: Bool,
                            multiSelect: Bool, hp: CGFloat, avatarSpacing: CGFloat,
                            statusReserve: CGFloat) {
        avatarView.snp.removeConstraints()
        nicknameLabel.snp.removeConstraints()
        detailTimeLabel.snp.removeConstraints()
        if showAvatar {
            avatarView.snp.makeConstraints { make in
                if multiSelect {
                    make.leading.equalTo(checkboxView.snp.trailing).offset(Self.checkboxMarginEnd)
                } else {
                    make.leading.equalToSuperview().offset(hp)
                }
                make.top.equalToSuperview()
                make.width.height.equalTo(Self.avatarSize)
                make.bottom.lessThanOrEqualToSuperview()
            }
        }

        bubbleColumn.snp.remakeConstraints { make in
            if showAvatar {
                make.leading.equalTo(avatarView.snp.trailing).offset(avatarSpacing)
            } else if multiSelect {
                make.leading.equalTo(checkboxView.snp.trailing).offset(Self.checkboxMarginEnd)
            } else {
                make.leading.equalToSuperview().offset(hp)
            }
            if showNickname {
                make.top.equalTo(nicknameLabel.snp.bottom).offset(Self.nicknameBottomMargin)
            } else {
                make.top.equalToSuperview()
            }
            make.bottom.lessThanOrEqualToSuperview()
            if detailTimeLabel.isHidden {
                make.trailing.lessThanOrEqualToSuperview().offset(-(hp + statusReserve))
            } else {
                make.trailing.lessThanOrEqualTo(detailTimeLabel.snp.leading).offset(-Self.nicknameDetailTimeSpacing)
            }
            make.width.equalTo(0).priority(.low)
        }

        if showNickname {
            nicknameLabel.snp.makeConstraints { make in
                make.leading.equalTo(bubbleColumn.snp.leading)
                make.top.equalToSuperview()
                if detailTimeLabel.isHidden {
                    make.trailing.lessThanOrEqualToSuperview().offset(-(hp + statusReserve))
                } else {
                    make.trailing.lessThanOrEqualTo(detailTimeLabel.snp.leading).offset(-Self.nicknameDetailTimeSpacing)
                }
            }
        }
        if !detailTimeLabel.isHidden {
            detailTimeLabel.snp.makeConstraints { make in
                make.trailing.equalToSuperview().offset(-hp)
                if showNickname {
                    make.centerY.equalTo(nicknameLabel)
                } else {
                    make.top.equalToSuperview()
                }
            }
        }

        layoutStatusSlot(show: showStatus, isLeft: true, hp: hp)
        layoutReactionBar(isLeft: true)
        layoutAuxiliaryTextBubble(isLeft: true, hp: hp)
        layoutViolationLabel(isLeft: true, hp: hp)
    }

    private func layoutRight(showAvatar: Bool, showNickname: Bool, showStatus: Bool,
                             multiSelect: Bool, hp: CGFloat, avatarSpacing: CGFloat,
                             statusReserve: CGFloat) {
        avatarView.snp.removeConstraints()
        nicknameLabel.snp.removeConstraints()
        detailTimeLabel.snp.removeConstraints()
        if showAvatar {
            avatarView.snp.makeConstraints { make in
                if detailTimeLabel.isHidden {
                    make.trailing.equalToSuperview().offset(-hp)
                } else {
                    make.trailing.equalTo(detailTimeLabel.snp.leading).offset(-Self.nicknameDetailTimeSpacing)
                }
                make.top.equalToSuperview()
                make.width.height.equalTo(Self.avatarSize)
                make.bottom.lessThanOrEqualToSuperview()
            }
        }

        let leadingBound = hp + statusReserve + (multiSelect ? (Self.checkboxSize + Self.checkboxMarginEnd) : 0)
        bubbleColumn.snp.remakeConstraints { make in
            if showAvatar {
                make.trailing.equalTo(avatarView.snp.leading).offset(-avatarSpacing)
            } else if !detailTimeLabel.isHidden {
                make.trailing.equalTo(detailTimeLabel.snp.leading).offset(-Self.nicknameDetailTimeSpacing)
            } else {
                make.trailing.equalToSuperview().offset(-hp)
            }
            if showNickname {
                make.top.equalTo(nicknameLabel.snp.bottom).offset(Self.nicknameBottomMargin)
            } else {
                make.top.equalToSuperview()
            }
            make.bottom.lessThanOrEqualToSuperview()
            make.leading.greaterThanOrEqualToSuperview().offset(leadingBound)
            make.width.equalTo(0).priority(.low)
        }

        if showNickname {
            nicknameLabel.snp.makeConstraints { make in
                make.trailing.equalTo(bubbleColumn.snp.trailing)
                make.top.equalToSuperview()
                make.leading.greaterThanOrEqualToSuperview().offset(leadingBound)
            }
        }
        if !detailTimeLabel.isHidden {
            detailTimeLabel.snp.makeConstraints { make in
                make.trailing.equalToSuperview().offset(-hp)
                if showNickname {
                    make.centerY.equalTo(nicknameLabel)
                } else {
                    make.top.equalToSuperview()
                }
            }
        }

        layoutStatusSlot(show: showStatus, isLeft: false, hp: hp)
        layoutReactionBar(isLeft: false)
        layoutAuxiliaryTextBubble(isLeft: false, hp: hp)
        layoutViolationLabel(isLeft: false, hp: hp)
    }

    private func layoutReactionBar(isLeft: Bool) {
        guard let contentView = contentView0 else { return }
        let showReaction = !reactionBar.isHidden
        let insets = reactionBarLayoutInsets()
        if showReaction {
            contentView.snp.remakeConstraints { make in
                make.top.equalToSuperview().offset(insets.contentPadding)
                if isLeft {
                    make.leading.equalToSuperview().offset(insets.contentPadding)
                    make.trailing.lessThanOrEqualToSuperview().offset(-insets.contentPadding)
                } else {
                    make.trailing.equalToSuperview().offset(-insets.contentPadding)
                    make.leading.greaterThanOrEqualToSuperview().offset(insets.contentPadding)
                }
                make.height.greaterThanOrEqualTo(Self.bubbleMinHeight)
                make.bottom.equalTo(reactionBar.snp.top).offset(-insets.top)
            }
            reactionBar.snp.remakeConstraints { make in
                make.top.equalTo(contentView.snp.bottom).offset(insets.top)
                make.bottom.equalToSuperview().offset(-insets.bottom)
                if isLeft {
                    make.leading.equalToSuperview().offset(insets.horizontal)
                    make.trailing.lessThanOrEqualToSuperview().offset(-insets.horizontal)
                } else {
                    make.trailing.equalToSuperview().offset(-insets.horizontal)
                    make.leading.greaterThanOrEqualToSuperview().offset(insets.horizontal)
                }
            }
            let minBubbleWidth = reactionBar.contentWidth + 2 * insets.horizontal
            if let constraint = reactionBarMinWidthConstraint {
                constraint.update(offset: minBubbleWidth)
                constraint.activate()
            } else {
                contentContainer.snp.makeConstraints { make in
                    reactionBarMinWidthConstraint = make.width.greaterThanOrEqualTo(minBubbleWidth).constraint
                }
            }
        } else {
            reactionBarMinWidthConstraint?.deactivate()
            contentView.snp.remakeConstraints { make in
                make.top.leading.trailing.equalToSuperview()
                make.height.greaterThanOrEqualTo(Self.bubbleMinHeight)
                make.bottom.equalToSuperview()
            }
            reactionBar.snp.removeConstraints()
        }
    }

    private func layoutViolationLabel(isLeft: Bool, hp: CGFloat) {
        if violationLabel.isHidden {
            violationLabel.snp.removeConstraints()
            return
        }
        violationLabel.snp.remakeConstraints { make in
            make.top.equalTo(bubbleColumn.snp.bottom).offset(Self.violationTopInset)
            make.bottom.equalToSuperview()
            if isLeft {
                make.leading.equalTo(bubbleColumn)
                make.trailing.lessThanOrEqualToSuperview().offset(-hp)
            } else {
                make.trailing.equalTo(bubbleColumn)
                make.leading.greaterThanOrEqualToSuperview().offset(hp)
            }
        }
    }

    private func layoutAuxiliaryTextBubble(isLeft: Bool, hp: CGFloat) {
        guard !auxiliaryTextBubbleView.isHidden else {
            auxiliaryTextBubbleView.snp.removeConstraints()
            return
        }
        let topInset = contentKind == .audio ? Self.auxiliaryAudioTopInset : Self.auxiliaryTextTopInset
        auxiliaryTextBubbleView.snp.remakeConstraints { make in
            make.top.equalTo(bubbleColumn.snp.bottom).offset(topInset)
            make.bottom.equalToSuperview()
            if isLeft {
                make.leading.equalTo(bubbleColumn)
                make.trailing.lessThanOrEqualToSuperview().offset(-hp)
            } else {
                make.trailing.equalTo(bubbleColumn)
                make.leading.greaterThanOrEqualToSuperview().offset(hp)
            }
        }
    }

    private func layoutStatusSlot(show: Bool, isLeft: Bool, hp: CGFloat) {
        guard show else {
            statusImageView.snp.removeConstraints()
            sendingIndicator.snp.removeConstraints()
            readReceiptLabel.snp.removeConstraints()
            return
        }
        statusImageView.snp.remakeConstraints { make in
            if isLeft {
                make.leading.equalTo(bubbleColumn.snp.trailing).offset(Self.statusSlotGap)
            } else {
                make.trailing.equalTo(bubbleColumn.snp.leading).offset(-Self.statusSlotGap)
            }
            make.bottom.equalTo(bubbleColumn)
            make.width.height.equalTo(Self.statusIconSize)
        }
        sendingIndicator.snp.remakeConstraints { make in
            make.center.equalTo(statusImageView)
        }
        if !readReceiptLabel.isHidden {
            readReceiptLabel.snp.remakeConstraints { make in
                if isLeft {
                    make.leading.equalTo(bubbleColumn.snp.trailing).offset(Self.statusSlotGap)
                } else {
                    make.trailing.equalTo(bubbleColumn.snp.leading).offset(-Self.statusSlotGap)
                }
                make.bottom.equalTo(bubbleColumn)
            }
        } else {
            readReceiptLabel.snp.removeConstraints()
        }
    }
}
