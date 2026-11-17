import Foundation

extension ChatMessageListConfig {
    func applyingChatbotRestrictions() -> ChatMessageListConfig {
        var config = self
        config.isSupportReaction = false
        config.isSupportQuote = false
        config.isSupportRecall = false
        config.isSupportMultiSelect = false
        config.isSupportConvertToText = false
        config.isSupportTranslate = false
        config.isSupportListenFromHere = false
        config.enableTyping = false
        config.actionCustomizer = nil
        return config
    }
}
