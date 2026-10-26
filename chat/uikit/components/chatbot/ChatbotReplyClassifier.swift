import Foundation
import AtomicXCore

/// 机器人回复所属通道，对齐 Android ChatbotReplyClassifier。
///
/// - plugin：chatbotPlugin 自定义消息，正文在 chunks 数组里，靠 msgKey 定位、isFinished 收尾，支持打断。
/// - stream：TIMStreamElem 流式消息（.stream）。正文是 markdown，靠 isStreamEnded 收尾，没有 msgKey 也没有打断入口。
/// - plain：普通文本、卡片这类一次性回复。
/// - control：不该展示给用户的信令。
enum ChatbotReplyChannel {
    case plugin
    case stream
    case plain
    case control

    var isReply: Bool {
        return self != .control
    }
}

enum ChatbotReplyClassifier {

    /// 是否是一条已经有内容可看的回复。
    ///
    /// TIMStreamElem 的消息体先到、正文随后由消息变更回调补上，刚到那一刻 markdown 还是空的，
    /// 列表里也被可见性策略挡着不显示。此时若判定「回复到了」就把等待态收掉，屏幕上会空出一段
    /// 什么都没有的时间，所以要等到第一段正文。
    static func isVisibleReply(_ message: MessageInfo) -> Bool {
        let channel = classify(message)
        guard channel.isReply else { return false }
        if channel != .stream { return true }
        guard case .stream(let payload) = message.messagePayload else { return true }
        return !payload.markdown.isEmpty
    }

    static func classify(_ message: MessageInfo) -> ChatbotReplyChannel {
        if isStreamElement(message) {
            return .stream
        }
        guard let plugin = ChatbotMessageProtocol.parse(message) else {
            return .plain
        }
        switch plugin.source {
        case .flow, .error:
            return .plugin
        case .interrupt, .unknown:
            return .control
        }
    }

    private static func isStreamElement(_ message: MessageInfo) -> Bool {
        if message.messageType != .stream { return false }
        if case .stream = message.messagePayload { return true }
        return false
    }
}
