//
//  UITextField+Extension.swift
//  TUILiveKit
//
//  Created by gg on 2026/1/7.
//

import UIKit

extension UITextField {
    private static let swizzleOnce: Void = {
        // Swizzle init(frame:)
        if let originalMethod = class_getInstanceMethod(UITextField.self, #selector(UITextField.init(frame:))),
           let swizzledMethod = class_getInstanceMethod(UITextField.self, #selector(UITextField.swizzled_init(frame:)))
        {
            method_exchangeImplementations(originalMethod, swizzledMethod)
        }
        
        // Swizzle init(coder:)
        if let originalMethod = class_getInstanceMethod(UITextField.self, #selector(UITextField.init(coder:))),
           let swizzledMethod = class_getInstanceMethod(UITextField.self, #selector(UITextField.swizzled_init(coder:)))
        {
            method_exchangeImplementations(originalMethod, swizzledMethod)
        }
    }()
    
    static func enableRTLAlignment() {
        _ = swizzleOnce
    }
    
    @objc private func swizzled_init(frame: CGRect) -> UITextField {
        let textField = swizzled_init(frame: frame)
        textField.applyRTLAlignmentIfNeeded()
        return textField
    }
    
    @objc private func swizzled_init(coder: NSCoder) -> UITextField? {
        let textField = swizzled_init(coder: coder)
        textField?.applyRTLAlignmentIfNeeded()
        return textField
    }
    
    private func applyRTLAlignmentIfNeeded() {
        textAlignment = .natural
    }
}
