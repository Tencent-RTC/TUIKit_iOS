public final class C2CChatSettingConfig {
    // 联系人资料：头像资料区与好友备注。
    public var userIsShowHeader: Bool? = nil
    public var userIsShowRemark: Bool? = nil

    // 会话偏好：免打扰、置顶与聊天背景。
    public var userIsShowDoNotDisturb: Bool? = nil
    public var userIsShowPin: Bool? = nil
    public var userIsShowChatBackground: Bool? = nil

    // 聊天入口：发送消息、语音通话与视频通话。
    public var userIsShowSendMessage: Bool? = nil
    public var userIsShowVoiceCall: Bool? = nil
    public var userIsShowVideoCall: Bool? = nil

    // 联系人与历史管理：黑名单、清空历史与删除好友。
    public var userIsShowBlacklist: Bool? = nil
    public var userIsShowClearHistory: Bool? = nil
    public var userIsShowDeleteFriend: Bool? = nil

    // 扩展：设置页面自定义行。
    public var userItemCustomizer: C2CChatSettingItemCustomizer? = nil
}

public final class GroupChatSettingConfig {
    // 群资料：头像资料区、成员预览与群公告。
    public var userIsShowHeader: Bool? = nil
    public var userIsShowMemberPreview: Bool? = nil
    public var userIsShowNotice: Bool? = nil

    // 群管理：管理入口、群类型、加入方式与邀请方式。
    public var userIsShowManagement: Bool? = nil
    public var userIsShowGroupType: Bool? = nil
    public var userIsShowJoinMethod: Bool? = nil
    public var userIsShowInviteMethod: Bool? = nil

    // 个人与会话偏好：群内昵称、免打扰、置顶与聊天背景。
    public var userIsShowAlias: Bool? = nil
    public var userIsShowDoNotDisturb: Bool? = nil
    public var userIsShowPin: Bool? = nil
    public var userIsShowChatBackground: Bool? = nil

    // 群与历史操作：转让群主、清空历史、退群与解散群。
    public var userIsShowTransferOwner: Bool? = nil
    public var userIsShowClearHistory: Bool? = nil
    public var userIsShowDeleteAndQuit: Bool? = nil
    public var userIsShowDismiss: Bool? = nil

    // 扩展：设置页面自定义行。
    public var userItemCustomizer: GroupChatSettingItemCustomizer? = nil
}
