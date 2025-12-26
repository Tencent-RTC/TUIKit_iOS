//
//  AtomicToastConfig.swift
//  AtomicX
//
//  Created on 2025-12-02.
//

import UIKit

// MARK: - Icon Asset Names

private enum IconAssetName {
    static let info = "toast_info"
    static let help = "toast_help"
    static let loading = "toast_load"
    static let success = "toast_success"
    static let warning = "toast_warn"
    static let error = "toast_error"
}

// MARK: - Toast Style Preset

public enum ToastStyle {
    case text
    case info
    case help
    case loading
    case success
    case warning
    case error
}

// MARK: - Toast Design Config

struct AtomicToastConfig {
    let backgroundColor: UIColor
    let textColor: UIColor
    let cornerRadius: CGFloat
    let shadow: Shadow?
    let font: UIFont
    let customIcon: UIImage?

    init(
        backgroundColor: UIColor,
        textColor: UIColor,
        cornerRadius: CGFloat,
        shadow: Shadow? = nil,
        font: UIFont,
        customIcon: UIImage? = nil
    ) {
        self.backgroundColor = backgroundColor
        self.textColor = textColor
        self.cornerRadius = cornerRadius
        self.shadow = shadow
        self.font = font
        self.customIcon = customIcon
    }
}

// MARK: - Theme Factory Methods

extension AtomicToastConfig {

    static func style(
        _ style: ToastStyle,
        for theme: Theme,
        customIcon: UIImage? = nil
    ) -> AtomicToastConfig {
        let tokens = theme.tokens
        let font = tokens.typography.Medium14
        let shadow = tokens.shadows.smallShadow
        let cornerRadius = tokens.borderRadius.radius6

        let iconToUse = resolveIcon(for: style, customIcon: customIcon)
        
        return AtomicToastConfig(
            backgroundColor: tokens.color.bgColorOperate,
            textColor: tokens.color.textColorPrimary,
            cornerRadius: cornerRadius,
            shadow: shadow,
            font: font,
            customIcon: iconToUse
        )
    }
    
    private static func resolveIcon(for style: ToastStyle, customIcon: UIImage?) -> UIImage? {
        if let customIcon = customIcon {
            return customIcon
        }
        
        return iconName(for: style).flatMap { UIImage.atomicXBundleImage(named: $0) }
    }
    
    private static func iconName(for style: ToastStyle) -> String? {
        switch style {
        case .text:
            return nil
        case .info:
            return IconAssetName.info
        case .help:
            return IconAssetName.help
        case .loading:
            return IconAssetName.loading
        case .success:
            return IconAssetName.success
        case .warning:
            return IconAssetName.warning
        case .error:
            return IconAssetName.error
        }
    }
}
