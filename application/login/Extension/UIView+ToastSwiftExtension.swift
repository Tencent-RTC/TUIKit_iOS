//
//  UIView+ToastSwiftExtension.swift
//  Login
//
//  Created by gg on 2026/3/26.
//

import Toast_Swift

extension UIView {
    func makeToast(_ message: String?, duration: TimeInterval = ToastManager.shared.duration, position: ToastPosition = ToastManager.shared.position, title: String? = nil, image: UIImage? = nil, style: ToastStyle = ToastManager.shared.style, completion: ((_ didTap: Bool) -> Void)? = nil) {
        guard window != nil else { return }
        guard let toast = try? toastViewForMessage(message, title: title, image: image, style: style) else { return }
        showToast(toast, duration: duration, position: position, completion: completion)
    }
}
