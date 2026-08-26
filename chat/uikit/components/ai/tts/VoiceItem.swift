import Foundation

public struct CustomVoiceItem: Equatable, Hashable {
    public let voiceId: String

    public let name: String

    let isDefault: Bool

    public init(voiceId: String, name: String, isDefault: Bool) {
        self.voiceId = voiceId
        self.name = name
        self.isDefault = isDefault
    }

    public static func == (lhs: CustomVoiceItem, rhs: CustomVoiceItem) -> Bool {
        return lhs.voiceId == rhs.voiceId
    }

    public func hash(into hasher: inout Hasher) {
        hasher.combine(voiceId)
    }
}

enum SystemVoiceID {
    static let xiaoxuMale = "male-kefu-xiaoxu"
    static let xiaomeiFemale = "female-kefu-xiaomei"
    static let xiaoxinFemale = "female-kefu-xiaoxin"
    static let xiaoyueFemale = "female-kefu-xiaoyue"
}

struct DefaultVoiceItem {
    public let voiceId: String
    let nameKey: String

    init(voiceId: String, nameKey: String) {
        self.voiceId = voiceId
        self.nameKey = nameKey
    }
}

public enum VoiceItemProvider {

    static let defaultVoiceItems: [DefaultVoiceItem] = [
        DefaultVoiceItem(voiceId: "", nameKey: "voice_message_voice_default"),
        DefaultVoiceItem(voiceId: SystemVoiceID.xiaoxuMale, nameKey: "voice_message_voice_xiaoxu"),
        DefaultVoiceItem(voiceId: SystemVoiceID.xiaomeiFemale, nameKey: "voice_message_voice_xiaomei"),
        DefaultVoiceItem(voiceId: SystemVoiceID.xiaoxinFemale, nameKey: "voice_message_voice_xiaoxin"),
        DefaultVoiceItem(voiceId: SystemVoiceID.xiaoyueFemale, nameKey: "voice_message_voice_xiaoyue")
    ]

    public static func defaultVoiceList() -> [CustomVoiceItem] {
        return defaultVoiceItems.map { item in
            CustomVoiceItem(voiceId: item.voiceId, name: LocalizedChatString(item.nameKey), isDefault: true)
        }
    }
}
