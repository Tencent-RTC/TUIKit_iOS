//
//  UIView+makeToast.swift
//  Pods
//
//  Created by ssc on 2025/10/14.
//

import UIKit
import TUICore

public extension UIView {

    func makeToast(message: String, imageName: String = "live_tips",duration: TimeInterval = 2.0) {

        hideAllToasts()
        
        let style = TUICSToastStyle(defaultStyle: ())
        style?.imageSize = CGSize(width: 20, height: 20)
        style?.imageContentMode = .center
        style?.backgroundColor = .bgEntrycardColor
        style?.messageColor = .white.withAlphaComponent(0.9)
        style?.messageFont = .customFont(ofSize: 14, weight: .medium)

        let info: [String: Any] = ["message": message,"image": internalImage(imageName) as Any]
        makeToastParam(info, duration: duration, position: TUICSToastPositionCenter, style: style, completion: nil)
    }

}
