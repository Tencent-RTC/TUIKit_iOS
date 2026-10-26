import UIKit

extension MessageInputAppearance {
    public init(
        fill: MessageInputFill? = nil,
        showTopDivider: Bool? = nil,
        field: MessageInputFieldAppearance? = nil,
        audioRecordButton: MessageInputButtonAppearance? = nil,
        emojiButton: MessageInputButtonAppearance? = nil,
        moreButton: MessageInputButtonAppearance? = nil,
        sendButton: MessageInputButtonAppearance? = nil,
        morePanel: MessageInputMorePanelAppearance? = nil
    ) {
        self.userFill = fill
        self.userShowTopDivider = showTopDivider
        self.userField = field
        self.userAudioRecordButton = audioRecordButton
        self.userEmojiButton = emojiButton
        self.userMoreButton = moreButton
        self.userSendButton = sendButton
        self.userMorePanel = morePanel
    }

    public var fill: MessageInputFill? {
        get { userFill }
        set { userFill = newValue }
    }

    public var showTopDivider: Bool? {
        get { userShowTopDivider }
        set { userShowTopDivider = newValue }
    }

    public var field: MessageInputFieldAppearance? {
        get { userField }
        set { userField = newValue }
    }

    public var audioRecordButton: MessageInputButtonAppearance? {
        get { userAudioRecordButton }
        set { userAudioRecordButton = newValue }
    }

    public var emojiButton: MessageInputButtonAppearance? {
        get { userEmojiButton }
        set { userEmojiButton = newValue }
    }

    public var moreButton: MessageInputButtonAppearance? {
        get { userMoreButton }
        set { userMoreButton = newValue }
    }

    public var sendButton: MessageInputButtonAppearance? {
        get { userSendButton }
        set { userSendButton = newValue }
    }

    public var morePanel: MessageInputMorePanelAppearance? {
        get { userMorePanel }
        set { userMorePanel = newValue }
    }
}

extension MessageInputButtonAppearance {
    public static let cornerRadiusPill: CGFloat = -1

    public init(
        width: CGFloat? = nil,
        height: CGFloat? = nil,
        iconSize: CGFloat? = nil,
        cornerRadius: CGFloat? = nil,
        fill: MessageInputFill? = nil,
        iconTint: UIColor? = nil,
        icon: UIImage? = nil,
        activeIcon: UIImage? = nil,
        title: String? = nil,
        titleColor: UIColor? = nil,
        titleSize: CGFloat? = nil,
        horizontalPadding: CGFloat? = nil
    ) {
        self.userWidth = width
        self.userHeight = height
        self.userIconSize = iconSize
        self.userCornerRadius = cornerRadius
        self.userFill = fill
        self.userIconTint = iconTint
        self.userIcon = icon
        self.userActiveIcon = activeIcon
        self.userTitle = title
        self.userTitleColor = titleColor
        self.userTitleSize = titleSize
        self.userHorizontalPadding = horizontalPadding
    }

    public var width: CGFloat? {
        get { userWidth }
        set { userWidth = newValue }
    }

    public var height: CGFloat? {
        get { userHeight }
        set { userHeight = newValue }
    }

    public var iconSize: CGFloat? {
        get { userIconSize }
        set { userIconSize = newValue }
    }

    public var cornerRadius: CGFloat? {
        get { userCornerRadius }
        set { userCornerRadius = newValue }
    }

    public var fill: MessageInputFill? {
        get { userFill }
        set { userFill = newValue }
    }

    public var iconTint: UIColor? {
        get { userIconTint }
        set { userIconTint = newValue }
    }

    public var icon: UIImage? {
        get { userIcon }
        set { userIcon = newValue }
    }

    public var activeIcon: UIImage? {
        get { userActiveIcon }
        set { userActiveIcon = newValue }
    }

    public var title: String? {
        get { userTitle }
        set { userTitle = newValue }
    }

    public var titleColor: UIColor? {
        get { userTitleColor }
        set { userTitleColor = newValue }
    }

    public var titleSize: CGFloat? {
        get { userTitleSize }
        set { userTitleSize = newValue }
    }

    public var horizontalPadding: CGFloat? {
        get { userHorizontalPadding }
        set { userHorizontalPadding = newValue }
    }
}

extension MessageInputFieldAppearance {
    public init(
        fill: MessageInputFill? = nil,
        cornerRadius: CGFloat? = nil,
        minHeight: CGFloat? = nil,
        horizontalPadding: CGFloat? = nil,
        textColor: UIColor? = nil,
        hintColor: UIColor? = nil,
        hintText: String? = nil
    ) {
        self.userFill = fill
        self.userCornerRadius = cornerRadius
        self.userMinHeight = minHeight
        self.userHorizontalPadding = horizontalPadding
        self.userTextColor = textColor
        self.userHintColor = hintColor
        self.userHintText = hintText
    }

    public var fill: MessageInputFill? {
        get { userFill }
        set { userFill = newValue }
    }

    public var cornerRadius: CGFloat? {
        get { userCornerRadius }
        set { userCornerRadius = newValue }
    }

    public var minHeight: CGFloat? {
        get { userMinHeight }
        set { userMinHeight = newValue }
    }

    public var horizontalPadding: CGFloat? {
        get { userHorizontalPadding }
        set { userHorizontalPadding = newValue }
    }

    public var textColor: UIColor? {
        get { userTextColor }
        set { userTextColor = newValue }
    }

    public var hintColor: UIColor? {
        get { userHintColor }
        set { userHintColor = newValue }
    }

    public var hintText: String? {
        get { userHintText }
        set { userHintText = newValue }
    }
}

extension MessageInputMorePanelAppearance {
    public init(
        fill: MessageInputFill? = nil,
        itemSize: CGFloat? = nil,
        itemIconSize: CGFloat? = nil,
        itemCornerRadius: CGFloat? = nil,
        itemFills: [MessageInputFill]? = nil,
        itemIconTint: UIColor? = nil,
        itemTitleColor: UIColor? = nil,
        itemTitleSize: CGFloat? = nil
    ) {
        self.userFill = fill
        self.userItemSize = itemSize
        self.userItemIconSize = itemIconSize
        self.userItemCornerRadius = itemCornerRadius
        self.userItemFills = itemFills
        self.userItemIconTint = itemIconTint
        self.userItemTitleColor = itemTitleColor
        self.userItemTitleSize = itemTitleSize
    }

    public var fill: MessageInputFill? {
        get { userFill }
        set { userFill = newValue }
    }

    public var itemSize: CGFloat? {
        get { userItemSize }
        set { userItemSize = newValue }
    }

    public var itemIconSize: CGFloat? {
        get { userItemIconSize }
        set { userItemIconSize = newValue }
    }

    public var itemCornerRadius: CGFloat? {
        get { userItemCornerRadius }
        set { userItemCornerRadius = newValue }
    }

    public var itemFills: [MessageInputFill] {
        get { userItemFills ?? [] }
        set { userItemFills = newValue }
    }

    public var itemIconTint: UIColor? {
        get { userItemIconTint }
        set { userItemIconTint = newValue }
    }

    public var itemTitleColor: UIColor? {
        get { userItemTitleColor }
        set { userItemTitleColor = newValue }
    }

    public var itemTitleSize: CGFloat? {
        get { userItemTitleSize }
        set { userItemTitleSize = newValue }
    }
}
