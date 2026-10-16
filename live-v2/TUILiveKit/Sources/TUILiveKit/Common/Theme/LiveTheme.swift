import UIKit

enum LiveTheme {
    enum TextRole {
        case sheetTitle
        case dialogTitle
        case pageTitle
        case sectionTitle
        case itemTitle
        case listTitle
        case body
        case prominent
        case caption
        case metadata
        case control
        case action
    }

    enum TextTone {
        case primary
        case secondary
        case tertiary
        case disabled
    }

    enum Typography {
        static func font(for role: TextRole, emphasized: Bool = false) -> UIFont {
            var size: CGFloat = 0
            var weight: UIFont.Weight = .regular
            switch role {
            case .sheetTitle: (size, weight) = (15, .semibold)
            case .dialogTitle: (size, weight) = (16, .semibold)
            case .pageTitle: (size, weight) = (21, .semibold)
            case .sectionTitle: (size, weight) = (12, .semibold)
            case .itemTitle: (size, weight) = (13, .regular)
            case .listTitle: (size, weight) = (15, .regular)
            case .body: (size, weight) = (14, .regular)
            case .prominent: (size, weight) = (17, .semibold)
            case .caption: (size, weight) = (12, .regular)
            case .metadata: (size, weight) = (10, .regular)
            case .control: (size, weight) = (11, .regular)
            case .action: (size, weight) = (13, .semibold)
            }
            return .systemFont(ofSize: size, weight: emphasized ? .semibold : weight)
        }
    }

    enum Color {
        // Keep the original floating-point components. Gift-panel and beauty
        // colors have distinct values and remain owned by their features.
        static let brandBlue = UIColor(red: 0.29, green: 0.62, blue: 1, alpha: 1)
        static let brandDeepBlue = UIColor(red: 0, green: 0.32, blue: 0.85, alpha: 1)
        static let brandCyan = UIColor(red: 0.49, green: 0.91, blue: 1, alpha: 1)
        static let canvasBackground = UIColor(red: 0.06, green: 0.07, blue: 0.10, alpha: 1)

        // Shared video-overlay surfaces; each component owns its opacity.
        static let overlayBase = UIColor(red: 0.039, green: 0.047, blue: 0.071, alpha: 1)
        static let controlBase = UIColor(red: 0.039, green: 0.039, blue: 0.059, alpha: 1)
        static let nickname = UIColor(red: 0.471, green: 0.847, blue: 1, alpha: 1)
        static let audienceGiftValue = UIColor(red: 1, green: 0.886, blue: 0.604, alpha: 1)
        static let sheetScrim = UIColor.black.withAlphaComponent(0.4)

        static func text(_ tone: TextTone) -> UIColor {
            switch tone {
            case .primary: return .white
            case .secondary: return UIColor.white.withAlphaComponent(0.75)
            case .tertiary: return UIColor.white.withAlphaComponent(0.48)
            case .disabled: return UIColor.white.withAlphaComponent(0.38)
            }
        }
    }
}

// Styles owned by this component or feature. Values preserve the existing design.
enum LiveVideoOverlayStyle {
    static let capsuleBackground: UIColor = LiveTheme.Color.overlayBase.withAlphaComponent(0.22)
}

enum LiveHeaderStyle {
    static let middle: UIColor = UIColor(red: 0.055, green: 0.063, blue: 0.11, alpha: 0.20)
    static let purple: UIColor = UIColor(red: 0.482, green: 0.302, blue: 1, alpha: 0.18)
    static let rose: UIColor = UIColor(red: 1, green: 0.357, blue: 0.478, alpha: 0.16)
    static let border: UIColor = UIColor.white.withAlphaComponent(0.06)
    static let capsuleRadius: CGFloat = 18
    static let avatarRadius: CGFloat = 16
}

enum LiveAudienceRowStyle {
    static let giftValueFont: UIFont = UIFont.systemFont(ofSize: 12, weight: .bold)
    static let separator: UIColor = UIColor.white.withAlphaComponent(0.08)
    static let avatarRadius: CGFloat = 21
    static let edgeInset: CGFloat = 10
    static let avatarLeading: CGFloat = 36
    static let avatarTop: CGFloat = 11
    static let avatarSize: CGFloat = 42
    static let nameLeading: CGFloat = 92
    static let rankSize: CGSize = CGSize(width: 12, height: 21)
    static let giftValueSize: CGSize = CGSize(width: 38, height: 16)
}
