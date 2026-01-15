//
//  UITextView+Extension.swift
//  TUILiveKit
//
//  Created by gg on 2026/1/14.
//

import UIKit

extension UITextView {
    private static let swizzleOnce: Void = {
        // Swizzle init(frame:)
        if let originalMethod = class_getInstanceMethod(UITextView.self, #selector(UITextView.init(frame:))),
           let swizzledMethod = class_getInstanceMethod(UITextView.self, #selector(UITextView.swizzled_init(frame:)))
        {
            method_exchangeImplementations(originalMethod, swizzledMethod)
        }
        
        // Swizzle init(coder:)
        if let originalMethod = class_getInstanceMethod(UITextView.self, #selector(UITextView.init(coder:))),
           let swizzledMethod = class_getInstanceMethod(UITextView.self, #selector(UITextView.swizzled_init(coder:)))
        {
            method_exchangeImplementations(originalMethod, swizzledMethod)
        }
        
        // Swizzle init(frame:textContainer:)
        if let originalMethod = class_getInstanceMethod(UITextView.self, #selector(UITextView.init(frame:textContainer:))),
           let swizzledMethod = class_getInstanceMethod(UITextView.self, #selector(UITextView.swizzled_init(frame:textContainer:)))
        {
            method_exchangeImplementations(originalMethod, swizzledMethod)
        }
    }()
    
    static func enableRTLAlignment() {
        _ = swizzleOnce
    }
    
    @objc private func swizzled_init(frame: CGRect) -> UITextView {
        let textView = swizzled_init(frame: frame)
        textView.applyRTLAlignmentIfNeeded()
        return textView
    }
    
    @objc private func swizzled_init(coder: NSCoder) -> UITextView? {
        let textView = swizzled_init(coder: coder)
        textView?.applyRTLAlignmentIfNeeded()
        return textView
    }
    
    @objc private func swizzled_init(frame: CGRect, textContainer: NSTextContainer?) -> UITextView {
        let textView = swizzled_init(frame: frame, textContainer: textContainer)
        textView.applyRTLAlignmentIfNeeded()
        return textView
    }
    
    private func applyRTLAlignmentIfNeeded() {
        textAlignment = .natural
    }
}
