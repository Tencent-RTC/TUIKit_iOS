//
//  WindowUtils.swift
//  RTCCommon
//
//  Created by krabyu on 2023/10/16.
//

import Foundation
import UIKit

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
