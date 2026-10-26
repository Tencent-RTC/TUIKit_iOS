import UIKit

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
    private let implementation = ChatSettingItemEditorImpl<Section>()

    var customRows: [(section: Section, row: UIView)] {
        return implementation.customRows
    }

    public init() {}

    public func addCustomRow(_ view: UIView, after section: Section) {
        implementation.addCustomRow(view, after: section)
    }
}

public typealias C2CChatSettingItemCustomizer = (ChatSettingItemEditor<C2CChatSettingSection>) -> Void

public typealias GroupChatSettingItemCustomizer = (ChatSettingItemEditor<GroupChatSettingSection>) -> Void
