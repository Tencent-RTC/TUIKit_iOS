//
//  BaseView.swift
//  TUIRoomKit
//
//  Created on 2025/11/20.
//  Copyright © 2025 Tencent. All rights reserved.
//

import UIKit

/// Base view protocol for custom views
/// All custom views must conform to this protocol
protocol BaseView: AnyObject {
    /// Router context for triggering navigation (weak reference to avoid retain cycles)
    var routerContext: RouterContext? { get set }
    
    /// Setup subviews hierarchy
    func setupViews()
    
    /// Setup layout constraints
    func setupConstraints()
    
    /// Setup view styles and appearance
    func setupStyles()
    
    /// Setup data bindings and event handlers
    func setupBindings()
}

// MARK: - Default Implementation

extension BaseView {
    func setupViews() {}
    func setupConstraints() {}
    func setupStyles() {}
    func setupBindings() {}
}
