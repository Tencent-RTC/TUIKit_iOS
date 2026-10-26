extension C2CChatSettingConfig {
    public convenience init(
        isShowHeader: Bool? = nil,
        isShowRemark: Bool? = nil,
        isShowDoNotDisturb: Bool? = nil,
        isShowPin: Bool? = nil,
        isShowChatBackground: Bool? = nil,
        isShowBlacklist: Bool? = nil,
        isShowSendMessage: Bool? = nil,
        isShowVoiceCall: Bool? = nil,
        isShowVideoCall: Bool? = nil,
        isShowClearHistory: Bool? = nil,
        isShowDeleteFriend: Bool? = nil,
        itemCustomizer: C2CChatSettingItemCustomizer? = nil
    ) {
        self.init()
        self.userIsShowHeader = isShowHeader
        self.userIsShowRemark = isShowRemark
        self.userIsShowDoNotDisturb = isShowDoNotDisturb
        self.userIsShowPin = isShowPin
        self.userIsShowChatBackground = isShowChatBackground
        self.userIsShowBlacklist = isShowBlacklist
        self.userIsShowSendMessage = isShowSendMessage
        self.userIsShowVoiceCall = isShowVoiceCall
        self.userIsShowVideoCall = isShowVideoCall
        self.userIsShowClearHistory = isShowClearHistory
        self.userIsShowDeleteFriend = isShowDeleteFriend
        self.userItemCustomizer = itemCustomizer
    }

    public var isShowHeader: Bool {
        get { userIsShowHeader ?? true }
        set { userIsShowHeader = newValue }
    }

    public var isShowRemark: Bool {
        get { userIsShowRemark ?? true }
        set { userIsShowRemark = newValue }
    }

    public var isShowDoNotDisturb: Bool {
        get { userIsShowDoNotDisturb ?? true }
        set { userIsShowDoNotDisturb = newValue }
    }

    public var isShowPin: Bool {
        get { userIsShowPin ?? true }
        set { userIsShowPin = newValue }
    }

    public var isShowChatBackground: Bool {
        get { userIsShowChatBackground ?? true }
        set { userIsShowChatBackground = newValue }
    }

    public var isShowBlacklist: Bool {
        get { userIsShowBlacklist ?? true }
        set { userIsShowBlacklist = newValue }
    }

    public var isShowSendMessage: Bool {
        get { userIsShowSendMessage ?? true }
        set { userIsShowSendMessage = newValue }
    }

    public var isShowVoiceCall: Bool {
        get { userIsShowVoiceCall ?? true }
        set { userIsShowVoiceCall = newValue }
    }

    public var isShowVideoCall: Bool {
        get { userIsShowVideoCall ?? true }
        set { userIsShowVideoCall = newValue }
    }

    public var isShowClearHistory: Bool {
        get { userIsShowClearHistory ?? true }
        set { userIsShowClearHistory = newValue }
    }

    public var isShowDeleteFriend: Bool {
        get { userIsShowDeleteFriend ?? true }
        set { userIsShowDeleteFriend = newValue }
    }

    public var itemCustomizer: C2CChatSettingItemCustomizer? {
        get { userItemCustomizer }
        set { userItemCustomizer = newValue }
    }
}

extension GroupChatSettingConfig {
    public convenience init(
        isShowHeader: Bool? = nil,
        isShowMemberPreview: Bool? = nil,
        isShowNotice: Bool? = nil,
        isShowManagement: Bool? = nil,
        isShowGroupType: Bool? = nil,
        isShowJoinMethod: Bool? = nil,
        isShowInviteMethod: Bool? = nil,
        isShowAlias: Bool? = nil,
        isShowDoNotDisturb: Bool? = nil,
        isShowPin: Bool? = nil,
        isShowChatBackground: Bool? = nil,
        isShowTransferOwner: Bool? = nil,
        isShowClearHistory: Bool? = nil,
        isShowDeleteAndQuit: Bool? = nil,
        isShowDismiss: Bool? = nil,
        itemCustomizer: GroupChatSettingItemCustomizer? = nil
    ) {
        self.init()
        self.userIsShowHeader = isShowHeader
        self.userIsShowMemberPreview = isShowMemberPreview
        self.userIsShowNotice = isShowNotice
        self.userIsShowManagement = isShowManagement
        self.userIsShowGroupType = isShowGroupType
        self.userIsShowJoinMethod = isShowJoinMethod
        self.userIsShowInviteMethod = isShowInviteMethod
        self.userIsShowAlias = isShowAlias
        self.userIsShowDoNotDisturb = isShowDoNotDisturb
        self.userIsShowPin = isShowPin
        self.userIsShowChatBackground = isShowChatBackground
        self.userIsShowTransferOwner = isShowTransferOwner
        self.userIsShowClearHistory = isShowClearHistory
        self.userIsShowDeleteAndQuit = isShowDeleteAndQuit
        self.userIsShowDismiss = isShowDismiss
        self.userItemCustomizer = itemCustomizer
    }

    public var isShowHeader: Bool {
        get { userIsShowHeader ?? true }
        set { userIsShowHeader = newValue }
    }

    public var isShowMemberPreview: Bool {
        get { userIsShowMemberPreview ?? true }
        set { userIsShowMemberPreview = newValue }
    }

    public var isShowNotice: Bool {
        get { userIsShowNotice ?? true }
        set { userIsShowNotice = newValue }
    }

    public var isShowManagement: Bool {
        get { userIsShowManagement ?? true }
        set { userIsShowManagement = newValue }
    }

    public var isShowGroupType: Bool {
        get { userIsShowGroupType ?? true }
        set { userIsShowGroupType = newValue }
    }

    public var isShowJoinMethod: Bool {
        get { userIsShowJoinMethod ?? true }
        set { userIsShowJoinMethod = newValue }
    }

    public var isShowInviteMethod: Bool {
        get { userIsShowInviteMethod ?? true }
        set { userIsShowInviteMethod = newValue }
    }

    public var isShowAlias: Bool {
        get { userIsShowAlias ?? true }
        set { userIsShowAlias = newValue }
    }

    public var isShowDoNotDisturb: Bool {
        get { userIsShowDoNotDisturb ?? true }
        set { userIsShowDoNotDisturb = newValue }
    }

    public var isShowPin: Bool {
        get { userIsShowPin ?? true }
        set { userIsShowPin = newValue }
    }

    public var isShowChatBackground: Bool {
        get { userIsShowChatBackground ?? true }
        set { userIsShowChatBackground = newValue }
    }

    public var isShowTransferOwner: Bool {
        get { userIsShowTransferOwner ?? true }
        set { userIsShowTransferOwner = newValue }
    }

    public var isShowClearHistory: Bool {
        get { userIsShowClearHistory ?? true }
        set { userIsShowClearHistory = newValue }
    }

    public var isShowDeleteAndQuit: Bool {
        get { userIsShowDeleteAndQuit ?? true }
        set { userIsShowDeleteAndQuit = newValue }
    }

    public var isShowDismiss: Bool {
        get { userIsShowDismiss ?? true }
        set { userIsShowDismiss = newValue }
    }

    public var itemCustomizer: GroupChatSettingItemCustomizer? {
        get { userItemCustomizer }
        set { userItemCustomizer = newValue }
    }
}
