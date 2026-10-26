import Foundation

public struct ChatRealtimeASRConfig {
    public var userLanguage: String? = nil                  /// 识别语言，nil 时默认 zh。
    public var userEnableVoiceprintDenoise: Bool? = nil     /// 声纹降噪，nil 时默认 false。
    public var userVoiceprintAutoEnrollMs: Int? = nil       /// 声纹自动注册时长，单位毫秒，nil 时默认 3000。
    public var userEnablePCMOutput: Bool? = nil             /// 是否回调 PCM，nil 时默认 true。
    public var userStartTimeoutMs: Int? = nil               /// 启动超时，单位毫秒，nil 时默认 5000。
}

public struct ChatRealtimeASRMessage {
    public let segmentIndex: Int                          /// 同一识别实例内不重复的句子序号；同一句更新使用相同序号，按序号排序拼接文字。
    public let sourceText: String
    public let isCompleted: Bool                          /// 段级最终化。当前 IM 链路在会话结束通知到达后才逐段确认，不能即时确认每句。
}

public protocol RealtimeASRListener: AnyObject {
    func onRealtimeTranscriberStarted(_ voiceId: String)
    func onReceiveTranscriberMessage(_ message: ChatRealtimeASRMessage)
    func onRealtimeTranscriberStopped()
    func onRealtimeTranscriberError(_ errorCode: Int32, errorMsg: String)
    func onReceiveTranscriberPCM(_ pcm: [Int16])
}

public final class RealtimeASR {
    let implementation: RealtimeASRImpl

    public init(config: ChatRealtimeASRConfig? = nil, listener: RealtimeASRListener) {
        implementation = RealtimeASRImpl(config: config ?? ChatRealtimeASRConfig(), listener: listener)
    }

    public func startASR() {
        implementation.performOnMain { $0.start() }
    }

    public func stopASR() {
        implementation.performOnMain { $0.stop() }
    }

    deinit {
        implementation.performOnMain { $0.cancel(stopCapture: true) }
    }
}
