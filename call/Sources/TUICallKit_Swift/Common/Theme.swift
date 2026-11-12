import UIKit

enum CallKitTheme {

    static let callRed = UIColor(hex: 0xED4651)
    static let callGreen = UIColor(hex: 0x51C271)
    static let bannerBackground = UIColor(red: 30/255, green: 33/255, blue: 42/255, alpha: 0.94)
    static let audioBackgroundTop = UIColor(hex: 0x1D222A)
    static let audioBackgroundBottom = UIColor(hex: 0x0E0F13)
    static let controlForeground = UIColor(hex: 0x18191C)
    static let controlOffBackground = UIColor.white.withAlphaComponent(0.20)
    static let controlOffForeground = UIColor.white.withAlphaComponent(0.72)
    static let audioStateText = UIColor(hex: 0x8A9099)
    static let bubbleBackground = UIColor(hex: 0x2B2B2E)
    static let brandText = UIColor(hex: 0x7FB0FF)

    static let brand = UIColor(hex: 0x1C66E6)
    static let sheetText = UIColor(hex: 0x18191C)
    static let sheetText2 = UIColor(hex: 0x8F959E)
    static let sheetText3 = UIColor(hex: 0xA6ABB3)
    static let sheetText4 = UIColor(hex: 0xB7BDC2)
    static let sheetLine = UIColor(hex: 0xEEF0F2)
    static let sheetGrey = UIColor(hex: 0xF2F3F5)
    static let switchOff = UIColor(hex: 0xC9CDD4)
    static let sheetTagBackground = UIColor(hex: 0xF2F5FA)
    static let incomingActionText = UIColor(hex: 0xE6E9ED)
    static let textOnDarkSecondary = UIColor.white.withAlphaComponent(0.82)
    static let hairlineOnDark = UIColor.white.withAlphaComponent(0.1)
    static let toastBackground = UIColor(hex: 0x14161C, alpha: 0.88)
    static let panelBackground = UIColor(red: 28/255, green: 28/255, blue: 30/255, alpha: 0.94)
    static let dimBackground = UIColor(red: 10/255, green: 12/255, blue: 16/255, alpha: 0.42)

    static func makeAudioGradient() -> CAGradientLayer {
        let layer = CAGradientLayer()
        layer.colors = [audioBackgroundTop.cgColor, audioBackgroundBottom.cgColor]
        return layer
    }

    static let controlButtonSize: CGFloat = 58
    static let controlCellWidth: CGFloat = 72
    static let controlLabelGap: CGFloat = 10
    static let controlLabelFont = UIFont.systemFont(ofSize: 13)
    static let topBarHeight: CGFloat = 44
    static let topBarButtonSize: CGFloat = 40
    static let timerFont = UIFont.monospacedDigitSystemFont(ofSize: 17, weight: .regular)
}

extension UIColor {

    convenience init(hex: UInt32, alpha: CGFloat = 1) {
        self.init(
            red: CGFloat((hex >> 16) & 0xFF) / 255,
            green: CGFloat((hex >> 8) & 0xFF) / 255,
            blue: CGFloat(hex & 0xFF) / 255,
            alpha: alpha
        )
    }
}
