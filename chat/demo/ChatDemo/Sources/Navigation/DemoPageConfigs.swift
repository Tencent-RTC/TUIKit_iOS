import TUIChatKit
import AtomicXCore

internal enum DemoPageConfigs {
    private static let assistantStreamingCharacterLimit: Double = 100

    internal static func makeConversationsConfig() -> ConversationActionConfig {
        var config = ConversationActionConfig()
        config.isSupportDelete = nil
        config.isSupportMute = nil
        config.isSupportPin = nil
        config.isSupportMarkUnread = nil
        config.isSupportClearHistory = nil
        config.actionCustomizer = nil
        return config
    }

    internal static func makeContactsConfig() -> ContactListConfig {
        var config = ContactListConfig()
        config.showNewContacts = true
        config.showGroupApplications = true
        config.showMyGroups = true
        config.showBlacklist = true
        config.showSearchBar = true
        config.itemCustomizer = nil
        return config
    }

    internal static func makeMessageListConfig() -> ChatMessageListConfig {
        var config = ChatMessageListConfig()
        config.isShowLeftAvatar = nil
        config.isShowRightAvatar = nil
        config.isShowLeftNickname = nil
        config.isShowRightNickname = nil
        config.isSupportTranslate = nil
        config.isSupportConvertToText = nil
        config.streamingMaxCharactersPerSecond = nil
        config.actionCustomizer = nil
        config.enableChatbotReplyPlaceholder = false
        return config
    }

    internal static func makeMessageInputConfig(conversationID: String) -> ChatMessageInputConfig {
        let sdkAppID = LoginStore.shared.sdkAppID
        var config = ChatMessageInputConfig()
        config.enableReadReceipt = nil
        config.enableRealtimeVoiceToText = nil
        config.realtimeVoiceToTextLanguage = nil
        config.enableVoiceprintDenoise = nil
        config.isShowAudioCall = nil
        config.isShowVideoCall = nil
        config.enableSendRecordedVoice = true
        let enableReadReceipt = config.enableReadReceipt ?? AppBuilderConfig.shared.enableReadReceipt
        config.actionCustomizer = { editor in
            editor.add(CustomLinkMessageManager.makeMenuAction(conversationID: conversationID, enableReadReceipt: enableReadReceipt))
            editor.replace(MessageInputDefaultActionIDs.videoCall) { action in
                DemoCallMenuBadge.addUnreadBadgeIfNeeded(to: action, sdkAppID: sdkAppID)
            }
            editor.replace(MessageInputDefaultActionIDs.audioCall) { action in
                DemoCallMenuBadge.addUnreadBadgeIfNeeded(to: action, sdkAppID: sdkAppID)
            }
        }
        return config
    }

    internal static func makeContactSettingsConfig() -> C2CChatSettingConfig {
        let config = C2CChatSettingConfig(isShowHeader: nil)
        config.isShowHeader = true
        config.isShowRemark = true
        config.isShowDoNotDisturb = true
        config.isShowPin = true
        config.isShowChatBackground = true
        config.isShowSendMessage = true
        config.isShowVoiceCall = true
        config.isShowVideoCall = true
        config.isShowBlacklist = true
        config.isShowClearHistory = true
        config.isShowDeleteFriend = true
        config.itemCustomizer = nil
        return config
    }

    internal static func makeGroupSettingsConfig() -> GroupChatSettingConfig {
        let config = GroupChatSettingConfig(isShowHeader: nil)
        config.isShowHeader = true
        config.isShowMemberPreview = true
        config.isShowNotice = true
        config.isShowManagement = true
        config.isShowGroupType = true
        config.isShowJoinMethod = true
        config.isShowInviteMethod = true
        config.isShowAlias = true
        config.isShowDoNotDisturb = true
        config.isShowPin = true
        config.isShowChatBackground = true
        config.isShowTransferOwner = true
        config.isShowClearHistory = true
        config.isShowDeleteAndQuit = true
        config.isShowDismiss = true
        config.itemCustomizer = nil
        return config
    }

    internal static func makeAssistantConfig() -> AIAssistantPageConfig {
        var config = AIAssistantPageConfig()
        config.streamingMaxCharactersPerSecond = assistantStreamingCharacterLimit
        config.enableRealtimeVoiceToText = true
        config.userEnableSendRecordedVoice = nil
        config.userEnableChatbotReplyPlaceholder = nil
        config.callConfig = makeAssistantCallConfig()
        return config
    }

    internal static func makeAssistantCallConfig() -> AICallConfig {
        var config = AICallConfig()
        config.userTTSSpeed = nil
        config.userSilenceHoldMs = nil
        config.userThinkingTimeoutMs = nil
        config.userEnableVoiceprintDenoise = nil
        config.userSyncTextWithSpeech = false
        return config
    }
}
