extension ConversationActionConfig {
    var _isSupportDelete: Bool {
        isSupportDelete ?? AppBuilderConfig.shared.conversationActionList.contains(.delete)
    }

    var _isSupportMute: Bool {
        isSupportMute ?? AppBuilderConfig.shared.conversationActionList.contains(.mute)
    }

    var _isSupportPin: Bool {
        isSupportPin ?? AppBuilderConfig.shared.conversationActionList.contains(.pin)
    }

    var _isSupportMarkUnread: Bool {
        isSupportMarkUnread ?? AppBuilderConfig.shared.conversationActionList.contains(.markUnread)
    }

    var _isSupportClearHistory: Bool {
        isSupportClearHistory ?? AppBuilderConfig.shared.conversationActionList.contains(.clearHistory)
    }

    var _actionCustomizer: ConversationActionCustomizer? {
        actionCustomizer
    }
}
