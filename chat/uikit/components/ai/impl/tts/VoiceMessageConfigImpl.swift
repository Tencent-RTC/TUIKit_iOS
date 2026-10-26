import Foundation
import AtomicXCore

final class VoiceMessageConfigImpl {
    private let KeyPrefix = "voice_message_config"

    private let NameSelectedVoiceId = "selectedVoiceId"

    private let NameSelectedVoiceName = "selectedVoiceName"

    private let NameRecordTranslateTargetLanguage = "recordTranslateTargetLanguage"

    /// 录音翻译的目标语言，未设置时返回空字符串，按当前登录用户保存。
    func getRecordTranslateTargetLanguage() -> String {
        return storage().string(forKey: key(NameRecordTranslateTargetLanguage)) ?? ""
    }

    func setRecordTranslateTargetLanguage(_ language: String) {
        storage().set(language, forKey: key(NameRecordTranslateTargetLanguage))
    }

    func getSelectedVoiceId() -> String {
        return storage().string(forKey: key(NameSelectedVoiceId)) ?? ""
    }

    func getSelectedVoiceName() -> String {
        return storage().string(forKey: key(NameSelectedVoiceName)) ?? ""
    }

    func setSelectedVoice(id: String, name: String) {
        let storage = storage()
        storage.set(id, forKey: key(NameSelectedVoiceId))
        storage.set(name, forKey: key(NameSelectedVoiceName))
    }

    init() {}

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
