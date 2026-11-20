import AtomicXCore
import Combine
import Foundation

@MainActor final class VoiceLoungeSettings {
    var changes: AnyPublisher<Void, Never> { changeSubject.eraseToAnyPublisher() }

    var config = VoiceLoungeConfig() { didSet { if config != oldValue { changeSubject.send() } } }
    private(set) var hostName = ""
    private(set) var hostAvatarURL = ""
    private(set) var hostUserID = ""

    private let changeSubject = PassthroughSubject<Void, Never>()

    var seatLayout: VoiceLoungeSeatLayout { config.seatLayout }
    var topic: String { config.topic }
    var isTranscriberEnabled: Bool { config.isTranscriberEnabled }
    var transcriberShowOriginal: Bool { config.transcriberShowOriginal }
    var transcriberScale: VoiceLoungeTranscriberScale { config.transcriberScale }
    var transcriberLanguage: TranslationLanguage { config.transcriberLanguage }
    var skin: VoiceLoungeSkin { config.skin }
    var background: VoiceLoungeBackground { config.background }

    var displayRoomName: String {
        config.roomName.isEmpty ? VoiceLoungeConfig.defaultRoomName(hostName: hostName) : config.roomName
    }

    func updateHost(name: String, avatarURL: String, userID: String) {
        guard name != hostName || avatarURL != hostAvatarURL || userID != hostUserID else { return }
        hostName = name
        hostAvatarURL = avatarURL
        hostUserID = userID
        changeSubject.send()
    }
}

struct VoiceLoungeConfig: Equatable {
    var roomName = ""
    var coverURL = LiveKitResources.defaultCoverURL
    var topic = VoiceLoungeConfig.defaultTopic
    var seatLayout: VoiceLoungeSeatLayout = .oneV8
    var skin = VoiceLoungeSkin.defaultSkin
    var background = VoiceLoungeBackground.defaultBackground
    var isTranscriberEnabled = false
    var transcriberShowOriginal = false
    var transcriberScale: VoiceLoungeTranscriberScale = .standard
    var transcriberLanguage: TranslationLanguage = .english

    static var defaultTopic: String { LiveKitResources.localizedString("tuilivekit.voiceroom.topic.default") }

    static func defaultRoomName(hostName: String) -> String {
        let trimmed = hostName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return .roomNameFallback }
        return .roomNameVoice(trimmed)
    }
}

enum VoiceLoungeTranscriberScale: String, CaseIterable, Equatable {
    case small
    case standard
    case large

    var fontSize: CGFloat {
        switch self {
        case .small: return 11
        case .standard: return 13
        case .large: return 18
        }
    }
}

struct VoiceLoungeTranscriberDefaults: Equatable {
    var isEnabled: Bool
    var showOriginal: Bool
    var scale: VoiceLoungeTranscriberScale
    var language: TranslationLanguage

    static var current: VoiceLoungeTranscriberDefaults? {
        get {
            guard let key = defaultsKey else { return nil }
            let d = UserDefaults.standard
            guard d.object(forKey: "\(key).enabled") != nil else { return nil }
            let scaleRaw = d.string(forKey: "\(key).scale") ?? VoiceLoungeTranscriberScale.standard.rawValue
            let langRaw = d.string(forKey: "\(key).lang") ?? TranslationLanguage.english.rawValue
            return VoiceLoungeTranscriberDefaults(
                isEnabled: d.bool(forKey: "\(key).enabled"), showOriginal: d.bool(forKey: "\(key).original"),
                scale: VoiceLoungeTranscriberScale(rawValue: scaleRaw) ?? .standard,
                language: TranslationLanguage(rawValue: langRaw) ?? .english, )
        }
        set {
            guard let key = defaultsKey, let v = newValue else { return }
            let d = UserDefaults.standard
            d.set(v.isEnabled, forKey: "\(key).enabled")
            d.set(v.showOriginal, forKey: "\(key).original")
            d.set(v.scale.rawValue, forKey: "\(key).scale")
            d.set(v.language.rawValue, forKey: "\(key).lang")
        }
    }

    private static var defaultsKey: String? {
        guard let userID = LoginStore.shared.state.value.loginUserInfo?.userID, !userID.isEmpty else { return nil }
        return "TUILiveKit.voiceLounge.transcriber.v1.\(LoginStore.shared.sdkAppID).\(userID)"
    }
}

extension VoiceLoungeConfig {
    private enum MetaKey {
        static let layout = "vl_layout"
        static let background = "vl_bg"
        static let skin = "vl_skin"
        static let topic = "vl_topic"
        static let transcriber = "vl_caption"
    }

    static let metaKeys = [MetaKey.layout, MetaKey.background, MetaKey.skin, MetaKey.topic, MetaKey.transcriber]
    static let pausedMetaKey = "vl_paused"

    static func hasMeta(in metaData: [String: String]) -> Bool { metaKeys.contains { metaData[$0] != nil } }

    var metaData: [String: String] {
        [
            MetaKey.layout: seatLayout.rawValue, MetaKey.background: background.id, MetaKey.skin: skin.id,
            MetaKey.topic: topic, MetaKey.transcriber: isTranscriberEnabled ? "1" : "0",
        ]
    }

    mutating func applyMeta(_ metaData: [String: String], includeTranscriber: Bool = true) {
        let defaults = VoiceLoungeConfig()
        seatLayout = metaData[MetaKey.layout].flatMap(VoiceLoungeSeatLayout.init(rawValue:)) ?? defaults.seatLayout
        background = metaData[MetaKey.background].flatMap(VoiceLoungeBackground.background(id:)) ?? defaults.background
        skin = metaData[MetaKey.skin].flatMap(VoiceLoungeSkin.skin(id:)) ?? defaults.skin
        topic = metaData[MetaKey.topic] ?? defaults.topic
        guard includeTranscriber else { return }
        isTranscriberEnabled = metaData[MetaKey.transcriber].map { $0 == "1" } ?? defaults.isTranscriberEnabled
    }
}

private extension String {
    static func roomNameVoice(_ args: CVarArg...) -> String {
        LiveKitResources.localizedFormat("tuilivekit.voiceroom.prepare.room_name_voice", args)
    }
    static var roomNameFallback: String {
        LiveKitResources.localizedString("tuilivekit.voiceroom.prepare.room_name_fallback")
    }
}

enum VoiceLoungeSeatLayout: String, Equatable, CaseIterable {
    case oneV8
    case oneV8x
    case twoV8
    case duo

    var labelKey: String {
        switch self {
        case .oneV8: return "tuilivekit.voiceroom.layout.one_v8"
        case .oneV8x: return "tuilivekit.voiceroom.layout.one_v8x"
        case .twoV8: return "tuilivekit.voiceroom.layout.two_v8"
        case .duo: return "tuilivekit.voiceroom.layout.duo"
        }
    }

    var displayName: String { LiveKitResources.localizedString(labelKey) }

    static var savedDefault: VoiceLoungeSeatLayout? {
        get {
            guard let key = defaultKey, let raw = UserDefaults.standard.string(forKey: key) else { return nil }
            return VoiceLoungeSeatLayout(rawValue: raw)
        }
        set {
            guard let key = defaultKey else { return }
            if let newValue {
                UserDefaults.standard.set(newValue.rawValue, forKey: key)
            } else {
                UserDefaults.standard.removeObject(forKey: key)
            }
        }
    }

    private static var defaultKey: String? {
        guard let userID = LoginStore.shared.state.value.loginUserInfo?.userID, !userID.isEmpty else { return nil }
        return "TUILiveKit.voiceLounge.defaultLayout.v1.\(LoginStore.shared.sdkAppID).\(userID).voice"
    }
}
