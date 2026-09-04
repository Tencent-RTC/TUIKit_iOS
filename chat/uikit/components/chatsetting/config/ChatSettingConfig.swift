import UIKit

// MARK: - C2C Chat Setting Config

public protocol C2CChatSettingConfigProtocol {
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

public extension C2CChatSettingConfigProtocol {
    var itemCustomizer: C2CChatSettingItemCustomizer? { nil }
}

public final class C2CChatSettingConfig: C2CChatSettingConfigProtocol {
    public var isShowHeader: Bool
    public var isShowRemark: Bool
    public var isShowDoNotDisturb: Bool
    public var isShowPin: Bool
    public var isShowChatBackground: Bool
    public var isShowBlacklist: Bool
    public var isShowSendMessage: Bool
    public var isShowVoiceCall: Bool
    public var isShowVideoCall: Bool
    public var isShowClearHistory: Bool
    public var isShowDeleteFriend: Bool
    public var itemCustomizer: C2CChatSettingItemCustomizer?

    public init(
        isShowHeader: Bool = true,
        isShowRemark: Bool = true,
        isShowDoNotDisturb: Bool = true,
        isShowPin: Bool = true,
        isShowChatBackground: Bool = true,
        isShowBlacklist: Bool = true,
        isShowSendMessage: Bool = true,
        isShowVoiceCall: Bool = true,
        isShowVideoCall: Bool = true,
        isShowClearHistory: Bool = true,
        isShowDeleteFriend: Bool = true,
        itemCustomizer: C2CChatSettingItemCustomizer? = nil
    ) {
        self.isShowHeader = isShowHeader
        self.isShowRemark = isShowRemark
        self.isShowDoNotDisturb = isShowDoNotDisturb
        self.isShowPin = isShowPin
        self.isShowChatBackground = isShowChatBackground
        self.isShowBlacklist = isShowBlacklist
        self.isShowSendMessage = isShowSendMessage
        self.isShowVoiceCall = isShowVoiceCall
        self.isShowVideoCall = isShowVideoCall
        self.isShowClearHistory = isShowClearHistory
        self.isShowDeleteFriend = isShowDeleteFriend
        self.itemCustomizer = itemCustomizer
    }
}

// MARK: - Group Chat Setting Config

public protocol GroupChatSettingConfigProtocol {
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

public extension GroupChatSettingConfigProtocol {
    var itemCustomizer: GroupChatSettingItemCustomizer? { nil }
}

public final class GroupChatSettingConfig: GroupChatSettingConfigProtocol {
    public var isShowHeader: Bool
    public var isShowMemberPreview: Bool
    public var isShowNotice: Bool
    public var isShowManagement: Bool
    public var isShowGroupType: Bool
    public var isShowJoinMethod: Bool
    public var isShowInviteMethod: Bool
    public var isShowAlias: Bool
    public var isShowDoNotDisturb: Bool
    public var isShowPin: Bool
    public var isShowChatBackground: Bool
    public var isShowTransferOwner: Bool
    public var isShowClearHistory: Bool
    public var isShowDeleteAndQuit: Bool
    public var isShowDismiss: Bool
    public var itemCustomizer: GroupChatSettingItemCustomizer?

    public init(
        isShowHeader: Bool = true,
        isShowMemberPreview: Bool = true,
        isShowNotice: Bool = true,
        isShowManagement: Bool = true,
        isShowGroupType: Bool = true,
        isShowJoinMethod: Bool = true,
        isShowInviteMethod: Bool = true,
        isShowAlias: Bool = true,
        isShowDoNotDisturb: Bool = true,
        isShowPin: Bool = true,
        isShowChatBackground: Bool = true,
        isShowTransferOwner: Bool = true,
        isShowClearHistory: Bool = true,
        isShowDeleteAndQuit: Bool = true,
        isShowDismiss: Bool = true,
        itemCustomizer: GroupChatSettingItemCustomizer? = nil
    ) {
        self.isShowHeader = isShowHeader
        self.isShowMemberPreview = isShowMemberPreview
        self.isShowNotice = isShowNotice
        self.isShowManagement = isShowManagement
        self.isShowGroupType = isShowGroupType
        self.isShowJoinMethod = isShowJoinMethod
        self.isShowInviteMethod = isShowInviteMethod
        self.isShowAlias = isShowAlias
        self.isShowDoNotDisturb = isShowDoNotDisturb
        self.isShowPin = isShowPin
        self.isShowChatBackground = isShowChatBackground
        self.isShowTransferOwner = isShowTransferOwner
        self.isShowClearHistory = isShowClearHistory
        self.isShowDeleteAndQuit = isShowDeleteAndQuit
        self.isShowDismiss = isShowDismiss
        self.itemCustomizer = itemCustomizer
    }
}

// MARK: - Item Customizer

public enum C2CChatSettingSection {
    case header
    case remark
    case switches
    case background
    case blacklist
    case actions
    case end
}

public enum GroupChatSettingSection {
    case header
    case memberPreview
    case settings
    case alias
    case switches
    case background
    case actions
    case end
}

public final class ChatSettingItemEditor<Section> {
    private(set) var customRows: [(section: Section, row: UIView)] = []

    public init() {}

    public func addCustomRow(_ view: UIView, after section: Section) {
        customRows.append((section, view))
    }
}

public typealias C2CChatSettingItemCustomizer = (ChatSettingItemEditor<C2CChatSettingSection>) -> Void

public typealias GroupChatSettingItemCustomizer = (ChatSettingItemEditor<GroupChatSettingSection>) -> Void
