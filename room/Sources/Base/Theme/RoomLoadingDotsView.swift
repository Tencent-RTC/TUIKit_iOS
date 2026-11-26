import UIKit
import SnapKit

final class RoomLoadingDotsView: UIView {

    var dotColor: UIColor = .roomKitFgTertiary {
        didSet { dots.forEach { $0.backgroundColor = dotColor } }
    }

    private let dots = (0..<3).map { _ in UIView() }

    override init(frame: CGRect) {
        super.init(frame: frame)
        setupViews()
        setupConstraints()
        setupStyles()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override var intrinsicContentSize: CGSize {
        CGSize(width: 15, height: 3)
    }

    override var isHidden: Bool {
        didSet { isHidden ? stopAnimations() : startAnimations() }
    }

    override func didMoveToWindow() {
        super.didMoveToWindow()
        window == nil ? stopAnimations() : startAnimations()
    }

    private func setupViews() {
        dots.forEach(addSubview)
    }

    private func setupConstraints() {
        for (index, dot) in dots.enumerated() {
            dot.snp.makeConstraints {
                if index == 0 {
                    $0.leading.equalToSuperview()
                } else {
                    $0.leading.equalTo(dots[index - 1].snp.trailing).offset(3)
                }
                $0.centerY.equalToSuperview()
                $0.size.equalTo(3)
            }
        }
        dots.last?.snp.makeConstraints { $0.trailing.lessThanOrEqualToSuperview() }
    }

    private func setupStyles() {
        isUserInteractionEnabled = false
        dots.forEach {
            $0.backgroundColor = dotColor
            $0.layer.cornerRadius = 1.5
        }
    }

    private func startAnimations() {
        guard !isHidden, window != nil else { return }
        for (index, dot) in dots.enumerated() {
            guard dot.layer.animation(forKey: "roomTypingAlpha") == nil else { continue }
            let animation = CABasicAnimation(keyPath: "opacity")
            animation.fromValue = 0.28
            animation.toValue = 1
            animation.duration = 0.7
            animation.autoreverses = true
            animation.repeatCount = .infinity
            animation.beginTime = CACurrentMediaTime() + Double(index) * 0.18
            dot.layer.add(animation, forKey: "roomTypingAlpha")
        }
    }

    private func stopAnimations() {
        dots.forEach { $0.layer.removeAnimation(forKey: "roomTypingAlpha") }
    }
}
