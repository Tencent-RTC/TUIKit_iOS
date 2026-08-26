import Foundation
import ImSDK_Plus

public final class AiMediaProcessManager {
    private static let ApiUploadFile = "uploadFile"

    private static let ApiConvertTextToVoice = "convertTextToVoice"

    private static let ApiVoiceClone = "voiceClone"

    private static let ApiGetCustomVoiceList = "getCustomVoiceList"

    private static let ApiDeleteCustomVoice = "deleteCustomVoice"

    private static let ApiConvertVoiceToText = "convertVoiceToText"

    private static let KeyFilePath = "filePath"

    private static let KeyFileType = "fileType"

    private static let KeyText = "text"

    private static let KeyVoiceId = "voiceId"

    private static let KeyVoiceName = "voiceName"

    private static let KeyAudioFormat = "audioFormat"

    private static let KeyAudioUrl = "audioUrl"

    private static let KeyLanguage = "language"

    private static let KeyPromptText = "promptText"

    private static let KeyVoiceList = "voiceList"

    private static let KeyUrl = "url"

    private static let EmptyJSON = "{}"

    private static let ErrorUnknown: Int32 = -1

    private static let FileTypeAudio = 3

    static func uploadAudioFile(filePath: String,
                                onSuccess: @escaping (String) -> Void,
                                onFailure: @escaping (Int32, String) -> Void) {
        callExperimentalAPI(api: ApiUploadFile,
                            params: buildUploadFileParams(filePath: filePath),
                            onSuccess: { result in
                                if result.isEmpty {
                                    onFailure(ErrorUnknown, "upload url is empty")
                                } else {
                                    onSuccess(result)
                                }
                            },
                            onFailure: onFailure)
    }

    static func convertTextToVoice(text: String,
                                   voiceId: String = "",
                                   audioFormat: String = "wav",
                                   language: String = "",
                                   onSuccess: @escaping (String) -> Void,
                                   onFailure: @escaping (Int32, String) -> Void) {
        callExperimentalAPI(api: ApiConvertTextToVoice,
                            params: buildConvertTextToVoiceParams(text: text, voiceId: voiceId, audioFormat: audioFormat, language: language),
                            onSuccess: { result in
                                if let audioUrl = parseAudioUrl(result), !audioUrl.isEmpty {
                                    onSuccess(audioUrl)
                                } else {
                                    onFailure(ErrorUnknown, "tts audio url is empty")
                                }
                            },
                            onFailure: onFailure)
    }

    public static func voiceClone(filePath: String,
                           voiceName: String,
                           promptText: String = "",
                           language: String = "",
                           onSuccess: @escaping (String) -> Void,
                           onFailure: @escaping (Int32, String) -> Void) {
        uploadAudioFile(filePath: filePath,
                        onSuccess: { audioUrl in
                            callExperimentalAPI(api: ApiVoiceClone,
                                                params: buildVoiceCloneParams(voiceName: voiceName, audioUrl: audioUrl, promptText: promptText, language: language),
                                                onSuccess: { result in
                                                    if let voiceId = parseVoiceId(result), !voiceId.isEmpty {
                                                        onSuccess(voiceId)
                                                    } else {
                                                        onFailure(ErrorUnknown, "voice clone id is empty")
                                                    }
                                                },
                                                onFailure: onFailure)
                        },
                        onFailure: onFailure)
    }

    public static func getCustomVoiceList(onSuccess: @escaping ([CustomVoiceItem]) -> Void,
                                   onFailure: @escaping (Int32, String) -> Void) {
        callExperimentalAPI(api: ApiGetCustomVoiceList,
                            params: EmptyJSON,
                            onSuccess: { result in
                                onSuccess(parseVoiceList(result))
                            },
                            onFailure: onFailure)
    }

    public static func deleteCustomVoice(voiceId: String,
                                  onSuccess: @escaping () -> Void,
                                  onFailure: @escaping (Int32, String) -> Void) {
        callExperimentalAPI(api: ApiDeleteCustomVoice,
                            params: buildDeleteCustomVoiceParams(voiceId: voiceId),
                            onSuccess: { _ in
                                onSuccess()
                            },
                            onFailure: onFailure)
    }

    static func translateSingleText(text: String,
                                    targetLanguage: String,
                                    sourceLanguage: String = "",
                                    onSuccess: @escaping (String) -> Void,
                                    onFailure: @escaping (Int32, String) -> Void) {
        V2TIMManager.sharedInstance().translateText(sourceTextList: [text],
                                                     sourceLanguage: sourceLanguage.isEmpty ? nil : sourceLanguage,
                                                     targetLanguage: targetLanguage) { code, desc, result in
            DispatchQueue.main.async {
                if code != 0 {
                    onFailure(code, desc ?? "")
                    return
                }
                guard let translated = result?[text], !translated.isEmpty else {
                    onFailure(ErrorUnknown, "translation result is empty")
                    return
                }
                onSuccess(translated)
            }
        }
    }

    // MARK: - Voice to Text（对齐 Android `AudioTranscriber`）

    static func convertVoiceToText(url: String,
                                   language: String = "",
                                   onSuccess: @escaping (String) -> Void,
                                   onFailure: @escaping (Int32, String) -> Void) {
        callExperimentalAPI(api: ApiConvertVoiceToText,
                            params: buildConvertVoiceToTextParams(url: url, language: language),
                            onSuccess: { result in
                                let text = result.trimmingCharacters(in: .whitespacesAndNewlines)
                                if text.isEmpty {
                                    onFailure(ErrorUnknown, "voice to text result is empty")
                                } else {
                                    onSuccess(text)
                                }
                            },
                            onFailure: onFailure)
    }

    static func convertLocalAudioToText(filePath: String,
                                        onSuccess: @escaping (String) -> Void,
                                        onFailure: @escaping (Int32, String) -> Void) {
        uploadAudioFile(filePath: filePath,
                        onSuccess: { url in
                            convertVoiceToText(url: url, language: "", onSuccess: onSuccess, onFailure: onFailure)
                        },
                        onFailure: onFailure)
    }

    // MARK: - Constants

    private static func callExperimentalAPI(api: String,
                                            params: String,
                                            onSuccess: @escaping (String) -> Void,
                                            onFailure: @escaping (Int32, String) -> Void) {
        V2TIMManager.sharedInstance().callExperimentalAPI(api: api, param: params as NSObject) { result in
            DispatchQueue.main.async {
                onSuccess(result?.description ?? "")
            }
        } fail: { code, desc in
            DispatchQueue.main.async {
                onFailure(code, desc ?? "")
            }
        }
    }

    private static func parseAudioUrl(_ result: String) -> String? {
        guard !result.isEmpty,
              let data = result.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let url = json[KeyAudioUrl] as? String, !url.isEmpty else {
            return nil
        }
        return url
    }

    private static func parseVoiceId(_ result: String) -> String? {
        guard !result.isEmpty,
              let data = result.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let id = json[KeyVoiceId] as? String, !id.isEmpty else {
            return nil
        }
        return id
    }

    private static func parseVoiceList(_ result: String) -> [CustomVoiceItem] {
        guard !result.isEmpty,
              let data = result.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let array = json[KeyVoiceList] as? [[String: Any]] else {
            return []
        }
        var list: [CustomVoiceItem] = []
        for item in array {
            guard let id = item[KeyVoiceId] as? String, !id.isEmpty else { continue }
            let name = item[KeyVoiceName] as? String ?? ""
            list.append(CustomVoiceItem(voiceId: id, name: name, isDefault: false))
        }
        return list
    }

    private static func buildUploadFileParams(filePath: String) -> String {
        let dict: [String: Any] = [KeyFilePath: filePath, KeyFileType: FileTypeAudio]
        return jsonString(from: dict) ?? ""
    }

    private static func buildConvertTextToVoiceParams(text: String, voiceId: String, audioFormat: String, language: String) -> String {
        var dict: [String: Any] = [KeyText: text, KeyAudioFormat: audioFormat, KeyLanguage: language]
        if !voiceId.isEmpty {
            dict[KeyVoiceId] = voiceId
        }
        return jsonString(from: dict) ?? ""
    }

    private static func buildConvertVoiceToTextParams(url: String, language: String) -> String {
        var dict: [String: Any] = [KeyUrl: url, KeyLanguage: language]
        return jsonString(from: dict) ?? ""
    }

    private static func buildVoiceCloneParams(voiceName: String, audioUrl: String, promptText: String, language: String) -> String {
        let dict: [String: Any] = [KeyVoiceName: voiceName, KeyAudioUrl: audioUrl, KeyPromptText: promptText, KeyLanguage: language]
        return jsonString(from: dict) ?? ""
    }

    private static func buildDeleteCustomVoiceParams(voiceId: String) -> String {
        let dict: [String: Any] = [KeyVoiceId: voiceId]
        return jsonString(from: dict) ?? ""
    }

    private static func jsonString(from dict: [String: Any]) -> String? {
        guard let data = try? JSONSerialization.data(withJSONObject: dict, options: []),
              let string = String(data: data, encoding: .utf8) else {
            return nil
        }
        return string
    }
}
