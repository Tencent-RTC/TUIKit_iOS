import Foundation

extension ChatMessageListConfig {
    public var isSupportCopy: Bool {
        get { userIsSupportCopy ?? AppBuilderConfig.shared.messageActionList.contains(.copy) }
        set { userIsSupportCopy = newValue }
    }

    public var isSupportDelete: Bool {
        get { userIsSupportDelete ?? AppBuilderConfig.shared.messageActionList.contains(.delete) }
        set { userIsSupportDelete = newValue }
    }

    public var isSupportRecall: Bool {
        get { userIsSupportRecall ?? AppBuilderConfig.shared.messageActionList.contains(.recall) }
        set { userIsSupportRecall = newValue }
    }

    public var isSupportForward: Bool {
        get { userIsSupportForward ?? AppBuilderConfig.shared.messageActionList.contains(.forward) }
        set { userIsSupportForward = newValue }
    }

    public var isSupportQuote: Bool {
        get { userIsSupportQuote ?? AppBuilderConfig.shared.messageActionList.contains(.quote) }
        set { userIsSupportQuote = newValue }
    }

    public var isSupportMultiSelect: Bool {
        get { userIsSupportMultiSelect ?? true }
        set { userIsSupportMultiSelect = newValue }
    }

    public var isSupportConvertToText: Bool {
        get { userIsSupportConvertToText ?? true }
        set { userIsSupportConvertToText = newValue }
    }

    public var isSupportTranslate: Bool {
        get { userIsSupportTranslate ?? true }
        set { userIsSupportTranslate = newValue }
    }

    public var isSupportListenFromHere: Bool {
        get { userIsSupportListenFromHere ?? true }
        set { userIsSupportListenFromHere = newValue }
    }

    public var actionCustomizer: MessageActionCustomizer? {
        get { userActionCustomizer }
        set { userActionCustomizer = newValue }
    }
}
