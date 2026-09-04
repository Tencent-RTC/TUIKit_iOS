import UIKit

public final class ExpandedHitButton: UIButton {
    public var hitAreaExpansion: CGFloat = 10

    override public func point(inside point: CGPoint, with event: UIEvent?) -> Bool {
        if isHidden || alpha == 0 || !isUserInteractionEnabled {
            return false
        }
        return bounds.insetBy(dx: -hitAreaExpansion, dy: -hitAreaExpansion).contains(point)
    }
}

public enum BackBarButtonFactory {
    private static let buttonWidth: CGFloat = 28

    private static let buttonHeight: CGFloat = 44

    public static func makeBackBarButtonItem(target: Any?, action: Selector, tintColor: UIColor) -> UIBarButtonItem {
        let button = ExpandedHitButton(type: .custom)
        let image = AtomicXChatResources.image(named: "contact_info_back")?.withRenderingMode(.alwaysTemplate)
            ?? UIImage(systemName: "chevron.left")?.withRenderingMode(.alwaysTemplate)
        button.setImage(image, for: .normal)
        button.tintColor = tintColor
        button.contentHorizontalAlignment = .leading
        button.addTarget(target, action: action, for: .touchUpInside)
        button.frame = CGRect(x: 0, y: 0, width: buttonWidth, height: buttonHeight)
        let item = UIBarButtonItem(customView: button)
        if item.responds(to: NSSelectorFromString("setHidesSharedBackground:")) {
            item.setValue(true, forKey: "hidesSharedBackground")
        }
        return item
    }
}
