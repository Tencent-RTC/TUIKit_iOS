public final class AiMediaProcessManager {
    // MARK: - 文字处理

    public static func translateSingleText(text: String,
                                           targetLanguage: String,
                                           sourceLanguage: String = "",
                                           onSuccess: @escaping (String) -> Void,
                                           onFailure: @escaping (Int32, String) -> Void) {
        AiMediaProcessManagerImpl.translateSingleText(
            text: text, targetLanguage: targetLanguage, sourceLanguage: sourceLanguage,
            onSuccess: onSuccess, onFailure: onFailure
        )
    }

    // MARK: - 语音合成与音色

    public static func convertTextToVoice(text: String,
                                         voiceId: String = "",
                                         audioFormat: String = "wav",
                                         language: String = "",
                                         onSuccess: @escaping (String) -> Void,
                                         onFailure: @escaping (Int32, String) -> Void) {
        AiMediaProcessManagerImpl.convertTextToVoice(
            text: text, voiceId: voiceId, audioFormat: audioFormat, language: language,
            onSuccess: onSuccess, onFailure: onFailure
        )
    }

    public static func voiceClone(filePath: String,
                                  voiceName: String,
                                  promptText: String = "",
                                  language: String = "",
                                  onSuccess: @escaping (String) -> Void,
                                  onFailure: @escaping (Int32, String) -> Void) {
        AiMediaProcessManagerImpl.voiceClone(
            filePath: filePath, voiceName: voiceName, promptText: promptText, language: language,
            onSuccess: onSuccess, onFailure: onFailure
        )
    }

    /// 返回内置音色列表，名称随当前语言本地化，不请求服务器。
    public static func defaultVoiceList() -> [CustomVoiceItem] {
        return AiMediaProcessManagerImpl.defaultVoiceList()
    }

    public static func getCustomVoiceList(onSuccess: @escaping ([CustomVoiceItem]) -> Void,
                                         onFailure: @escaping (Int32, String) -> Void) {
        AiMediaProcessManagerImpl.getCustomVoiceList(onSuccess: onSuccess, onFailure: onFailure)
    }

    public static func deleteCustomVoice(voiceId: String,
                                        onSuccess: @escaping () -> Void,
                                        onFailure: @escaping (Int32, String) -> Void) {
        AiMediaProcessManagerImpl.deleteCustomVoice(voiceId: voiceId, onSuccess: onSuccess, onFailure: onFailure)
    }

    // MARK: - 录音上传与转写

    static func uploadAudioFile(filePath: String,
                                onSuccess: @escaping (String) -> Void,
                                onFailure: @escaping (Int32, String) -> Void) {
        AiMediaProcessManagerImpl.uploadAudioFile(filePath: filePath, onSuccess: onSuccess, onFailure: onFailure)
    }

    static func convertVoiceToText(url: String,
                                   language: String = "",
                                   onSuccess: @escaping (String) -> Void,
                                   onFailure: @escaping (Int32, String) -> Void) {
        AiMediaProcessManagerImpl.convertVoiceToText(
            url: url, language: language, onSuccess: onSuccess, onFailure: onFailure
        )
    }

    static func convertLocalAudioToText(filePath: String,
                                        onSuccess: @escaping (String) -> Void,
                                        onFailure: @escaping (Int32, String) -> Void) {
        AiMediaProcessManagerImpl.convertLocalAudioToText(
            filePath: filePath, onSuccess: onSuccess, onFailure: onFailure
        )
    }
}
