//
//  AppUtils.swift
//  App-UIKit
//
//  Created by yukiwwwang on 2025/8/13.
//

import UIKit

// MARK: - 屏幕适配方法
public func convertPixel(w:CGFloat) -> CGFloat {
    return w / 375.0 * screenWidth
}

public func convertPixel(h:CGFloat) -> CGFloat {
    return h / 812.0 * screenHeight
}

public func statusBarHeight() -> CGFloat {
    var statusBarHeight: CGFloat = 0
    if #available(iOS 13.0, *) {
        let scene = UIApplication.shared.connectedScenes.first
        guard let windowScene = scene as? UIWindowScene else { return 0 }
        guard let statusBarManager = windowScene.statusBarManager else { return 0 }
        statusBarHeight = statusBarManager.statusBarFrame.height
    } else {
        statusBarHeight = UIApplication.shared.statusBarFrame.height
    }
    return statusBarHeight
}

public func navigationBarHeight() -> CGFloat {
    return 44.0
}

public func navigationFullHeight() -> CGFloat {
    return statusBarHeight() + navigationBarHeight()
}
