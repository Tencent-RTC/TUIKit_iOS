//
//  CallingExtensions.swift
//  main
//
//  Call 模块专用扩展
//  addTapGesture / getCurrentViewController 等已迁移到公共 Extension/UIView+Extension.swift
//

import UIKit

// MARK: - UIView + roundedRect(_:withCornerRatio:)

extension UIView {
    /// 便捷圆角方法（Call 模块专用简化签名）
    func roundedRect(_ corners: UIRectCorner, withCornerRatio ratio: CGFloat) {
        let path = UIBezierPath(roundedRect: bounds,
                                byRoundingCorners: corners,
                                cornerRadii: CGSize(width: ratio, height: ratio))
        let mask = CAShapeLayer()
        mask.frame = bounds
        mask.path = path.cgPath
        layer.mask = mask
    }
}
