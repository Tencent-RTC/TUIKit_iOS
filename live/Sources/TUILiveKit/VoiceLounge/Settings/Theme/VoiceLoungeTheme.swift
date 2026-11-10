import UIKit

struct VoiceLoungeSkin: Equatable {
    let id: String
    let nameKey: String
    let deep: UIColor
    let mid: UIColor
    let light: UIColor

    var displayName: String { LiveKitResources.localizedString(nameKey) }

    var swatchColors: [UIColor] { [deep, mid, light] }
    var swatchLocations: [NSNumber] { [0, 0.55, 1] }
}

extension VoiceLoungeSkin {
    static let all: [VoiceLoungeSkin] = [
        make("blue", "tuilivekit.voiceroom.skin.blue", 0x0052D9, 0x4A9EFF, 0x7EE8FF),
        make("red", "tuilivekit.voiceroom.skin.red", 0xC9162B, 0xFF5B5B, 0xFFB199),
        make("green", "tuilivekit.voiceroom.skin.green", 0x06A35A, 0x3ED598, 0xA8F0C6),
        make("purple", "tuilivekit.voiceroom.skin.purple", 0x0052D9, 0x7B4DFF, 0xFF5B7A),
        make("gold", "tuilivekit.voiceroom.skin.gold", 0xA66A00, 0xF5C542, 0xFFE9A8),
    ]

    static let defaultID = "blue"

    static var defaultSkin: VoiceLoungeSkin { all.first { $0.id == defaultID } ?? all[0] }

    static func skin(id: String) -> VoiceLoungeSkin? { all.first { $0.id == id } }

    private static func make(_ id: String, _ nameKey: String, _ deep: Int, _ mid: Int, _ light: Int) -> VoiceLoungeSkin
    {
        VoiceLoungeSkin(
            id: id, nameKey: nameKey, deep: UIColor(hex: deep), mid: UIColor(hex: mid), light: UIColor(hex: light))
    }
}

private extension UIColor {
    convenience init(hex: Int) {
        self.init(
            red: CGFloat((hex >> 16) & 0xFF) / 255, green: CGFloat((hex >> 8) & 0xFF) / 255,
            blue: CGFloat(hex & 0xFF) / 255, alpha: 1)
    }
}

struct VoiceLoungeBackground: Equatable {
    let id: String
    let nameKey: String
    let imageName: String
    let previewName: String
    let gifResource: String?

    var displayName: String { LiveKitResources.localizedString(nameKey) }

    var image: UIImage? { LiveKitResources.image(named: imageName) }

    var previewImage: UIImage? { LiveKitResources.image(named: previewName) }

    var gifURL: URL? {
        guard let gifResource else { return nil }
        return LiveKitResources.bundle.url(forResource: gifResource, withExtension: "gif")
    }
}

extension VoiceLoungeBackground {
    static let all: [VoiceLoungeBackground] = [
        make("sakura", "tuilivekit.voiceroom.bg.sakura", animated: true),
        make("cyberpunk", "tuilivekit.voiceroom.bg.cyberpunk", animated: true),
        make("aurora", "tuilivekit.voiceroom.bg.aurora", animated: true),
        make("moonlit", "tuilivekit.voiceroom.bg.moonlit", animated: true),
        make("mountain", "tuilivekit.voiceroom.bg.mountain", animated: true),
        make("sea", "tuilivekit.voiceroom.bg.sea", animated: true),
        make("space", "tuilivekit.voiceroom.bg.space", animated: false),
        make("travel", "tuilivekit.voiceroom.bg.travel", animated: false),
        make("party", "tuilivekit.voiceroom.bg.party", animated: true),
    ]

    static let defaultID = "moonlit"

    static var defaultBackground: VoiceLoungeBackground { all.first { $0.id == defaultID } ?? all[0] }

    static func background(id: String) -> VoiceLoungeBackground? { all.first { $0.id == id } }

    private static func make(_ id: String, _ nameKey: String, animated: Bool) -> VoiceLoungeBackground {
        VoiceLoungeBackground(
            id: id, nameKey: nameKey, imageName: "livekit_voicebg_\(id)", previewName: "livekit_voicebg_\(id)_preview",
            gifResource: animated ? "livekit_voicebg_\(id)" : nil)
    }
}

enum VoiceLoungeColor {
    static let overlayHair = UIColor.white.withAlphaComponent(0.06)
    static let overlaySoft = UIColor.white.withAlphaComponent(0.08)
    static let overlayBase = UIColor.white.withAlphaComponent(0.10)
    static let overlayMarked = UIColor.white.withAlphaComponent(0.14)

    static let card = UIColor.black.withAlphaComponent(0.28)

    // MARK: - Shared Colors

    static let rose = UIColor(red: 1.0, green: 0.325, blue: 0.439, alpha: 1)
    static let statHighlight = UIColor(red: 0.557, green: 0.812, blue: 1, alpha: 1)

    static let prepareDeep = UIColor(red: 0.188, green: 0.506, blue: 0.812, alpha: 1)
    static let prepareMid = UIColor(red: 0.478, green: 0.663, blue: 0.839, alpha: 1)
    static let prepareLight = UIColor(red: 0.725, green: 0.8, blue: 0.875, alpha: 1)
    static let prepareIconBackground = UIColor(red: 0.078, green: 0.078, blue: 0.086, alpha: 0.5)
    static let prepareIconBorder = UIColor.white.withAlphaComponent(0.102)

    static let dialogBackground = UIColor(red: 0.094, green: 0.086, blue: 0.125, alpha: 1)
    static let floatingBar = UIColor(white: 0.08, alpha: 0.92)
    static let floatingBarIcon = UIColor.white.withAlphaComponent(0.7)

    static let avatarPlaceholders: [UIColor] = [
        UIColor(red: 0.42, green: 0.49, blue: 0.9, alpha: 1), UIColor(red: 0.9, green: 0.45, blue: 0.55, alpha: 1),
        UIColor(red: 0.35, green: 0.73, blue: 0.6, alpha: 1), UIColor(red: 0.78, green: 0.55, blue: 0.9, alpha: 1),
        UIColor(red: 0.95, green: 0.68, blue: 0.4, alpha: 1),
    ]
}

enum VoiceLoungeFont {
    static func size(_ base: CGFloat) -> CGFloat { base < 13 ? base + 2 : base + 1 }

    static func scaled(_ font: UIFont) -> UIFont { font.withSize(size(font.pointSize)) }
}

extension LiveText {
    static func voiceLounge(
        _ role: LiveTheme.TextRole, text: String? = nil, tone: LiveTheme.TextTone = .primary,
        alignment: NSTextAlignment = .left, emphasized: Bool = false
    ) -> LiveText {
        let label = LiveText(role, text: text, tone: tone, alignment: alignment, emphasized: emphasized)
        label.font = VoiceLoungeFont.scaled(label.font)
        return label
    }
}
