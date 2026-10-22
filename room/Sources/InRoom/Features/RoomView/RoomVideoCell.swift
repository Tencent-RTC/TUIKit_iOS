import UIKit
import AtomicXCore

///
final class RoomVideoCell: RoomParticipantCell {

    override class var streamType: VideoStreamType { .camera }

    var onFloatingPan: ((UIGestureRecognizer.State, CGPoint) -> Void)?

    var isFloating = false {
        didSet { floatingPanGesture.isEnabled = isFloating }
    }

    private let floatingPanGesture = UIPanGestureRecognizer()

    override init(frame: CGRect) {
        super.init(frame: frame)
        floatingPanGesture.addTarget(self, action: #selector(handleFloatingPan(_:)))
        floatingPanGesture.delegate = self
        floatingPanGesture.maximumNumberOfTouches = 1
        floatingPanGesture.isEnabled = false
        addGestureRecognizer(floatingPanGesture)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func prepareForReuse() {
        super.prepareForReuse()
        isFloating = false
        onFloatingPan = nil
        transform = .identity
    }

    @objc private func handleFloatingPan(_ gesture: UIPanGestureRecognizer) {
        onFloatingPan?(gesture.state, gesture.translation(in: superview))
    }
}

// MARK: - Delegate

extension RoomVideoCell: UIGestureRecognizerDelegate {

    func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer,
                           shouldBeRequiredToFailBy otherGestureRecognizer: UIGestureRecognizer) -> Bool {
        gestureRecognizer === floatingPanGesture
            && otherGestureRecognizer is UIPanGestureRecognizer
            && otherGestureRecognizer.view is UICollectionView
    }
}
