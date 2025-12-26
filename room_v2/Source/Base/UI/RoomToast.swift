//
//  RoomAlert.swift
//  TUIRoomKit
//
//  Created by adamsfliu on 2025/12/04.
//
//  Copyright © 2025 Tencent. All rights reserved.

// MARK: - RoomToastPosition
enum RoomToastPosition {
    case center
    case bottom
}

// MARK: - RoomToastManager
class RoomToast {
    static let shared = RoomToast()
    
    private init() {}
    
    func showToast(message: String, duration: TimeInterval = 2.0, position: RoomToastPosition = .center) {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            displayToast(message: message, duration: duration, position: position)
        }
    }
    
    private func displayToast(message: String, duration: TimeInterval, position: RoomToastPosition) {
        guard let keyWindow = getKeyWindow() else { return }
        
        removeExistingToast(from: keyWindow)
        
        let toastView = createToastView(message: message)
        keyWindow.addSubview(toastView)
        
        setupToastConstraints(toastView: toastView, in: keyWindow, position: position)
        animateToast(toastView: toastView, duration: duration)
    }
    
    private func getKeyWindow() -> UIWindow? {
        return UIApplication.shared.connectedScenes
            .compactMap({ $0 as? UIWindowScene })
            .flatMap({ $0.windows })
            .first(where: { $0.isKeyWindow })
    }
    
    private func removeExistingToast(from window: UIWindow) {
        window.subviews.forEach { subview in
            if subview.tag == 999999 {
                subview.removeFromSuperview()
            }
        }
    }
    
    private func createToastView(message: String) -> UIView {
        let containerView = UIView()
        containerView.tag = 999999
        containerView.backgroundColor = UIColor.black.withAlphaComponent(0.8)
        containerView.layer.cornerRadius = 8
        containerView.layer.masksToBounds = true
        
        let messageLabel = UILabel()
        messageLabel.text = message
        messageLabel.font = RoomFonts.pingFangSCFont(size: 14, weight: .regular)
        messageLabel.textColor = .white
        messageLabel.textAlignment = .center
        messageLabel.numberOfLines = 0
        
        containerView.addSubview(messageLabel)
        
        messageLabel.snp.makeConstraints { make in
            make.edges.equalToSuperview().inset(UIEdgeInsets(top: 12, left: 16, bottom: 12, right: 16))
        }
        
        return containerView
    }
    
    private func setupToastConstraints(toastView: UIView, in window: UIWindow, position: RoomToastPosition) {
        toastView.snp.makeConstraints { make in
            make.centerX.equalToSuperview()
            make.left.greaterThanOrEqualToSuperview().offset(20)
            make.right.lessThanOrEqualToSuperview().offset(-20)
            
            switch position {
            case .center:
                make.centerY.equalToSuperview()
            case .bottom:
                make.bottom.equalToSuperview().offset(-100)
            }
        }
    }
    
    private func animateToast(toastView: UIView, duration: TimeInterval) {
        toastView.alpha = 0
        toastView.transform = CGAffineTransform(scaleX: 0.9, y: 0.9)
        
        UIView.animate(withDuration: 0.3, animations: {
            toastView.alpha = 1
            toastView.transform = .identity
        }) { _ in
            UIView.animate(withDuration: 0.3, delay: duration, options: [], animations: {
                toastView.alpha = 0
                toastView.transform = CGAffineTransform(scaleX: 0.9, y: 0.9)
            }) { _ in
                toastView.removeFromSuperview()
            }
        }
    }
}

extension UIView {
    func showToast(_ message: String, duration: TimeInterval = 2.0, position: RoomToastPosition = .center) {
        RoomToast.shared.showToast(message: message, duration: duration, position: position)
    }
}

extension UIViewController {
    func showToast(_ message: String, duration: TimeInterval = 2.0, position: RoomToastPosition = .center) {
        RoomToast.shared.showToast(message: message, duration: duration, position: position)
    }
}
