import UIKit

extension UISwitch {

    public func applyRoomKitStyle() {
        onTintColor = UIColor.roomKitAccent
        backgroundColor = UIColor.roomKitToggleOff
        layer.cornerRadius = 15.5
        clipsToBounds = true
        thumbTintColor = .white
        transform = CGAffineTransform(scaleX: 40.0 / 51.0, y: 22.0 / 31.0)
    }
}

