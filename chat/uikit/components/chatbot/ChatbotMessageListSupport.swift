import Foundation
import AtomicXCore

/// 机器人相关消息的可见性策略，对齐 Android MessageListVisibilityPolicy 的对应分支。
enum ChatbotMessageVisibilityPolicy {
    static func shouldHide(_ message: MessageInfo) -> Bool {
        // 打断信令不展示
        if ChatbotMessageProtocol.parse(message)?.source == .interrupt {
            return true
        }
        if isEmptyStreamMessage(message) {
            return true
        }
        return false
    }

    /// 正文还没到的 TIMStreamElem 流式消息。
    ///
    /// 这条路径不显示三点加载动画，空正文渲染出来就只是一个空气泡，等第一段正文到了
    /// 再让消息出现。顺带也挡掉了那些正文补丁丢失、永远填不上的残骸消息。
    private static func isEmptyStreamMessage(_ message: MessageInfo) -> Bool {
        guard message.messageType == .stream,
              case .stream(let payload) = message.messagePayload else {
            return false
        }
        return payload.markdown.isEmpty
    }
}

/// 会话列表 / 搜索结果里的机器人消息摘要，对齐 Android ChatbotMessageSummaryPolicy。
enum ChatbotMessageSummaryPolicy {
    static func getSummary(_ message: MessageInfo) -> String? {
        guard let data = ChatbotMessageProtocol.parse(message) else { return nil }
        switch data.source {
        case .flow, .error:
            return data.displayText
        case .interrupt, .unknown:
            return nil
        }
    }
}

/// 「AI 正在输入」占位气泡的数据源，对齐 Android ChatbotPlaceholderMessageFactory。
///
/// 造出来的 MessageInfo 只活在展示列表里：不调 insertMessageToLocalStorage、不进本地库、
/// 不参与登录同步，进程一死就没了。这是它和真正插一条本地消息的根本区别——后者会在卸载重装时
/// 被同步通道重放成永远转圈的残骸，而这条不可能被重放。
///
/// 复用 chatbotPlugin 的 FLOW 结构是为了直接落到流式气泡的加载态分支上，不用再为它单独做一套
/// cell 类型；`localPlaceholder` 标记让渲染和长按菜单能把它和真实回复区分开。
enum ChatbotPlaceholderMessageFactory {
    static let messageIDPrefix = "chatbot_placeholder_"

    /// 从最近一条对端消息上取头像昵称，让占位气泡和随后真正的回复长得一样。
    static func resolveSender(_ messages: [MessageInfo]) -> MessageSenderInfo? {
        return messages.first(where: { !$0.isSentBySelf })?.from
    }

    static func create(conversationID: String, timestampSeconds: Int64, sender: MessageSenderInfo? = nil) -> MessageInfo {
        let targetID = ChatbotConversationPolicy.targetID(conversationID) ?? ""
        var resolvedSender = sender ?? MessageSenderInfo()
        if resolvedSender.userID.isEmpty {
            resolvedSender.userID = targetID
        }
        if resolvedSender.nickname?.isEmpty != false {
            resolvedSender.nickname = targetID
        }

        var message = MessageInfo()
        message.msgID = "\(messageIDPrefix)\(conversationID)"
        message.status = .sendSuccess
        message.timestamp = timestampSeconds
        message.from = resolvedSender
        message.to = targetID
        message.isSentBySelf = false
        if conversationID.hasPrefix("c2c_") {
            message.conversationType = .c2c
        } else if conversationID.hasPrefix("group_") {
            message.conversationType = .group
        } else {
            message.conversationType = .unknown
        }
        message.messageType = .custom
        var payload = CustomMessagePayload()
        payload.customData = ChatbotMessageProtocol.makePlaceholderCustomData()
        message.messagePayload = .custom(payload)
        message.needReadReceipt = false
        return message
    }
}
