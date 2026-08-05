//
//  BarrageLevelTag.swift
//  TUILiveKit
//

import UIKit
import AtomicX

enum BarrageLevel: Int {
    case level1 = 1
    case level2 = 2
    case level3 = 3
    case level4 = 4

    var backgroundColor: UIColor {
        let tokens = ThemeStore.shared.colorTokens
        switch self {
        case .level1: return tokens.tagColorLevel1
        case .level2: return tokens.tagColorLevel2
        case .level3: return tokens.tagColorLevel3
        case .level4: return tokens.tagColorLevel4
        }
    }

    var iconImage: UIImage? {
        return internalImage("live_barrage_level_\(rawValue)")
    }

    static func from(level: Int) -> BarrageLevel? {
        switch level {
        case 0...20: return .level1
        case 21...40: return .level2
        case 41...60: return .level3
        case 61...100: return .level4
        default: return .level4
        }
    }

    var displayText: String {
        return "\(rawValue)"
    }
}


enum BarrageLevelTagRenderer {
    static let height: CGFloat = 14
    
    private static let iconSize: CGFloat = 10

    private static let iconLeading: CGFloat = 6
    
    private static let iconToTextGap: CGFloat = 2

    private static let textTrailing: CGFloat = 4

    private static var textFont: UIFont {
        return UIFont.customFont(ofSize: 11, weight: .semibold)
    }

    static func size(for level: BarrageLevel) -> CGSize {
        return size(forText: level.displayText)
    }

    static func size(forText text: String) -> CGSize {
        let ns = text as NSString
        let textWidth = ceil(ns.size(withAttributes: [.font: textFont]).width)
        let width = iconLeading + iconSize + iconToTextGap + textWidth + textTrailing
        return CGSize(width: width, height: height)
    }

    static func image(for level: BarrageLevel) -> UIImage {
        return image(for: level, text: level.displayText)
    }

    static func image(for level: BarrageLevel, text: String) -> UIImage {
        let size = size(forText: text)
        let bounds = CGRect(origin: .zero, size: size)
        let cornerRadius = size.height * 0.5

        let renderer = UIGraphicsImageRenderer(size: size)
        return renderer.image { _ in
            let path = UIBezierPath(roundedRect: bounds, cornerRadius: cornerRadius)
            level.backgroundColor.setFill()
            path.fill()

            let iconY = (size.height - iconSize) * 0.5
            let iconRect = CGRect(x: iconLeading, y: iconY, width: iconSize, height: iconSize)
            level.iconImage?.draw(in: iconRect)

            let ns = text as NSString
            let attributes: [NSAttributedString.Key: Any] = [
                .font: textFont,
                .foregroundColor: UIColor.white
            ]
            let textSize = ns.size(withAttributes: attributes)
            let textX = iconLeading + iconSize + iconToTextGap
            let textY = (size.height - textSize.height) * 0.5
            ns.draw(at: CGPoint(x: textX, y: textY), withAttributes: attributes)
        }
    }
}
