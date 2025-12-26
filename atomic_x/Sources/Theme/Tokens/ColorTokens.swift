//
//  ColorTokens.swift
//  Runtime Theme & Design Tokens
//
//  Created: 2025-11-14
//  Feature: 001-runtime-theme-tokens (Semantic Color Layer)
//

import UIKit

public struct ColorTokens {
    // text & icon
    public let textColorPrimary: UIColor
    public let textColorSecondary: UIColor
    public let textColorTertiary: UIColor
    public let textColorDisable: UIColor
    public let textColorButton: UIColor
    public let textColorButtonDisabled: UIColor
    public let textColorLink: UIColor
    public let textColorLinkHover: UIColor
    public let textColorLinkActive: UIColor
    public let textColorLinkDisabled: UIColor
    public let textColorAntiPrimary: UIColor
    public let textColorAntiSecondary: UIColor
    public let textColorWarning: UIColor
    public let textColorSuccess: UIColor
    public let textColorError: UIColor
    // background
    public let bgColorTopBar: UIColor
    public let bgColorOperate: UIColor
    public let bgColorDialog: UIColor
    public let bgColorDialogModule: UIColor
    public let bgColorEntryCard: UIColor
    public let bgColorFunction: UIColor
    public let bgColorBottomBar: UIColor
    public let bgColorInput: UIColor
    public let bgColorBubbleReciprocal: UIColor
    public let bgColorBubbleOwn: UIColor
    public let bgColorDefault: UIColor
    public let bgColorTagMask: UIColor
    public let bgColorElementMask: UIColor
    public let bgColorMask: UIColor
    public let bgColorMaskDisappeared: UIColor
    public let bgColorMaskBegin: UIColor
    public let bgColorAvatar: UIColor
    // border
    public let strokeColorPrimary: UIColor
    public let strokeColorSecondary: UIColor
    public let strokeColorModule: UIColor
    // shadow
    public let shadowColor: UIColor
    // status
    public let listColorDefault: UIColor
    public let listColorHover: UIColor
    public let listColorFocused: UIColor
    // button
    public let buttonColorPrimaryDefault: UIColor
    public let buttonColorPrimaryHover: UIColor
    public let buttonColorPrimaryActive: UIColor
    public let buttonColorPrimaryDisabled: UIColor
    public let buttonColorSecondaryDefault: UIColor
    public let buttonColorSecondaryHover: UIColor
    public let buttonColorSecondaryActive: UIColor
    public let buttonColorSecondaryDisabled: UIColor
    public let buttonColorAccept: UIColor
    public let buttonColorHangupDefault: UIColor
    public let buttonColorHangupDisabled: UIColor
    public let buttonColorHangupHover: UIColor
    public let buttonColorHangupActive: UIColor
    public let buttonColorOn: UIColor
    public let buttonColorOff: UIColor
    // dropdown
    public let dropdownColorDefault: UIColor
    public let dropdownColorHover: UIColor
    public let dropdownColorActive: UIColor
    // scrollbar
    public let scrollbarColorDefault: UIColor
    public let scrollbarColorHover: UIColor
    // floating
    public let floatingColorDefault: UIColor
    public let floatingColorOperate: UIColor
    // checkbox
    public let checkboxColorSelected: UIColor
    // toast
    public let toastColorWarning: UIColor
    public let toastColorSuccess: UIColor
    public let toastColorError: UIColor
    public let toastColorDefault: UIColor
    // tag
    public let tagColorLevel1: UIColor
    public let tagColorLevel2: UIColor
    public let tagColorLevel3: UIColor
    public let tagColorLevel4: UIColor
    // switch
    public let switchColorOff: UIColor
    public let switchColorOn: UIColor
    public let switchColorButton: UIColor
    // slider
    public let sliderColorFilled: UIColor
    public let sliderColorEmpty: UIColor
    public let sliderColorButton: UIColor
    // tab
    public let tabColorSelected: UIColor
    public let tabColorUnselected: UIColor
    public let tabColorOption: UIColor
    // clear
    public let clearColor: UIColor
    
    /// Create light mode semantic tokens from color palettes
    public static func light(from primaryColor: String = "#1C66E5") -> ColorTokens {
        let colorPalettes = ColorPalettes(
            primaryColor: BrandColorToken.generate(from: primaryColor, themeId: "light"),
            successColor: BrandColorToken.generate(from: "#0ABF77", themeId: "light"),
            errorColor: BrandColorToken.generate(from: "#E54545", themeId: "light"),
            warningColor: BrandColorToken.generate(from: "#FF7200", themeId: "light"),
            neutralColor: NeutralColorToken.generate(),
            whiteColor: .standard,
            blackColor: .standard,
            accentColor: .init()
        )
        return ColorTokens(
            // text & icon
            textColorPrimary: colorPalettes.blackColor.black2,
            textColorSecondary: colorPalettes.blackColor.black4,
            textColorTertiary: colorPalettes.blackColor.black5,
            textColorDisable: colorPalettes.blackColor.black6,
            textColorButton: colorPalettes.whiteColor.white1,
            textColorButtonDisabled: colorPalettes.whiteColor.white1,
            textColorLink: colorPalettes.primaryColor.color6,
            textColorLinkHover: colorPalettes.primaryColor.color5,
            textColorLinkActive: colorPalettes.primaryColor.color7,
            textColorLinkDisabled: colorPalettes.primaryColor.color2,
            textColorAntiPrimary: colorPalettes.blackColor.black2,
            textColorAntiSecondary:colorPalettes.blackColor.black4,
            textColorWarning: colorPalettes.warningColor.color6,
            textColorSuccess: colorPalettes.successColor.color6,
            textColorError: colorPalettes.errorColor.color6,
            // background
            bgColorTopBar: colorPalettes.neutralColor.grayLight1,
            bgColorOperate: colorPalettes.whiteColor.white1,
            bgColorDialog: colorPalettes.whiteColor.white1,
            bgColorDialogModule: colorPalettes.neutralColor.grayLight2,
            bgColorEntryCard: colorPalettes.neutralColor.grayLight2,
            bgColorFunction: colorPalettes.neutralColor.grayLight2,
            bgColorBottomBar: colorPalettes.whiteColor.white1,
            bgColorInput: colorPalettes.neutralColor.grayLight2,
            bgColorBubbleReciprocal: colorPalettes.neutralColor.grayLight2,
            bgColorBubbleOwn: colorPalettes.primaryColor.color2,
            bgColorDefault: colorPalettes.neutralColor.grayLight2,
            bgColorTagMask:  colorPalettes.whiteColor.white4,
            bgColorElementMask: colorPalettes.blackColor.black6,
            bgColorMask: colorPalettes.blackColor.black4,
            bgColorMaskDisappeared: colorPalettes.whiteColor.white7,
            bgColorMaskBegin: colorPalettes.whiteColor.white1,
            bgColorAvatar: colorPalettes.primaryColor.color2,
            // border
            strokeColorPrimary: colorPalettes.neutralColor.grayLight3,
            strokeColorSecondary: colorPalettes.neutralColor.grayLight2,
            strokeColorModule: colorPalettes.neutralColor.grayLight3,
            // shadow
            shadowColor: colorPalettes.blackColor.black8,
            // status
            listColorDefault: colorPalettes.whiteColor.white1,
            listColorHover: colorPalettes.neutralColor.grayLight1,
            listColorFocused: colorPalettes.primaryColor.color1,
            // button
            buttonColorPrimaryDefault: colorPalettes.primaryColor.color6,
            buttonColorPrimaryHover: colorPalettes.primaryColor.color5,
            buttonColorPrimaryActive: colorPalettes.primaryColor.color7,
            buttonColorPrimaryDisabled: colorPalettes.primaryColor.color2,
            buttonColorSecondaryDefault: colorPalettes.neutralColor.grayLight2,
            buttonColorSecondaryHover: colorPalettes.neutralColor.grayLight1,
            buttonColorSecondaryActive: colorPalettes.neutralColor.grayLight3,
            buttonColorSecondaryDisabled: colorPalettes.neutralColor.grayLight1,
            buttonColorAccept: colorPalettes.successColor.color6,
            buttonColorHangupDefault: colorPalettes.errorColor.color6,
            buttonColorHangupDisabled: colorPalettes.errorColor.color2,
            buttonColorHangupHover: colorPalettes.errorColor.color5,
            buttonColorHangupActive:colorPalettes.errorColor.color7,
            buttonColorOn: colorPalettes.whiteColor.white1,
            buttonColorOff: colorPalettes.blackColor.black5,
            // dropdown
            dropdownColorDefault: colorPalettes.whiteColor.white1,
            dropdownColorHover: colorPalettes.neutralColor.grayLight1,
            dropdownColorActive: colorPalettes.primaryColor.color1,
            // scrollbar
            scrollbarColorDefault: colorPalettes.blackColor.black7,
            scrollbarColorHover: colorPalettes.blackColor.black6,
            // floating
            floatingColorDefault: colorPalettes.whiteColor.white1,
            floatingColorOperate: colorPalettes.neutralColor.grayLight2,
            // checkbox
            checkboxColorSelected: colorPalettes.primaryColor.color6,
            // toast
            toastColorWarning: colorPalettes.warningColor.color1,
            toastColorSuccess: colorPalettes.successColor.color1,
            toastColorError: colorPalettes.errorColor.color1,
            toastColorDefault: colorPalettes.primaryColor.color1,
            // tag
            tagColorLevel1: colorPalettes.accentColor.turquoiseLight,
            tagColorLevel2: colorPalettes.primaryColor.color5,
            tagColorLevel3: colorPalettes.accentColor.purpleLight,
            tagColorLevel4: colorPalettes.accentColor.magentaLight,
            // switch
            switchColorOff: colorPalettes.neutralColor.grayLight4,
            switchColorOn: colorPalettes.primaryColor.color6,
            switchColorButton: colorPalettes.whiteColor.white1,
            // slider
            sliderColorFilled: colorPalettes.primaryColor.color6,
            sliderColorEmpty: colorPalettes.neutralColor.grayLight3,
            sliderColorButton: colorPalettes.whiteColor.white1,
            // tab
            tabColorSelected: colorPalettes.neutralColor.grayLight2,
            tabColorUnselected: colorPalettes.neutralColor.grayLight2,
            tabColorOption: colorPalettes.neutralColor.grayLight3,
            // clear
            clearColor: .clear
        )
    }
    
    /// Create dark mode semantic tokens from color palettes
    public static func dark(from primaryColor: String = "#4086FF") -> ColorTokens {
        let colorPalettes = ColorPalettes(
            primaryColor: BrandColorToken.generate(from: primaryColor, themeId: "dark"),
            successColor: BrandColorToken.generate(from: "#38A673", themeId: "dark"),
            errorColor: BrandColorToken.generate(from: "#E6594C", themeId: "dark"),
            warningColor: BrandColorToken.generate(from: "#E37F32", themeId: "dark"),
            neutralColor: NeutralColorToken.generate(),
            whiteColor: .standard,
            blackColor: .standard,
            accentColor: .init()
        )
        return ColorTokens(
            // text & icon
            textColorPrimary: colorPalettes.whiteColor.white2,
            textColorSecondary: colorPalettes.whiteColor.white4,
            textColorTertiary: colorPalettes.whiteColor.white6,
            textColorDisable: colorPalettes.whiteColor.white7,
            textColorButton: colorPalettes.whiteColor.white1,
            textColorButtonDisabled: colorPalettes.whiteColor.white5,
            textColorLink: colorPalettes.primaryColor.color6,
            textColorLinkHover: colorPalettes.primaryColor.color5,
            textColorLinkActive: colorPalettes.primaryColor.color7,
            textColorLinkDisabled: colorPalettes.primaryColor.color2,
            textColorAntiPrimary: colorPalettes.blackColor.black2,
            textColorAntiSecondary: colorPalettes.blackColor.black4,
            textColorWarning: colorPalettes.warningColor.color6,
            textColorSuccess: colorPalettes.successColor.color6,
            textColorError: colorPalettes.errorColor.color6,
            // background
            bgColorTopBar: colorPalettes.neutralColor.grayDark1,
            bgColorOperate: colorPalettes.neutralColor.grayDark2,
            bgColorDialog: colorPalettes.neutralColor.grayDark2,
            bgColorDialogModule: colorPalettes.neutralColor.grayDark1,
            bgColorEntryCard: colorPalettes.neutralColor.grayDark3,
            bgColorFunction: colorPalettes.neutralColor.grayDark4,
            bgColorBottomBar: colorPalettes.neutralColor.grayDark3,
            bgColorInput: colorPalettes.neutralColor.grayDark3,
            bgColorBubbleReciprocal: colorPalettes.neutralColor.grayDark3,
            bgColorBubbleOwn: colorPalettes.primaryColor.color7,
            bgColorDefault: colorPalettes.neutralColor.grayDark1,
            bgColorTagMask: colorPalettes.blackColor.black4,
            bgColorElementMask: colorPalettes.blackColor.black6,
            bgColorMask: colorPalettes.blackColor.black4,
            bgColorMaskDisappeared: colorPalettes.blackColor.black2,
            bgColorMaskBegin:colorPalettes.blackColor.black2,
            bgColorAvatar: colorPalettes.primaryColor.color2,
            // border
            strokeColorPrimary: colorPalettes.neutralColor.grayDark4,
            strokeColorSecondary: colorPalettes.neutralColor.grayDark3,
            strokeColorModule: colorPalettes.neutralColor.grayDark5,
            // shadow
            shadowColor: colorPalettes.blackColor.black8,
            // status
            listColorDefault: colorPalettes.neutralColor.grayDark2,
            listColorHover: colorPalettes.neutralColor.grayDark3,
            listColorFocused: colorPalettes.primaryColor.color2,
            // button
            buttonColorPrimaryDefault: colorPalettes.primaryColor.color6,
            buttonColorPrimaryHover: colorPalettes.primaryColor.color5,
            buttonColorPrimaryActive: colorPalettes.primaryColor.color7,
            buttonColorPrimaryDisabled: colorPalettes.primaryColor.color2,
            buttonColorSecondaryDefault: colorPalettes.neutralColor.grayDark4,
            buttonColorSecondaryHover: colorPalettes.neutralColor.grayDark3,
            buttonColorSecondaryActive: colorPalettes.neutralColor.grayDark5,
            buttonColorSecondaryDisabled: colorPalettes.neutralColor.grayDark3,
            buttonColorAccept: colorPalettes.successColor.color6,
            buttonColorHangupDefault: colorPalettes.errorColor.color6,
            buttonColorHangupDisabled: colorPalettes.errorColor.color2,
            buttonColorHangupHover: colorPalettes.errorColor.color5,
            buttonColorHangupActive: colorPalettes.errorColor.color7,
            buttonColorOn: colorPalettes.whiteColor.white1,
            buttonColorOff: colorPalettes.blackColor.black5,
            // dropdown
            dropdownColorDefault: colorPalettes.neutralColor.grayDark3,
            dropdownColorHover: colorPalettes.neutralColor.grayDark4,
            dropdownColorActive: colorPalettes.neutralColor.grayDark2,
            // scrollbar
            scrollbarColorDefault: colorPalettes.whiteColor.white7,
            scrollbarColorHover: colorPalettes.whiteColor.white6,
            // floating
            floatingColorDefault: colorPalettes.neutralColor.grayDark3,
            floatingColorOperate: colorPalettes.neutralColor.grayDark4,
            // checkbox
            checkboxColorSelected: colorPalettes.primaryColor.color5,
            // toast
            toastColorWarning: colorPalettes.warningColor.color2,
            toastColorSuccess: colorPalettes.successColor.color2,
            toastColorError: colorPalettes.errorColor.color2,
            toastColorDefault: colorPalettes.primaryColor.color2,
            // tag
            tagColorLevel1: colorPalettes.accentColor.turquoiseDark,
            tagColorLevel2: colorPalettes.primaryColor.color5,
            tagColorLevel3: colorPalettes.accentColor.purpleDark,
            tagColorLevel4: colorPalettes.accentColor.magentaDark,
            // switch
            switchColorOff: colorPalettes.neutralColor.grayDark4,
            switchColorOn: colorPalettes.primaryColor.color5,
            switchColorButton: colorPalettes.whiteColor.white1,
            // slider
            sliderColorFilled: colorPalettes.primaryColor.color5,
            sliderColorEmpty: colorPalettes.neutralColor.grayDark5,
            sliderColorButton: colorPalettes.whiteColor.white1,
            // tab
            tabColorSelected: colorPalettes.neutralColor.grayDark5,
            tabColorUnselected: colorPalettes.neutralColor.grayDark4,
            tabColorOption: colorPalettes.neutralColor.grayDark4,
            // clear
            clearColor: .clear
        )
    }
}

// MARK: - Placeholder

extension DesignTokenSet {
    static var placeholder: DesignTokenSet {
        return DesignTokenSet(
            id: "placeholder",
            displayName: "Placeholder",
            color: ColorTokens.light(),
            space: .standard,
            borderRadius: .standard,
            typography: TypographyToken(fontFamilyName: "PingFang"),
            shadows: .standard
        )
    }
}
