import UIKit
import SnapKit
import AtomicXCore

final class MessageTextContentView: UIView, MessageContentView {
    private static let horizontalInset = CGFloat(SpacingScheme.iconIconSpacing)

    private static let verticalInset = CGFloat(SpacingScheme.smallSpacing)

    private static let lineSpacingMultiplier: CGFloat = 0.3

    private static let maxBubbleWidth: CGFloat = UIScreen.main.bounds.width * 0.72

    private let textLabel = UILabel()

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
        let text = Self.currentText(from: message)
        applyText(text, isSelf: context.isSelf)
    }

    // MARK: - Private

    private func constructViewHierarchy() {
        addSubview(textLabel)
    }

    private func activateConstraints() {
        textLabel.snp.makeConstraints { make in
            make.top.bottom.equalToSuperview().inset(Self.verticalInset)
            make.leading.equalToSuperview().offset(Self.horizontalInset)
            make.trailing.lessThanOrEqualToSuperview().offset(-Self.horizontalInset)
            make.width.lessThanOrEqualTo(Self.maxBubbleWidth - Self.horizontalInset * 2)
        }
    }

    private func setupViewStyle() {
        textLabel.numberOfLines = 0
        textLabel.font = FontScheme.caption1Regular
        textLabel.textAlignment = .natural
        textLabel.preferredMaxLayoutWidth = Self.maxBubbleWidth - Self.horizontalInset * 2
    }

    private static func currentText(from message: MessageInfo) -> String {
        if case .text(let payload) = message.messagePayload {
            return payload.text
        }
        return ""
    }

    private func applyText(_ text: String, isSelf: Bool) {
        let textColor = isSelf ? ChatUIKitTheme.colors.textColorAntiPrimary : ChatUIKitTheme.colors.textColorPrimary
        textLabel.textAlignment = .natural
        if text.contains("[TUIEmoji_") {
            textLabel.attributedText = emojiAttributedString(from: text, textColor: textColor)
        } else {
            textLabel.attributedText = plainAttributedString(from: text, textColor: textColor)
        }
        applyLabelPosition(isSelf: isSelf)
    }

    private func plainAttributedString(from text: String, textColor: UIColor) -> NSAttributedString {
        let font = FontScheme.caption1Regular
        let paragraph = NSMutableParagraphStyle()
        paragraph.alignment = .natural
        paragraph.lineSpacing = font.lineHeight * Self.lineSpacingMultiplier
        return NSAttributedString(string: text, attributes: [
            .font: font,
            .foregroundColor: textColor,
            .paragraphStyle: paragraph
        ])
    }

    private func applyLabelPosition(isSelf: Bool) {
        textLabel.snp.remakeConstraints { make in
            make.top.bottom.equalToSuperview().inset(Self.verticalInset)
            make.width.lessThanOrEqualTo(Self.maxBubbleWidth - Self.horizontalInset * 2)
            if isSelf {
                make.trailing.equalToSuperview().offset(-Self.horizontalInset)
                make.leading.greaterThanOrEqualToSuperview().offset(Self.horizontalInset)
            } else {
                make.leading.equalToSuperview().offset(Self.horizontalInset)
                make.trailing.lessThanOrEqualToSuperview().offset(-Self.horizontalInset)
            }
        }
    }

    private func emojiAttributedString(from text: String, textColor: UIColor) -> NSAttributedString {
        let source = EmojiManager.shared.createAttributedStringFromEmojiCodes(from: text)
        let mutable = NSMutableAttributedString(attributedString: source)
        let fullRange = NSRange(location: 0, length: mutable.length)
        mutable.enumerateAttribute(.attachment, in: fullRange, options: []) { value, range, _ in
            guard value == nil else { return }
            mutable.addAttribute(.font, value: FontScheme.caption1Regular, range: range)
            mutable.addAttribute(.foregroundColor, value: textColor, range: range)
        }
        let paragraph = NSMutableParagraphStyle()
        paragraph.alignment = .natural
        paragraph.lineSpacing = FontScheme.caption1Regular.lineHeight * Self.lineSpacingMultiplier
        mutable.addAttribute(.paragraphStyle, value: paragraph, range: fullRange)
        return mutable
    }
}
