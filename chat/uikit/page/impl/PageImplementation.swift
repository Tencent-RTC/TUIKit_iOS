import UIKit

internal class PageImplementation: NSObject {
    internal weak var owner: UIViewController?

    internal var view: UIView {
        guard let owner else { preconditionFailure("Page owner is unavailable") }
        return owner.view
    }

    internal var isViewLoaded: Bool {
        owner?.isViewLoaded ?? false
    }

    internal var navigationController: UINavigationController? {
        owner?.navigationController
    }

    internal var isBeingDismissed: Bool {
        owner?.isBeingDismissed ?? false
    }

    internal func present(_ controller: UIViewController, animated: Bool, completion: (() -> Void)? = nil) {
        owner?.present(controller, animated: animated, completion: completion)
    }

    internal func dismiss(animated: Bool) {
        owner?.dismiss(animated: animated)
    }
}
