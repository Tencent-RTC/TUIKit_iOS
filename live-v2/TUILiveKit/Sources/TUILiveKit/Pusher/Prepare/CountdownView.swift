import SnapKit
import UIKit

final class CountdownView: UIView {
    var onCancel: (() -> Void)?

    private let numberLabel = UILabel()

    override init(frame: CGRect) {
        super.init(frame: frame)
        configureUI()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func show(number: Int) {
        numberLabel.text = String(number)
        numberLabel.layer.removeAllAnimations()
        numberLabel.alpha = 0
        numberLabel.transform = CGAffineTransform(scaleX: 1.6, y: 1.6)
        UIView.animateKeyframes(
            withDuration: 1,
            delay: 0,
            options: [.beginFromCurrentState, .calculationModeCubic]
        ) {
            UIView.addKeyframe(withRelativeStartTime: 0, relativeDuration: 0.18) {
                self.numberLabel.alpha = 1
                self.numberLabel.transform = .identity
            }
            UIView.addKeyframe(withRelativeStartTime: 0.8, relativeDuration: 0.2) {
                self.numberLabel.alpha = 0
                self.numberLabel.transform = CGAffineTransform(scaleX: 0.85, y: 0.85)
            }
        }
    }

    func stopAnimation() {
        numberLabel.layer.removeAllAnimations()
        numberLabel.alpha = 0
        numberLabel.transform = .identity
    }

    private func configureUI() {
        backgroundColor = .clear

        let darkBar = UIView()
        darkBar.backgroundColor = CountdownStyle.barBackground
        darkBar.isUserInteractionEnabled = false
        addSubview(darkBar)

        let circle = UIView()
        circle.backgroundColor = CountdownStyle.circleBackground
        circle.layer.cornerRadius = 75
        addSubview(circle)

        numberLabel.textColor = .white
        numberLabel.font = CountdownStyle.numberFont
        numberLabel.textAlignment = .center
        numberLabel.layer.shadowColor = UIColor.black.cgColor
        numberLabel.layer.shadowOpacity = 0.5
        numberLabel.layer.shadowOffset = CGSize(width: 0, height: 4)
        numberLabel.layer.shadowRadius = 12
        addSubview(numberLabel)

        let cancelButton = UIButton(type: .system)
        cancelButton.setTitle(LiveKitResources.localizedString("tuilivekit.common.cancel"), for: .normal)
        cancelButton.setTitleColor(CountdownStyle.cancelForeground, for: .normal)
        cancelButton.titleLabel?.font = CountdownStyle.cancelFont
        cancelButton.backgroundColor = CountdownStyle.cancelBackground
        cancelButton.layer.cornerRadius = 14
        cancelButton.addTarget(self, action: #selector(cancel), for: .touchUpInside)
        addSubview(cancelButton)

        darkBar.snp.makeConstraints { make in
            make.leading.trailing.bottom.equalToSuperview()
            make.height.equalTo(112)
        }
        circle.snp.makeConstraints { make in
            make.centerX.equalToSuperview()
            make.centerY.equalToSuperview().offset(-56)
            make.size.equalTo(150)
        }
        numberLabel.snp.makeConstraints { make in
            make.center.equalTo(circle)
            make.size.equalTo(CGSize(width: 150, height: 140))
        }
        cancelButton.snp.makeConstraints { make in
            make.centerX.equalToSuperview()
            make.bottom.equalTo(safeAreaLayoutGuide.snp.bottom).offset(-8)
            make.size.equalTo(CGSize(width: 200, height: 50))
        }
    }

    @objc private func cancel() {
        onCancel?()
    }
}

// Styles owned by this component or feature. Values preserve the existing design.
private enum CountdownStyle {
    static let barBackground: UIColor = UIColor(red: 0.04, green: 0.04, blue: 0.06, alpha: 1)
    static let circleBackground: UIColor = UIColor.white.withAlphaComponent(0.16)
    static let cancelForeground: UIColor = UIColor.white.withAlphaComponent(0.92)
    static let cancelBackground: UIColor = UIColor(red: 0.15, green: 0.15, blue: 0.17, alpha: 0.86)
    static let numberFont: UIFont = UIFont.systemFont(ofSize: 96, weight: .light)
    static let cancelFont: UIFont = UIFont.systemFont(ofSize: 16)
}
