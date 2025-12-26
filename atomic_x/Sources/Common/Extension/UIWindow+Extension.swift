//
//  UIWindow+Extension.swift
//  Pods
//
//  Created by yukiwwwang on 2025/8/27.
//

extension UIWindow {
    public static func getKeyWindow() -> UIWindow? {
        var keyWindow: UIWindow?
        if #available(iOS 13, *) {
            keyWindow = UIApplication.shared.connectedScenes
                .filter({ $0.activationState == .foregroundActive })
                .compactMap { $0 as? UIWindowScene }
                .flatMap { $0.windows }
                .first(where: { $0.isKeyWindow })
        } else {
            keyWindow = UIApplication.shared.keyWindow
        }
        return keyWindow
    }
    
    public static var isPortrait: Bool {
        if #available(iOS 13.0, *) {
            guard let isPortrait = UIApplication.shared.windows.first?.windowScene?.interfaceOrientation.isPortrait as? Bool
            else { return UIDevice.current.orientation.isPortrait }
            return isPortrait
        } else {
            return UIDevice.current.orientation.isPortrait
        }
    }
}
