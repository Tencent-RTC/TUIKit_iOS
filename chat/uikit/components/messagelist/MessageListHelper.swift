import Foundation
import UIKit
import AtomicXCore

public final class MessageListHelper {
    private init() {}

    /// 添加或更新本地展示占位；相同会话和占位 ID 的更新保留原位置。
    public static func addPlaceholder(conversationID: String, info: MessagePlaceholderInfo) {
        MessageListPlaceholderStore.shared.upsert(conversationID: conversationID, info: info)
    }

    /// 删除本地展示占位，不撤回消息或取消发送任务。
    public static func removePlaceholder(conversationID: String, placeholderID: String) {
        MessageListPlaceholderStore.shared.remove(conversationID: conversationID, placeholderID: placeholderID)
    }

    public static func registerCustomMessageCell(businessID: String,
                                                 summaryProvider: @escaping (CustomMessagePayload) -> String?,
                                                 makeContentView: @escaping () -> MessageContentView) {
        MessageCellRegistry.shared.registerCustomMessageCell(
            businessID: businessID,
            summaryProvider: summaryProvider,
            makeContentView: makeContentView
        )
    }

    /// 注册自定义消息摘要匹配器，返回非 nil 即命中（用于会话列表与引用预览）。
    public static func registerCustomMessageSummary(matcher: @escaping (CustomMessagePayload) -> String?) {
        CustomMessageSummaryRegistry.shared.registerMatcher(matcher)
    }
}
