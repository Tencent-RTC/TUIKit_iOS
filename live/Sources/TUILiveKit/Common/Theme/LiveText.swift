import UIKit

final class LiveText: UILabel {
    var role: LiveTheme.TextRole {
        didSet { applyFont() }
    }

    var tone: LiveTheme.TextTone {
        didSet { textColor = LiveTheme.Color.text(tone) }
    }

    var isEmphasized: Bool {
        didSet { applyFont() }
    }

    init(
        _ role: LiveTheme.TextRole,
        text: String? = nil,
        tone: LiveTheme.TextTone = .primary,
        alignment: NSTextAlignment = .left,
        emphasized: Bool = false
    ) {
        self.role = role
        self.tone = tone
        isEmphasized = emphasized
        super.init(frame: .zero)
        self.text = text
        textAlignment = alignment
        textColor = LiveTheme.Color.text(tone)
        applyFont()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func applyFont() {
        font = LiveTheme.Typography.font(for: role, emphasized: isEmphasized)
    }

    func setText(_ text: String, lineHeight: CGFloat) {
        let paragraph = NSMutableParagraphStyle()
        paragraph.minimumLineHeight = lineHeight
        paragraph.maximumLineHeight = lineHeight
        attributedText = NSAttributedString(string: text, attributes: [
            .paragraphStyle: paragraph,
        ])
    }
}
