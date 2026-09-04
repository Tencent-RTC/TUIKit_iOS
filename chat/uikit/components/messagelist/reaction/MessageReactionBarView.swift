import UIKit
import SnapKit
import AtomicXCore

final class MessageReactionBarView: UIView {
    var onTap: (() -> Void)?

    private enum Metric {
        static let maxDisplayReactions = 5
        static let chipHorizontalSpacing = CGFloat(SpacingScheme.smallSpacing)
        static let chipVerticalSpacing: CGFloat = 6
        static let chipHorizontalPadding = CGFloat(SpacingScheme.smallSpacing)
        static let chipVerticalPadding = CGFloat(SpacingScheme.iconTextSpacing)
        static let chipCornerRadius = CGFloat(RadiusScheme.alertRadius)
        static let chipEmojiSize: CGFloat = 16
        static let chipDividerWidth: CGFloat = 1
        static let chipDividerHeight: CGFloat = 14
        static let chipTextMaxWidth: CGFloat = 120
        static let chipMaxWidth: CGFloat = 180
        static let minRowWidth: CGFloat = 160
        static let fadeInDuration: TimeInterval = 0.2
        static let selfChipBgAlpha: CGFloat = 24.0 / 255.0
        static let otherChipBgAlpha: CGFloat = 16.0 / 255.0
        static let selfChipDividerAlpha: CGFloat = 64.0 / 255.0
        static let otherChipDividerAlpha: CGFloat = 32.0 / 255.0
        static let chipTextMaxLines = 1
        static let spacerHeight: CGFloat = 1
    }

    private let rowsStack = UIStackView()

    private var lastBoundMsgID: String?

    private var lastReactionSignature = ""

    private(set) var contentWidth: CGFloat = 0 {
        didSet {
            if contentWidth != oldValue {
                invalidateIntrinsicContentSize()
            }
        }
    }

    override var intrinsicContentSize: CGSize {
        return CGSize(width: contentWidth, height: UIView.noIntrinsicMetric)
    }

    init() {
        super.init(frame: .zero)
        setContentCompressionResistancePriority(.required, for: .horizontal)
        constructViewHierarchy()
        setupViewStyle()
        bindInteraction()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    // MARK: - Bind

    func bind(message: MessageInfo, maxWidth: CGFloat, isLeft: Bool) {
        let signature = Self.reactionSignature(message)

        if !message.reactionList.isEmpty,
           message.msgID == lastBoundMsgID,
           signature == lastReactionSignature {
            isHidden = false
            return
        }

        rowsStack.arrangedSubviews.forEach { $0.removeFromSuperview() }
        guard !message.reactionList.isEmpty else {
            isHidden = true
            contentWidth = 0
            lastBoundMsgID = message.msgID
            lastReactionSignature = ""
            return
        }

        let shouldFadeIn = !message.msgID.isEmpty
            && message.msgID == lastBoundMsgID
            && signature != lastReactionSignature
        lastBoundMsgID = message.msgID
        lastReactionSignature = signature

        isHidden = false
        rowsStack.alignment = isLeft ? .leading : .trailing

        let maxRowWidth = max(maxWidth, Metric.minRowWidth)
        let displayReactions = Array(message.reactionList.prefix(Metric.maxDisplayReactions))
        buildRows(reactions: displayReactions, isSelf: message.isSentBySelf, maxRowWidth: maxRowWidth)

        layer.removeAllAnimations()
        if shouldFadeIn {
            alpha = 0
            UIView.animate(withDuration: Metric.fadeInDuration) {
                self.alpha = 1
            }
        } else {
            alpha = 1
        }
    }

    // MARK: - Label

    private func constructViewHierarchy() {
        addSubview(rowsStack)
        rowsStack.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }
    }

    private func setupViewStyle() {
        rowsStack.axis = .vertical
        rowsStack.spacing = Metric.chipVerticalSpacing
        rowsStack.distribution = .fill
    }

    private func bindInteraction() {
        isUserInteractionEnabled = true
        addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(handleTap)))
    }

    @objc private func handleTap() {
        onTap?()
    }

    private static func reactionSignature(_ message: MessageInfo) -> String {
        return message.reactionList.map { "\($0.reactionID):\($0.totalUserCount)" }.joined(separator: "|")
    }

    private func buildRows(reactions: [MessageReaction], isSelf: Bool, maxRowWidth: CGFloat) {
        var currentRow = makeRowStack()
        var currentRowWidth: CGFloat = 0
        var widestRowWidth: CGFloat = 0

        for reaction in reactions {
            let chip = makeChip(reaction: reaction, isSelf: isSelf)
            let chipSize = chip.systemLayoutSizeFitting(
                CGSize(width: maxRowWidth, height: UIView.layoutFittingCompressedSize.height),
                withHorizontalFittingPriority: .fittingSizeLevel,
                verticalFittingPriority: .fittingSizeLevel
            )
            let chipWidth = min(chipSize.width, Metric.chipMaxWidth)

            if !currentRow.arrangedSubviews.isEmpty,
               currentRowWidth + Metric.chipHorizontalSpacing + chipWidth > maxRowWidth {
                rowsStack.addArrangedSubview(currentRow)
                widestRowWidth = max(widestRowWidth, currentRowWidth)
                currentRow = makeRowStack()
                currentRowWidth = 0
            }

            let spacing = currentRow.arrangedSubviews.isEmpty ? 0 : Metric.chipHorizontalSpacing
            currentRow.addArrangedSubview(chip)
            currentRowWidth += spacing + chipWidth
        }

        if !currentRow.arrangedSubviews.isEmpty {
            rowsStack.addArrangedSubview(currentRow)
            widestRowWidth = max(widestRowWidth, currentRowWidth)
        }
        contentWidth = widestRowWidth
    }

    private func makeRowStack() -> UIStackView {
        let row = UIStackView()
        row.axis = .horizontal
        row.alignment = .center
        row.spacing = Metric.chipHorizontalSpacing
        return row
    }

    private func makeChip(reaction: MessageReaction, isSelf: Bool) -> UIView {
        let colors = TUIChatKitTheme.colors
        let baseTextColor = isSelf ? colors.textColorAntiPrimary : colors.textColorPrimary

        let chip = UIView()
        chip.backgroundColor = baseTextColor.withAlphaComponent(
            isSelf ? Metric.selfChipBgAlpha : Metric.otherChipBgAlpha
        )
        chip.layer.cornerRadius = Metric.chipCornerRadius
        chip.snp.makeConstraints { make in
            make.width.lessThanOrEqualTo(Metric.chipMaxWidth)
        }

        let content = UIStackView()
        content.axis = .horizontal
        content.alignment = .center
        content.spacing = 0
        chip.addSubview(content)
        content.snp.makeConstraints { make in
            make.edges.equalToSuperview().inset(UIEdgeInsets(
                top: Metric.chipVerticalPadding,
                left: Metric.chipHorizontalPadding,
                bottom: Metric.chipVerticalPadding,
                right: Metric.chipHorizontalPadding
            ))
        }

        let emojiImage = Self.emojiImage(for: reaction.reactionID)
        if let emojiImage = emojiImage {
            let imageView = UIImageView(image: emojiImage)
            imageView.contentMode = .scaleAspectFit
            content.addArrangedSubview(imageView)
            imageView.snp.makeConstraints { make in
                make.width.height.equalTo(Metric.chipEmojiSize)
            }
        }

        let labelText = Self.reactionLabel(reaction)
        if !labelText.isEmpty {
            if emojiImage != nil {
                content.addArrangedSubview(makeSpacer(width: Metric.chipHorizontalSpacing / 2))
                let divider = UIView()
                divider.backgroundColor = baseTextColor.withAlphaComponent(
                    isSelf ? Metric.selfChipDividerAlpha : Metric.otherChipDividerAlpha
                )
                content.addArrangedSubview(divider)
                divider.snp.makeConstraints { make in
                    make.width.equalTo(Metric.chipDividerWidth)
                    make.height.equalTo(Metric.chipDividerHeight)
                }
                content.addArrangedSubview(makeSpacer(width: Metric.chipHorizontalSpacing / 2))
            }
            let label = UILabel()
            label.font = FontScheme.caption3Regular
            label.textColor = isSelf ? colors.textColorAntiPrimary : colors.textColorSecondary
            label.text = labelText
            label.numberOfLines = Metric.chipTextMaxLines
            label.lineBreakMode = .byTruncatingTail
            content.addArrangedSubview(label)
            label.snp.makeConstraints { make in
                make.width.lessThanOrEqualTo(Metric.chipTextMaxWidth)
            }
        }
        return chip
    }

    private static func emojiImage(for reactionID: String) -> UIImage? {
        guard let image = ReactionEmojiRenderer.image(for: reactionID), image.size != .zero else {
            return nil
        }
        return image
    }

    private func makeSpacer(width: CGFloat) -> UIView {
        let spacer = UIView()
        spacer.snp.makeConstraints { make in
            make.width.equalTo(width)
            make.height.equalTo(Metric.spacerHeight)
        }
        return spacer
    }

    private static func reactionLabel(_ reaction: MessageReaction) -> String {
        let totalUserCount = reaction.totalUserCount
        guard totalUserCount > 0 else { return "" }

        let firstUser = reaction.partialUserList.first
        var displayName: String?
        if let nickname = firstUser?.nickname,
           !nickname.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            displayName = nickname
        } else if let userID = firstUser?.userID, !userID.isEmpty {
            displayName = userID
        }
        guard let name = displayName else {
            return "\(totalUserCount)"
        }
        if totalUserCount == 1 {
            return name
        }

        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let isChinese = LanguageHelper.getCurrentLanguage().hasPrefix("zh")
        let count = isChinese ? totalUserCount : max(totalUserCount - 1, 1)
        let suffix = String(format: LocalizedChatString("MessageReactionUserSuffix"), count)
        return isChinese ? trimmed + suffix : trimmed + " " + suffix
    }
}
