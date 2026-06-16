//
//  CGFloat+Extension.swift
//  RTCube
//
//  以 375x812 设计稿为基准的屏幕适配扩展
//

import UIKit

let screenWidth = UIScreen.main.bounds.width
let screenHeight = UIScreen.main.bounds.height

extension CGFloat {
    /// 以 375 宽度为基准做等比缩放
    func scale375() -> CGFloat {
        return self * UIScreen.main.bounds.width / 375.0
    }
    /// 同 scale375()，用于宽度方向
    func scale375Width() -> CGFloat {
        return scale375()
    }
    /// 以 812 高度为基准做等比缩放
    func scale375Height() -> CGFloat {
        return self * UIScreen.main.bounds.height / 812.0
    }
}
