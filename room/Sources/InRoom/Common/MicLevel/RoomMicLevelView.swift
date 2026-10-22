import UIKit

final class RoomMicLevelView: UIView {

    static let updateInterval: TimeInterval = 0.2
    static let maxVolume = 100

    private let bar = UIView()
    private var volume = 0
    private var hasBoundVolume = false
    private var lastLayoutSize = CGSize.zero

    override init(frame: CGRect) {
        super.init(frame: frame)
        isUserInteractionEnabled = false
        layer.masksToBounds = true
        addSubview(bar)
        applyTheme()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func didMoveToWindow() {
        super.didMoveToWindow()
        if window != nil {
            applyTheme()
        }
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        guard bounds.size != lastLayoutSize else { return }
        lastLayoutSize = bounds.size
        layer.cornerRadius = bounds.width / 2
        bar.frame = barFrame()
    }

    private func applyTheme() {
        bar.backgroundColor = UIColor.roomKitSuccess
    }

    private func barFrame() -> CGRect {
        let fraction = CGFloat(volume) / CGFloat(Self.maxVolume)
        let height = bounds.height * fraction
        return CGRect(x: 0, y: bounds.height - height, width: bounds.width, height: height)
    }
}

// MARK: - public methods

extension RoomMicLevelView {

    static func cavityFrame(inIconBox box: CGRect) -> CGRect {
        CGRect(x: box.minX + box.width * 0.34375,
               y: box.minY + box.height * 0.125,
               width: box.width * 0.3125,
               height: box.height * 0.53125)
    }

    func setVolume(_ value: Int) {
        let clamped = min(max(value, 0), Self.maxVolume)
        guard clamped != volume || !hasBoundVolume else { return }
        volume = clamped
        if hasBoundVolume && window != nil && bounds.height > 0 {
            UIView.animate(withDuration: 0.12, delay: 0,
                           options: [.beginFromCurrentState, .curveLinear, .allowUserInteraction]) {
                self.bar.frame = self.barFrame()
            }
        } else {
            bar.layer.removeAllAnimations()
            bar.frame = barFrame()
        }
        hasBoundVolume = true
    }

    func reset() {
        volume = 0
        hasBoundVolume = false
        bar.layer.removeAllAnimations()
        bar.frame = barFrame()
    }
}
