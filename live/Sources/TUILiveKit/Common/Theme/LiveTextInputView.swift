import UIKit

/// Multiline input shared by the live topic editor and comment composer.
final class LiveTextInputView: UITextView, UITextViewDelegate {
    enum LimitUnit {
        case characters
        case utf8Bytes
    }

    var onTextChanged: (() -> Void)?
    var onSubmit: (() -> Void)?
    var onLimitExceeded: (() -> Void)?
    var placeholder: String = "" {
        didSet { placeholderLabel.text = placeholder }
    }

    private let inputLimit: Int
    private let limitUnit: LimitUnit
    private let maximumLines: Int
    private let minimumHeight: CGFloat
    private let placeholderLabel = UILabel()
    private var lastWidth: CGFloat = 0
    private var committedText = ""
    private var pendingEdit: (text: String, range: NSRange, replacement: String)?

    init(limit: Int, unit: LimitUnit = .characters, maximumLines: Int, minimumHeight: CGFloat) {
        self.inputLimit = limit
        self.limitUnit = unit
        self.maximumLines = maximumLines
        self.minimumHeight = minimumHeight
        super.init(frame: .zero, textContainer: nil)
        delegate = self
        backgroundColor = .clear
        textContainerInset = .zero
        textContainer.lineFragmentPadding = 0
        textContainer.lineBreakMode = .byCharWrapping
        isScrollEnabled = false
        showsVerticalScrollIndicator = false
        placeholderLabel.textColor = UIColor.white.withAlphaComponent(0.4)
        placeholderLabel.isUserInteractionEnabled = false
        addSubview(placeholderLabel)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override var intrinsicContentSize: CGSize {
        CGSize(width: UIView.noIntrinsicMetric, height: fittedHeight)
    }

    private var fittedHeight: CGFloat {
        guard bounds.width > 0 else { return minimumHeight }
        let naturalHeight = sizeThatFits(CGSize(width: bounds.width, height: .greatestFiniteMagnitude)).height
        let maximumHeight = ceil((font?.lineHeight ?? 20) * CGFloat(maximumLines))
        return max(minimumHeight, min(ceil(naturalHeight), maximumHeight))
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        placeholderLabel.font = font
        placeholderLabel.textAlignment = textAlignment
        placeholderLabel.frame = CGRect(x: 0, y: 0, width: bounds.width, height: font?.lineHeight ?? 20)
        if lastWidth != bounds.width {
            lastWidth = bounds.width
            refresh()
        }
    }

    func setContent(_ content: String) {
        text = limitedPrefix(content, budget: inputLimit)
        committedText = text
        pendingEdit = nil
        refresh()
    }

    private func inputLength(_ value: String) -> Int {
        limitUnit == .utf8Bytes ? value.utf8.count : value.count
    }

    private func limitedPrefix(_ value: String, budget: Int) -> String {
        var remaining = max(0, budget)
        return String(value.prefix { character in
            let length = inputLength(String(character))
            guard length <= remaining else { return false }
            remaining -= length
            return true
        })
    }

    private func refresh() {
        placeholderLabel.isHidden = !text.isEmpty
        if bounds.width > 0 {
            let naturalHeight = sizeThatFits(CGSize(width: bounds.width, height: .greatestFiniteMagnitude)).height
            isScrollEnabled = naturalHeight > fittedHeight + 0.5
        }
        invalidateIntrinsicContentSize()
        setNeedsLayout()
        onTextChanged?()
    }

    func textView(_ textView: UITextView, shouldChangeTextIn range: NSRange, replacementText replacement: String) -> Bool {
        if replacement == "\n", markedTextRange == nil {
            onSubmit?()
            return false
        }
        pendingEdit = (text, range, replacement)
        return true
    }

    func textViewDidChange(_ textView: UITextView) {
        // Wait until the input method commits its candidate before counting characters.
        guard markedTextRange == nil else {
            refresh()
            return
        }
        if inputLength(text) > inputLimit {
            if let edit = pendingEdit,
               inputLength(edit.text) <= inputLimit,
               let range = Range(edit.range, in: edit.text),
               edit.text.replacingCharacters(in: range, with: edit.replacement) == text {
                let available = inputLimit - inputLength(edit.text) + inputLength(String(edit.text[range]))
                let accepted = limitedPrefix(edit.replacement, budget: available)
                text = edit.text.replacingCharacters(in: range, with: accepted)
                selectedRange = NSRange(location: edit.range.location + accepted.utf16.count, length: 0)
            } else {
                // A candidate may have changed several times. Keep the unchanged
                // text on both sides and limit only the newly committed content.
                let previous = Array(committedText)
                let updated = Array(text!)
                let prefixCount = zip(previous, updated).prefix { $0.0 == $0.1 }.count
                let suffixCount = zip(previous.dropFirst(prefixCount).reversed(), updated.dropFirst(prefixCount).reversed())
                    .prefix { $0.0 == $0.1 }.count
                let prefix = String(updated.prefix(prefixCount))
                let suffix = String(updated.suffix(suffixCount))
                let available = max(0, inputLimit - inputLength(prefix) - inputLength(suffix))
                let accepted = limitedPrefix(String(updated.dropFirst(prefixCount).dropLast(suffixCount)), budget: available)
                text = prefix + accepted + suffix
                selectedRange = NSRange(location: prefix.utf16.count + accepted.utf16.count, length: 0)
            }
            onLimitExceeded?()
        }
        pendingEdit = nil
        committedText = text
        refresh()
        scrollRangeToVisible(selectedRange)
    }

    func textViewDidEndEditing(_ textView: UITextView) {
        textViewDidChange(textView)
    }
}
