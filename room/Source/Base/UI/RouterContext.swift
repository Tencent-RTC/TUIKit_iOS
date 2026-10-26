//
//  RouterContext.swift
//  TUIRoomKit
//
//  Created on 2025/11/20.
//  Copyright © 2025 Tencent. All rights reserved.
//

import UIKit

/// Router context protocol for navigation and presentation
/// All custom UIViewControllers must conform to this protocol
public protocol RouterContext: AnyObject {
    /// Current navigation controller
    var navigationController: UINavigationController? { get }
    
    /// Push a new view controller onto the navigation stack
    /// - Parameters:
    ///   - viewController: The view controller to push
    ///   - animated: Whether to animate the transition
    func push(_ viewController: UIViewController, animated: Bool)
    
    /// Pop the current view controller from the navigation stack
    /// - Parameter animated: Whether to animate the transition
    /// - Returns: The popped view controller
    @discardableResult
    func pop(animated: Bool) -> UIViewController?
    
    /// Pop to the root view controller
    /// - Parameter animated: Whether to animate the transition
    /// - Returns: An array of popped view controllers
    @discardableResult
    func popToRoot(animated: Bool) -> [UIViewController]?
    
    /// Present a view controller modally
    /// - Parameters:
    ///   - viewController: The view controller to present
    ///   - animated: Whether to animate the presentation
    ///   - completion: Optional completion handler
    func present(_ viewController: UIViewController, animated: Bool, completion: (() -> Void)?)
    
    /// Dismiss the presented view controller
    /// - Parameters:
    ///   - animated: Whether to animate the dismissal
    ///   - completion: Optional completion handler
    func dismiss(animated: Bool, completion: (() -> Void)?)
}

// MARK: - Default Implementation for UIViewController

extension RouterContext where Self: UIViewController {
    public func push(_ viewController: UIViewController, animated: Bool = true) {
        navigationController?.pushViewController(viewController, animated: animated)
    }
    
    @discardableResult
    public func pop(animated: Bool = true) -> UIViewController? {
        return navigationController?.popViewController(animated: animated)
    }
    
    @discardableResult
    public func popToRoot(animated: Bool = true) -> [UIViewController]? {
        return navigationController?.popToRootViewController(animated: animated)
    }
    
    public func present(_ viewController: UIViewController, animated: Bool = true, completion: (() -> Void)? = nil) {
        present(viewController, animated: animated, completion: completion)
    }
    
    public func dismiss(animated: Bool = true, completion: (() -> Void)? = nil) {
        dismiss(animated: animated, completion: completion)
    }
}
