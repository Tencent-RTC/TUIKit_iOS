//
//  CallConstants.swift
//  Pods
//
//  Created by yukiwwwang on 2025/9/4.
//

class CallConstants{
    static let screenSize = UIScreen.main.bounds.size
    static let screenWidth = UIScreen.main.bounds.size.width
    static let screenHeight = UIScreen.main.bounds.size.height
    static let MAX_PARTICIPANT = 9
    
    static let statusBar_Height: CGFloat = {
        var statusBarHeight: CGFloat = 0
        if #available(iOS 13.0, *) {
            statusBarHeight = UIApplication.shared.windows.first?.windowScene?.statusBarManager?.statusBarFrame.height ?? 0
        } else {
            statusBarHeight = UIApplication.shared.statusBarFrame.height
        }
        return statusBarHeight
    }()
    
    static let Bottom_SafeHeight = {var bottomSafeHeight: CGFloat = 0
        if #available(iOS 11.0, *) {
            let window = UIApplication.shared.windows.first
            bottomSafeHeight = window?.safeAreaInsets.bottom ?? 0
        }
        return bottomSafeHeight
    }()
    
    static let kControlBtnSize = CGSize(width: 100.scale375Width(), height: 94.scale375Width())
    static let kBtnLargeSize = CGSize(width: 64.scale375Width(), height: 64.scale375Width())
    static let kBtnSmallSize = CGSize(width: 60.scale375Width(), height: 60.scale375Width())
    static let Color_White = UIColor(hex: "#FFFFFF")
    static let kCallKitSingleSmallStreamViewWidth = 100.0
    static let horizontalOffset = 110.scale375Width()
    
    static let groupFunctionAnimationDuration = 0.3
    static let groupFunctionBaseControlBtnHeight = 60.scale375Width() + 5.scale375Height() + 20
    static let groupFunctionBottomHeight = Bottom_SafeHeight > 1 ? Bottom_SafeHeight : 8
    static let groupFunctionViewHeight = 220.scale375Height()
    static let groupSmallFunctionViewHeight = 116.scale375Height()
}

