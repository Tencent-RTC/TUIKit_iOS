import UIKit

/**
 */
extension UIColor {


    public static let roomKitFgPrimary = UIColor(argbHex: 0xFF1C1B1C)
    public static let roomKitFgSecondary = UIColor(argbHex: 0xFF636263)
    public static let roomKitFgTertiary = UIColor(argbHex: 0xFF8E8D8E)
    public static let roomKitFgOnAccent = UIColor(argbHex: 0xFFFFFFFF)
    public static let roomKitFgOnMedia = UIColor(argbHex: 0xFFFFFFFF)
    public static let roomKitBgOnMedia = UIColor(argbHex: 0x73000000)
    public static let roomKitBgPressOnMedia = UIColor(argbHex: 0x3DFFFFFF)

    public static let roomKitBgCanvas = UIColor(argbHex: 0xFFF5F4F5)
    public static let roomKitBgSurface = UIColor(argbHex: 0xFFFFFFFF)
    public static let roomKitBgHover = UIColor(argbHex: 0x0F1C1B1C)
    public static let roomKitBgPress = UIColor(argbHex: 0x1F1C1B1C)
    public static let roomKitBorder = UIColor(argbHex: 0x171C1B1C)

    public static let roomKitAccent = UIColor(argbHex: 0xFF0071E3)
    public static let roomKitAccentSoft = UIColor(argbHex: 0x240071E3)
    public static let roomKitDanger = UIColor(argbHex: 0xFFFF453A)
    public static let roomKitFgOnDanger = UIColor(argbHex: 0xFFFFFFFF)
    public static let roomKitBgInverse = UIColor(argbHex: 0xFF1C1B1C)
    public static let roomKitSuccess = UIColor(argbHex: 0xFF34C759)
    public static let roomKitWarning = UIColor(argbHex: 0xFFFF9F0A)

    public static let roomKitScrim = UIColor(argbHex: 0x52141314)
    public static let roomKitToastBg = UIColor(argbHex: 0xC0000000)
    public static let roomKitDragHandle = UIColor(argbHex: 0x2E1C1B1C)
    public static let roomKitPopupBorder = UIColor(argbHex: 0x1A1C1B1C)
    public static let roomKitBgSheet = UIColor(argbHex: 0xFAFFFFFF)

    public static let roomKitTileChip = UIColor(argbHex: 0x9E707074)
    public static let roomKitRoleOwnerFg = UIColor(argbHex: 0xFF0058B1)
    public static let roomKitRoleOwnerBg = UIColor(argbHex: 0xFFCCE3F9)
    public static let roomKitRoleAdminFg = UIColor(argbHex: 0xFF945C06)
    public static let roomKitRoleAdminBg = UIColor(argbHex: 0xFFFFECCE)
    public static let roomKitRoleSelfFg = UIColor(argbHex: 0xFF636263)
    public static let roomKitRoleSelfBg = UIColor(argbHex: 0xFFE8E8E8)


    public static let roomKitBgHoverStrong = UIColor(argbHex: 0x1A1C1B1C)
    public static let roomKitBorderStrong = UIColor(argbHex: 0x241C1B1C)
    public static let roomKitBgPopoverSolid = UIColor(argbHex: 0xFCFFFFFF)
    public static let roomKitShadowLg = UIColor(argbHex: 0x1F000000)
    public static let roomKitDangerSoft = UIColor(argbHex: 0x24FF453A)
    public static let roomKitDangerSoftStrong = UIColor(argbHex: 0x2EFF453A)
    public static let roomKitDangerFaint = UIColor(argbHex: 0x14FF453A)
    public static let roomKitDangerPressed = UIColor(argbHex: 0xFFF23F35)
    public static let roomKitWarningSoft = UIColor(argbHex: 0x24FF9F0A)
    public static let roomKitAccentBorderSoft = UIColor(argbHex: 0x590071E3)
    public static let roomKitAccentSoftTint = UIColor(argbHex: 0xFF3890E9)
    public static let roomKitSeparator = UIColor(argbHex: 0x381C1B1C)
    public static let roomKitInfoLine = UIColor(argbHex: 0x0F1C1B1C)
    public static let roomKitSuccessText = UIColor(argbHex: 0xFF2DAB4A)
    public static let roomKitSuccessSoft = UIColor(argbHex: 0x1F34C759)
    public static let roomKitSuccessBorder = UIColor(argbHex: 0xA634C759)
    public static let roomKitBgPageIndicator = UIColor(argbHex: 0x6B000000)
    public static let roomKitFgIcon = UIColor(argbHex: 0xFF3A393A)
    public static let roomKitToggleOff = UIColor(argbHex: 0xFFE5E5EA)
    public static let roomKitSharePlaceholderBg = UIColor(argbHex: 0xFFF4F4F4)
}

extension UIColor {

    public convenience init(argbHex: UInt32) {
        self.init(
            red: CGFloat((argbHex >> 16) & 0xFF) / 255.0,
            green: CGFloat((argbHex >> 8) & 0xFF) / 255.0,
            blue: CGFloat(argbHex & 0xFF) / 255.0,
            alpha: CGFloat((argbHex >> 24) & 0xFF) / 255.0
        )
    }
}

extension UIImage {

    public static func solid(_ color: UIColor) -> UIImage {
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: 1, height: 1))
        return renderer.image { color.setFill(); $0.fill(CGRect(x: 0, y: 0, width: 1, height: 1)) }
    }
}
