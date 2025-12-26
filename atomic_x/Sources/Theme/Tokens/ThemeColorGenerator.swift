//
//  ThemeColorGenerator.swift
//  Pods
//
//  Created by CY zhao on 2025/11/14.
//

import UIKit
import RTCCommon

class ThemeColorGenerator {
    
    // MARK: - Data Structures
    
    private struct HSL {
        var h: Double // 0 - 360
        var s: Double // 0 - 100
        var l: Double // 0 - 100
    }
    
    private struct Adjustment {
        let s: Double
        let l: Double
    }
    
    // MARK: - Constants (Palettes & Adjustments)
    
    private typealias ColorPaletteMap = [Int: String]
    private struct FullPalette {
        let light: ColorPaletteMap
        let dark: ColorPaletteMap
    }
    
    private static let BLUE_PALETTE = FullPalette(
        light: [1: "#ebf3ff", 2: "#cce2ff", 3: "#adcfff", 4: "#7aafff", 5: "#4588f5", 6: "#1c66e5", 7: "#0d49bf", 8: "#033099", 9: "#001f73", 10: "#00124d"],
        dark: [1: "#1c2333", 2: "#243047", 3: "#2f4875", 4: "#305ba6", 5: "#2b6ad6", 6: "#4086ff", 7: "#5c9dff", 8: "#78b0ff", 9: "#9cc7ff", 10: "#c2deff"]
    )
    
    private static let GREEN_PALETTE = FullPalette(
        light: [1: "#dcfae9", 2: "#b6f0d1", 3: "#84e3b5", 4: "#5ad69e", 5: "#3cc98c", 6: "#0abf77", 7: "#09a768", 8: "#078f59", 9: "#067049", 10: "#044d37"],
        dark: [1: "#1a2620", 2: "#22352c", 3: "#2f4f3f", 4: "#377355", 5: "#368f65", 6: "#38a673", 7: "#62b58b", 8: "#8bc7a9", 9: "#a9d4bd", 10: "#c8e5d5"]
    )
    
    private static let RED_PALETTE = FullPalette(
        light: [1: "#ffe7e6", 2: "#fcc9c7", 3: "#faaeac", 4: "#f58989", 5: "#e86666", 6: "#e54545", 7: "#c93439", 8: "#ad2934", 9: "#8f222d", 10: "#6b1a27"],
        dark: [1: "#2b1c1f", 2: "#422324", 3: "#613234", 4: "#8a4242", 5: "#c2544e", 6: "#e6594c", 7: "#e57a6e", 8: "#f3a599", 9: "#facbc3", 10: "#fae4de"]
    )
    
    private static let ORANGE_PALETTE = FullPalette(
        light: [1: "#ffeedb", 2: "#ffd6b2", 3: "#ffbe85", 4: "#ffa455", 5: "#ff8b2b", 6: "#ff7200", 7: "#e05d00", 8: "#bf4900", 9: "#8f370b", 10: "#662200"],
        dark: [1: "#211a19", 2: "#35231a", 3: "#462e1f", 4: "#653c21", 5: "#96562a", 6: "#e37f32", 7: "#e39552", 8: "#eead72", 9: "#f7cfa4", 10: "#f9e9d1"]
    )
    
    private static let HSL_ADJUSTMENTS: [String: [Int: Adjustment]] = [
        "light": [
            1: Adjustment(s: -40, l: 45),
            2: Adjustment(s: -30, l: 35),
            3: Adjustment(s: -20, l: 25),
            4: Adjustment(s: -10, l: 15),
            5: Adjustment(s: -5, l: 5),
            6: Adjustment(s: 0, l: 0),
            7: Adjustment(s: 5, l: -10),
            8: Adjustment(s: 10, l: -20),
            9: Adjustment(s: 15, l: -30),
            10: Adjustment(s: 20, l: -40)
        ],
        "dark": [
            1: Adjustment(s: -60, l: -35),
            2: Adjustment(s: -50, l: -25),
            3: Adjustment(s: -40, l: -15),
            4: Adjustment(s: -30, l: -5),
            5: Adjustment(s: -20, l: 5),
            6: Adjustment(s: 0, l: 0),
            7: Adjustment(s: -10, l: 15),
            8: Adjustment(s: -20, l: 30),
            9: Adjustment(s: -30, l: 45),
            10: Adjustment(s: -40, l: 60)
        ]
    ]

    // MARK: - Public API
    
    /// 生成颜色变体数组 (1-10级)
    /// - Parameters:
    ///   - baseColor: 十六进制颜色字符串 (例如 "#1c66e5")
    ///   - theme: 主题模式 (.light 或 .dark)
    /// - Returns: 包含 10 个 Hex 颜色字符串的数组，按顺序排列
    static func generateThemeColors(baseColor: String, themeId: String) -> [UIColor] {
        if isStandardColor(baseColor) {
            let palette = getClosestPalette(color: baseColor)
            let targetColors = themeId == "light" ? palette.light : palette.dark
            return targetColors.sorted { $0.key < $1.key }.map { UIColor(hex: $0.value) ?? .white }
        }
        
        return generateDynamicColorVariations(baseColor: baseColor, themeId: themeId)
    }
    
    static func generateNeutralColors() -> [UIColor] {
        let garyColorString =
            ["#F9FAFC", "#F0F2F7", "#E6E9F0", "#D1D4DE", "#C0C3CC", "#B3B6BE", "#A5A9B0",
             "#676A70", "#54565C", "#48494F", "#3A3C42", "#2B2C30", "#1F2024", "#131417"]
        return garyColorString.map { UIColor(hex: $0) ?? .gray }
    }
    
    // MARK: - Private Logic (Algorithms)
    
    private static func generateDynamicColorVariations(baseColor: String, themeId: String) -> [UIColor] {
        var variations: [String] = []
        guard let adjustments = HSL_ADJUSTMENTS[themeId] else { return [] }
        
        let baseHsl = hexToHSL(hexInput: baseColor)
        
        // 计算校准因子
        var saturationFactor: Double = 1
        if baseHsl.s > 70 {
            saturationFactor = 0.8
        } else if baseHsl.s < 30 {
            saturationFactor = 1.2
        }
        
        var lightnessFactor: Double = 1
        if baseHsl.l > 70 {
            lightnessFactor = 0.8
        } else if baseHsl.l < 30 {
            lightnessFactor = 1.2
        }
        
        // 循环生成 1 到 10 级
        for i in 1...10 {
            if let adjustment = adjustments[i] {
                let adjustedS = adjustment.s * saturationFactor
                let adjustedL = adjustment.l * lightnessFactor
                
                let newColor = adjustColor(baseColor: baseColor, adjustmentS: adjustedS, adjustmentL: adjustedL)
                variations.push(newColor) // 辅助扩展方法
            }
        }
        
        return variations.map { hex in
            UIColor(hex: hex) ?? .white
        }
    }
    
    private static func isStandardColor(_ color: String) -> Bool {
        let standardColors = [
            BLUE_PALETTE.light[6]!,
            GREEN_PALETTE.light[6]!,
            RED_PALETTE.light[6]!,
            ORANGE_PALETTE.light[6]!
        ]
        
        let inputHsl = hexToHSL(hexInput: color)
        
        for standardColor in standardColors {
            let standardHsl = hexToHSL(hexInput: standardColor)
            
            var dh = abs(inputHsl.h - standardHsl.h)
            dh = min(dh, 360 - dh)
            
            let ds = abs(inputHsl.s - standardHsl.s)
            let dl = abs(inputHsl.l - standardHsl.l)
            
            if dh < 30 && ds < 30 && dl < 30 {
                return true
            }
        }
        return false
    }
    
    private static func getClosestPalette(color: String) -> FullPalette {
        let hsl = hexToHSL(hexInput: color)
        
        let palettes: [(palette: FullPalette, baseColor: String)] = [
            (BLUE_PALETTE, BLUE_PALETTE.light[6]!),
            (GREEN_PALETTE, GREEN_PALETTE.light[6]!),
            (RED_PALETTE, RED_PALETTE.light[6]!),
            (ORANGE_PALETTE, ORANGE_PALETTE.light[6]!)
        ]
        
        // 计算距离并排序
        let sorted = palettes.map { item -> (palette: FullPalette, distance: Double) in
            let targetHsl = hexToHSL(hexInput: item.baseColor)
            
            var dh = abs(hsl.h - targetHsl.h)
            dh = min(dh, 360 - dh)
            let ds = hsl.s - targetHsl.s
            let dl = hsl.l - targetHsl.l
            
            let distance = sqrt(dh * dh + ds * ds + dl * dl)
            return (item.palette, distance)
        }.sorted { a, b in
            return a.distance < b.distance
        }
        
        return sorted.first?.palette ?? BLUE_PALETTE
    }
    
    private static func adjustColor(baseColor: String, adjustmentS: Double, adjustmentL: Double) -> String {
        let hsl = hexToHSL(hexInput: baseColor)
        // 限制范围 0-100
        let newS = max(0, min(100, hsl.s + adjustmentS))
        let newL = max(0, min(100, hsl.l + adjustmentL))
        
        return HSLToHex(h: hsl.h, s: newS, l: newL)
    }
    
    // MARK: - Math Helpers (Ported from TS)
    
    private static func hexToHSL(hexInput: String) -> HSL {
        var hex = hexInput.replacingOccurrences(of: "#", with: "")
        if hex.count != 6 { return HSL(h: 0, s: 0, l: 0) } // Error Handling
        
        // Swift String slicing is tricky, using simple extraction
        let rStr = hex.prefix(2)
        let gStr = hex.dropFirst(2).prefix(2)
        let bStr = hex.dropFirst(4).prefix(2)
        
        guard let rInt = Int(rStr, radix: 16),
              let gInt = Int(gStr, radix: 16),
              let bInt = Int(bStr, radix: 16) else {
            return HSL(h: 0, s: 0, l: 0)
        }
        
        let r = Double(rInt) / 255.0
        let g = Double(gInt) / 255.0
        let b = Double(bInt) / 255.0
        
        let maxVal = max(r, g, b)
        let minVal = min(r, g, b)
        
        var h: Double = 0
        var s: Double = 0
        let l: Double = (maxVal + minVal) / 2.0
        
        if maxVal != minVal {
            let d = maxVal - minVal
            s = l > 0.5 ? d / (2 - maxVal - minVal) : d / (maxVal + minVal)
            
            switch maxVal {
            case r:
                h = (g - b) / d + (g < b ? 6 : 0)
            case g:
                h = (b - r) / d + 2
            case b:
                h = (r - g) / d + 4
            default:
                break
            }
            h /= 6
        }
        
        return HSL(h: h * 360, s: s * 100, l: l * 100)
    }
    
    private static func HSLToHex(h: Double, s: Double, l: Double) -> String {
        let normalizedL = l / 100.0
        let normalizedS = s
        let a = normalizedS * min(normalizedL, 1 - normalizedL) / 100.0
        
        let f = { (n: Double) -> String in
            let k = (n + h / 30.0).truncatingRemainder(dividingBy: 12)
            let subCalc = max(min(k - 3, 9 - k, 1), -1)
            let color = normalizedL - a * subCalc
            
            let hexInt = Int(round(255 * color))
            return String(format: "%02x", hexInt)
        }
        
        return "#\(f(0))\(f(8))\(f(4))"
    }
    
    private static func blend(_ color1: UIColor, with color2: UIColor, ratio: CGFloat) -> UIColor {
        var r1: CGFloat = 0, g1: CGFloat = 0, b1: CGFloat = 0, a1: CGFloat = 0
        var r2: CGFloat = 0, g2: CGFloat = 0, b2: CGFloat = 0, a2: CGFloat = 0
        
        color1.getRed(&r1, green: &g1, blue: &b1, alpha: &a1)
        color2.getRed(&r2, green: &g2, blue: &b2, alpha: &a2)
        
        return UIColor(
            red: r1 * ratio + r2 * (1 - ratio),
            green: g1 * ratio + g2 * (1 - ratio),
            blue: b1 * ratio + b2 * (1 - ratio),
            alpha: a1 * ratio + a2 * (1 - ratio)
        )
    }
}

// MARK: - Helper Extension for Array Push
private extension Array {
    mutating func push(_ element: Element) {
        self.append(element)
    }
}
