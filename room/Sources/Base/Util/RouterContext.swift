import UIKit

public protocol RouterContext: AnyObject {
    var navigationController: UINavigationController? { get }
    func push(_ viewController: UIViewController, animated: Bool)
    @discardableResult func pop(animated: Bool) -> UIViewController?
    @discardableResult func popToRoot(animated: Bool) -> [UIViewController]?
    func present(_ viewController: UIViewController, animated: Bool, completion: (() -> Void)?)
    func dismiss(animated: Bool, completion: (() -> Void)?)
}

public extension RouterContext where Self: UIViewController {
    func push(_ viewController: UIViewController, animated: Bool) {
        navigationController?.pushViewController(viewController, animated: animated)
    }

    @discardableResult
    func pop(animated: Bool) -> UIViewController? {
        navigationController?.popViewController(animated: animated)
    }

    @discardableResult
    func popToRoot(animated: Bool) -> [UIViewController]? {
        navigationController?.popToRootViewController(animated: animated)
    }
}
