import Foundation
import ImSDK_Plus

// MARK: - 音色

public struct CustomVoiceItem: Equatable, Hashable {
    public let voiceId: String
    public let name: String
    public let isDefault: Bool

    public init(voiceId: String, name: String, isDefault: Bool = false) {
        self.voiceId = voiceId
        self.name = name
        self.isDefault = isDefault
    }
}

// MARK: - 播放

public struct TtsPlaybackProgress {
    public let messageID: String
    public let playedMilliseconds: Int               /// 已播放时长，按音频缓冲块完成粒度更新。
    public let synthesizedMilliseconds: Int          /// 已解码音频时长，合成结束后为最终总时长。
    public let isSynthesisFinished: Bool
    public let audioLevel: Float                     /// 最近入队音频的电平，范围 0...1，并非实时输出游标。
}

public final class TtsPlaybacker {
    private let implementation = TtsPlaybackerImpl()

    public init() {
        implementation.owner = self
    }

    /// 合成并播放文本。removeSymbols 默认 false；开启后移除表情标记和多余空白，保留正常标点。
    /// 重复调用会使旧请求回调失效。清洗后为空时跳过合成并通知完成。请在主线程调用。
    public func playText(text: String,
                         voiceId: String = "",
                         language: String = "",
                         removeSymbols: Bool = false,
                         onStart: (() -> Void)? = nil,
                         onComplete: (() -> Void)? = nil,
                         onError: ((String) -> Void)? = nil) {
        implementation.playText(text: text, voiceId: voiceId, language: language, removeSymbols: removeSymbols,
                                onStart: onStart, onComplete: onComplete, onError: onError)
    }

    /// 朗读流式消息。onStart 表示 SDK 接受合成请求；onComplete 只在音频实际播完时触发。
    public func playStreamMessage(message: V2TIMMessage,
                                  voiceId: String = "",
                                  speed: Float = 1.0,
                                  onStart: (() -> Void)? = nil,
                                  onProgress: ((TtsPlaybackProgress) -> Void)? = nil,
                                  onComplete: (() -> Void)? = nil,
                                  onError: ((Int32, String) -> Void)? = nil) {
        implementation.playStreamMessage(message: message, voiceId: voiceId, speed: speed,
                                         onStart: onStart, onProgress: onProgress, onComplete: onComplete, onError: onError)
    }

    /// 停止合成和播放并使旧回调失效。默认通知完成；取消回复时传 false。请在主线程调用。
    public func stop(notifyCompletion: Bool = true) {
        implementation.stop(notifyCompletion: notifyCompletion)
    }
}

// MARK: - 语音偏好

public final class VoiceMessageConfig {
    public static let shared = VoiceMessageConfig()

    private let implementation = VoiceMessageConfigImpl()

    private init() {}

    public func getRecordTranslateTargetLanguage() -> String {
        return implementation.getRecordTranslateTargetLanguage()
    }

    public func setRecordTranslateTargetLanguage(_ language: String) {
        implementation.setRecordTranslateTargetLanguage(language)
    }

    public func getSelectedVoiceId() -> String {
        return implementation.getSelectedVoiceId()
    }

    public func getSelectedVoiceName() -> String {
        return implementation.getSelectedVoiceName()
    }

    public func setSelectedVoice(id: String, name: String) {
        implementation.setSelectedVoice(id: id, name: name)
    }
}
