import UIKit

final class MessageBubbleContainerView: UIView {
    var isLeftBubble = true

    var isCustomMaskEnabled = false

    override func layoutSubviews() {
        super.layoutSubviews()
        guard isCustomMaskEnabled else { return }
        MessageBubbleStyler.updateBubbleMask(for: self, isLeft: isLeftBubble)
    }
}

struct BubbleHighlightSpec {
    let color: UIColor
    let maxAlpha: CGFloat
}

enum MessageBubbleStyler {

    static let cornerRadius: CGFloat = 10

    static let avatarSideTopCornerRadius: CGFloat = 2

    static let highlightMaxAlpha: CGFloat = 72 / 255

    static let highlightDarkBubbleMaxAlpha: CGFloat = 128 / 255

    static let highlightDarkBubbleLuminanceThreshold: CGFloat = 0.5

    static let highlightDarkBubbleLightenRatio: CGFloat = 0.4

    static let highlightFlashDuration: TimeInterval = 0.26

    static let highlightFlashCount = 3

    static func highlightSpec(bubbleColor: UIColor, traitCollection: UITraitCollection) -> BubbleHighlightSpec {
        var red: CGFloat = 0
        var green: CGFloat = 0
        var blue: CGFloat = 0
        var alpha: CGFloat = 0
        bubbleColor.resolvedColor(with: traitCollection).getRed(&red, green: &green, blue: &blue, alpha: &alpha)
        let luminance = 0.299 * red + 0.587 * green + 0.114 * blue
        let isDarkBubble = luminance < highlightDarkBubbleLuminanceThreshold
        var warningRed: CGFloat = 0
        var warningGreen: CGFloat = 0
        var warningBlue: CGFloat = 0
        var warningAlpha: CGFloat = 0
        ChatUIKitTheme.colors.textColorWarning.resolvedColor(with: traitCollection).getRed(&warningRed, green: &warningGreen, blue: &warningBlue, alpha: &warningAlpha)
        let lightenRatio = isDarkBubble ? highlightDarkBubbleLightenRatio : 0
        let flashColor = UIColor(
            red: warningRed + (1 - warningRed) * lightenRatio,
            green: warningGreen + (1 - warningGreen) * lightenRatio,
            blue: warningBlue + (1 - warningBlue) * lightenRatio,
            alpha: warningAlpha
        )
        return BubbleHighlightSpec(
            color: flashColor,
            maxAlpha: isDarkBubble ? highlightDarkBubbleMaxAlpha : highlightMaxAlpha
        )
    }

    static func apply(to bubble: UIView, isSelf: Bool, isLeft: Bool) {
        bubble.clipsToBounds = true
        let colors = ChatUIKitTheme.colors
        bubble.backgroundColor = isSelf ? colors.bgColorBubbleOwn : colors.bgColorBubbleReciprocal
        updateBubbleMask(for: bubble, isLeft: isLeft)
    }

    static func updateBubbleMask(for bubble: UIView, isLeft: Bool) {
        guard bubble.bounds.width > 0, bubble.bounds.height > 0 else { return }
        let maskLayer = CAShapeLayer()
        let isRTL = bubble.effectiveUserInterfaceLayoutDirection == .rightToLeft
        maskLayer.path = bubblePath(in: bubble.bounds, isLeft: isLeft != isRTL).cgPath
        bubble.layer.mask = maskLayer
    }

    static func squaredCornerMask(isLeft: Bool) -> CACornerMask {
        if isLeft {
            return [.layerMaxXMinYCorner, .layerMinXMaxYCorner, .layerMaxXMaxYCorner]
        }
        return [.layerMinXMinYCorner, .layerMinXMaxYCorner, .layerMaxXMaxYCorner]
    }

    private static func bubblePath(in rect: CGRect, isLeft: Bool) -> UIBezierPath {
        let big = cornerRadius
        let small = avatarSideTopCornerRadius
        let path = UIBezierPath()
        if isLeft {
            path.move(to: CGPoint(x: rect.minX + small, y: rect.minY))
            path.addLine(to: CGPoint(x: rect.maxX - big, y: rect.minY))
            path.addArc(withCenter: CGPoint(x: rect.maxX - big, y: rect.minY + big), radius: big,
                        startAngle: -.pi / 2, endAngle: 0, clockwise: true)
            path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY - big))
            path.addArc(withCenter: CGPoint(x: rect.maxX - big, y: rect.maxY - big), radius: big,
                        startAngle: 0, endAngle: .pi / 2, clockwise: true)
            path.addLine(to: CGPoint(x: rect.minX + big, y: rect.maxY))
            path.addArc(withCenter: CGPoint(x: rect.minX + big, y: rect.maxY - big), radius: big,
                        startAngle: .pi / 2, endAngle: .pi, clockwise: true)
            path.addLine(to: CGPoint(x: rect.minX, y: rect.minY + small))
            path.addArc(withCenter: CGPoint(x: rect.minX + small, y: rect.minY + small), radius: small,
                        startAngle: .pi, endAngle: -.pi / 2, clockwise: true)
        } else {
            path.move(to: CGPoint(x: rect.minX + big, y: rect.minY))
            path.addLine(to: CGPoint(x: rect.maxX - small, y: rect.minY))
            path.addArc(withCenter: CGPoint(x: rect.maxX - small, y: rect.minY + small), radius: small,
                        startAngle: -.pi / 2, endAngle: 0, clockwise: true)
            path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY - big))
            path.addArc(withCenter: CGPoint(x: rect.maxX - big, y: rect.maxY - big), radius: big,
                        startAngle: 0, endAngle: .pi / 2, clockwise: true)
            path.addLine(to: CGPoint(x: rect.minX + big, y: rect.maxY))
            path.addArc(withCenter: CGPoint(x: rect.minX + big, y: rect.maxY - big), radius: big,
                        startAngle: .pi / 2, endAngle: .pi, clockwise: true)
            path.addLine(to: CGPoint(x: rect.minX, y: rect.minY + big))
            path.addArc(withCenter: CGPoint(x: rect.minX + big, y: rect.minY + big), radius: big,
                        startAngle: .pi, endAngle: -.pi / 2, clockwise: true)
        }
        path.close()
        return path
    }
}
