import UIKit

final class ChatSettingItemEditorImpl<Section> {
    private(set) var customRows: [(section: Section, row: UIView)] = []

    func addCustomRow(_ view: UIView, after section: Section) {
        customRows.append((section, view))
    }
}
