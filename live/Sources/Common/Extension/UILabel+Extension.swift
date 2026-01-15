//
//  UILabel+Extension.swift
//  TUILiveKit
//
//  Created by gg on 2026/1/12.
//

import UIKit

extension UILabel {
    private static let swizzleOnce: Void = {
        // Swizzle init(frame:)
        if let originalMethod = class_getInstanceMethod(UILabel.self, #selector(UILabel.init(frame:))),
           let swizzledMethod = class_getInstanceMethod(UILabel.self, #selector(UILabel.swizzled_init(frame:)))
        {
            method_exchangeImplementations(originalMethod, swizzledMethod)
        }
        
        // Swizzle init(coder:)
        if let originalMethod = class_getInstanceMethod(UILabel.self, #selector(UILabel.init(coder:))),
           let swizzledMethod = class_getInstanceMethod(UILabel.self, #selector(UILabel.swizzled_init(coder:)))
        {
            method_exchangeImplementations(originalMethod, swizzledMethod)
        }
    }()
    
    static func enableRTLAlignment() {
        _ = swizzleOnce
    }
    
    @objc private func swizzled_init(frame: CGRect) -> UILabel {
        let label = swizzled_init(frame: frame)
        label.applyRTLAlignmentIfNeeded()
        return label
    }
    
    @objc private func swizzled_init(coder: NSCoder) -> UILabel? {
        let label = swizzled_init(coder: coder)
        label?.applyRTLAlignmentIfNeeded()
        return label
    }
    
    private func applyRTLAlignmentIfNeeded() {
        textAlignment = .natural
    }
}
