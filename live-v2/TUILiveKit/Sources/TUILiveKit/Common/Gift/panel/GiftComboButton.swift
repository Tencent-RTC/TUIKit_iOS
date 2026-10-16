import SnapKit
import UIKit

final class GiftComboButton: UIView {
    struct Style {
        static let comboDuration: TimeInterval = 2.0
        static let holdDelay: TimeInterval = 0.3
        static let holdInterval: TimeInterval = 0.3
        static let brandBlue = GiftPanelStyle.blue
        static let brandBlueDark = GiftPanelStyle.deepBlue
        static let faceToCoreRatio: CGFloat = 46.0 / 52.0
    }

    var onSendOnce: (() -> Void)?
    var onExpired: (() -> Void)?

    private(set) var giftID: String?

    private let faceView = UIView()
    private let faceGradientLayer = CAGradientLayer()
    private let faceHighlightLayer = CAGradientLayer()
    private let progressLayer = CAShapeLayer()
    private let backgroundRingLayer = CAShapeLayer()
    private let iconView = UIImageView()
    private let countLabel = UILabel()
    private let countBadge = UIView()
    private let holdHintLabel = UILabel()
    private let tapButton = UIControl()

    private var progressAnimation: CAAnimation?
    private var expireWorkItem: DispatchWorkItem?
    private var holdWorkItem: DispatchWorkItem?
    private var holdRepeatTimer: Timer?
    private var comboCount: Int = 1
    private var isPressing: Bool = false

    override init(frame: CGRect) {
        super.init(frame: frame)
        setupViews()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func setupViews() {
        backgroundColor = .clear
        isUserInteractionEnabled = true

        addSubview(faceView)

        backgroundRingLayer.fillColor = GiftComboStyle.ringBackground.cgColor
        backgroundRingLayer.strokeColor = UIColor.clear.cgColor
        backgroundRingLayer.lineWidth = 0
        faceView.layer.addSublayer(backgroundRingLayer)

        progressLayer.fillColor = UIColor.clear.cgColor
        progressLayer.strokeColor = Style.brandBlue.cgColor
        progressLayer.lineWidth = 3
        progressLayer.lineCap = .butt
        progressLayer.strokeEnd = 1.0
        progressLayer.shadowColor = Style.brandBlue.cgColor
        progressLayer.shadowRadius = 5
        progressLayer.shadowOpacity = 0.72
        progressLayer.shadowOffset = .zero
        faceView.layer.addSublayer(progressLayer)

        faceGradientLayer.colors = [
            Style.brandBlue.cgColor,
            Style.brandBlue.cgColor,
            Style.brandBlueDark.cgColor,
        ]
        faceGradientLayer.locations = [0, 0.55, 1]
        faceGradientLayer.startPoint = CGPoint(x: 0, y: 0)
        faceGradientLayer.endPoint = CGPoint(x: 1, y: 1)
        faceView.layer.addSublayer(faceGradientLayer)

        faceHighlightLayer.type = .radial
        faceHighlightLayer.colors = [
            UIColor.white.withAlphaComponent(0.28).cgColor,
            UIColor.white.withAlphaComponent(0).cgColor,
        ]
        faceHighlightLayer.locations = [0, 1]
        faceHighlightLayer.startPoint = CGPoint(x: 0.5, y: 0.15)
        faceHighlightLayer.endPoint = CGPoint(x: 1.05, y: 0.7)
        faceView.layer.addSublayer(faceHighlightLayer)

        iconView.contentMode = .scaleAspectFit
        iconView.clipsToBounds = true
        iconView.isHidden = true
        faceView.addSubview(iconView)

        holdHintLabel.text = Self.formattedHint(
            LiveKitResources.localizedString("tuilivekit.player.gift.combo.hint")
        )
        holdHintLabel.textColor = .white
        holdHintLabel.font = GiftComboButtonTypography.holdHintFont
        holdHintLabel.textAlignment = .center
        holdHintLabel.numberOfLines = 2
        faceView.addSubview(holdHintLabel)

        countBadge.backgroundColor = Style.brandBlue
        countBadge.layer.cornerRadius = 10
        countBadge.isUserInteractionEnabled = false
        addSubview(countBadge)

        countLabel.textColor = .white
        countLabel.font = GiftComboButtonTypography.countFont
        countLabel.textAlignment = .center
        countBadge.addSubview(countLabel)

        addSubview(tapButton)
        tapButton.addTarget(self, action: #selector(handleTouchDown), for: .touchDown)
        tapButton.addTarget(self, action: #selector(handleTouchUp), for: [.touchUpInside, .touchUpOutside, .touchCancel])

        faceView.snp.makeConstraints { make in
            make.centerX.equalToSuperview()
            make.top.equalToSuperview().offset(4)
            make.width.height.equalTo(68)
        }

        iconView.snp.makeConstraints { make in
            make.center.equalTo(faceView)
            make.width.height.equalTo(30)
        }

        holdHintLabel.snp.makeConstraints { make in
            make.center.equalTo(faceView)
            make.leading.greaterThanOrEqualTo(faceView).offset(6)
            make.trailing.lessThanOrEqualTo(faceView).offset(-6)
        }

        countBadge.snp.makeConstraints { make in
            make.centerX.equalTo(faceView)
            make.top.equalTo(faceView.snp.bottom).offset(6)
            make.height.equalTo(20)
            make.width.greaterThanOrEqualTo(30)
        }

        countLabel.snp.makeConstraints { make in
            make.center.equalToSuperview()
            make.leading.equalToSuperview().offset(6)
            make.trailing.equalToSuperview().offset(-6)
        }

        tapButton.snp.makeConstraints { make in
            make.edges.equalTo(faceView)
        }
    }

    func begin(with gift: GiftUIStore.GiftItem) {
        giftID = gift.id
        comboCount = 0
        performSingleShot()
    }

    func end() {
        cancelTimers()
        progressLayer.removeAllAnimations()
        giftID = nil
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        faceView.layoutIfNeeded()
        let size = faceView.bounds.size
        let outerRadius = min(size.width, size.height) / 2 - 2
        let center = CGPoint(x: size.width / 2, y: size.height / 2)

        let coreRadius = outerRadius - 6
        let faceSide = coreRadius * 2 * Style.faceToCoreRatio
        let faceRect = CGRect(
            x: center.x - faceSide / 2,
            y: center.y - faceSide / 2,
            width: faceSide,
            height: faceSide
        )
        faceGradientLayer.frame = faceRect
        faceGradientLayer.cornerRadius = faceSide / 2
        faceGradientLayer.masksToBounds = true
        faceHighlightLayer.frame = faceRect
        faceHighlightLayer.cornerRadius = faceSide / 2
        faceHighlightLayer.masksToBounds = true

        backgroundRingLayer.frame = faceView.bounds
        let bgPath = UIBezierPath(arcCenter: center, radius: coreRadius, startAngle: 0, endAngle: .pi * 2, clockwise: true)
        backgroundRingLayer.path = bgPath.cgPath

        let progressRadius = outerRadius - 3
        progressLayer.frame = faceView.bounds
        let progressPath = UIBezierPath(
            arcCenter: center,
            radius: progressRadius,
            startAngle: -.pi / 2,
            endAngle: -.pi * 5 / 2,
            clockwise: false
        )
        progressLayer.path = progressPath.cgPath

        let circumference = 2 * CGFloat.pi * progressRadius
        let dashLength = circumference * 8.0 / 360.0
        let gapLength = circumference * 4.0 / 360.0
        progressLayer.lineDashPattern = [NSNumber(value: Double(dashLength)), NSNumber(value: Double(gapLength))]
    }

    private func updateCountLabel(animated: Bool) {
        countLabel.text = "\(comboCount)"
        countBadge.isHidden = false
        if animated {
            countBadge.transform = CGAffineTransform(scaleX: 1.35, y: 1.35)
            UIView.animate(
                withDuration: 0.22,
                delay: 0,
                usingSpringWithDamping: 0.5,
                initialSpringVelocity: 0.6,
                options: [.curveEaseOut, .beginFromCurrentState]
            ) {
                self.countBadge.transform = .identity
            }
        }
    }

    private func restartTimer() {
        progressLayer.removeAllAnimations()
        let anim = CABasicAnimation(keyPath: "strokeEnd")
        anim.fromValue = 1.0
        anim.toValue = 0.0
        anim.duration = Style.comboDuration
        anim.timingFunction = CAMediaTimingFunction(name: .linear)
        anim.fillMode = .forwards
        anim.isRemovedOnCompletion = false
        progressLayer.add(anim, forKey: "strokeEnd")

        expireWorkItem?.cancel()
        let item = DispatchWorkItem { [weak self] in
            self?.handleExpired()
        }
        expireWorkItem = item
        DispatchQueue.main.asyncAfter(deadline: .now() + Style.comboDuration, execute: item)
    }

    private func handleExpired() {
        cancelTimers()
        onExpired?()
    }

    private func cancelTimers() {
        expireWorkItem?.cancel()
        expireWorkItem = nil
        holdWorkItem?.cancel()
        holdWorkItem = nil
        holdRepeatTimer?.invalidate()
        holdRepeatTimer = nil
        isPressing = false
    }

    @objc private func handleTouchDown() {
        isPressing = true
        performSingleShot()

        holdWorkItem?.cancel()
        let workItem = DispatchWorkItem { [weak self] in
            self?.startHoldRepeat()
        }
        holdWorkItem = workItem
        DispatchQueue.main.asyncAfter(deadline: .now() + Style.holdDelay, execute: workItem)
    }

    @objc private func handleTouchUp() {
        isPressing = false
        holdWorkItem?.cancel()
        holdWorkItem = nil
        holdRepeatTimer?.invalidate()
        holdRepeatTimer = nil
    }

    private func startHoldRepeat() {
        guard isPressing else { return }
        holdRepeatTimer?.invalidate()
        holdRepeatTimer = Timer.scheduledTimer(
            withTimeInterval: Style.holdInterval,
            repeats: true
        ) { [weak self] _ in
            guard let self, self.isPressing else {
                self?.holdRepeatTimer?.invalidate()
                return
            }
            self.performSingleShot()
        }
    }

    private func performSingleShot() {
        comboCount += 1
        updateCountLabel(animated: true)
        restartTimer()
        onSendOnce?()
    }

    private static func formattedHint(_ raw: String) -> String {
        let trimmed = raw.trimmingCharacters(in: .whitespaces)
        if trimmed.contains(" ") {
            return trimmed
        }
        let chars = Array(trimmed)
        guard chars.count == 4 else { return trimmed }
        return "\(chars[0])\(chars[1])\n\(chars[2])\(chars[3])"
    }
}

// Styles owned by this component or feature. Values preserve the existing design.
private enum GiftComboStyle {
    static let ringBackground: UIColor = UIColor(red: 5/255.0, green: 6/255.0, blue: 12/255.0, alpha: 0.9)
}

private enum GiftComboButtonTypography {
    static let holdHintFont: UIFont = UIFont.systemFont(ofSize: 13, weight: .bold)
    static let countFont: UIFont = UIFont.systemFont(ofSize: 12, weight: .heavy)
}
