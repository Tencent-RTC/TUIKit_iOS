import Foundation

extension ChatMessageListConfig {
    var _isSupportCopy: Bool {
        isSupportCopy ?? AppBuilderConfig.shared.messageActionList.contains(.copy)
    }

    var _isSupportDelete: Bool {
        isSupportDelete ?? AppBuilderConfig.shared.messageActionList.contains(.delete)
    }

    var _isSupportRecall: Bool {
        isSupportRecall ?? AppBuilderConfig.shared.messageActionList.contains(.recall)
    }

    var _isSupportForward: Bool {
        isSupportForward ?? AppBuilderConfig.shared.messageActionList.contains(.forward)
    }

    var _isSupportQuote: Bool {
        isSupportQuote ?? AppBuilderConfig.shared.messageActionList.contains(.quote)
    }

    var _isSupportMultiSelect: Bool {
        isSupportMultiSelect ?? true
    }

    var _isSupportConvertToText: Bool {
        isSupportConvertToText ?? true
    }

    var _isSupportTranslate: Bool {
        isSupportTranslate ?? true
    }

    var _isSupportListenFromHere: Bool {
        isSupportListenFromHere ?? true
    }

    var _actionCustomizer: MessageActionCustomizer? {
        actionCustomizer
    }
}
