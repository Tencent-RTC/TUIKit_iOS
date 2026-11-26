import UIKit

final class TypewriterLabel: UILabel {

    var formatText: ((String) -> NSAttributedString)? {
        didSet { renderText() }
    }
    var showCaret = false {
        didSet { updateCaretAnimation() }
    }
    var showLastLineOnly = false {
        didSet {
            numberOfLines = showLastLineOnly ? 1 : 0
            lineBreakMode = showLastLineOnly ? .byTruncatingHead : .byTruncatingTail
            renderText()
        }
    }

    private var contentId = ""
    private var targetText = ""
    private var displayedText = ""
    private var renderedText = ""
    private var previousWidth: CGFloat = -1
    private var isStreaming = false
    private var typewriterTimer: Timer?
    private var caretTimer: Timer?
    private let caretView = UIView()

    override init(frame: CGRect) {
        super.init(frame: frame)
        setupViews()
        setupStyles()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override var isHidden: Bool {
        didSet {
            if isHidden { stopAnimations() } else { resumeAnimations() }
        }
    }

    override func layoutSubviews() {
        let widthChanged = bounds.width != previousWidth
        previousWidth = bounds.width
        if widthChanged && showLastLineOnly { renderText() }
        super.layoutSubviews()
        caretView.backgroundColor = textColor
        let textWidth = min(renderedText.size(withAttributes: [.font: font as Any]).width, max(0, bounds.width - 5))
        let caretHeight = font.pointSize * 0.95
        caretView.frame = CGRect(
            x: textWidth + 3,
            y: (bounds.height - caretHeight) / 2,
            width: 2,
            height: caretHeight
        )
    }

    override func didMoveToWindow() {
        super.didMoveToWindow()
        if window == nil { stopAnimations() } else { resumeAnimations() }
    }

    func updateText(contentId: String, text: String, isStreaming: Bool) {
        if self.contentId != contentId {
            stopTypewriter()
            self.contentId = contentId
            displayedText = ""
            renderText()
        }
        targetText = text
        self.isStreaming = isStreaming
        guard isStreaming, !text.isEmpty else {
            stopTypewriter()
            displayedText = targetText
            renderText()
            stopCaret()
            return
        }
        if displayedText != text && !text.hasPrefix(displayedText) {
            displayedText = String(displayedText.prefix(displayedText.commonPrefix(with: text).count))
            renderText()
        }
        resumeAnimations()
    }

    func stopAnimations() {
        stopTypewriter()
        stopCaret()
        displayedText = targetText
        renderText()
    }

    private func setupViews() {
        addSubview(caretView)
    }

    private func setupStyles() {
        numberOfLines = 0
        caretView.isHidden = true
    }

    private func renderText() {
        renderedText = showLastLineOnly ? lastLine(displayedText) : displayedText
        if let formatText {
            attributedText = formatText(renderedText)
        } else {
            text = renderedText
        }
        setNeedsLayout()
    }

    private func lastLine(_ value: String) -> String {
        guard !value.isEmpty, bounds.width > 0 else { return value }
        let textStorage = NSTextStorage(
            string: value,
            attributes: [.font: font as Any]
        )
        let layoutManager = NSLayoutManager()
        let textContainer = NSTextContainer(
            size: CGSize(width: bounds.width, height: .greatestFiniteMagnitude)
        )
        textContainer.lineFragmentPadding = 0
        textContainer.lineBreakMode = .byWordWrapping
        layoutManager.addTextContainer(textContainer)
        textStorage.addLayoutManager(layoutManager)
        layoutManager.ensureLayout(for: textContainer)
        let lastGlyph = layoutManager.numberOfGlyphs - 1
        guard lastGlyph >= 0 else { return value }
        let lastLineY = layoutManager.lineFragmentRect(
            forGlyphAt: lastGlyph,
            effectiveRange: nil
        ).minY
        var low = 0
        var high = lastGlyph
        while low < high {
            let middle = (low + high) / 2
            let lineY = layoutManager.lineFragmentRect(
                forGlyphAt: middle,
                effectiveRange: nil
            ).minY
            if lineY < lastLineY {
                low = middle + 1
            } else {
                high = middle
            }
        }
        let characterIndex = layoutManager.characterIndexForGlyph(at: low)
        return (value as NSString).substring(from: characterIndex)
    }

    private func resumeAnimations() {
        guard isStreaming, !isHidden, window != nil else { return }
        startTypewriter()
        updateCaretAnimation()
    }

    private func startTypewriter() {
        guard typewriterTimer == nil, displayedText.count < targetText.count else { return }
        advanceTypewriter()
        guard displayedText.count < targetText.count else { return }
        let timer = Timer(timeInterval: 0.05, repeats: true) { [weak self] _ in
            self?.advanceTypewriter()
        }
        typewriterTimer = timer
        RunLoop.main.add(timer, forMode: .common)
    }

    private func advanceTypewriter() {
        guard isStreaming, !isHidden, window != nil else {
            stopTypewriter()
            return
        }
        guard displayedText.count < targetText.count else {
            stopTypewriter()
            return
        }
        let end = targetText.index(targetText.startIndex, offsetBy: displayedText.count + 1)
        displayedText = String(targetText[..<end])
        renderText()
    }

    private func stopTypewriter() {
        typewriterTimer?.invalidate()
        typewriterTimer = nil
    }

    private func updateCaretAnimation() {
        let shouldAnimate = showCaret && isStreaming && !isHidden && window != nil
        if shouldAnimate {
            startCaret()
        } else {
            stopCaret()
        }
    }

    private func startCaret() {
        caretView.isHidden = false
        caretView.alpha = 0.7
        guard caretTimer == nil else { return }
        let timer = Timer(timeInterval: 0.45, repeats: true) { [weak self] _ in
            guard let self else { return }
            self.caretView.alpha = self.caretView.alpha > 0 ? 0 : 0.7
        }
        caretTimer = timer
        RunLoop.main.add(timer, forMode: .common)
    }

    private func stopCaret() {
        caretTimer?.invalidate()
        caretTimer = nil
        caretView.isHidden = true
    }
}
