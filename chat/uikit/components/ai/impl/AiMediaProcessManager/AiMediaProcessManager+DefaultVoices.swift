import Foundation

private enum SystemVoiceID {
    static let xiaoxuMale = "male-kefu-xiaoxu"
    static let xiaomeiFemale = "female-kefu-xiaomei"
    static let xiaoxinFemale = "female-kefu-xiaoxin"
    static let xiaoyueFemale = "female-kefu-xiaoyue"
}

private struct DefaultVoiceItem {
    let voiceId: String
    let nameKey: String

    init(voiceId: String, nameKey: String) {
        self.voiceId = voiceId
        self.nameKey = nameKey
    }
}

extension AiMediaProcessManagerImpl {
    private static let defaultVoiceItems: [DefaultVoiceItem] = [
        DefaultVoiceItem(voiceId: "", nameKey: "voice_message_voice_default"),
        DefaultVoiceItem(voiceId: SystemVoiceID.xiaoxuMale, nameKey: "voice_message_voice_xiaoxu"),
        DefaultVoiceItem(voiceId: SystemVoiceID.xiaomeiFemale, nameKey: "voice_message_voice_xiaomei"),
        DefaultVoiceItem(voiceId: SystemVoiceID.xiaoxinFemale, nameKey: "voice_message_voice_xiaoxin"),
        DefaultVoiceItem(voiceId: SystemVoiceID.xiaoyueFemale, nameKey: "voice_message_voice_xiaoyue")
    ]

    static func defaultVoiceList() -> [CustomVoiceItem] {
        return defaultVoiceItems.map { item in
            CustomVoiceItem(voiceId: item.voiceId, name: LocalizedChatString(item.nameKey), isDefault: true)
        }
    }
}
