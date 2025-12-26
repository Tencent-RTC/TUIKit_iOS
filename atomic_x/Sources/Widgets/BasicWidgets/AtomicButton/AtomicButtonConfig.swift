//
//  AtomicButtonConfig.swift
//  AtomicX
//
//  Created on 2025-11-26.
//

import UIKit

// MARK: - Button Colors

public struct ButtonColors {
    public let backgroundColor: UIColor
    public let textColor: UIColor
    public let borderColor: UIColor
    
    public init(
        backgroundColor: UIColor,
        textColor: UIColor,
        borderColor: UIColor
    ) {
        self.backgroundColor = backgroundColor
        self.textColor = textColor
        self.borderColor = borderColor
    }
}

// MARK: - Button Design Config

public struct AtomicButtonConfig {
    public let normalButtonColor: ButtonColors
    public let highlightedButtonColor: ButtonColors
    public let disabledButtonColor: ButtonColors
    
    public let cornerRadius: CGFloat
    public let borderWidth: CGFloat
    
    public let font: UIFont
    
    public init(
        normalButtonColor: ButtonColors,
        cornerRadius: CGFloat = 0,
        borderWidth: CGFloat = 1,
        font: UIFont
    ) {
        let autoHighlight = AtomicButtonConfig.generateHighlighted(from: normalButtonColor)
        let autoDisabled = AtomicButtonConfig.generateDisabled(from: normalButtonColor)
        
        self.normalButtonColor = normalButtonColor
        self.highlightedButtonColor = autoHighlight
        self.disabledButtonColor = autoDisabled
        self.cornerRadius = cornerRadius
        self.borderWidth = borderWidth
        self.font = font
    }
    
    fileprivate init(
        normalButtonColor: ButtonColors,
        highlightedButtonColor: ButtonColors,
        disabledButtonColor: ButtonColors,
        cornerRadius: CGFloat = 0,
        borderWidth: CGFloat = 1,
        font: UIFont
    ) {
        self.normalButtonColor = normalButtonColor
        self.highlightedButtonColor = highlightedButtonColor
        self.disabledButtonColor = disabledButtonColor
        self.cornerRadius = cornerRadius
        self.borderWidth = borderWidth
        self.font = font
    }
    
    private static func generateHighlighted(from source: ButtonColors) -> ButtonColors {
        return ButtonColors(
            backgroundColor: source.backgroundColor,
            textColor: source.textColor,
            borderColor: source.borderColor
        )
    }
    
    private static func generateDisabled(from source: ButtonColors) -> ButtonColors {
        return ButtonColors(
            backgroundColor: source.backgroundColor.withAlphaComponent(0.3),
            textColor: source.textColor.withAlphaComponent(0.3),
            borderColor: source.borderColor.withAlphaComponent(0.3)
        )
    }
}

// MARK: - Theme Factory Methods

extension AtomicButtonConfig {
    
    /// 预设配置获取接口
    /// - Parameters:
    ///   - intent: 按钮的语义（主色、默认、警告）
    ///   - variant: 按钮的样式（填充、描边、文字）
    ///   - theme: 当前的主题对象（提供基础色板）
    public static func preset(
        colorType: ButtonColorType,
        variant: ButtonVariant,
        ButtonSize: ButtonSize,
        for theme: Theme
    ) -> AtomicButtonConfig {
        let font: UIFont
        switch ButtonSize {
        case .large, .medium:
            font = theme.tokens.typography.Medium16
        case .small:
            font = theme.tokens.typography.Medium14
        case .xsmall:
            font = theme.tokens.typography.Medium12
        }
        
        let colors = theme.tokens.color
        func make(_ bg: UIColor, _ text: UIColor, _ border: UIColor) -> ButtonColors {
            return ButtonColors(backgroundColor: bg, textColor: text, borderColor: border)
        }
        
        let normal: ButtonColors
        let highlight: ButtonColors
        let disabled: ButtonColors
        var borderWidth: CGFloat
        let cornerRadius = theme.tokens.borderRadius.radiusCircle

        switch variant {
        case .filled:
            borderWidth = 0
            
            switch colorType {
            case .primary:
                normal    = make(colors.buttonColorPrimaryDefault,  colors.textColorButton,         colors.clearColor)
                highlight = make(colors.buttonColorPrimaryActive,   colors.textColorButton,         colors.clearColor)
                disabled  = make(colors.buttonColorPrimaryDisabled, colors.textColorButtonDisabled, colors.clearColor)
            case .secondary:
                normal    = make(colors.buttonColorSecondaryDefault,  colors.textColorPrimary, colors.clearColor)
                highlight = make(colors.buttonColorSecondaryActive,   colors.textColorTertiary, colors.clearColor)
                disabled  = make(colors.buttonColorSecondaryDisabled, colors.textColorDisable, colors.clearColor)
            case .danger:
                normal    = make(colors.buttonColorHangupDefault,  colors.textColorButton,         colors.clearColor)
                highlight = make(colors.buttonColorHangupActive,   colors.textColorButton,         colors.clearColor)
                disabled  = make(colors.buttonColorHangupDisabled, colors.textColorButtonDisabled, colors.clearColor)
            }
            
        case .outlined:
            borderWidth = 1
            
            switch colorType {
            case .primary:
                normal    = make(colors.clearColor, colors.buttonColorPrimaryDefault,  colors.buttonColorPrimaryDefault)
                highlight = make(colors.clearColor, colors.buttonColorPrimaryActive,   colors.buttonColorPrimaryActive)
                disabled  = make(colors.clearColor, colors.buttonColorPrimaryDisabled, colors.buttonColorPrimaryDisabled)
            case .secondary:
                normal    = make(colors.clearColor, colors.textColorPrimary,  colors.strokeColorPrimary)
                highlight = make(colors.clearColor, colors.textColorTertiary, colors.strokeColorModule)
                disabled  = make(colors.clearColor, colors.textColorDisable,  colors.strokeColorSecondary)
            case .danger:
                normal    = make(colors.clearColor, colors.buttonColorHangupDefault,  colors.buttonColorHangupDefault)
                highlight = make(colors.clearColor, colors.buttonColorHangupActive,   colors.buttonColorHangupActive)
                disabled  = make(colors.clearColor, colors.buttonColorHangupDisabled, colors.buttonColorHangupDisabled)
            }
            
        case .text:
            borderWidth = 0
            
            switch colorType {
            case .primary:
                normal    = make(colors.clearColor, colors.buttonColorPrimaryDefault, colors.clearColor)
                highlight = make(colors.clearColor, colors.buttonColorPrimaryActive,   colors.clearColor)
                disabled  = make(colors.clearColor, colors.buttonColorPrimaryDisabled, colors.clearColor)
            case .secondary:
                normal    = make(colors.clearColor, colors.textColorPrimary,  colors.clearColor)
                highlight = make(colors.clearColor, colors.textColorTertiary, colors.clearColor)
                disabled  = make(colors.clearColor, colors.textColorDisable,  colors.clearColor)
            case .danger:
                normal    = make(colors.clearColor, colors.buttonColorHangupDefault,  colors.clearColor)
                highlight = make(colors.clearColor, colors.buttonColorHangupActive,   colors.clearColor)
                disabled  = make(colors.clearColor, colors.buttonColorHangupDisabled, colors.clearColor)
            }
        }
        
        return AtomicButtonConfig(
            normalButtonColor: normal,
            highlightedButtonColor: highlight,
            disabledButtonColor: disabled,
            cornerRadius: cornerRadius,
            borderWidth: borderWidth,
            font: font
        )
    }
}
