//
//  BasePanel.swift
//  TUIRoomKit
//
//  Created by AI Assistant on 2025/11/25.
//  Copyright © 2025 Tencent. All rights reserved.
//

import UIKit

/// Base panel protocol for panel views with mask and animations
///
/// Usage Example:
/// ```swift
/// // 1. Create a panel view that conforms to BasePanel and PanelHeightProvider
/// class MyPanelView: UIView, BasePanel, PanelHeightProvider {
///     weak var parentView: UIView?
///     
///     var panelHeight: CGFloat {
///         return 500
///     }
///     
///     // ... your panel implementation
/// }
///
/// // 2. Show the panel in a view controller
/// let panelView = MyPanelView()
/// panelView.show(in: self.view, animated: true)
///
/// // 3. Dismiss the panel programmatically
/// panelView.dismiss(animated: true) {
///     print("Panel dismissed")
/// }
///
/// // 4. The panel will auto-dismiss when tapping the mask area
/// ```
///
/// Real-world Example (RoomMemberPanelView):
/// ```swift
/// // In your ViewController or View:
/// func showMemberPanel() {
///     let memberPanel = RoomMemberPanelView(roomID: "12345")
///     memberPanel.show(in: self.view, animated: true)
/// }
///
/// // The panel will:
/// // - Show with a semi-transparent black mask (50% opacity)
/// // - Slide up from bottom with animation
/// // - Auto-dismiss when user taps the mask area
/// // - Support programmatic dismissal via dismiss(animated:completion:)
/// ```
public protocol BasePanel: AnyObject {
    /// Parent view to attach the panel (usually window or view controller's view)
    var parentView: UIView? { get set }

    var backgroundMaskView: PanelMaskView? { get set }

    /// Show the panel with animation
    func show(in parentView: UIView, animated: Bool)
    
    /// Dismiss the panel with animation
    func dismiss(animated: Bool, completion: (() -> Void)?)
}

// MARK: - Default Implementation
public extension BasePanel where Self: UIView {
    /// Show the panel with animation
    /// - Parameters:
    ///   - parentView: Parent view to attach the panel
    ///   - animated: Whether to animate the presentation
    func show(in parentView: UIView, animated: Bool = true) {
        self.parentView = parentView
        
        let maskView = createMaskView()
        backgroundMaskView = maskView
        
        parentView.addSubview(maskView)
        
        maskView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }
        
        parentView.addSubview(self)
        
        self.snp.makeConstraints { make in
            make.left.right.equalToSuperview()
            make.top.equalTo(parentView.snp.bottom)
        }
        
        parentView.layoutIfNeeded()
        
        if animated {
            maskView.alpha = 0
            
            UIView.animate(withDuration: 0.3, delay: 0, options: .curveEaseOut) {
                maskView.alpha = 1
                
                self.snp.remakeConstraints { make in
                    make.left.right.bottom.equalToSuperview()
                    make.height.equalTo(self.getPanelHeight())
                }
                parentView.layoutIfNeeded()
            }
        } else {
            self.snp.remakeConstraints { make in
                make.left.right.bottom.equalToSuperview()
                make.height.equalTo(self.getPanelHeight())
            }
            parentView.layoutIfNeeded()
        }
    }
    
    /// Dismiss the panel with animation
    /// - Parameters:
    ///   - animated: Whether to animate the dismissal
    ///   - completion: Completion handler called after dismissal
    func dismiss(animated: Bool = true, completion: (() -> Void)? = nil) {
        guard let parentView = self.parentView else {
            completion?()
            return
        }
        
        if animated {
            UIView.animate(withDuration: 0.25,
                           delay: 0,
                           options: .curveEaseIn,
                           animations: { [weak self] in
                guard let self = self else { return }
                self.backgroundMaskView?.alpha = 0
                
                self.snp.remakeConstraints { make in
                    make.left.right.equalToSuperview()
                    make.top.equalTo(parentView.snp.bottom)
                }
                parentView.layoutIfNeeded()
            }) { [weak self] _ in
                guard let self = self else { return }
                self.backgroundMaskView?.removeFromSuperview()
                self.removeFromSuperview()
                self.parentView = nil
                self.backgroundMaskView = nil
                completion?()
            }
        } else {
            self.backgroundMaskView?.removeFromSuperview()
            self.removeFromSuperview()
            self.parentView = nil
            self.backgroundMaskView = nil
            completion?()
        }
    }
    
    // MARK: - Private Methods
    private func createMaskView() -> PanelMaskView {
        let maskView = PanelMaskView()
        maskView.backgroundColor = UIColor.black.withAlphaComponent(0.5)
        
        let tapGesture = UITapGestureRecognizer(target: maskView, action: #selector(PanelMaskView.handleTap))
        maskView.addGestureRecognizer(tapGesture)
        
        maskView.onTap = { [weak self] in
            guard let self = self else { return }
            dismiss(animated: true)
        }
        
        return maskView
    }
    
    private func getPanelHeight() -> CGFloat {
        if let heightProvider = self as? PanelHeightProvider {
            return heightProvider.panelHeight
        }
        return UIScreen.main.bounds.height * 0.8
    }
}

// MARK: - Panel Height Provider Protocol
public protocol PanelHeightProvider {
    var panelHeight: CGFloat { get }
}

// MARK: - Panel Mask View
public class PanelMaskView: UIView {
    var onTap: (() -> Void)?
    
    public override func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
        let view = super.hitTest(point, with: event)
        return view == self ? self : nil
    }
    
    @objc func handleTap() {
        onTap?()
    }
}
