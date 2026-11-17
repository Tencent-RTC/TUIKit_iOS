public struct ConversationActionConfig {
    public var isSupportDelete: Bool? = nil
    public var isSupportMute: Bool? = nil
    public var isSupportPin: Bool? = nil
    public var isSupportMarkUnread: Bool? = nil
    public var isSupportClearHistory: Bool? = nil
    public var actionCustomizer: ConversationActionCustomizer? = nil

    public init(
        isSupportDelete: Bool? = nil,
        isSupportMute: Bool? = nil,
        isSupportPin: Bool? = nil,
        isSupportMarkUnread: Bool? = nil,
        isSupportClearHistory: Bool? = nil,
        actionCustomizer: ConversationActionCustomizer? = nil
    ) {
        self.isSupportDelete = isSupportDelete
        self.isSupportMute = isSupportMute
        self.isSupportPin = isSupportPin
        self.isSupportMarkUnread = isSupportMarkUnread
        self.isSupportClearHistory = isSupportClearHistory
        self.actionCustomizer = actionCustomizer
    }
}
