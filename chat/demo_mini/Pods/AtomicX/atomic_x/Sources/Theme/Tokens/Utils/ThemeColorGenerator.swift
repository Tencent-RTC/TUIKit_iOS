//
//  ThemeColorGenerator.swift
//  Pods
//
//  Created by CY zhao on 2025/11/14.
//

import UIKit

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
    
    private struct Palette {
        let light: [Int: String]
        let dark: [Int: String]
    }
    
    private static let bluePalette = Palette(
        light: [1: "ebf3ff", 2: "cce2ff", 3: "adcfff", 4: "7aafff", 5: "4588f5", 6: "1c66e5", 7: "0d49bf", 8: "033099", 9: "001f73", 10: "00124d"],
        dark: [1: "1c2333", 2: "243047", 3: "2f4875", 4: "305ba6", 5: "2b6ad6", 6: "4086ff", 7: "5c9dff", 8: "78b0ff", 9: "9cc7ff", 10: "c2deff"]
    )
    
    private static let greenPalette = Palette(
        light: [1: "dcfae9", 2: "b6f0d1", 3: "84e3b5", 4: "5ad69e", 5: "3cc98c", 6: "0abf77", 7: "09a768", 8: "078f59", 9: "067049", 10: "044d37"],
        dark: [1: "1a2620", 2: "22352c", 3: "2f4f3f", 4: "377355", 5: "368f65", 6: "38a673", 7: "62b58b", 8: "8bc7a9", 9: "a9d4bd", 10: "c8e5d5"]
    )
    
    private static let redPalette = Palette(
        light: [1: "ffe7e6", 2: "fcc9c7", 3: "faaeac", 4: "f58989", 5: "e86666", 6: "e54545", 7: "c93439", 8: "ad2934", 9: "8f222d", 10: "6b1a27"],
        dark: [1: "2b1c1f", 2: "422324", 3: "613234", 4: "8a4242", 5: "c2544e", 6: "e6594c", 7: "e57a6e", 8: "f3a599", 9: "facbc3", 10: "fae4de"]
    )
    
    private static let orangePalette = Palette(
        light: [1: "ffeedb", 2: "ffd6b2", 3: "ffbe85", 4: "ffa455", 5: "ff8b2b", 6: "ff7200", 7: "e05d00", 8: "bf4900", 9: "8f370b", 10: "662200"],
        dark: [1: "211a19", 2: "35231a", 3: "462e1f", 4: "653c21", 5: "96562a", 6: "e37f32", 7: "e39552", 8: "eead72", 9: "f7cfa4", 10: "f9e9d1"]
    )
    
    private static let standardColorsHSL: [(hsl: HSL, palette: Palette)] = {
        let palettes = [bluePalette, greenPalette, redPalette, orangePalette]
        return palettes.compactMap { palette in
            guard let hex = palette.light[6] else { return nil }
            return (hexToHSL(hexInput: hex), palette)
        }
    }()
    
    private static let hslAdjustments: [ThemeMode: [Int: Adjustment]] = [
        .light: [
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
        .dark: [
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
    ///   - baseColor: 十六进制颜色字符串 (例如 "1c66e5")
    ///   - theme: 主题模式 (.light 或 .dark)
    /// - Returns: 包含 10 个 Hex 颜色字符串的数组，按顺序排列
    static func generateThemeColors(baseColor: String, themeMode: ThemeMode) -> [UIColor] {
        let inputHsl = hexToHSL(hexInput: baseColor)
        
        if isStandardColor(inputHsl), let palette = getClosestPalette(inputHsl)  {
            let targetMap = (themeMode == .light) ? palette.light : palette.dark
            return (1...10).compactMap { index in
                targetMap[index].flatMap { UIColor( $0) }
            }
        }
        
        return generateDynamicColorVariations(hsl: inputHsl, themeMode: themeMode)
    }
    
    static func generateNeutralColors() -> [UIColor] {
        let garyColorString =
            ["F9FAFC", "F0F2F7", "E6E9F0", "D1D4DE", "C0C3CC", "B3B6BE", "A5A9B0",
             "676A70", "54565C", "48494F", "3A3C42", "2B2C30", "1F2024", "131417"]
        return garyColorString.map { UIColor( $0) }
    }
    
    // MARK: - Private Logic (Algorithms)
    
    private static func generateDynamicColorVariations(hsl: HSL, themeMode: ThemeMode) -> [UIColor] {
        var variations: [UIColor] = []
        guard let adjustments = hslAdjustments[themeMode] else { return [] }
        
        var saturationFactor: Double = 1.0
        if hsl.s > 70 { saturationFactor = 0.8 }
        else if hsl.s < 30 { saturationFactor = 1.2 }
        
        var lightnessFactor: Double = 1.0
        if hsl.l > 70 { lightnessFactor = 0.8 }
        else if hsl.l < 30 { lightnessFactor = 1.2 }
        
        for i in 1...10 {
            guard let adjustment = adjustments[i] else { continue }
            let adjustedS = adjustment.s * saturationFactor
            let adjustedL = adjustment.l * lightnessFactor
            
            variations.append(adjustColor(hsl: hsl, adjustmentS: adjustedS, adjustmentL: adjustedL))
        }
        
        return variations
    }
    
    private static func isStandardColor(_ inputHsl: HSL) -> Bool {
        for standard in standardColorsHSL {
            let standardHsl = standard.hsl
            
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
    
    private static func getClosestPalette(_ inputHsl: HSL) -> Palette? {
        let sorted = standardColorsHSL.map { item -> (palette: Palette, distance: Double) in
            let standardHsl = item.hsl
            
            var dh = abs(inputHsl.h - standardHsl.h)
            dh = min(dh, 360 - dh)
            let ds = inputHsl.s - standardHsl.s
            let dl = inputHsl.l - standardHsl.l
            
            let distance = sqrt(dh * dh + ds * ds + dl * dl)
            return (item.palette, distance)
        }.sorted { $0.distance < $1.distance }
        
        return sorted.first?.palette
    }
    
    private static func adjustColor(hsl: HSL, adjustmentS: Double, adjustmentL: Double) -> UIColor {
        let newS = max(0, min(100, hsl.s + adjustmentS))
        let newL = max(0, min(100, hsl.l + adjustmentL))
        
        let h = hsl.h
        let s = newS / 100.0
        let l = newL / 100.0
        
        let c = (1 - abs(2 * l - 1)) * s
        let x = c * (1 - abs((h / 60).truncatingRemainder(dividingBy: 2) - 1))
        let m = l - c / 2
        
        var r: Double = 0, g: Double = 0, b: Double = 0
        
        if h < 60 { r = c; g = x; b = 0 }
        else if h < 120 { r = x; g = c; b = 0 }
        else if h < 180 { r = 0; g = c; b = x }
        else if h < 240 { r = 0; g = x; b = c }
        else if h < 300 { r = x; g = 0; b = c }
        else { r = c; g = 0; b = x }
        
        return UIColor(red: CGFloat(r + m), green: CGFloat(g + m), blue: CGFloat(b + m), alpha: 1.0)
    }
    
    // MARK: - Math Helpers (Ported from TS)
    
    private static func hexToHSL(hexInput: String) -> HSL {
        let hex = hexInput.replacingOccurrences(of: "#", with: "")
        
        guard hex.count == 6 else {
            return HSL(h: 0, s: 0, l: 0)
        }
        
        var rgb: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&rgb)
        
        let r = Double((rgb >> 16) & 0xFF) / 255.0
        let g = Double((rgb >> 8) & 0xFF) / 255.0
        let b = Double(rgb & 0xFF) / 255.0
        
        let maxVal = max(r, g, b)
        let minVal = min(r, g, b)
        
        var h: Double = 0
        var s: Double = 0
        let l: Double = (maxVal + minVal) / 2.0
        
        if maxVal != minVal {
            let d = maxVal - minVal
            s = l > 0.5 ? d / (2.0 - maxVal - minVal) : d / (maxVal + minVal)
            
            switch maxVal {
            case r: h = (g - b) / d + (g < b ? 6 : 0)
            case g: h = (b - r) / d + 2
            case b: h = (r - g) / d + 4
            default: break
            }
            h /= 6.0
        }
        
        return HSL(h: h * 360.0, s: s * 100.0, l: l * 100.0)
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
