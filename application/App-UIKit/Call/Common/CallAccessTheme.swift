import UIKit

/// CallKitAccess theme. Values mirror `uikit_interaction_design/call/mobile/general/styles/theme.css`;
/// keep them as CSS variable values, do not invent new colors.
enum CallAccessTheme {
    static let brand = UIColor(hex: 0x1C66E6)          // --brand
    static let brandHover = UIColor(hex: 0x1557C9)     // --brand-hover
    static let brandSoft = UIColor(hex: 0x1C66E6, alpha: 0.18) // --brand-soft
    static let pageBackground = UIColor(hex: 0xF2F3F5) // --bg-s234
    static let card = UIColor.white                    // --card
    static let text = UIColor(hex: 0x18191C)           // --text
    static let text2 = UIColor(hex: 0x8F959E)          // --text-2
    static let text3 = UIColor(hex: 0xA6ABB3)          // --text-3
    static let text4 = UIColor(hex: 0xB7BDC2)          // --text-4
    static let line = UIColor(hex: 0xEEF0F2)           // --line
    static let arrow = UIColor(hex: 0xC3C7CC)          // --arrow
    static let green = UIColor(hex: 0x07C160)          // --green
    static let red = UIColor(hex: 0xFA5151)            // --red (validation)
    static let callRed = UIColor(hex: 0xED4651)        // --call-red
    static let switchOff = UIColor(hex: 0xE3E5E9)
    static let ctaDisabled = UIColor(hex: 0xA9BEDE)
    static let closeBackground = UIColor(hex: 0xEEF0F4) // --grey-bg
    static let mask = UIColor(hex: 0x0A0C10, alpha: 0.42)
    static let cardShadow = UIColor.black.withAlphaComponent(0.06)

    /// One physical pixel for hairline dividers. `UIScreen.main.scale` is only used
    /// for 1px lines, never for layout.
    static var hairline: CGFloat { 1 / UIScreen.main.scale }
}

extension UIColor {
    convenience init(hex: UInt32, alpha: CGFloat = 1) {
        self.init(
            red: CGFloat((hex >> 16) & 0xFF) / 255.0,
            green: CGFloat((hex >> 8) & 0xFF) / 255.0,
            blue: CGFloat(hex & 0xFF) / 255.0,
            alpha: alpha
        )
    }

    /// Solid-color image for UIButton background states.
    static func solidImage(_ color: UIColor) -> UIImage? {
        let rect = CGRect(x: 0, y: 0, width: 1, height: 1)
        return UIGraphicsImageRenderer(size: rect.size).image { context in
            color.setFill()
            context.fill(rect)
        }
    }
}
