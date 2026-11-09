import UIKit

extension UISwitch {

    public func applyRoomKitStyle() {
        onTintColor = UIColor.roomKitAccent
        backgroundColor = UIColor.clear
        clipsToBounds = true
        thumbTintColor = .white
        transform = CGAffineTransform(scaleX: 0.8, y: 0.8)
    }
}

