extension ConversationActionConfig {
    public init(
        isSupportDelete: Bool? = nil,
        isSupportMute: Bool? = nil,
        isSupportPin: Bool? = nil,
        isSupportMarkUnread: Bool? = nil,
        isSupportClearHistory: Bool? = nil,
        actionCustomizer: ConversationActionCustomizer? = nil
    ) {
        self.userIsSupportDelete = isSupportDelete
        self.userIsSupportMute = isSupportMute
        self.userIsSupportPin = isSupportPin
        self.userIsSupportMarkUnread = isSupportMarkUnread
        self.userIsSupportClearHistory = isSupportClearHistory
        self.userActionCustomizer = actionCustomizer
    }

    public var isSupportDelete: Bool {
        get { userIsSupportDelete ?? AppBuilderConfig.shared.conversationActionList.contains(.delete) }
        set { userIsSupportDelete = newValue }
    }

    public var isSupportMute: Bool {
        get { userIsSupportMute ?? AppBuilderConfig.shared.conversationActionList.contains(.mute) }
        set { userIsSupportMute = newValue }
    }

    public var isSupportPin: Bool {
        get { userIsSupportPin ?? AppBuilderConfig.shared.conversationActionList.contains(.pin) }
        set { userIsSupportPin = newValue }
    }

    public var isSupportMarkUnread: Bool {
        get { userIsSupportMarkUnread ?? AppBuilderConfig.shared.conversationActionList.contains(.markUnread) }
        set { userIsSupportMarkUnread = newValue }
    }

    public var isSupportClearHistory: Bool {
        get { userIsSupportClearHistory ?? AppBuilderConfig.shared.conversationActionList.contains(.clearHistory) }
        set { userIsSupportClearHistory = newValue }
    }

    public var actionCustomizer: ConversationActionCustomizer? {
        get { userActionCustomizer }
        set { userActionCustomizer = newValue }
    }
}
