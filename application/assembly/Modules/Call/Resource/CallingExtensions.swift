//
//  CallingExtensions.swift
//  main
//

import UIKit

// MARK: - UIView + roundedRect(_:withCornerRatio:)

extension UIView {
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
