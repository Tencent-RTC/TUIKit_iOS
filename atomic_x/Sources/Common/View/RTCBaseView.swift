//
//  RTCBaseView.swift
//  RTCCommon
//
//  Created by aby on 2024/5/14.
//

import UIKit
import os

private let subsystem = "com.rtc.uikit.common"
private let warningLog = OSLog(subsystem: subsystem, category: "WARNING")

func warning(_ string: String, fileName: String = #file, methodName: String = #function, lineNumber: Int = #line) {
    let file = (fileName as NSString).lastPathComponent.replacingOccurrences(of: ".Swift", with: "")
    let log = "\(file):line \(lineNumber) method:\(methodName):\(string)"
    if #available(iOS 10.0, *) {
        os_log("%@", log: warningLog, type: .fault, log)
    } else {
        print("<WARNING>: %@", string)
    }
}

open class RTCBaseView: UIView {
    
    public override init(frame: CGRect) {
        super.init(frame: frame)
    }
    
    @available(*, unavailable, message: "Loading this view from a nib is unsupported")
    public required init?(coder aDecoder: NSCoder) {
        fatalError("Loading this view from a nib is unsupported")
    }
    
    private var isViewReady = false
    open override func didMoveToWindow() {
        super.didMoveToWindow()
        guard !isViewReady else { return }
        constructViewHierarchy()
        activateConstraints()
        bindInteraction()
        setupViewStyle()
        isViewReady = true
    }
    
    // This function must to be override.
    open func constructViewHierarchy() {
        assertionFailure("RTCBaseView constructViewHierarchy function can not be called")
    }
    
    // This function must to be override.
    open func activateConstraints() {
        assertionFailure("RTCBaseView activateConstraints function can not be called")
    }
    
    open func bindInteraction() {
        warning("RTCBaseView bindInteraction function be called, check child view has been implementation function")
    }
    
    open func setupViewStyle() {
        warning("RTCBaseView setupViewStyle function be called, check child view has been implementation function")
    }
}

