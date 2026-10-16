import UIKit

final class LiveSlider: UISlider {
    var onValueChanged: ((Float) -> Void)?
    let step: Float

    init(range: ClosedRange<Float>, step: Float = 1) {
        self.step = step
        super.init(frame: .zero)
        minimumValue = range.lowerBound
        maximumValue = range.upperBound
        minimumTrackTintColor = LiveTheme.Color.brandBlue
        maximumTrackTintColor = SliderStyle.inactiveTrack
        setThumbImage(Self.makeThumbImage(), for: .normal)
        addTarget(self, action: #selector(valueDidChange), for: .valueChanged)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    @objc private func valueDidChange() {
        let snappedValue = ((value - minimumValue) / step).rounded() * step + minimumValue
        value = min(max(snappedValue, minimumValue), maximumValue)
        onValueChanged?(value)
    }

    private static func makeThumbImage() -> UIImage {
        UIGraphicsImageRenderer(size: CGSize(width: SliderStyle.thumbSize, height: SliderStyle.thumbSize)).image { context in
            let rect = CGRect(x: SliderStyle.thumbInset, y: SliderStyle.thumbInset, width: SliderStyle.thumbDiameter, height: SliderStyle.thumbDiameter)
            context.cgContext.setShadow(offset: .zero, blur: 3, color: SliderStyle.thumbShadow.cgColor)
            UIColor.white.setFill()
            UIBezierPath(ovalIn: rect).fill()
            LiveTheme.Color.brandBlue.setStroke()
            let border = UIBezierPath(ovalIn: rect)
            border.lineWidth = 1
            border.stroke()
        }
    }
}

private enum SliderStyle {
    static let thumbSize: CGFloat = 18
    static let thumbInset: CGFloat = 1
    static let thumbDiameter: CGFloat = 16

    static let inactiveTrack: UIColor = UIColor.white.withAlphaComponent(0.12)
    static let thumbShadow: UIColor = UIColor.black.withAlphaComponent(0.25)
}
