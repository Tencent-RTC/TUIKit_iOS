//
//  RoomThemeManager.swift
//  TUIRoomKit
//
//  Created on 2025/11/12.
//  Copyright © 2025 Tencent. All rights reserved.
//

import UIKit

/// 主题管理器
/// - 提供全局的 Light/Dark 模式颜色和样式适配
/// - 支持动态颜色创建和主题切换监听
///
/// **使用示例：**
/// ```swift
/// // 1. 使用预定义颜色
/// view.backgroundColor = RoomColors.background
/// label.textColor = RoomColors.primaryText
///
/// // 2. 创建动态颜色
/// let customColor = RoomThemeManager.dynamicColor(lightHex: "#FFFFFF", darkHex: "#000000")
///
/// // 3. 使用渐变
/// view.applyGradient(colors: RoomGradients.blueGradient())
///
/// // 4. 使用预定义字体
/// label.font = RoomFonts.title1
///
/// // 5. 使用间距和圆角
/// stackView.spacing = RoomSpacing.standard
/// view.layer.cornerRadius = RoomCornerRadius.medium
///
/// // 6. 应用卡片样式
/// cardView.applyCardStyle()
///
/// // 7. 监听主题变化
/// RoomThemeManager.shared.addObserver(self)
/// ```
public class RoomThemeManager {
    
    // MARK: - Singleton
    
    public static let shared = RoomThemeManager()
    
    private init() {}
    
    // MARK: - Current Theme
    
    /// 当前是否为暗黑模式
    public var isDarkMode: Bool {
        if #available(iOS 13.0, *) {
            return UITraitCollection.current.userInterfaceStyle == .dark
        }
        return false
    }
    
    /// 当前主题模式
    public var currentTheme: UIUserInterfaceStyle {
        if #available(iOS 13.0, *) {
            return UITraitCollection.current.userInterfaceStyle
        }
        return .light
    }
    
    // MARK: - Dynamic Colors
    
    /// 创建动态颜色（支持 Light/Dark 模式）
    /// - Parameters:
    ///   - light: 明亮模式颜色
    ///   - dark: 暗黑模式颜色
    /// - Returns: 动态颜色
    public static func dynamicColor(light: UIColor, dark: UIColor) -> UIColor {
        if #available(iOS 13.0, *) {
            return UIColor { traitCollection in
                return traitCollection.userInterfaceStyle == .dark ? dark : light
            }
        }
        return light
    }
    
    /// 创建动态颜色（使用十六进制）
    /// - Parameters:
    ///   - lightHex: 明亮模式十六进制颜色
    ///   - darkHex: 暗黑模式十六进制颜色
    /// - Returns: 动态颜色
    public static func dynamicColor(lightHex: String, darkHex: String) -> UIColor {
        return dynamicColor(
            light: UIColor(hex: lightHex),
            dark: UIColor(hex: darkHex)
        )
    }
    
    // MARK: - Theme Observer
    
    /// 主题变化观察者协议
    public protocol ThemeObserver: AnyObject {
        func themeDidChange(isDarkMode: Bool)
    }
    
    private var observers: NSHashTable<AnyObject> = NSHashTable.weakObjects()
    
    /// 添加主题观察者
    /// - Parameter observer: 观察者
    public func addObserver(_ observer: ThemeObserver) {
        observers.add(observer)
    }
    
    /// 移除主题观察者
    /// - Parameter observer: 观察者
    public func removeObserver(_ observer: ThemeObserver) {
        observers.remove(observer)
    }
    
    /// 通知主题变化
    internal func notifyThemeChange() {
        let isDark = isDarkMode
        observers.allObjects.forEach { observer in
            (observer as? ThemeObserver)?.themeDidChange(isDarkMode: isDark)
        }
    }
}

// MARK: - UIColor Extension

extension UIColor {
    
    /// 通过十六进制创建颜色
    /// - Parameters:
    ///   - hex: 十六进制字符串 (如 "#FFFFFF" 或 "FFFFFF")
    ///   - alpha: 透明度 (0.0 - 1.0)
    convenience init(hex: String, alpha: CGFloat = 1.0) {
        var hexSanitized = hex.trimmingCharacters(in: .whitespacesAndNewlines)
        hexSanitized = hexSanitized.replacingOccurrences(of: "#", with: "")
        
        var rgb: UInt64 = 0
        Scanner(string: hexSanitized).scanHexInt64(&rgb)
        
        let red = CGFloat((rgb & 0xFF0000) >> 16) / 255.0
        let green = CGFloat((rgb & 0x00FF00) >> 8) / 255.0
        let blue = CGFloat(rgb & 0x0000FF) / 255.0
        
        self.init(red: red, green: green, blue: blue, alpha: alpha)
    }
    
    /// 转换为十六进制字符串
    var hexString: String {
        var red: CGFloat = 0
        var green: CGFloat = 0
        var blue: CGFloat = 0
        var alpha: CGFloat = 0
        
        getRed(&red, green: &green, blue: &blue, alpha: &alpha)
        
        let rgb: Int = Int(red * 255) << 16 | Int(green * 255) << 8 | Int(blue * 255)
        return String(format: "#%06X", rgb)
    }
}

// MARK: - RoomColors (预定义颜色)

/// RoomKit 预定义颜色
/// - 所有色值来源于 Figma 设计稿 Token 规范
/// - Figma 链接: https://www.figma.com/design/3iztZNCXD1Aip70GPXnEah/RoomKit?node-id=6445-16618
public struct RoomColors {
    
    // MARK: - Grayscale Colors (灰阶颜色)
    
    /// G2 - 主文本色
    public static let g2 = RoomThemeManager.dynamicColor(
        lightHex: "#22262E",
        darkHex: "#22262E"
    )
    
    /// G3 - 次要文本色/标签色
    public static let g3 = RoomThemeManager.dynamicColor(
        lightHex: "#4F586B",
        darkHex: "#4F586B"
    )
    
    /// G6 - 占位符文本色 (通常配合 0.5 透明度使用)
    public static let g6 = RoomThemeManager.dynamicColor(
        lightHex: "#B2BBD1",
        darkHex: "#B2BBD1"
    )
    
    /// G7 - 浅背景色/开关关闭状态
    public static let g7 = RoomThemeManager.dynamicColor(
        lightHex: "#E7ECF6",
        darkHex: "#E7ECF6"
    )
    
    /// G8 - 分割线/卡片背景色
    public static let g8 = RoomThemeManager.dynamicColor(
        lightHex: "#F2F5FC",
        darkHex: "#F2F5FC"
    )
    
    public static let b2d = RoomThemeManager.dynamicColor(
        lightHex: "#1AFFC9",
        darkHex: "#1AFFC9"
    )
    
    public static let b1d = RoomThemeManager.dynamicColor(
        lightHex: "#4791FF",
        darkHex: "#4791FF"
    )
    
    public static let adminTagColor = RoomThemeManager.dynamicColor(
        lightHex: "#F06C4B",
        darkHex: "#F06C4B"
    )
    
    public static let copyButtonBackground = RoomThemeManager.dynamicColor(
        lightHex: "#6B758A",
        darkHex: "#6B758A"
    )
    
    // MARK: - Brand Colors (品牌色)
    
    /// B1 - 主色蓝/开关开启状态
    public static let b1 = RoomThemeManager.dynamicColor(
        lightHex: "#1C66E5",
        darkHex: "#1C66E5"
    )
    
    /// 品牌蓝 - 按钮背景色
    public static let brandBlue = RoomThemeManager.dynamicColor(
        lightHex: "#006EFF",
        darkHex: "#006EFF"
    )
    
    public static let endTitleColor = RoomThemeManager.dynamicColor(
        lightHex: "#ED414D",
        darkHex: "#ED414D"
    )
    
    public static let actionSheetTitleColor = RoomThemeManager.dynamicColor(
        lightHex: "#7C85A6",
        darkHex: "#7C85A6"
    )
    
    public static let defaultActionButtonTitleColor = RoomThemeManager.dynamicColor(
        lightHex: "#006CFF",
        darkHex: "#006CFF"
    )
    
    public static let destructiveActionButtonTitleColor = RoomThemeManager.dynamicColor(
        lightHex: "#E5395C",
        darkHex: "#E5395C"
    )
    
    // MARK: - Background Colors (背景色)
    
    /// 主题背景色
    public static let themeBackground = RoomThemeManager.dynamicColor(
        lightHex: "#F8F9FB",
        darkHex: "#F8F9FB"
    )
    
    /// 卡片背景色
    public static let cardBackground = RoomThemeManager.dynamicColor(
        lightHex: "#FFFFFF",
        darkHex: "#FFFFFF"
    )
    
    /// 房间内背景色
    public static let inRoomBackground = RoomThemeManager.dynamicColor(
        lightHex: "#0F1014",
        darkHex: "#0F1014"
    )
    
}

// MARK: - RoomFonts (预定义字体)

/// RoomKit 预定义字体
public struct RoomFonts {
    public static func pingFangSCFont(size: CGFloat, weight: UIFont.Weight) -> UIFont {
        return UIFont.systemFont(ofSize: size, weight: weight)
    }
}

// MARK: - RoomSpacing (预定义间距)

/// RoomKit 预定义间距
public struct RoomSpacing {
    
    /// 超小间距 (4pt)
    public static let extraSmall: CGFloat = 4
    
    /// 小间距 (8pt)
    public static let small: CGFloat = 8
    
    /// 中等间距 (12pt)
    public static let medium: CGFloat = 12
    
    /// 标准间距 (16pt)
    public static let standard: CGFloat = 16
    
    /// 大间距 (20pt)
    public static let large: CGFloat = 20
    
    /// 超大间距 (24pt)
    public static let extraLarge: CGFloat = 24
    
    /// 特大间距 (32pt)
    public static let huge: CGFloat = 32
}

// MARK: - RoomCornerRadius (预定义圆角)

/// RoomKit 预定义圆角
public struct RoomCornerRadius {
    
    /// 小圆角 (4pt)
    public static let small: CGFloat = 4
    
    /// 中等圆角 (8pt)
    public static let medium: CGFloat = 8
    
    /// 标准圆角 (12pt)
    public static let standard: CGFloat = 12
    
    /// 大圆角 (16pt)
    public static let large: CGFloat = 16
    
    /// 超大圆角 (20pt)
    public static let extraLarge: CGFloat = 20
    
    /// 圆形 (用于计算)
    public static func circle(size: CGFloat) -> CGFloat {
        return size / 2
    }
}

// MARK: - UIViewController Extension

extension UIViewController {
    
    /// 监听主题变化
    @objc open func themeDidChange() {
        // 子类重写此方法以响应主题变化
    }
    
    /// 开始监听主题变化
    public func startObservingTheme() {
        if #available(iOS 13.0, *) {
            NotificationCenter.default.addObserver(
                self,
                selector: #selector(handleThemeChange),
                name: UIApplication.didBecomeActiveNotification,
                object: nil
            )
        }
    }
    
    /// 停止监听主题变化
    public func stopObservingTheme() {
        if #available(iOS 13.0, *) {
            NotificationCenter.default.removeObserver(
                self,
                name: UIApplication.didBecomeActiveNotification,
                object: nil
            )
        }
    }
    
    @objc private func handleThemeChange() {
        themeDidChange()
        RoomThemeManager.shared.notifyThemeChange()
    }
}
