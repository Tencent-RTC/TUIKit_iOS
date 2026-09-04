import UIKit

final class AtomicIndexBarView: UIView {
    var onLetterSelected: ((String) -> Void)?

    var onDragStart: (() -> Void)?

    var onDragEnd: (() -> Void)?

    override var intrinsicContentSize: CGSize {
        if letters.isEmpty {
            return CGSize(width: Self.barWidth, height: 0)
        }
        let contentHeight = CGFloat(letters.count) * Self.letterSlotHeight
            + CGFloat(letters.count - 1) * Self.letterSpacing
            + Self.verticalPadding * 2
        return CGSize(width: Self.barWidth, height: contentHeight)
    }

    private static let barWidth: CGFloat = 24

    private static let letterSlotHeight: CGFloat = 16

    private static let letterSpacing: CGFloat = 1

    private static let verticalPadding: CGFloat = CGFloat(SpacingScheme.smallSpacing)

    private static let highlightedDiameter: CGFloat = 20

    private var letters: [String] = []

    private var currentLetter: String?

    private var draggedLetter: String?

    override init(frame: CGRect) {
        super.init(frame: frame)
        backgroundColor = .clear
        isUserInteractionEnabled = true
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func setLetters(_ letters: [String]) {
        self.letters = letters
        invalidateIntrinsicContentSize()
        setNeedsDisplay()
    }

    func setCurrentLetter(_ letter: String?) {
        if currentLetter != letter {
            currentLetter = letter
            setNeedsDisplay()
        }
    }

    override func draw(_ rect: CGRect) {
        guard !letters.isEmpty, let context = UIGraphicsGetCurrentContext() else { return }
        let colors = TUIChatKitTheme.colors
        let centerX = bounds.width / 2

        for (index, letter) in letters.enumerated() {
            let slotTop = Self.verticalPadding + CGFloat(index) * (Self.letterSlotHeight + Self.letterSpacing)
            let centerY = slotTop + Self.letterSlotHeight / 2
            let isDragged = draggedLetter == letter
            let isCurrent = draggedLetter == nil && currentLetter == letter
            let isHighlighted = isDragged || isCurrent

            let textColor = isHighlighted ? colors.textColorButton : colors.textColorLink
            if isHighlighted {
                context.setFillColor(colors.textColorLink.cgColor)
                let circleRect = CGRect(
                    x: centerX - Self.highlightedDiameter / 2,
                    y: centerY - Self.highlightedDiameter / 2,
                    width: Self.highlightedDiameter,
                    height: Self.highlightedDiameter
                )
                context.fillEllipse(in: circleRect)
            }

            let attributes: [NSAttributedString.Key: Any] = [
                .font: FontScheme.caption3Regular,
                .foregroundColor: textColor,
            ]
            let textSize = (letter as NSString).size(withAttributes: attributes)
            let textRect = CGRect(
                x: centerX - textSize.width / 2,
                y: centerY - textSize.height / 2,
                width: textSize.width,
                height: textSize.height
            )
            (letter as NSString).draw(in: textRect, withAttributes: attributes)
        }
    }

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let touch = touches.first else { return }
        onDragStart?()
        updateDraggedLetter(at: touch.location(in: self).y, notify: true)
    }

    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let touch = touches.first else { return }
        updateDraggedLetter(at: touch.location(in: self).y, notify: true)
    }

    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        draggedLetter = nil
        setNeedsDisplay()
        onDragEnd?()
    }

    override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?) {
        draggedLetter = nil
        setNeedsDisplay()
        onDragEnd?()
    }

    private func updateDraggedLetter(at y: CGFloat, notify: Bool) {
        guard let letter = letter(at: y) else { return }
        if draggedLetter != letter {
            draggedLetter = letter
            setNeedsDisplay()
            if notify {
                onLetterSelected?(letter)
            }
        }
    }

    private func letter(at y: CGFloat) -> String? {
        guard !letters.isEmpty else { return nil }
        let step = Self.letterSlotHeight + Self.letterSpacing
        let relativeY = y - Self.verticalPadding
        if relativeY <= 0 {
            return letters.first
        }
        let index = Int(relativeY / step)
        if index >= letters.count {
            return letters.last
        }
        return letters[index]
    }
}
