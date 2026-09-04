import UIKit

enum TUIChatKitLayoutDirection {
    private static let installOnce: Void = {
        guard let originalMethod = class_getInstanceMethod(UIViewController.self, #selector(UIViewController.viewDidLoad)),
              let swizzledMethod = class_getInstanceMethod(UIViewController.self, #selector(UIViewController.chatUIKitLayoutDirection_viewDidLoad)) else {
            return
        }
        method_exchangeImplementations(originalMethod, swizzledMethod)
    }()

    static func install() {
        _ = installOnce
    }
}

extension UIViewController {
    @objc fileprivate dynamic func chatUIKitLayoutDirection_viewDidLoad() {
        chatUIKitLayoutDirection_viewDidLoad()
        guard Bundle(for: type(of: self)) == Bundle(for: AtomicXChatResources.self) else { return }
        LanguageHelper.applyLayoutDirection(to: view)
    }
}
