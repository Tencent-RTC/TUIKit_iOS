import UIKit

// MARK: - Message List Background

public enum MessageListBackground {
    case color(UIColor)
    case gradient(colors: [UIColor], startPoint: CGPoint, endPoint: CGPoint)
    case image(UIImage)
}

// MARK: - Message Bubble Background

public enum MessageBubbleBackground {
    case color(UIColor)
    case gradient(colors: [UIColor], startPoint: CGPoint, endPoint: CGPoint)
    case image(UIImage)
}

// MARK: - Message Bubble Corner Radius

public struct MessageBubbleCornerRadius {
    public var topLeft: CGFloat?
    public var topRight: CGFloat?
    public var bottomLeft: CGFloat?
    public var bottomRight: CGFloat?

    public init(topLeft: CGFloat? = nil, topRight: CGFloat? = nil, bottomLeft: CGFloat? = nil, bottomRight: CGFloat? = nil) {
        self.topLeft = topLeft
        self.topRight = topRight
        self.bottomLeft = bottomLeft
        self.bottomRight = bottomRight
    }
}

// MARK: - Message Bubble Stroke

public struct MessageBubbleStroke {
    public var width: CGFloat
    public var color: UIColor

    public init(width: CGFloat, color: UIColor) {
        self.width = width
        self.color = color
    }
}

// MARK: - Message Bubble Size

public struct MessageBubbleSize {
    public var width: CGFloat?
    public var height: CGFloat?

    public init(width: CGFloat? = nil, height: CGFloat? = nil) {
        self.width = width
        self.height = height
    }
}

// MARK: - Message Bubble Appearance

public struct MessageBubbleAppearance {
    public var background: MessageBubbleBackground?
    public var cornerRadius: MessageBubbleCornerRadius?
    public var stroke: MessageBubbleStroke?
    public var contentInsets: UIEdgeInsets?
    public var minimumSize: MessageBubbleSize?

    public init(
        background: MessageBubbleBackground? = nil,
        cornerRadius: MessageBubbleCornerRadius? = nil,
        stroke: MessageBubbleStroke? = nil,
        contentInsets: UIEdgeInsets? = nil,
        minimumSize: MessageBubbleSize? = nil
    ) {
        self.background = background
        self.cornerRadius = cornerRadius
        self.stroke = stroke
        self.contentInsets = contentInsets
        self.minimumSize = minimumSize
    }

    public func merged(over base: MessageBubbleAppearance?) -> MessageBubbleAppearance {
        guard let base = base else { return self }
        return MessageBubbleAppearance(
            background: background ?? base.background,
            cornerRadius: cornerRadius ?? base.cornerRadius,
            stroke: stroke ?? base.stroke,
            contentInsets: contentInsets ?? base.contentInsets,
            minimumSize: minimumSize ?? base.minimumSize
        )
    }
}
