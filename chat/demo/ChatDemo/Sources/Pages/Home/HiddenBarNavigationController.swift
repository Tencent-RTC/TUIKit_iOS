import TUIChatKit
import UIKit

internal final class HiddenBarNavigationController: UINavigationController, UIGestureRecognizerDelegate, UINavigationControllerDelegate {
    internal override func viewDidLoad() {
        super.viewDidLoad()
        setNavigationBarHidden(true, animated: false)
        interactivePopGestureRecognizer?.delegate = self
        delegate = self
    }

    internal func gestureRecognizerShouldBegin(_ gestureRecognizer: UIGestureRecognizer) -> Bool {
        viewControllers.count > 1
    }

    internal func navigationController(_ navigationController: UINavigationController, willShow viewController: UIViewController, animated: Bool) {
        setNavigationBarHidden(!(viewController is SystemNavigationBarPage), animated: animated)
    }
}
