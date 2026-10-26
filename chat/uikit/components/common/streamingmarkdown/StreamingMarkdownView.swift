import UIKit
import SnapKit

/// 通用流式 Markdown 视图，支持解析缓存、出字限速和外部显示进度限制。
public final class StreamingMarkdownView: UIView {
    private static let newlineCharacter: unichar = 0x0A
    private static let lineSeparatorCharacter: unichar = 0x2028
    private static let lineSeparator = "\u{2028}"
    private static let widthTolerance: CGFloat = 0.5
    private static let heightTolerance: CGFloat = 0.5
    private static let linkHitSlop: CGFloat = 2

    private static var learnedTextWidths: [String: CGFloat] = [:]

    private final class RenderCache {
        let text: String
        let isStreaming: Bool
        let textColor: UIColor
        let result: MarkdownRenderResult
        var softBreakWidth: CGFloat?
        var softBreakOffsets: [Int] = []

        init(text: String, isStreaming: Bool, textColor: UIColor, result: MarkdownRenderResult) {
            self.text = text
            self.isStreaming = isStreaming
            self.textColor = textColor
            self.result = result
        }
    }

    public var onDisplayedHeightChange: (() -> Void)?

    private let textView = StreamingMarkdownView.makeTextView()
    private var widthConstraint: Constraint?
    private var maxTextWidth: CGFloat = UIScreen.main.bounds.width
    private var layoutKey = ""
    private var currentMsgID = ""
    private var currentRevealedLength = 0
    private var lastTextHeight: CGFloat = 0
    private var renderCache: RenderCache?
    private var lastDisplayedText: NSAttributedString?

    public override init(frame: CGRect) {
        super.init(frame: frame)
        addSubview(textView)
        textView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
            widthConstraint = make.width.lessThanOrEqualTo(maxTextWidth).constraint
        }
        setupTextViewStyle()
    }

    public convenience init() {
        self.init(frame: .zero)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    public var isDisplayingText: Bool {
        return !textView.isHidden
    }

    public static func discardProgress(msgID: String) {
        StreamTextPacer.shared.discard(msgID: msgID)
    }

    public static func isRevealing(msgID: String) -> Bool {
        return StreamTextPacer.shared.isRevealing(msgID: msgID)
    }

    public func bind(msgID: String,
                     markdown: String,
                     isStreaming: Bool,
                     textColor: UIColor,
                     maxTextWidth: CGFloat,
                     layoutKey: String,
                     revealLimiter: StreamRevealLimiter? = nil,
                     maxCharactersPerSecond: Double = 0) {
        self.maxTextWidth = maxTextWidth
        widthConstraint?.update(offset: maxTextWidth)
        self.layoutKey = "\(maxTextWidth)|\(layoutKey)"
        if !currentMsgID.isEmpty, currentMsgID != msgID {
            StreamTextPacer.shared.detach(msgID: currentMsgID, listener: self)
            renderCache = nil
            lastDisplayedText = nil
        }
        currentMsgID = msgID
        let cache = renderedText(markdown, isStreaming: isStreaming, textColor: textColor)
        let revealedLength = StreamTextPacer.shared.revealedLength(
            msgID: msgID,
            rendered: cache.result.attributedText,
            stableLength: cache.result.stableLength,
            isStreaming: isStreaming,
            limiter: revealLimiter,
            maxCharactersPerSecond: maxCharactersPerSecond,
            listener: self
        )
        currentRevealedLength = revealedLength
        applyText(displayText(of: cache, revealedLength: revealedLength), notifyHeightChange: false)
    }

    public func recycle() {
        if !currentMsgID.isEmpty {
            StreamTextPacer.shared.detach(msgID: currentMsgID, listener: self)
            currentMsgID = ""
        }
        textView.text = nil
        renderCache = nil
        lastDisplayedText = nil
        lastTextHeight = 0
    }

    public func linkURL(at point: CGPoint) -> URL? {
        guard !textView.isHidden, let attributedText = textView.attributedText else { return nil }
        let pointInText = convert(point, to: textView)
        let layoutManager = textView.layoutManager
        let textContainer = textView.textContainer
        let glyphIndex = layoutManager.glyphIndex(for: pointInText, in: textContainer)
        let glyphRect = layoutManager.boundingRect(forGlyphRange: NSRange(location: glyphIndex, length: 1), in: textContainer)
        guard glyphRect.insetBy(dx: -Self.linkHitSlop, dy: -Self.linkHitSlop).contains(pointInText) else { return nil }
        let characterIndex = layoutManager.characterIndexForGlyph(at: glyphIndex)
        guard characterIndex < attributedText.length else { return nil }
        return attributedText.attribute(.link, at: characterIndex, effectiveRange: nil) as? URL
    }

    public override func layoutSubviews() {
        super.layoutSubviews()
        learnActualTextWidthIfNeeded()
    }

    private var workingTextWidth: CGFloat {
        return min(maxTextWidth, Self.learnedTextWidths[layoutKey] ?? maxTextWidth)
    }

    private func renderedText(_ text: String, isStreaming: Bool, textColor: UIColor) -> RenderCache {
        if let cache = renderCache, cache.text == text, cache.isStreaming == isStreaming, cache.textColor == textColor {
            return cache
        }
        let result = text.isEmpty
            ? MarkdownRenderResult(attributedText: NSAttributedString(), stableLength: 0)
            : MarkdownRenderer.renderResult(markdown: text, isStreaming: isStreaming, textColor: textColor)
        let cache = RenderCache(text: text, isStreaming: isStreaming, textColor: textColor, result: result)
        renderCache = cache
        return cache
    }

    private func learnActualTextWidthIfNeeded() {
        guard let cache = renderCache, !textView.isHidden else { return }
        let actualWidth = textView.bounds.width
        guard actualWidth > 0, actualWidth < workingTextWidth - Self.widthTolerance, hasSoftWrap() else { return }
        Self.learnedTextWidths[layoutKey] = actualWidth
        lastDisplayedText = nil
        applyText(displayText(of: cache, revealedLength: currentRevealedLength), notifyHeightChange: true, deferNotification: true)
    }

    private func hasSoftWrap() -> Bool {
        let layoutManager = textView.layoutManager
        let string = textView.textStorage.string as NSString
        layoutManager.ensureLayout(for: textView.textContainer)
        var glyphIndex = 0
        while glyphIndex < layoutManager.numberOfGlyphs {
            var lineGlyphRange = NSRange()
            layoutManager.lineFragmentRect(forGlyphAt: glyphIndex, effectiveRange: &lineGlyphRange)
            let lineEnd = NSMaxRange(layoutManager.characterRange(forGlyphRange: lineGlyphRange, actualGlyphRange: nil))
            if lineEnd > 0, lineEnd < string.length, !Self.isHardBreak(string.character(at: lineEnd - 1)) {
                return true
            }
            glyphIndex = NSMaxRange(lineGlyphRange)
        }
        return false
    }

    private static func isHardBreak(_ character: unichar) -> Bool {
        return character == newlineCharacter || character == lineSeparatorCharacter
    }

    private func displayText(of cache: RenderCache, revealedLength: Int) -> NSAttributedString {
        let rendered = cache.result.attributedText
        let string = rendered.string as NSString
        var end = min(revealedLength, rendered.length)
        while end > 0, string.character(at: end - 1) == Self.newlineCharacter {
            end -= 1
        }
        guard end > 0 else { return NSAttributedString() }
        let prefix = NSMutableAttributedString(attributedString: rendered.attributedSubstring(from: NSRange(location: 0, length: end)))
        removeTrailingParagraphSpacing(prefix)
        for offset in softBreakOffsets(of: cache).reversed() where offset < end {
            let attributes = prefix.attributes(at: offset - 1, effectiveRange: nil)
            prefix.insert(NSAttributedString(string: Self.lineSeparator, attributes: attributes), at: offset)
        }
        return prefix
    }

    private func removeTrailingParagraphSpacing(_ prefix: NSMutableAttributedString) {
        let lastParagraph = (prefix.string as NSString).paragraphRange(for: NSRange(location: prefix.length - 1, length: 0))
        prefix.enumerateAttribute(.paragraphStyle, in: lastParagraph) { value, range, _ in
            guard let style = (value as? NSParagraphStyle)?.mutableCopy() as? NSMutableParagraphStyle else { return }
            style.paragraphSpacing = 0
            prefix.addAttribute(.paragraphStyle, value: style, range: range)
        }
    }

    private func softBreakOffsets(of cache: RenderCache) -> [Int] {
        let width = workingTextWidth
        if cache.softBreakWidth == width {
            return cache.softBreakOffsets
        }
        cache.softBreakWidth = width
        cache.softBreakOffsets = Self.measureSoftBreakOffsets(cache.result.attributedText, width: width)
        return cache.softBreakOffsets
    }

    private static func measureSoftBreakOffsets(_ text: NSAttributedString, width: CGFloat) -> [Int] {
        guard text.length > 0, width > 0 else { return [] }
        let storage = NSTextStorage(attributedString: text)
        let layoutManager = NSLayoutManager()
        storage.addLayoutManager(layoutManager)
        defer { withExtendedLifetime(storage) {} }
        let container = NSTextContainer(size: CGSize(width: width, height: .greatestFiniteMagnitude))
        container.lineFragmentPadding = 0
        container.lineBreakMode = .byWordWrapping
        layoutManager.addTextContainer(container)
        layoutManager.ensureLayout(for: container)
        let string = text.string as NSString
        var offsets: [Int] = []
        var glyphIndex = 0
        while glyphIndex < layoutManager.numberOfGlyphs {
            var lineGlyphRange = NSRange()
            layoutManager.lineFragmentRect(forGlyphAt: glyphIndex, effectiveRange: &lineGlyphRange)
            let characterRange = layoutManager.characterRange(forGlyphRange: lineGlyphRange, actualGlyphRange: nil)
            let lineEnd = NSMaxRange(characterRange)
            if lineEnd > 0, lineEnd < string.length, string.character(at: lineEnd - 1) != newlineCharacter {
                offsets.append(lineEnd)
            }
            glyphIndex = NSMaxRange(lineGlyphRange)
        }
        return offsets
    }

    private func applyText(_ displayText: NSAttributedString, notifyHeightChange: Bool, deferNotification: Bool = false) {
        if let lastDisplayedText, lastDisplayedText.isEqual(to: displayText) { return }
        lastDisplayedText = displayText
        textView.isHidden = displayText.length == 0
        if displayText.length == 0 {
            textView.text = nil
        } else {
            textView.attributedText = displayText
        }
        invalidateIntrinsicContentSize()
        let textHeight = textView.sizeThatFits(CGSize(width: workingTextWidth, height: .greatestFiniteMagnitude)).height
        let heightChanged = abs(textHeight - lastTextHeight) > Self.heightTolerance
        lastTextHeight = textHeight
        guard notifyHeightChange, heightChanged else { return }
        if deferNotification {
            DispatchQueue.main.async { [weak self] in
                self?.onDisplayedHeightChange?()
            }
        } else {
            onDisplayedHeightChange?()
        }
    }

    private static func makeTextView() -> UITextView {
        if #available(iOS 16.0, *) {
            return UITextView(usingTextLayoutManager: false)
        }
        return UITextView()
    }

    private func setupTextViewStyle() {
        textView.isEditable = false
        textView.isScrollEnabled = false
        textView.isSelectable = false
        textView.isUserInteractionEnabled = false
        textView.backgroundColor = .clear
        textView.textContainerInset = .zero
        textView.textContainer.lineFragmentPadding = 0
        textView.textContainer.maximumNumberOfLines = 0
        textView.textContainer.lineBreakMode = .byWordWrapping
    }
}

extension StreamingMarkdownView: StreamTextPacerListener {
    func streamTextPacer(_ pacer: StreamTextPacer, didAdvance msgID: String, revealedLength: Int) {
        guard msgID == currentMsgID, let cache = renderCache else { return }
        currentRevealedLength = revealedLength
        applyText(displayText(of: cache, revealedLength: revealedLength), notifyHeightChange: true)
    }
}

