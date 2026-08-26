import UIKit

public enum ChatUIKitTheme {

    public static var colors: ChatUIKitColorScheme {
        return ChatUIKitColorScheme()
    }
}

public struct ChatUIKitColorScheme {
    public var bgColorOperate: UIColor { dynamic(\.bgColorOperate) }

    public var bgColorInput: UIColor { dynamic(\.bgColorInput) }

    public var bgColorTopBar: UIColor { dynamic(\.bgColorTopBar) }

    public var bgColorDefault: UIColor { dynamic(\.bgColorDefault) }

    public var bgColorEntryCard: UIColor { dynamic(\.bgColorEntryCard) }

    public var bgColorBottomBar: UIColor { dynamic(\.bgColorBottomBar) }

    public var bgColorBubbleOwn: UIColor { dynamic(\.bgColorBubbleOwn) }

    public var bgColorBubbleReciprocal: UIColor { dynamic(\.bgColorBubbleReciprocal) }

    public var bgColorAvatar: UIColor { dynamic(\.bgColorAvatar) }

    public var bgColorDialog: UIColor { dynamic(\.bgColorDialog) }

    public var textColorPrimary: UIColor { dynamic(\.textColorPrimary) }

    public var textColorSecondary: UIColor { dynamic(\.textColorSecondary) }

    public var textColorTertiary: UIColor { dynamic(\.textColorTertiary) }

    public var textColorAntiPrimary: UIColor { dynamic(\.textColorAntiPrimary) }

    public var textColorAntiSecondary: UIColor { dynamic(\.textColorAntiSecondary) }

    public var textColorLink: UIColor { dynamic(\.textColorLink) }

    public var textColorButton: UIColor { dynamic(\.textColorButton) }

    public var textColorError: UIColor { dynamic(\.textColorError) }

    public var textColorDisable: UIColor { dynamic(\.textColorDisable) }

    public var textColorLinkDisabled: UIColor { dynamic(\.textColorLinkDisabled) }

    public var textColorButtonDisabled: UIColor { dynamic(\.textColorButtonDisabled) }

    public var textColorSuccess: UIColor { dynamic(\.textColorSuccess) }

    public var textColorWarning: UIColor { dynamic(\.textColorWarning) }

    public var shadowColor: UIColor { dynamic(\.shadowColor) }

    public var floatingColorDefault: UIColor { dynamic(\.floatingColorDefault) }

    public var dropdownColorDefault: UIColor { dynamic(\.dropdownColorDefault) }

    public var dropdownColorHover: UIColor { dynamic(\.dropdownColorHover) }

    public var buttonColorPrimaryDefault: UIColor { dynamic(\.buttonColorPrimaryDefault) }

    public var buttonColorPrimaryDisabled: UIColor { dynamic(\.buttonColorPrimaryDisabled) }

    public var buttonColorSecondaryDefault: UIColor { dynamic(\.buttonColorSecondaryDefault) }

    public var buttonColorHangupDefault: UIColor { dynamic(\.buttonColorHangupDefault) }

    public var buttonColorOff: UIColor { dynamic(\.buttonColorOff) }

    public var strokeColorPrimary: UIColor { dynamic(\.strokeColorPrimary) }

    public var strokeColorSecondary: UIColor { dynamic(\.strokeColorSecondary) }

    public var strokeColorModule: UIColor { dynamic(\.strokeColorModule) }

    public var scrollbarColorDefault: UIColor { dynamic(\.scrollbarColorDefault) }

    public var listColorDefault: UIColor { dynamic(\.listColorDefault) }

    public var switchColorOn: UIColor { dynamic(\.switchColorOn) }

    public var clearColor: UIColor { dynamic(\.clearColor) }

    public init() {}

    private func dynamic(_ keyPath: KeyPath<SemanticColorScheme, UIColor>) -> UIColor {
        return UIColor { _ in
            ThemeState.shared.colors[keyPath: keyPath]
        }
    }
}
