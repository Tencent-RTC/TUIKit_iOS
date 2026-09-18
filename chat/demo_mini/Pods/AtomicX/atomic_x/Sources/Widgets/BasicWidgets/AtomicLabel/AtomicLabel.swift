//
//  AtomicLabel.swift
//  AtomicX
//
//  Created by CY zhao on 2025/11/28.
//

import Foundation
import UIKit
import Combine

// MARK: - LabelAppearance

/// Label 外观配置，定义文本显示的基础视觉样式
/// 通过 Theme/Design Tokens 确保不同页面/场景采用一致的字体与颜色体系
public struct LabelAppearance {
    public let textColor: UIColor
    public let backgroundColor: UIColor
    public let font: UIFont
    
    public var cornerRadius: CGFloat
    
    public init(textColor: UIColor, backgroundColor: UIColor = .clear, font: UIFont, cornerRadius: CGFloat = 0.0 ) {
        self.textColor = textColor
        self.backgroundColor = backgroundColor
        self.font = font
        self.cornerRadius = cornerRadius
    }
    
    public static func defaultAppearance(for theme: Theme) -> LabelAppearance {
        return LabelAppearance(
            textColor: theme.tokens.color.textColorPrimary,
            backgroundColor: theme.tokens.color.textColorLink,
            font: theme.tokens.typography.Medium14,
            cornerRadius: theme.tokens.borderRadius.none
        )
    }
}

// MARK: - IconConfiguration

public struct IconConfiguration {
    public enum Position {
        case left
        case right
    }
    
    public let image: UIImage?
    public let position: Position
    public let spacing: CGFloat
    public let size: CGSize?
    
    /// 初始化图标配置
    /// - Parameters:
    ///   - icon: 图标图片资源标识
    ///   - position: 图标位置，默认 .left（文本左侧）
    ///   - spacing: 图文间距，默认 4pt（普通模式）
    ///   - size: 强制指定图标大小，默认 nil（自动适配）
    public init(
        icon: UIImage?,
        position: Position = .left,
        spacing: CGFloat = 4,
        size: CGSize? = nil
    ) {
        self.image = icon
        self.position = position
        self.spacing = max(0, spacing)
        self.size = size
    }
}

// MARK: - AtomicLabel

/// AtomicX 基础 Label 组件
/// 支持纯文本展示和简单图文混排，通过 Theme/Design Tokens 实现主题化
/// 图文混排采用 NSTextAttachment 实现，图标作为文本的一部分参与排版
public class AtomicLabel: UILabel {
    
    // MARK: - Type Aliases
    
    public typealias AppearanceProvider = (Theme) -> LabelAppearance
    
    // MARK: - Public Properties
    
    public override var text: String? {
        get { return _rawText }
        set {
            _rawText = newValue
            rebuildAttributedText()
        }
    }
    
    public var iconConfiguration: IconConfiguration? {
        didSet {
            rebuildAttributedText()
            invalidateIntrinsicContentSize()
        }
    }
    
    public var padding: UIEdgeInsets = .zero {
        didSet {
            invalidateIntrinsicContentSize()
            setNeedsDisplay()
        }
    }
    
    // MARK: - Private Properties
    
    private var appearanceProvider: AppearanceProvider
    private var currentAppearance: LabelAppearance?
    private var _rawText: String?
    private var cancellables = Set<AnyCancellable>()
    
    // MARK: - Initialization
    
    public init(_ text: String = "", appearanceProvider: @escaping AppearanceProvider = LabelAppearance.defaultAppearance) {
        self.appearanceProvider = appearanceProvider
        super.init(frame: .zero)
        self._rawText = text
        bindTheme()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    // MARK: - Layout Overrides
    
    public override func textRect(forBounds bounds: CGRect, limitedToNumberOfLines numberOfLines: Int) -> CGRect {
        let insetBounds = bounds.inset(by: padding)
        let textRect = super.textRect(forBounds: insetBounds, limitedToNumberOfLines: numberOfLines)
        
        let invertedInsets = UIEdgeInsets(
            top: -padding.top,
            left: -padding.left,
            bottom: -padding.bottom,
            right: -padding.right
        )
        
        return textRect.inset(by: invertedInsets)
    }
    
    public override func drawText(in rect: CGRect) {
        let insetRect = rect.inset(by: padding)
        super.drawText(in: insetRect)
    }
    
    public override func layoutSubviews() {
        super.layoutSubviews()
        self.applyCornerRadius(currentAppearance?.cornerRadius ?? 0)
    }
    
    // MARK: - AttributedText Building
    
    /// 重建 attributedText，整合文本、图标和行高配置
    private func rebuildAttributedText() {
        guard let text = _rawText, !text.isEmpty else {
            super.attributedText = nil
            return
        }
        
        let currentFont = font ?? UIFont.systemFont(ofSize: 14)
        let currentTextColor = textColor ?? UIColor.label
        
        // 构建段落样式
        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.alignment = textAlignment
        paragraphStyle.lineBreakMode = lineBreakMode
        
        // 文本属性
        let textAttributes: [NSAttributedString.Key: Any] = [
            .font: currentFont,
            .foregroundColor: currentTextColor,
            .paragraphStyle: paragraphStyle
        ]
        
        // 创建文本 AttributedString
        let textString = NSAttributedString(string: text, attributes: textAttributes)
        
        // 如果没有图标配置或图标加载失败，直接使用纯文本
        guard let config = iconConfiguration,
              let iconImage = config.image else {
            attributedText = textString
            return
        }
        // 创建图标 Attachment
        let attachment = NSTextAttachment()
        attachment.image = iconImage

        let iconSize = config.size ?? iconImage.size
        let iconY = (currentFont.capHeight - iconSize.height) / 2
        attachment.bounds = CGRect(x: 0, y: iconY, width: iconSize.width, height: iconSize.height)
        let iconString = NSAttributedString(attachment: attachment)
        
        let spacerAttachment = NSTextAttachment()
        spacerAttachment.bounds = CGRect(x: 0, y: 0, width: config.spacing, height: 0)
        let spacingString = NSAttributedString(attachment: spacerAttachment)
        
        // 根据位置拼接
        let result = NSMutableAttributedString()
        switch config.position {
        case .left:
            result.append(iconString)
            result.append(spacingString)
            result.append(textString)
        case .right:
            result.append(textString)
            result.append(spacingString)
            result.append(iconString)
        }
        result.addAttribute(.paragraphStyle, value: paragraphStyle, range: NSRange(location: 0, length: result.length))
        
        attributedText = result
    }
    
    // MARK: - Private Methods
    
    private func bindTheme() {
        ThemeStore.shared.$currentTheme
            .receive(on: DispatchQueue.main)
            .sink { [weak self] theme in
                guard let self = self else { return }
                self.applyAppearance(for: theme )
            }
            .store(in: &cancellables)
    }
    
    private func applyAppearance(for theme: Theme) {
        let appearance = appearanceProvider(theme)
        currentAppearance = appearance
        
        textColor = appearance.textColor
        backgroundColor = appearance.backgroundColor
        font = appearance.font
        
        rebuildAttributedText()
    }
    
    func applyCornerRadius(_ radius: CGFloat) {
        self.layer.masksToBounds = true
        self.layer.cornerCurve = .continuous
        self.layer.cornerRadius = radius
    }
}

