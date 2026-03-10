//
//  BaseView.swift
//  TUIRoomKit
//
//  Created on 2025/11/20.
//  Copyright © 2025 Tencent. All rights reserved.
//

import UIKit

/// Base view protocol for custom views
/// All custom views must conform to this protocol
public protocol BaseView: AnyObject {
    /// Router context for triggering navigation (weak reference to avoid retain cycles)
    var routerContext: RouterContext? { get set }
    
    /// Setup subviews hierarchy
    func setupViews()
    
    /// Setup layout constraints
    func setupConstraints()
    
    /// Setup view styles and appearance
    func setupStyles()
    
    /// Setup data bindings and event handlers
    func setupBindings()
}

// MARK: - Default Implementation

extension BaseView {
    func setupViews() {}
    func setupConstraints() {}
    func setupStyles() {}
    func setupBindings() {}
}

public class WindowUtils {
    public static func getCurrentWindow() -> UIWindow? {
        if #available(iOS 13.0, *) {
            return UIApplication.shared.connectedScenes
                .compactMap { $0 as? UIWindowScene }
                .filter { $0.activationState == .foregroundActive }
                .flatMap { $0.windows }
                .first { $0.isKeyWindow }
        }
        return UIApplication.shared.windows.first
    }

    public static func getCurrentWindowViewController() -> UIViewController? {
        var keyWindow: UIWindow?
        for window in UIApplication.shared.windows {
            if window.isMember(of: UIWindow.self), window.isKeyWindow {
                keyWindow = window
                break
            }
        }
        guard let rootController = keyWindow?.rootViewController else {
            return nil
        }
        func findCurrentController(from vc: UIViewController?) -> UIViewController? {
            if let nav = vc as? UINavigationController {
                return findCurrentController(from: nav.topViewController)
            } else if let tabBar = vc as? UITabBarController {
                return findCurrentController(from: tabBar.selectedViewController)
            } else if let presented = vc?.presentedViewController {
                return findCurrentController(from: presented)
            }
            return vc
        }
        let viewController = findCurrentController(from: rootController)
        return viewController
    }
    
    public static var bottomSafeHeight: CGFloat {
        getCurrentWindow()?.safeAreaInsets.bottom ?? 0
    }
    
    public static var topSafeHeight: CGFloat {
        getCurrentWindow()?.safeAreaInsets.top ?? 0
    }
    
    public static var isPortrait: Bool {
        if #available(iOS 13.0, *) {
            guard let isPortrait = UIApplication.shared.windows.first?.windowScene?.interfaceOrientation.isPortrait as? Bool
            else { return UIDevice.current.orientation.isPortrait }
            return isPortrait
        } else {
            return UIDevice.current.orientation.isPortrait
        }
    }
}
