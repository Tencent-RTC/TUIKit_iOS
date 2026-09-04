import UIKit
import SnapKit

final class MessageInputTextView: UIView {
    var onContentChanged: ((NSAttributedString?) -> Void)?

    var onHeightChanged: ((CGFloat) -> Void)?

    var onSend: (() -> Void)?

    var onAtTriggered: ((Int) -> Void)?

    var mentionToDeleteAtPosition: ((Int) -> (startIndex: Int, length: Int)?)?

    var onMentionDeleted: ((Int) -> Void)?

    var onUserTextChanged: ((Bool) -> Void)?

    var shouldBlockFirstResponder: (() -> Bool)?

    var isGroupChat: Bool = false

    var placeholderText: String? {
        didSet { placeholderLabel.text = placeholderText }
    }

    var suppressPlaceholderForPanel: Bool = false {
        didSet { updatePlaceholder() }
    }

    var enableMention: Bool = true

    var maxLines: Int = 5

    var attributedContent: NSAttributedString? {
        return textView.attributedText.length > 0 ? textView.attributedText : nil
    }

    override var isFirstResponder: Bool {
        return textView.isFirstResponder
    }

    private static let normalFont = FontScheme.caption1Regular

    private static let initialHeight: CGFloat = 36

    private static let fallbackLineHeight: CGFloat = 24

    private static let heightChangeThreshold: CGFloat = 0.5

    private let textContainerInsets = UIEdgeInsets(
        top: CGFloat(SpacingScheme.smallSpacing),
        left: CGFloat(SpacingScheme.iconTextSpacing),
        bottom: CGFloat(SpacingScheme.smallSpacing),
        right: CGFloat(SpacingScheme.iconTextSpacing)
    )

    private let textView = UITextView()

    private let placeholderLabel = UILabel()

    private var isUserEditing = false

    private var currentHeight: CGFloat = MessageInputTextView.initialHeight

    // MARK: - Init

    init() {
        super.init(frame: .zero)
        constructViewHierarchy()
        activateConstraints()
        bindInteraction()
        setupViewStyle()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    // MARK: - Public API

    @discardableResult

    override func becomeFirstResponder() -> Bool {
        return textView.becomeFirstResponder()
    }

    @discardableResult

    override func resignFirstResponder() -> Bool {
        return textView.resignFirstResponder()
    }

    func setContent(_ attributedText: NSAttributedString?) {
        if let attributedText = attributedText {
            textView.attributedText = attributedText
            textView.selectedRange = NSRange(location: attributedText.length, length: 0)
        } else {
            textView.attributedText = NSAttributedString(string: "")
        }
        resetTextStyle()
        updatePlaceholder()
        recalculateHeight()
        onContentChanged?(attributedContent)
    }

    func clear() {
        setContent(nil)
    }

    func insertEmoji(_ emojiString: NSAttributedString, emojiName: String) {
        if let attachment = emojiString.attribute(.attachment, at: 0, effectiveRange: nil) as? NSTextAttachment,
           let image = attachment.image {
            image.accessibilityIdentifier = emojiName
        }
        let selectedRange = textView.selectedRange
        textView.textStorage.insert(emojiString, at: selectedRange.location)
        textView.selectedRange = NSRange(location: selectedRange.location + 1, length: 0)
        resetTextStyle()
        updatePlaceholder()
        recalculateHeight()
        onContentChanged?(attributedContent)
    }

    func deleteLastCharacter() {
        guard textView.textStorage.length > 0 else { return }
        let selectedRange = textView.selectedRange
        if selectedRange.length > 0 {
            textView.textStorage.deleteCharacters(in: selectedRange)
            textView.selectedRange = NSRange(location: selectedRange.location, length: 0)
        } else if selectedRange.location > 0 {
            let deleteRange = NSRange(location: selectedRange.location - 1, length: 1)
            textView.textStorage.deleteCharacters(in: deleteRange)
            textView.selectedRange = NSRange(location: selectedRange.location - 1, length: 0)
        }
        resetTextStyle()
        updatePlaceholder()
        recalculateHeight()
        onContentChanged?(attributedContent)
    }

    func appendText(_ attributedText: NSAttributedString) {
        let endPosition = textView.textStorage.length
        textView.textStorage.insert(attributedText, at: endPosition)
        textView.selectedRange = NSRange(location: textView.textStorage.length, length: 0)
        resetTextStyle()
        updatePlaceholder()
        recalculateHeight()
        onContentChanged?(attributedContent)
    }

    func extractSendText() -> String {
        guard let attributedString = attributedContent else { return "" }
        var resultText = ""
        var currentPosition = 0
        attributedString.enumerateAttributes(
            in: NSRange(location: 0, length: attributedString.length), options: []
        ) { attributes, range, _ in
            if currentPosition < range.location {
                let textRange = NSRange(location: currentPosition, length: range.location - currentPosition)
                resultText += attributedString.attributedSubstring(from: textRange).string
            }
            if let attachment = attributes[.attachment] as? EmojiTextAttachment {
                resultText += attachment.emojiTag ?? "[emoji]"
            } else {
                resultText += attributedString.attributedSubstring(from: range).string
            }
            currentPosition = range.location + range.length
        }
        if currentPosition < attributedString.length {
            let textRange = NSRange(location: currentPosition, length: attributedString.length - currentPosition)
            resultText += attributedString.attributedSubstring(from: textRange).string
        }
        return resultText
    }

    func convertDisplayPositionToTextPosition(_ displayPosition: Int) -> Int {
        guard let attributedString = attributedContent else { return displayPosition }
        var textPosition = 0
        var displayPos = 0
        attributedString.enumerateAttributes(
            in: NSRange(location: 0, length: attributedString.length), options: []
        ) { attributes, range, stop in
            if displayPos >= displayPosition {
                stop.pointee = true
                return
            }
            if let attachment = attributes[.attachment] as? EmojiTextAttachment {
                textPosition += attachment.emojiTag?.count ?? "[emoji]".count
                displayPos += range.length
            } else {
                let charsToAdd = min(range.length, displayPosition - displayPos)
                textPosition += charsToAdd
                displayPos += charsToAdd
            }
        }
        if displayPos < displayPosition {
            textPosition += displayPosition - displayPos
        }
        return textPosition
    }

    // MARK: - Private Helpers

    override func layoutSubviews() {
        super.layoutSubviews()
        recalculateHeight()
    }

    private func constructViewHierarchy() {
        addSubview(textView)
        addSubview(placeholderLabel)
    }

    private func activateConstraints() {
        textView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }
        placeholderLabel.snp.makeConstraints { make in
            make.centerX.equalToSuperview()
            make.centerY.equalToSuperview()
        }
    }

    private func bindInteraction() {
        textView.delegate = self
    }

    private func setupViewStyle() {
        let colors = TUIChatKitTheme.colors
        textView.font = Self.normalFont
        textView.backgroundColor = .clear
        textView.isScrollEnabled = false
        textView.textContainer.lineFragmentPadding = 0
        textView.textContainerInset = textContainerInsets
        textView.returnKeyType = .send
        textView.textContainer.lineBreakMode = .byWordWrapping
        textView.textColor = colors.textColorPrimary
        textView.tintColor = colors.textColorLink
        textView.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)

        placeholderLabel.font = FontScheme.caption1Regular
        placeholderLabel.textColor = colors.textColorTertiary
        placeholderLabel.textAlignment = .center
        placeholderLabel.text = LocalizedChatString("SendMessage")
        placeholderLabel.isUserInteractionEnabled = false
    }

    private func updatePlaceholder() {
        let hasContent = attributedContent?.string.isEmpty == false
        placeholderLabel.isHidden = hasContent || textView.isFirstResponder || suppressPlaceholderForPanel
    }

    private func recalculateHeight() {
        let width = textView.frame.width > 0 ? textView.frame.width : bounds.width
        let fitting = textView.sizeThatFits(CGSize(width: width, height: .greatestFiniteMagnitude))
        let singleLineHeight = textView.font?.lineHeight ?? Self.fallbackLineHeight
        let padding = textContainerInsets.top + textContainerInsets.bottom
        let maxHeight = singleLineHeight * CGFloat(maxLines) + padding
        let newHeight = min(max(singleLineHeight + padding, fitting.height), maxHeight)
        textView.isScrollEnabled = fitting.height > maxHeight
        guard abs(newHeight - currentHeight) > Self.heightChangeThreshold else { return }
        currentHeight = newHeight
        onHeightChanged?(newHeight)
    }

    private func resetTextStyle() {
        let colors = TUIChatKitTheme.colors
        let wholeRange = NSRange(location: 0, length: textView.textStorage.length)
        textView.textStorage.removeAttribute(.font, range: wholeRange)
        textView.textStorage.removeAttribute(.foregroundColor, range: wholeRange)
        textView.textStorage.addAttribute(.foregroundColor, value: colors.textColorPrimary, range: wholeRange)
        textView.textStorage.addAttribute(.font, value: Self.normalFont, range: wholeRange)
        textView.textAlignment = .natural
        textView.textColor = colors.textColorPrimary
    }
}

// MARK: - UITextViewDelegate

extension MessageInputTextView: UITextViewDelegate {

    func textViewShouldBeginEditing(_ textView: UITextView) -> Bool {
        return shouldBlockFirstResponder?() != true
    }

    func textViewDidBeginEditing(_ textView: UITextView) {
        isUserEditing = true
        updatePlaceholder()
    }

    func textViewDidEndEditing(_ textView: UITextView) {
        isUserEditing = false
        updatePlaceholder()
    }

    func textViewDidChange(_ textView: UITextView) {
        isUserEditing = true
        resetTextStyle()
        updatePlaceholder()
        recalculateHeight()
        onContentChanged?(attributedContent)
        onUserTextChanged?(attributedContent != nil)
    }

    func textView(
        _ textView: UITextView,
        shouldChangeTextIn range: NSRange,
        replacementText text: String
    ) -> Bool {
        if (text == "@" || text == "＠") && isGroupChat && enableMention {
            DispatchQueue.main.async { [weak self] in
                self?.onAtTriggered?(range.location)
            }
            return true
        }

        if text.isEmpty && range.length > 0 {
            if handleMentionDeletion(in: textView, deletePosition: range.location) {
                return false
            }
        }

        if !text.contains("[") && !text.contains("]") {
            if text == "\n" {
                onSend?()
                return false
            }
            return true
        }

        let selectedRange = textView.selectedRange
        if selectedRange.length > 0 {
            textView.textStorage.deleteCharacters(in: selectedRange)
        }
        let textChange = EmojiManager.shared.createAttributedStringWithTextAndStyle(
            text: text, withFont: Self.normalFont, textColor: TUIChatKitTheme.colors.textColorPrimary
        )
        textView.textStorage.insert(textChange, at: selectedRange.location)
        let cursorLocation = selectedRange.location + textChange.length
        textView.selectedRange = NSRange(location: cursorLocation, length: 0)
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            let end = min(cursorLocation, self.textView.textStorage.length)
            self.textView.selectedRange = NSRange(location: end, length: 0)
        }
        resetTextStyle()
        updatePlaceholder()
        recalculateHeight()
        onContentChanged?(attributedContent)
        return false
    }

    private func handleMentionDeletion(in textView: UITextView, deletePosition: Int) -> Bool {
        guard let mention = mentionToDeleteAtPosition?(deletePosition) else { return false }
        let textLength = textView.textStorage.length
        let mentionStart = mention.startIndex
        guard mentionStart >= 0, mentionStart < textLength else { return false }
        let safeLength = min(mention.length, textLength - mentionStart)
        guard safeLength > 0 else { return false }
        let mentionRange = NSRange(location: mentionStart, length: safeLength)
        textView.textStorage.deleteCharacters(in: mentionRange)
        textView.selectedRange = NSRange(location: mentionStart, length: 0)
        resetTextStyle()
        updatePlaceholder()
        recalculateHeight()
        onContentChanged?(attributedContent)
        onMentionDeleted?(mentionStart)
        return true
    }
}
