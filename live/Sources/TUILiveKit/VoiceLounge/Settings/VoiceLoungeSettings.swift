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
    var topic = ""
    var seatLayout: VoiceLoungeSeatLayout = .oneV8
    var skin = VoiceLoungeSkin.defaultSkin
    var background = VoiceLoungeBackground.defaultBackground
    var isTranscriberEnabled = false

    static func defaultRoomName(hostName: String) -> String {
        let trimmed = hostName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return .roomNameFallback }
        return .roomNameVoice(trimmed)
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

    mutating func applyMeta(_ metaData: [String: String]) {
        let defaults = VoiceLoungeConfig()
        seatLayout = metaData[MetaKey.layout].flatMap(VoiceLoungeSeatLayout.init(rawValue:)) ?? defaults.seatLayout
        background = metaData[MetaKey.background].flatMap(VoiceLoungeBackground.background(id:)) ?? defaults.background
        skin = metaData[MetaKey.skin].flatMap(VoiceLoungeSkin.skin(id:)) ?? defaults.skin
        topic = metaData[MetaKey.topic] ?? defaults.topic
        isTranscriberEnabled = metaData[MetaKey.transcriber] == "1"
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
}
