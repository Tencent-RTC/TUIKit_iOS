import Foundation

extension CustomVoiceItem {
    public static func == (lhs: CustomVoiceItem, rhs: CustomVoiceItem) -> Bool {
        return lhs.voiceId == rhs.voiceId
    }

    public func hash(into hasher: inout Hasher) {
        hasher.combine(voiceId)
    }
}
