import Foundation

/// Localized strings for CallKitAccess (zh-Hans primary, en secondary).
/// Keys follow the design demo's copy in `general/index.html` + `scripts/i18n.js`.
enum CallAccessText {

    // Login
    static let loginTitle = NSLocalizedString("callkit_access.login.title", comment: "登录页标题与按钮")
    static let loginUserID = NSLocalizedString("callkit_access.login.user_id", comment: "")
    static let loginUserIDPlaceholder = NSLocalizedString("callkit_access.login.user_id_placeholder", comment: "")
    static let loginUserIDRequired = NSLocalizedString("callkit_access.login.user_id_required", comment: "")
    static let loginLoggedIn = NSLocalizedString("callkit_access.login.logged_in", comment: "")
    static let loginMissingConfig = NSLocalizedString("callkit_access.login.missing_config", comment: "")
    static let loginFailed = NSLocalizedString("callkit_access.login.failed", comment: "")
    static let loginKickedOffline = NSLocalizedString("callkit_access.login.kicked_offline", comment: "")
    static let loginExpired = NSLocalizedString("callkit_access.login.expired", comment: "")
    static let loginStateChanged = NSLocalizedString("callkit_access.login.state_changed", comment: "")

    // G1 entry
    static let entryTitle = NSLocalizedString("callkit_access.entry.title", comment: "通话")
    static let entryUserID = NSLocalizedString("callkit_access.entry.user_id", comment: "用户 ID")
    static let entryUserIDPlaceholder = NSLocalizedString("callkit_access.entry.user_id_placeholder", comment: "")
    static let entryIDPlaceholderFull = NSLocalizedString("callkit_access.entry.user_id_placeholder_full", comment: "")
    static let entryAdd = NSLocalizedString("callkit_access.entry.add", comment: "添加")
    static let entryRemainPrefix = NSLocalizedString("callkit_access.entry.remain_prefix", comment: "")
    static let entryRemainSuffix = NSLocalizedString("callkit_access.entry.remain_suffix", comment: "")
    static let entryPickFromFriends = NSLocalizedString("callkit_access.entry.pick_from_friends", comment: "")
    static let entryFriends = NSLocalizedString("callkit_access.entry.friends", comment: "好友")
    static let entryMediaType = NSLocalizedString("callkit_access.entry.media_type", comment: "通话类型")
    static let entryVideoCall = NSLocalizedString("callkit_access.entry.video_call", comment: "")
    static let entryAudioCall = NSLocalizedString("callkit_access.entry.audio_call", comment: "")
    static let entryCaption = NSLocalizedString("callkit_access.entry.caption", comment: "实时字幕")
    static let entryResolution = NSLocalizedString("callkit_access.entry.resolution", comment: "视频清晰度")
    static let entryMoreSettings = NSLocalizedString("callkit_access.entry.more_settings", comment: "更多设置")
    static let entryStartCall = NSLocalizedString("callkit_access.entry.start_call", comment: "开始通话")
    static let resolutionSD = NSLocalizedString("callkit_access.resolution.sd", comment: "标清")
    static let resolutionHD = NSLocalizedString("callkit_access.resolution.hd", comment: "高清")
    static let resolutionFHD = NSLocalizedString("callkit_access.resolution.fhd", comment: "超高清")
    static let resolution2K = NSLocalizedString("callkit_access.resolution.2k", comment: "尊享画质")

    // Captions
    static let captionSwitchCopy = NSLocalizedString("callkit_access.caption.switch_copy", comment: "")

    // G2 settings
    static let settingsTitle = NSLocalizedString("callkit_access.settings.title", comment: "更多设置")
    static let settingsProfile = NSLocalizedString("callkit_access.settings.profile", comment: "个人资料")
    static let settingsAvatar = NSLocalizedString("callkit_access.settings.avatar", comment: "头像")
    static let settingsNickname = NSLocalizedString("callkit_access.settings.nickname", comment: "昵称")
    static let settingsNicknameHint = NSLocalizedString("callkit_access.settings.nickname_hint", comment: "")
    static let settingsIncoming = NSLocalizedString("callkit_access.settings.incoming", comment: "来电")
    static let settingsRingtone = NSLocalizedString("callkit_access.settings.ringtone", comment: "铃声")
    static let settingsRingtoneDefault = NSLocalizedString("callkit_access.settings.ringtone_default", comment: "系统默认")
    static let settingsMuteMode = NSLocalizedString("callkit_access.settings.mute_mode", comment: "静音模式")
    static let settingsBanner = NSLocalizedString("callkit_access.settings.banner", comment: "横幅显示来电")
    static let settingsBannerCopy = NSLocalizedString("callkit_access.settings.banner_copy", comment: "")
    static let settingsCallUI = NSLocalizedString("callkit_access.settings.call_ui", comment: "通话界面")
    static let settingsFloatButton = NSLocalizedString("callkit_access.settings.float_button", comment: "显示悬浮窗按钮")
    static let settingsAdvanced = NSLocalizedString("callkit_access.settings.advanced", comment: "高级设置")
    static let settingsRoomID = NSLocalizedString("callkit_access.settings.room_id", comment: "指定房间号")
    static let settingsRoomIDSub = NSLocalizedString("callkit_access.settings.room_id_sub", comment: "strRoomId / intRoomId")
    static let settingsRoomIDHint = NSLocalizedString("callkit_access.settings.room_id_hint", comment: "")
    static let settingsRoomAutoAssign = NSLocalizedString("callkit_access.settings.room_auto_assign", comment: "自动分配")
    static let settingsTimeout = NSLocalizedString("callkit_access.settings.timeout", comment: "呼叫超时时长（秒）")
    static let settingsTimeoutSub = NSLocalizedString("callkit_access.settings.timeout_sub", comment: "timeout")
    static let settingsTimeoutHint = NSLocalizedString("callkit_access.settings.timeout_hint", comment: "")
    static let settingsExtendedInfo = NSLocalizedString("callkit_access.settings.extended_info", comment: "自定义信息")
    static let settingsExtendedInfoSub = NSLocalizedString("callkit_access.settings.extended_info_sub", comment: "extendedInfo")
    static let settingsExtendedInfoHint = NSLocalizedString("callkit_access.settings.extended_info_hint", comment: "")
    static let settingsExtendedInfoEmpty = NSLocalizedString("callkit_access.settings.extended_info_empty", comment: "未设置")
    static let settingsExtendedInfoPlaceholder = NSLocalizedString("callkit_access.settings.extended_info_placeholder", comment: "可留空")
    static let settingsBlurBackground = NSLocalizedString("callkit_access.settings.blur_background", comment: "模糊背景")
    static let settingsProBeauty = NSLocalizedString("callkit_access.settings.pro_beauty", comment: "高级美颜")
    static let settingsAvatarSetToast = NSLocalizedString("callkit_access.settings.avatar_set_toast", comment: "头像已更新")
    static let settingsRingtoneSetToast = NSLocalizedString("callkit_access.settings.ringtone_set_toast", comment: "铃声已设为：%@")

    // Sheets / friend picker
    static let sheetConfirm = NSLocalizedString("callkit_access.sheet.confirm", comment: "确定")
    static let sheetCancel = NSLocalizedString("callkit_access.sheet.cancel", comment: "取消")
    static let friendPickerTitle = NSLocalizedString("callkit_access.friend_picker.title", comment: "选择通话对象")
    static let friendPickerEmpty = NSLocalizedString("callkit_access.friend_picker.empty", comment: "还没有好友")
    static let avatarPickerTitle = NSLocalizedString("callkit_access.avatar_picker.title", comment: "选择头像")
    static let ringtonePickerTitle = NSLocalizedString("callkit_access.ringtone_picker.title", comment: "选择铃声")

    // Call flow
    static let callTooMany = NSLocalizedString("callkit_access.call.too_many", comment: "仅支持 9 人通话")
    static let callTooManyNoDial = NSLocalizedString("callkit_access.call.too_many_no_dial", comment: "")
    static let callEmptyCallee = NSLocalizedString("callkit_access.call.empty_callee", comment: "")
    static let callSelfOnly = NSLocalizedString("callkit_access.call.self_only", comment: "")
    static let callCalling = NSLocalizedString("callkit_access.call.calling", comment: "正在呼叫…")
    static let callFailed = NSLocalizedString("callkit_access.call.failed", comment: "")
    static let quality2KUnsupported = NSLocalizedString("callkit_access.call.2k_unsupported", comment: "")
}
