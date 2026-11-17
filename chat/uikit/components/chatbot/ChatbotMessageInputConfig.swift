import Foundation

extension ChatMessageInputConfig {
    func applyingChatbotRestrictions() -> ChatMessageInputConfig {
        var config = self
        config.isShowAudioCall = false
        config.isShowVideoCall = false
        config.enableMention = false
        config.enableTyping = false
        return config
    }
}
