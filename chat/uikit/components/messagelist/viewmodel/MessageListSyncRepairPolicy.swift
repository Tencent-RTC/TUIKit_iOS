import Foundation
import AtomicXCore

/// 判定消息列表是否被登录同步的重放消息污染，对齐 Android MessageListSyncRepairPolicy。
///
/// 全新安装登录时，IMSDK 会把一批历史消息经由新消息通道重放。这批消息会被追加到列表
/// 最新端（顺序错乱），而且流式消息的正文补丁可能在消息真正入列之前就已经派发完毕
/// 并被丢弃，导致气泡永远停在加载态。
///
/// 命中判定后由 ViewModel 重新拉取首屏，用历史接口的干净数据覆盖掉脏列表。
final class MessageListSyncRepairPolicy {
    private let nowSecondsProvider: () -> Int64

    init(nowSecondsProvider: @escaping () -> Int64 = { Int64(Date().timeIntervalSince1970) }) {
        self.nowSecondsProvider = nowSecondsProvider
    }

    func isCorrupted(_ messages: [MessageInfo]) -> Bool {
        if messages.count < 2 { return false }
        return hasStaleUnfilledStream(messages) || hasTimestampInversion(messages)
    }

    /// 流式消息既没有正文、也没有结束标记，且已经过了 settle 窗口。
    ///
    /// 正在生成中的流式消息同样是空正文 + 未结束，靠消息时间把两者区分开：真正在生成的
    /// 消息一定是刚刚发生的，而重放进来的都是很久以前的。
    private func hasStaleUnfilledStream(_ messages: [MessageInfo]) -> Bool {
        let threshold = nowSecondsProvider() - Self.streamSettleSeconds
        return messages.contains { message in
            guard message.messageType == .stream,
                  let timestamp = message.timestamp,
                  timestamp > 0, timestamp <= threshold,
                  case .stream(let payload) = message.messagePayload else {
                return false
            }
            return payload.markdown.isEmpty && !payload.isStreamEnded
        }
    }

    /// 列表整体走向由首尾决定，出现反向的相邻对即为乱序。
    private func hasTimestampInversion(_ messages: [MessageInfo]) -> Bool {
        let stamps = messages.compactMap { $0.timestamp }.filter { $0 > 0 }
        if stamps.count < 2 { return false }
        let descending = stamps.first! > stamps.last!
        for (prev, next) in zip(stamps, stamps.dropFirst()) {
            if descending {
                if next > prev { return true }
            } else {
                if next < prev { return true }
            }
        }
        return false
    }

    private static let streamSettleSeconds: Int64 = 60
}
