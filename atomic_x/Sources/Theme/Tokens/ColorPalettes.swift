//
//  ColorPalettes.swift
//  Runtime Theme & Design Tokens
//
//  Created: 2025-11-13
//  Feature: 001-runtime-theme-tokens (T005)
//

import UIKit

/// ColorPalettes - Raw color token palettes (bottom layer)
/// Contains 10-step brand colors, neutral grays, white/black tokens
public struct ColorPalettes {
    public let primaryColor: BrandColorToken
    public let successColor: BrandColorToken
    public let errorColor: BrandColorToken
    public let warningColor: BrandColorToken
    public let neutralColor: NeutralColorToken
    public let whiteColor: WhiteColorToken
    public let blackColor: BlackColorToken
    public let accentColor: AccentColorToken
    
    public init(
        primaryColor: BrandColorToken,
        successColor: BrandColorToken,
        errorColor: BrandColorToken,
        warningColor: BrandColorToken,
        neutralColor: NeutralColorToken,
        whiteColor: WhiteColorToken,
        blackColor: BlackColorToken,
        accentColor: AccentColorToken
    ) {
        self.primaryColor = primaryColor
        self.successColor = successColor
        self.errorColor = errorColor
        self.warningColor = warningColor
        self.neutralColor = neutralColor
        self.whiteColor = whiteColor
        self.blackColor = blackColor
        self.accentColor = accentColor
    }
}

// MARK: - BrandColorToken

/// BrandColorToken - 10-step brand color palette generated from base color using HSB
public struct BrandColorToken {
    public let color1: UIColor
    public let color2: UIColor
    public let color3: UIColor
    public let color4: UIColor
    public let color5: UIColor
    public let color6: UIColor
    public let color7: UIColor
    public let color8: UIColor
    public let color9: UIColor
    public let color10: UIColor
    
    public init(
        color1: UIColor, color2: UIColor, color3: UIColor, color4: UIColor, color5: UIColor,
        color6: UIColor, color7: UIColor, color8: UIColor, color9: UIColor, color10: UIColor
    ) {
        self.color1 = color1
        self.color2 = color2
        self.color3 = color3
        self.color4 = color4
        self.color5 = color5
        self.color6 = color6
        self.color7 = color7
        self.color8 = color8
        self.color9 = color9
        self.color10 = color10
    }
    
    /// Generate HSB-based brand color palette from base color (Ant Design algorithm)
    /// - Parameter baseColor: Base color (typically color6)
    /// - Returns: Complete 10-step brand color token
    public static func generate(from baseColorString: String, themeId: String) -> BrandColorToken {
        let colors = ThemeColorGenerator.generateThemeColors(baseColor: baseColorString, themeId: themeId)
        
        return BrandColorToken(
            color1: colors[0], color2: colors[1], color3: colors[2], color4: colors[3], color5: colors[4],
            color6: colors[5], color7: colors[6], color8: colors[7], color9: colors[8], color10: colors[9]
        )
    }
}

// MARK: - NeutralColorToken

/// NeutralColorToken - 14-step neutral gray palette 
public struct NeutralColorToken {
    public let grayLight1: UIColor
    public let grayLight2: UIColor
    public let grayLight3: UIColor
    public let grayLight4: UIColor
    public let grayLight5: UIColor
    public let grayLight6: UIColor
    public let grayLight7: UIColor
    
    public let grayDark7: UIColor
    public let grayDark6: UIColor
    public let grayDark5: UIColor
    public let grayDark4: UIColor
    public let grayDark3: UIColor
    public let grayDark2: UIColor
    public let grayDark1: UIColor
    
    public init(
        gray1: UIColor, gray2: UIColor, gray3: UIColor, gray4: UIColor, gray5: UIColor,
        gray6: UIColor, gray7: UIColor, gray8: UIColor, gray9: UIColor, gray10: UIColor,
        gray11: UIColor, gray12: UIColor, gray13: UIColor, gray14: UIColor
    ) {
        self.grayLight1 = gray1
        self.grayLight2 = gray2
        self.grayLight3 = gray3
        self.grayLight4 = gray4
        self.grayLight5 = gray5
        self.grayLight6 = gray6
        self.grayLight7 = gray7
        self.grayDark7 = gray8
        self.grayDark6 = gray9
        self.grayDark5 = gray10
        self.grayDark4 = gray11
        self.grayDark3 = gray12
        self.grayDark2 = gray13
        self.grayDark1 = gray14
    }
    

    public static func generate() -> NeutralColorToken {
        let colors = ThemeColorGenerator.generateNeutralColors()
        
        return NeutralColorToken(
            gray1: colors[0], gray2: colors[1], gray3: colors[2], gray4: colors[3],
            gray5: colors[4], gray6: colors[5], gray7: colors[6], gray8: colors[7],
            gray9: colors[8], gray10: colors[9], gray11: colors[10], gray12: colors[11],
            gray13: colors[12], gray14: colors[13]
        )
    }
}

// MARK: - BlackColorToken

/// BlackColorToken - Black with standard opacity levels
public struct BlackColorToken {
    public let black1: UIColor  // 100%
    public let black2: UIColor   // 90%
    public let black3: UIColor   // 72%
    public let black4: UIColor   // 55%
    public let black5: UIColor   // 40%
    public let black6: UIColor   // 25%
    public let black7: UIColor   // 12%
    public let black8: UIColor    // 6%
    
    public init(
        black1: UIColor, black2: UIColor, black3: UIColor, black4: UIColor,
        black5: UIColor, black6: UIColor, black7: UIColor, black8: UIColor
    ) {
        self.black1 = black1
        self.black2 = black2
        self.black3 = black3
        self.black4 = black4
        self.black5 = black5
        self.black6 = black6
        self.black7 = black7
        self.black8 = black8
    }
    
    public static var standard: BlackColorToken {
        return BlackColorToken(
            black1: UIColor.black.withAlphaComponent(1.0),
            black2: UIColor.black.withAlphaComponent(0.9),
            black3: UIColor.black.withAlphaComponent(0.72),
            black4: UIColor.black.withAlphaComponent(0.55),
            black5: UIColor.black.withAlphaComponent(0.4),
            black6: UIColor.black.withAlphaComponent(0.25),
            black7: UIColor.black.withAlphaComponent(0.12),
            black8: UIColor.black.withAlphaComponent(0.06)
        )
    }
}

// MARK: - WhiteColorToken

/// WhiteColorToken - White with standard opacity levels
public struct WhiteColorToken {
    public let white1: UIColor  // 100%
    public let white2: UIColor   // 93%
    public let white3: UIColor   // 75%
    public let white4: UIColor   // 55%
    public let white5: UIColor   // 42%
    public let white6: UIColor   // 30%
    public let white7: UIColor   // 14%
    
    public init(
        white1: UIColor, white2: UIColor, white3: UIColor, white4: UIColor,
        white5: UIColor, white6: UIColor, white7: UIColor
    ) {
        self.white1 = white1
        self.white2 = white2
        self.white3 = white3
        self.white4 = white4
        self.white5 = white5
        self.white6 = white6
        self.white7 = white7
    }
    
    public static var standard: WhiteColorToken {
        return WhiteColorToken(
            white1: UIColor.white.withAlphaComponent(1.0),
            white2: UIColor.white.withAlphaComponent(0.93),
            white3: UIColor.white.withAlphaComponent(0.75),
            white4: UIColor.white.withAlphaComponent(0.55),
            white5: UIColor.white.withAlphaComponent(0.42),
            white6: UIColor.white.withAlphaComponent(0.30),
            white7: UIColor.white.withAlphaComponent(0.14)
        )
    }
}

public struct AccentColorToken {
    public let turquoiseLight = themColor(hex: "#00ABD6")
    public let purpleLight = themColor(hex: "#8157FF")
    public let magentaLight = themColor(hex: "#F5457F")
    public let orangeLight = themColor(hex: "#FF6A4C")
    
    public let turquoiseDark = themColor(hex: "#008FB2")
    public let purpleDark = themColor(hex: "#693CF0")
    public let magentaDark = themColor(hex: "#C22F56")
    public let orangeDark = themColor(hex: "#F25B35")
    
    private static func themColor(hex: String) -> UIColor {
        return UIColor(hex: hex) ?? .black
    }
}
