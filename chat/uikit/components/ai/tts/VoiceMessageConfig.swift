import Foundation
import AtomicXCore

public final class VoiceMessageConfig {
    public static let shared = VoiceMessageConfig()

    private let KeyPrefix = "voice_message_config"

    private let NameSelectedVoiceId = "selectedVoiceId"

    private let NameSelectedVoiceName = "selectedVoiceName"

    public func getSelectedVoiceId() -> String {
        return storage().string(forKey: key(NameSelectedVoiceId)) ?? ""
    }

    public func getSelectedVoiceName() -> String {
        return storage().string(forKey: key(NameSelectedVoiceName)) ?? ""
    }

    public func setSelectedVoice(id: String, name: String) {
        let storage = storage()
        storage.set(id, forKey: key(NameSelectedVoiceId))
        storage.set(name, forKey: key(NameSelectedVoiceName))
    }

    private init() {}

    private func storage() -> UserDefaults {
        return UserDefaults.standard
    }

    private func key(_ name: String) -> String {
        let userId = currentUserId()
        return userId.isEmpty ? "\(KeyPrefix).\(name)" : "\(KeyPrefix).\(userId).\(name)"
    }

    private func currentUserId() -> String {
        return LoginStore.shared.state.value.loginUserInfo?.userID ?? ""
    }
}
