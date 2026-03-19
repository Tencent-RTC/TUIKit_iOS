//
//  UIColor+Extension.swift
//  TUILiveKit
//
//  Created by krabyu on 2024/3/11.
//

import UIKit
import AtomicX

internal extension UIColor {

    static var b1: UIColor { ThemeStore.shared.colorTokens.buttonColorPrimaryDefault }
    static var b2: UIColor { ThemeStore.shared.colorTokens.tagColorLevel1 }
    static var c1: UIColor { ThemeStore.shared.colorTokens.textColorSuccess }
    static var c2: UIColor { ThemeStore.shared.colorTokens.tagColorLevel3 }
    static var c3: UIColor { ThemeStore.shared.colorTokens.textColorWarning }
    static var c4: UIColor { ThemeStore.shared.colorTokens.textColorError }
    static var b1d: UIColor { ThemeStore.shared.colorTokens.buttonColorPrimaryHover }
    static var b2d: UIColor { ThemeStore.shared.colorTokens.tagColorLevel1 }
    static var g1: UIColor { ThemeStore.shared.colorTokens.bgColorTopBar }
    static var g2: UIColor { ThemeStore.shared.colorTokens.bgColorOperate }
    static var g3: UIColor { ThemeStore.shared.colorTokens.bgColorEntryCard }
    static var g3Divider: UIColor { ThemeStore.shared.colorTokens.strokeColorModule.withAlphaComponent(0.5) }
    static var g4: UIColor { ThemeStore.shared.colorTokens.textColorTertiary }
    static var g5: UIColor { ThemeStore.shared.colorTokens.textColorSecondary }
    static var g6: UIColor { ThemeStore.shared.colorTokens.textColorSecondary }
    static var g7: UIColor { ThemeStore.shared.colorTokens.textColorPrimary }
    static var g8: UIColor { ThemeStore.shared.colorTokens.textColorPrimary }
    static var g9: UIColor { ThemeStore.shared.colorTokens.textColorPrimary }
    static var flowKitRed: UIColor { ThemeStore.shared.colorTokens.textColorError }
    static var flowKitGreen: UIColor { ThemeStore.shared.colorTokens.textColorSuccess }
    static var flowKitBlue: UIColor { ThemeStore.shared.colorTokens.buttonColorPrimaryDefault }
    static var flowKitWhite: UIColor { .white }
    static var flowKitPurple: UIColor { ThemeStore.shared.colorTokens.tagColorLevel3 }
    static var flowKitCharcoal: UIColor { .black }
    static var transparent: UIColor { ThemeStore.shared.colorTokens.clearColor }
    static var warningTextColor: UIColor { ThemeStore.shared.colorTokens.textColorWarning }
    static var defaultTextColor: UIColor { ThemeStore.shared.colorTokens.textColorPrimary }

    static var gray60Transparency: UIColor { ThemeStore.shared.colorTokens.bgColorOperate.withAlphaComponent(0.6) }
    static var whiteColor: UIColor { ThemeStore.shared.colorTokens.textColorPrimary }
    static var greyColor: UIColor { ThemeStore.shared.colorTokens.textColorSecondary }
    static var redColor: UIColor { ThemeStore.shared.colorTokens.textColorError }
    static var white20Transparency: UIColor { UIColor.white.withAlphaComponent(0.2) }
    static var blue40Transparency: UIColor { ThemeStore.shared.colorTokens.bgColorEntryCard.withAlphaComponent(0.4) }
    static var brandBlueColor: UIColor { ThemeStore.shared.colorTokens.buttonColorPrimaryDefault }
    static var blackColor: UIColor { ThemeStore.shared.colorTokens.bgColorTopBar }
    static var redPinkColor: UIColor { ThemeStore.shared.colorTokens.textColorError }
    static var redDotColor: UIColor { ThemeStore.shared.colorTokens.textColorError }
    static var pureBlackColor: UIColor { .black }
    static var blueColor: UIColor { ThemeStore.shared.colorTokens.buttonColorPrimaryDefault }
    static var lightBlueColor: UIColor { ThemeStore.shared.colorTokens.buttonColorPrimaryHover }
    static var lightGrayColor: UIColor { ThemeStore.shared.colorTokens.textColorSecondary }
    static var darkGrayColor: UIColor { ThemeStore.shared.colorTokens.bgColorEntryCard }
    static var lightCyanColor: UIColor { ThemeStore.shared.colorTokens.bgColorDefault }
    static var darkBlueColor: UIColor { ThemeStore.shared.colorTokens.buttonColorPrimaryActive }
    static var lightPurpleColor: UIColor { ThemeStore.shared.colorTokens.textColorSecondary }
    static var yellowColor: UIColor { ThemeStore.shared.colorTokens.textColorWarning }
    static var darkNavyColor: UIColor { ThemeStore.shared.colorTokens.bgColorTopBar }
    static var lightGreenColor: UIColor { ThemeStore.shared.colorTokens.textColorSuccess }
    static var orangeColor: UIColor { ThemeStore.shared.colorTokens.textColorWarning }
    static var deepSeaBlueColor: UIColor { ThemeStore.shared.colorTokens.buttonColorPrimaryDefault }
    static var cyanColor: UIColor { ThemeStore.shared.colorTokens.tagColorLevel1 }
    static var grayColor: UIColor { ThemeStore.shared.colorTokens.textColorSecondary }
    static var tipsGrayColor: UIColor { ThemeStore.shared.colorTokens.textColorSecondary }
    static var pinkColor: UIColor { ThemeStore.shared.colorTokens.tagColorLevel4 }
    static var btnDisabledColor: UIColor { ThemeStore.shared.colorTokens.buttonColorPrimaryDisabled }
    static var btnGrayColor: UIColor { ThemeStore.shared.colorTokens.buttonColorSecondaryDefault }

    static var greenColor: UIColor { ThemeStore.shared.colorTokens.textColorSuccess }

    static var barrageColorMsg1: UIColor { ThemeStore.shared.colorTokens.buttonColorPrimaryDefault }
    static var barrageColorMsg2: UIColor { ThemeStore.shared.colorTokens.tagColorLevel1 }
    static var barrageColorMsg3: UIColor { ThemeStore.shared.colorTokens.textColorWarning }
    static var barrageColorMsg4: UIColor { ThemeStore.shared.colorTokens.tagColorLevel4 }
    static var barrageColorMsg5: UIColor { ThemeStore.shared.colorTokens.tagColorLevel4 }
    static var barrageColorMsg6: UIColor { ThemeStore.shared.colorTokens.tagColorLevel4 }
    static var barrageColorMsg7: UIColor { ThemeStore.shared.colorTokens.textColorWarning }
    static var barrageItemBackColor: UIColor { ThemeStore.shared.colorTokens.bgColorOperate.withAlphaComponent(0.4) }

    static var giftTwoFifthBlackColor: UIColor { UIColor.black.withAlphaComponent(0.4) }
    static var giftContentColor: UIColor { ThemeStore.shared.colorTokens.bgColorEntryCard.withAlphaComponent(0.93) }

    static var seatContentColor: UIColor { ThemeStore.shared.colorTokens.bgColorDefault.withAlphaComponent(0.1) }
    static var seatContentBorderColor: UIColor { ThemeStore.shared.colorTokens.strokeColorPrimary.withAlphaComponent(0.1) }
    static var seatWaveColor: UIColor { ThemeStore.shared.colorTokens.tagColorLevel4 }

    static var textPrimaryColor: UIColor { ThemeStore.shared.colorTokens.textColorPrimary }
    static var textSecondaryColor: UIColor { ThemeStore.shared.colorTokens.textColorSecondary }
    static var textDisabledColor: UIColor { ThemeStore.shared.colorTokens.textColorDisable }
    static var bgTopBarColor: UIColor { ThemeStore.shared.colorTokens.bgColorTopBar }
    static var bgOperateColor: UIColor { ThemeStore.shared.colorTokens.bgColorOperate }
    static var bgEntrycardColor: UIColor { ThemeStore.shared.colorTokens.bgColorEntryCard }
    static var strokeModuleColor: UIColor { ThemeStore.shared.colorTokens.strokeColorModule }
    static var buttonPrimaryDefaultColor: UIColor { ThemeStore.shared.colorTokens.buttonColorPrimaryDefault }
}


