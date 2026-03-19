//
//  UIView+Extension.swift
//
//  Created by jack on 2021/12/15.
//  Copyright © 2022 Tencent. All rights reserved.

import UIKit

extension UIView {
    public func getCurrentViewController() -> UIViewController? {
        var responder: UIResponder? = self
        while let nextResponder = responder?.next {
            if let viewController = nextResponder as? UIViewController {
                return viewController
            }
            responder = nextResponder
        }
        return nil
    }
    
    public func safeRemoveFromSuperview() {
        assert(Thread.isMainThread, "Should call in main thread")
        guard let _ = superview else { return }
        removeFromSuperview()
    }
    
    // MARK: - Rounded Corners
    public func roundedRect(rect: CGRect, byRoundingCorners: UIRectCorner, cornerRadii: CGSize) {
        let maskPath = UIBezierPath(roundedRect: rect, byRoundingCorners: byRoundingCorners, cornerRadii: cornerRadii)
        let maskLayer = CAShapeLayer()
        maskLayer.frame = bounds
        maskLayer.path = maskPath.cgPath
        layer.mask = maskLayer
    }

    public func roundedCircle(rect: CGRect) {
        roundedRect(rect: rect, byRoundingCorners: .allCorners, cornerRadii: CGSize(width: bounds.size.width / 2, height: bounds.size.height / 2))
    }
    
    public func clearRoundedCorners() {
        layer.mask = nil
    }
    
    // MARK: - Gradient Layer
    private struct AssociatedKeys {
        static var gradientLayerKey = "gradientLayerKey"
    }

    var gradientLayer: CAGradientLayer? {
        get {
            return objc_getAssociatedObject(self, &AssociatedKeys.gradientLayerKey) as? CAGradientLayer
        }
        set {
            objc_setAssociatedObject(self, &AssociatedKeys.gradientLayerKey, newValue, objc_AssociationPolicy.OBJC_ASSOCIATION_RETAIN_NONATOMIC)
        }
    }

    func removeGradientLayer() {
        guard let glayer = gradientLayer else {
            return
        }
        glayer.removeFromSuperlayer()
        gradientLayer = nil
    }

    @discardableResult
    public func gradient(colors: [UIColor], bounds: CGRect = .zero, isVertical: Bool = false) -> CAGradientLayer {
        let gradientLayer = self.gradientLayer ?? CAGradientLayer()
        if isVertical {
            gradientLayer.startPoint = CGPoint(x: 0.5, y: 0.0)
            gradientLayer.endPoint = CGPoint(x: 0.5, y: 1.0)
        } else {
            gradientLayer.startPoint = CGPoint(x: 0.0, y: 0.5)
            gradientLayer.endPoint = CGPoint(x: 1.0, y: 0.5)
        }
        self.gradientLayer = gradientLayer
        gradientLayer.colors = colors.map { $0.cgColor }
        gradientLayer.frame = bounds == .zero ? self.bounds : bounds
        layer.insertSublayer(gradientLayer, at: 0)
        return gradientLayer
    }
}
