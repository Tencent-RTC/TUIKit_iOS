import Foundation
import UIKit

extension MessageBubbleCornerRadius {
    public init(topLeft: CGFloat? = nil, topRight: CGFloat? = nil, bottomLeft: CGFloat? = nil, bottomRight: CGFloat? = nil) {
        self.userTopLeft = topLeft
        self.userTopRight = topRight
        self.userBottomLeft = bottomLeft
        self.userBottomRight = bottomRight
    }

    public var topLeft: CGFloat? {
        get { userTopLeft }
        set { userTopLeft = newValue }
    }

    public var topRight: CGFloat? {
        get { userTopRight }
        set { userTopRight = newValue }
    }

    public var bottomLeft: CGFloat? {
        get { userBottomLeft }
        set { userBottomLeft = newValue }
    }

    public var bottomRight: CGFloat? {
        get { userBottomRight }
        set { userBottomRight = newValue }
    }
}

extension MessageBubbleStroke {
    public init(width: CGFloat, color: UIColor) {
        self.userWidth = width
        self.userColor = color
    }

    public var width: CGFloat {
        get { userWidth ?? 0 }
        set { userWidth = newValue }
    }

    public var color: UIColor {
        get { userColor ?? .clear }
        set { userColor = newValue }
    }
}

extension MessageBubbleSize {
    public init(width: CGFloat? = nil, height: CGFloat? = nil) {
        self.userWidth = width
        self.userHeight = height
    }

    public var width: CGFloat? {
        get { userWidth }
        set { userWidth = newValue }
    }

    public var height: CGFloat? {
        get { userHeight }
        set { userHeight = newValue }
    }
}

extension MessageBubbleAppearance {
    public init(
        background: MessageBubbleBackground? = nil,
        cornerRadius: MessageBubbleCornerRadius? = nil,
        stroke: MessageBubbleStroke? = nil,
        contentInsets: UIEdgeInsets? = nil,
        minimumSize: MessageBubbleSize? = nil
    ) {
        self.userBackground = background
        self.userCornerRadius = cornerRadius
        self.userStroke = stroke
        self.userContentInsets = contentInsets
        self.userMinimumSize = minimumSize
    }

    public var background: MessageBubbleBackground? {
        get { userBackground }
        set { userBackground = newValue }
    }

    public var cornerRadius: MessageBubbleCornerRadius? {
        get { userCornerRadius }
        set { userCornerRadius = newValue }
    }

    public var stroke: MessageBubbleStroke? {
        get { userStroke }
        set { userStroke = newValue }
    }

    public var contentInsets: UIEdgeInsets? {
        get { userContentInsets }
        set { userContentInsets = newValue }
    }

    public var minimumSize: MessageBubbleSize? {
        get { userMinimumSize }
        set { userMinimumSize = newValue }
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
