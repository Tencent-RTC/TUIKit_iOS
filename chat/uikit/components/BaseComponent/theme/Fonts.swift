import UIKit

let FontScheme = SemanticFontScheme(
    title1Bold: Fonts.Bold40,
    title2Bold: Fonts.Bold36,
    title3Bold: Fonts.Bold34,
    title4Bold: Fonts.Bold32,
    body1Bold: Fonts.Bold28,
    body2Bold: Fonts.Bold24,
    body3Bold: Fonts.Bold20,
    body4Bold: Fonts.Bold18,
    caption1Bold: Fonts.Bold16,
    caption2Bold: Fonts.Bold14,
    caption3Bold: Fonts.Bold12,
    caption4Bold: Fonts.Bold10,
    title1Medium: Fonts.Medium40,
    title2Medium: Fonts.Medium36,
    title3Medium: Fonts.Medium34,
    title4Medium: Fonts.Medium32,
    body1Medium: Fonts.Medium28,
    body2Medium: Fonts.Medium24,
    body3Medium: Fonts.Medium20,
    body4Medium: Fonts.Medium18,
    caption1Medium: Fonts.Medium16,
    caption2Medium: Fonts.Medium14,
    caption3Medium: Fonts.Medium12,
    caption4Medium: Fonts.Medium10,
    title1Regular: Fonts.Regular40,
    title2Regular: Fonts.Regular36,
    title3Regular: Fonts.Regular34,
    title4Regular: Fonts.Regular32,
    body1Regular: Fonts.Regular28,
    body2Regular: Fonts.Regular24,
    body3Regular: Fonts.Regular20,
    body4Regular: Fonts.Regular18,
    caption1Regular: Fonts.Regular16,
    caption2Regular: Fonts.Regular14,
    caption3Regular: Fonts.Regular12,
    caption4Regular: Fonts.Regular10
)

public struct SemanticFontScheme {
    let title1Bold: UIFont
    let title2Bold: UIFont
    let title3Bold: UIFont
    let title4Bold: UIFont
    let body1Bold: UIFont
    let body2Bold: UIFont
    let body3Bold: UIFont
    let body4Bold: UIFont
    let caption1Bold: UIFont
    let caption2Bold: UIFont
    let caption3Bold: UIFont
    let caption4Bold: UIFont
    let title1Medium: UIFont
    let title2Medium: UIFont
    let title3Medium: UIFont
    let title4Medium: UIFont
    let body1Medium: UIFont
    let body2Medium: UIFont
    let body3Medium: UIFont
    let body4Medium: UIFont
    let caption1Medium: UIFont
    let caption2Medium: UIFont
    let caption3Medium: UIFont
    let caption4Medium: UIFont
    let title1Regular: UIFont
    let title2Regular: UIFont
    let title3Regular: UIFont
    let title4Regular: UIFont
    let body1Regular: UIFont
    let body2Regular: UIFont
    let body3Regular: UIFont
    let body4Regular: UIFont
    let caption1Regular: UIFont
    let caption2Regular: UIFont
    let caption3Regular: UIFont
    let caption4Regular: UIFont
}

private enum Fonts {
    static let Bold40 = UIFont.systemFont(ofSize: 40, weight: .bold)
    static let Bold36 = UIFont.systemFont(ofSize: 36, weight: .bold)
    static let Bold34 = UIFont.systemFont(ofSize: 34, weight: .bold)
    static let Bold32 = UIFont.systemFont(ofSize: 32, weight: .bold)
    static let Bold28 = UIFont.systemFont(ofSize: 28, weight: .bold)
    static let Bold24 = UIFont.systemFont(ofSize: 24, weight: .bold)
    static let Bold20 = UIFont.systemFont(ofSize: 20, weight: .bold)
    static let Bold18 = UIFont.systemFont(ofSize: 18, weight: .bold)
    static let Bold16 = UIFont.systemFont(ofSize: 16, weight: .bold)
    static let Bold14 = UIFont.systemFont(ofSize: 14, weight: .bold)
    static let Bold12 = UIFont.systemFont(ofSize: 12, weight: .bold)
    static let Bold10 = UIFont.systemFont(ofSize: 10, weight: .bold)
    static let Medium40 = UIFont.systemFont(ofSize: 40, weight: .medium)
    static let Medium36 = UIFont.systemFont(ofSize: 36, weight: .medium)
    static let Medium34 = UIFont.systemFont(ofSize: 34, weight: .medium)
    static let Medium32 = UIFont.systemFont(ofSize: 32, weight: .medium)
    static let Medium28 = UIFont.systemFont(ofSize: 28, weight: .medium)
    static let Medium24 = UIFont.systemFont(ofSize: 24, weight: .medium)
    static let Medium20 = UIFont.systemFont(ofSize: 20, weight: .medium)
    static let Medium18 = UIFont.systemFont(ofSize: 18, weight: .medium)
    static let Medium16 = UIFont.systemFont(ofSize: 16, weight: .medium)
    static let Medium14 = UIFont.systemFont(ofSize: 14, weight: .medium)
    static let Medium12 = UIFont.systemFont(ofSize: 12, weight: .medium)
    static let Medium10 = UIFont.systemFont(ofSize: 10, weight: .medium)
    static let Regular40 = UIFont.systemFont(ofSize: 40, weight: .regular)
    static let Regular36 = UIFont.systemFont(ofSize: 36, weight: .regular)
    static let Regular34 = UIFont.systemFont(ofSize: 34, weight: .regular)
    static let Regular32 = UIFont.systemFont(ofSize: 32, weight: .regular)
    static let Regular28 = UIFont.systemFont(ofSize: 28, weight: .regular)
    static let Regular24 = UIFont.systemFont(ofSize: 24, weight: .regular)
    static let Regular20 = UIFont.systemFont(ofSize: 20, weight: .regular)
    static let Regular18 = UIFont.systemFont(ofSize: 18, weight: .regular)
    static let Regular16 = UIFont.systemFont(ofSize: 16, weight: .regular)
    static let Regular14 = UIFont.systemFont(ofSize: 14, weight: .regular)
    static let Regular12 = UIFont.systemFont(ofSize: 12, weight: .regular)
    static let Regular10 = UIFont.systemFont(ofSize: 10, weight: .regular)
}
