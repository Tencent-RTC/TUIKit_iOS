import UIKit

// MARK: - C2C Chat Setting Config

protocol C2CChatSettingConfigProtocol {
    var isShowHeader: Bool { get }
    var isShowRemark: Bool { get }
    var isShowDoNotDisturb: Bool { get }
    var isShowPin: Bool { get }
    var isShowChatBackground: Bool { get }
    var isShowBlacklist: Bool { get }
    var isShowSendMessage: Bool { get }
    var isShowVoiceCall: Bool { get }
    var isShowVideoCall: Bool { get }
    var isShowClearHistory: Bool { get }
    var isShowDeleteFriend: Bool { get }
    var itemCustomizer: C2CChatSettingItemCustomizer? { get }
}

extension C2CChatSettingConfigProtocol {
    var itemCustomizer: C2CChatSettingItemCustomizer? { nil }
}

extension C2CChatSettingConfig: C2CChatSettingConfigProtocol {}

// MARK: - Group Chat Setting Config

protocol GroupChatSettingConfigProtocol {
    var isShowHeader: Bool { get }
    var isShowMemberPreview: Bool { get }
    var isShowNotice: Bool { get }
    var isShowManagement: Bool { get }
    var isShowGroupType: Bool { get }
    var isShowJoinMethod: Bool { get }
    var isShowInviteMethod: Bool { get }
    var isShowAlias: Bool { get }
    var isShowDoNotDisturb: Bool { get }
    var isShowPin: Bool { get }
    var isShowChatBackground: Bool { get }
    var isShowTransferOwner: Bool { get }
    var isShowClearHistory: Bool { get }
    var isShowDeleteAndQuit: Bool { get }
    var isShowDismiss: Bool { get }
    var itemCustomizer: GroupChatSettingItemCustomizer? { get }
}

extension GroupChatSettingConfigProtocol {
    var itemCustomizer: GroupChatSettingItemCustomizer? { nil }
}

extension GroupChatSettingConfig: GroupChatSettingConfigProtocol {}

