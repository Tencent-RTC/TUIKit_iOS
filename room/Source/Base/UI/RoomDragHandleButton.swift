import UIKit

class RoomDragHandleButton: UIButton {
    private let extraVerticalHitArea: CGFloat

    init(extraVerticalHitArea: CGFloat = 19) {
        self.extraVerticalHitArea = extraVerticalHitArea
        super.init(frame: .zero)
        setImage(ResourceLoader.loadImage("room_drop_arrow"), for: .normal)
        imageView?.contentMode = .center
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func point(inside point: CGPoint, with event: UIEvent?) -> Bool {
        let hitRect = bounds.insetBy(dx: 0, dy: -extraVerticalHitArea)
        return hitRect.contains(point)
    }
}
