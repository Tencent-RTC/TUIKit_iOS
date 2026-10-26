import UIKit
import SnapKit

class ChatSettingPageImplementation: PageImplementation {
    var page: CustomNavigationBarViewController {
        guard let page = owner as? CustomNavigationBarViewController else {
            preconditionFailure("Chat setting page owner is unavailable")
        }
        return page
    }

    var contentTopItem: ConstraintItem {
        return page.contentTopItem
    }

    func setNavTitle(_ title: String) {
        page.setNavTitle(title)
    }

    func setNavTrailingView(_ view: UIView) {
        page.setNavTrailingView(view)
    }

    func pushOrPresent(_ controller: UIViewController) {
        page.pushOrPresent(controller)
    }
}
