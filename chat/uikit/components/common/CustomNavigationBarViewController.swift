import UIKit
import SnapKit

public class CustomNavigationBarViewController: UIViewController {
    private lazy var implementation: CustomNavigationBarViewControllerImpl = {
        let implementation = CustomNavigationBarViewControllerImpl()
        implementation.owner = self
        return implementation
    }()

    var onBack: (() -> Void)? {
        get { implementation.onBack }
        set { implementation.onBack = newValue }
    }

    var contentTopItem: ConstraintItem {
        return implementation.contentTopItem
    }

    public override func viewDidLoad() {
        super.viewDidLoad()
        implementation.viewDidLoad()
    }

    func setNavTitle(_ text: String) {
        implementation.setNavTitle(text)
    }

    func setNavBackHidden(_ hidden: Bool) {
        implementation.setNavBackHidden(hidden)
    }

    func setNavLeadingView(_ view: UIView) {
        implementation.setNavLeadingView(view)
    }

    func setNavTrailingView(_ view: UIView) {
        implementation.setNavTrailingView(view)
    }

    func pushOrPresent(_ controller: UIViewController) {
        implementation.pushOrPresent(controller)
    }
}
