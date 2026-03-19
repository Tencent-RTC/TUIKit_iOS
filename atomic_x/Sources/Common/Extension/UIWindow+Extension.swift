//
//  UIWindow+Extension.swift
//  Pods
//
//  Created by vincepzhang on 2025/2/21.
//

extension UIWindow {
    /// Automatically associates with an active WindowScene and makes the window key and visible (iOS 13+ adaptation)
    ///
    /// Since iOS 13, the system introduced Scene architecture. When creating a new UIWindow, you must specify
    /// the `windowScene` property, otherwise the window won't be displayed properly. This method automatically
    /// finds and associates the current active WindowScene with the window.
    ///
    /// - Use cases:
    ///   - Creating custom floating windows (e.g., debug tools, call windows)
    ///   - Creating global alert windows (e.g., banner notifications)
    ///   - Creating temporary windows (e.g., popups, overlays)
    ///
    /// - Note: On iOS 12 and below, this method directly calls the system's `makeKeyAndVisible()` method
    ///
    /// - Warning: In iPad multi-window mode, this method will select the first active Scene found,
    ///            which may not be the window the user expects
    ///
    /// Example:
    /// ```swift
    /// let window = UIWindow(frame: UIScreen.main.bounds)
    /// window.rootViewController = MyViewController()
    /// window.makeKeyAndVisibleWithScene() // Automatically associates Scene and displays
    /// ```
    public func makeKeyAndVisibleWithScene() {
        if #available(iOS 13.0, *) {
            for windowScene in UIApplication.shared.connectedScenes {
                if windowScene.activationState == UIScene.ActivationState.foregroundActive ||
                    windowScene.activationState == UIScene.ActivationState.background ||
                    windowScene.activationState == UIScene.ActivationState.foregroundInactive {
                    self.windowScene = windowScene as? UIWindowScene
                    break
                }
            }
        }
        self.makeKeyAndVisible()
    }
}
