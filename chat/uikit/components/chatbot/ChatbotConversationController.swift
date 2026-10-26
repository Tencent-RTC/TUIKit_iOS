import Foundation
import Combine
import AtomicXCore

/// 机器人会话控制器：跟踪「等待回复 → 流式输出 → 结束」的状态，驱动占位气泡与停止按钮。
/// 对齐 Android ChatbotConversationController。
final class ChatbotConversationController {
    let conversationID: String

    @Published private(set) var state: ChatbotConversationState = .idle

    private let interruptAction: ChatbotInterruptAction
    private let nowSeconds: () -> Int64
    private let elapsedSeconds: () -> TimeInterval

    private var knownMessageIDs: Set<String> = []
    private var waitingBaselineMessageIDs: Set<String> = []
    private var watchdogTimer: Timer?
    private var lastProgressSeconds: TimeInterval = 0
    private var abandonedMessageIDs: Set<String> = []

    var isActive: Bool {
        return state != .idle
    }

    /// 当前状态是否支持打断。
    ///
    /// 只有 chatbotPlugin 协议的流式输出能按 msgKey 打断。TIMStreamElem 那条路径既没有 msgKey，
    /// 服务端也没有打断入口，状态机根本进不了 streaming，所以那边不出停止按钮，
    /// 「正在回复」交给列表里的占位气泡表达。
    var canInterrupt: Bool {
        if case .streaming = state { return true }
        return false
    }

    init(conversationID: String,
         interruptAction: ChatbotInterruptAction? = nil,
         nowSeconds: @escaping () -> Int64 = { Int64(Date().timeIntervalSince1970) },
         elapsedSeconds: @escaping () -> TimeInterval = { ProcessInfo.processInfo.systemUptime }) {
        self.conversationID = conversationID
        self.interruptAction = interruptAction ?? ChatbotInterruptSender(conversationID: conversationID)
        self.nowSeconds = nowSeconds
        self.elapsedSeconds = elapsedSeconds
    }

    deinit {
        watchdogTimer?.invalidate()
    }

    func onTextMessageSent() {
        NSLog("[ChatbotPlaceholderDiag] onTextMessageSent, conversation=\(conversationID) state=\(state)")
        waitingBaselineMessageIDs = knownMessageIDs
        dispatch(.textMessageSent(timestampSeconds: nowSeconds()))
    }

    func onMessagesChanged(_ messages: [MessageInfo]) {
        switch state {
        case .idle:
            restoreFromHistory(messages)
        case .waiting(let requestTimestampSeconds):
            let response = latestPluginResponse(in: messages) { message, data in
                !waitingBaselineMessageIDs.contains(message.msgID) && data.isVisualResponse &&
                    isNewReply(message, after: requestTimestampSeconds)
            }
            if let response = response {
                NSLog("[ChatbotPlaceholderDiag] waiting ended by plugin frame: \(Self.describe(response.0)) chunks=\(response.1.chunks.count) finished=\(response.1.isFinished)")
                dispatch(.botMessageReceived(messageID: response.0.msgID, data: response.1))
            } else if let inbound = firstInboundReply(messages, baseline: waitingBaselineMessageIDs, notBefore: requestTimestampSeconds) {
                // TIMStreamElem / 文本 / 卡片：没有 msgKey 也没有打断能力，收到就结束等待
                NSLog("[ChatbotPlaceholderDiag] waiting ended by inbound reply: \(Self.describe(inbound))")
                dispatch(.cleared)
            }
        case .streaming(let messageID, _):
            let response = latestPluginResponse(in: messages) { message, data in
                message.msgID == messageID && data.isVisualResponse
            }
            if let response = response {
                dispatch(.botMessageReceived(messageID: response.0.msgID, data: response.1))
            }
        }
        knownMessageIDs = Set(messages.map(\.msgID).filter { !$0.isEmpty })
    }

    /// 等待回复期间要补在列表最新端的「正在输入」气泡的时间戳，不需要补时返回 nil。
    ///
    /// 只有确实还没有任何东西可显示时才补：chatbotPlugin 协议收到首个分片后由真实气泡接管，
    /// TIMStreamElem 则要等正文落地，判定见 ChatbotReplyClassifier.isVisibleReply。
    func placeholderTimestampSeconds(_ messages: [MessageInfo]) -> Int64? {
        guard case .waiting(let requestTimestampSeconds) = state else { return nil }
        let pluginResponse = latestPluginResponse(in: messages) { message, data in
            !waitingBaselineMessageIDs.contains(message.msgID) && data.isVisualResponse &&
                isNewReply(message, after: requestTimestampSeconds)
        }
        let inboundReply = hasInboundReply(messages, baseline: waitingBaselineMessageIDs, notBefore: requestTimestampSeconds)
        if pluginResponse != nil || inboundReply {
            NSLog("[ChatbotPlaceholderDiag] placeholder suppressed, conversation=\(conversationID) plugin=\(pluginResponse != nil) inbound=\(inboundReply)")
            return nil
        }
        NSLog("[ChatbotPlaceholderDiag] placeholder visible, conversation=\(conversationID) ts=\(requestTimestampSeconds)")
        return requestTimestampSeconds
    }

    @discardableResult
    func sendInterrupt(completion: CompletionClosure? = nil) -> Bool {
        guard case .streaming(let messageID, let msgKey) = state else { return false }
        return interruptAction.send(messageID: messageID, fallbackMsgKey: msgKey) { [weak self] result in
            switch result {
            case .success:
                completion?(.success(()))
            case .failure(let error):
                // 打断都发不出去（例如后台不可用），本地强制解锁，别把用户困住
                self?.abandon(messageID)
                completion?(.failure(error))
            }
        }
    }

    func clear() {
        knownMessageIDs = []
        waitingBaselineMessageIDs = []
        abandonedMessageIDs = []
        dispatch(.cleared)
    }

    // MARK: - Private

    /// 是否收到了机器人的新回复。
    ///
    /// chatbotPlugin 协议的回复由 onMessagesChanged 按 msgKey 精确跟踪，走不到这里；
    /// TIMStreamElem 流式消息和普通文本、卡片都没有 msgKey，只能按"来了一条新的对端消息"判断。
    /// 机器人的控制信令（打断回执之类）不算回复，正文还没补上的流式消息也不算。
    private func hasInboundReply(_ messages: [MessageInfo], baseline: Set<String>, notBefore: Int64? = nil) -> Bool {
        return firstInboundReply(messages, baseline: baseline, notBefore: notBefore) != nil
    }

    private func firstInboundReply(_ messages: [MessageInfo], baseline: Set<String>, notBefore: Int64? = nil) -> MessageInfo? {
        return messages.first { message in
            !message.isSentBySelf &&
                !message.msgID.isEmpty &&
                !baseline.contains(message.msgID) &&
                (notBefore == nil || isNewReply(message, after: notBefore!)) &&
                ChatbotReplyClassifier.isVisibleReply(message)
        }
    }

    /// 本轮回复的服务器时间戳必然不早于发送时刻，早于此的一定是历史消息。
    private func isNewReply(_ message: MessageInfo, after requestTimestampSeconds: Int64) -> Bool {
        return (message.timestamp ?? 0) >= requestTimestampSeconds - Int64(Self.replyTimestampToleranceSeconds)
    }

    static func describe(_ message: MessageInfo) -> String {
        let channel = ChatbotReplyClassifier.classify(message)
        var detail = ""
        if case .stream(let payload) = message.messagePayload {
            detail = "markdownLen=\(payload.markdown.count) ended=\(payload.isStreamEnded)"
        } else if let data = ChatbotMessageProtocol.parse(message) {
            detail = "src=\(data.source) chunks=\(data.chunks.count) finished=\(data.isFinished) placeholder=\(data.isPlaceholder)"
        }
        return "msgID=\(message.msgID) type=\(message.messageType.rawValue) channel=\(channel) self=\(message.isSentBySelf) ts=\(message.timestamp ?? 0) \(detail)"
    }

    /// 历史里最后一条未结束的流式消息，可能只是很久以前留下的残骸：后台挂掉、
    /// 或登录同步时正文补丁丢失。把它恢复成 streaming 会让输入框一进会话就锁死，
    /// 所以只认刚刚发生的、且没有被超时放弃过的消息。
    private func restoreFromHistory(_ messages: [MessageInfo]) {
        let response = latestPluginResponse(in: messages) { _, data in
            data.isVisualResponse
        }
        let resumable = response != nil &&
            !abandonedMessageIDs.contains(response!.0.msgID) &&
            isRecentEnoughToResume(response!.0)
        dispatch(.historyRestored(
            messageID: resumable ? response?.0.msgID : nil,
            data: resumable ? response?.1 : nil
        ))
    }

    private func isRecentEnoughToResume(_ message: MessageInfo) -> Bool {
        guard let timestamp = message.timestamp, timestamp > 0 else { return false }
        return nowSeconds() - timestamp <= Self.streamResumeWindowSeconds
    }

    /// 超时或打断失败后强制回到空闲，并记下这条消息，避免历史恢复又把它锁回去。
    private func abandon(_ messageID: String?) {
        if let messageID = messageID, !messageID.isEmpty {
            abandonedMessageIDs.insert(messageID)
        }
        dispatch(.cleared)
    }

    private func dispatch(_ event: ChatbotConversationEvent) {
        let next = ChatbotConversationReducer.reduce(state, event)
        if next != state {
            NSLog("[ChatbotPlaceholderDiag] state \(state) -> \(next), conversation=\(conversationID)")
        }
        state = next
        syncWatchdog(next)
    }

    /// 机器人没有任何回应时把状态兜回空闲。
    ///
    /// 后台挂掉或回复丢失的情况下，waiting / streaming 不会有任何事件把状态推回 idle，
    /// 「正在输入」气泡就会一直转下去、停止按钮也收不回来。这里在超时后强制收场。
    ///
    /// 每次有进展（发出消息、收到分片）都会续期，所以正常长回复不会被误伤。
    private func syncWatchdog(_ state: ChatbotConversationState) {
        if state == .idle {
            watchdogTimer?.invalidate()
            watchdogTimer = nil
            return
        }
        lastProgressSeconds = elapsedSeconds()
        guard watchdogTimer == nil else { return }
        let timer = Timer(timeInterval: Self.watchdogTickSeconds, repeats: true) { [weak self] _ in
            self?.watchdogTick()
        }
        RunLoop.main.add(timer, forMode: .common)
        watchdogTimer = timer
    }

    private func watchdogTick() {
        guard Thread.isMainThread else { return }
        let current = state
        if current == .idle { return }
        let timeout: TimeInterval
        switch current {
        case .waiting:
            timeout = Self.waitingTimeoutSeconds
        default:
            timeout = Self.streamingStallTimeoutSeconds
        }
        if elapsedSeconds() - lastProgressSeconds < timeout { return }
        // 先摘掉句柄，避免 abandon 里的 dispatch 反过来操作正在执行的定时器
        watchdogTimer?.invalidate()
        watchdogTimer = nil
        if case .streaming(let messageID, _) = current {
            abandon(messageID)
        } else {
            abandon(nil)
        }
    }

    /// 只在 chatbotPlugin 自定义消息里找，TIMStreamElem 流式消息不走这条路径。
    private func latestPluginResponse(in messages: [MessageInfo],
                                      predicate: (MessageInfo, ChatbotMessageData) -> Bool) -> (MessageInfo, ChatbotMessageData)? {
        for message in messages.reversed() {
            guard let data = ChatbotMessageProtocol.parse(message) else { continue }
            if predicate(message, data) {
                return (message, data)
            }
        }
        return nil
    }

    private static let watchdogTickSeconds: TimeInterval = 0.5

    /// 发出消息后多久没有任何回复就撤掉「正在输入」气泡。
    private static let waitingTimeoutSeconds: TimeInterval = 15

    /// 判定「本轮回复」的时间容差（秒）。基线集合依赖控制器在发送前已见过历史消息，
    /// 刚进会话立即发送时基线可能不完整，上一轮旧回复会被误判为本轮回复而提前结束等待。
    /// 因此只有时间不早于发送时刻（容忍少量本地/服务端时钟偏差）的消息才算本轮回复。
    private static let replyTimestampToleranceSeconds: TimeInterval = 10

    /// chatbotPlugin 流式输出停滞多久判定为中断。每个分片都会续期，所以阈值要比等待态宽得多。
    private static let streamingStallTimeoutSeconds: TimeInterval = 60

    private static let streamResumeWindowSeconds: Int64 = 60
}
