import UIKit
import SnapKit

public final class RoomEnteringView: UIView {

    private static let spinnerSize: CGFloat = 44
    private static let spinnerStroke: CGFloat = 3
    private static let spinnerDuration: CFTimeInterval = 0.75

    private let holder = UIStackView()
    private let spinner = UIView()
    private let spinnerTrack = CAShapeLayer()
    private let spinnerArc = CAShapeLayer()
    private let textLabel = UILabel()

    public override init(frame: CGRect) {
        super.init(frame: frame)
        setupViews()
        setupConstraints()
        setupStyles()
    }

    @available(*, unavailable)
    public required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    public override func didMoveToWindow() {
        super.didMoveToWindow()
        if window != nil {
            applyTheme()
        } else {
            stopSpin()
        }
    }

    private func setupViews() {
        holder.addArrangedSubview(spinner)
        holder.addArrangedSubview(textLabel)
        addSubview(holder)
    }

    private func setupConstraints() {
        holder.snp.makeConstraints { $0.center.equalToSuperview() }
        spinner.snp.makeConstraints { $0.size.equalTo(Self.spinnerSize) }
    }

    private func setupStyles() {
        isHidden = true
        alpha = 0

        holder.axis = .vertical
        holder.alignment = .center
        holder.spacing = 20

        setupSpinner()

        textLabel.text = .enteringText
        textLabel.font = .systemFont(ofSize: 15, weight: .medium)
        textLabel.textAlignment = .center

        applyTheme()
        NotificationCenter.default.addObserver(self, selector: #selector(handleLanguageChanged),
                                               name: RoomKitResources.languageDidChangeNotification, object: nil)
    }

    private func setupSpinner() {
        spinner.backgroundColor = .clear
        let radius = (Self.spinnerSize - Self.spinnerStroke) / 2
        let center = CGPoint(x: Self.spinnerSize / 2, y: Self.spinnerSize / 2)

        let full = UIBezierPath(arcCenter: center, radius: radius,
                                startAngle: 0, endAngle: .pi * 2, clockwise: true)
        spinnerTrack.path = full.cgPath
        spinnerTrack.fillColor = UIColor.clear.cgColor
        spinnerTrack.lineWidth = Self.spinnerStroke
        spinner.layer.addSublayer(spinnerTrack)

        let arc = UIBezierPath(arcCenter: center, radius: radius,
                               startAngle: -.pi * 3 / 4, endAngle: -.pi / 4, clockwise: true)
        spinnerArc.path = arc.cgPath
        spinnerArc.fillColor = UIColor.clear.cgColor
        spinnerArc.lineWidth = Self.spinnerStroke
        spinnerArc.lineCap = .butt
        spinner.layer.addSublayer(spinnerArc)
    }

    private func applyTheme() {
        backgroundColor = UIColor.roomKitBgCanvas
        textLabel.textColor = UIColor.roomKitFgSecondary
        spinnerTrack.strokeColor = UIColor.roomKitBorder.cgColor
        spinnerArc.strokeColor = UIColor.roomKitAccent.cgColor
    }

    private func startSpin() {
        guard spinner.layer.animation(forKey: Self.spinKey) == nil else { return }
        let animation = CABasicAnimation(keyPath: "transform.rotation.z")
        animation.fromValue = 0
        animation.toValue = CGFloat.pi * 2
        animation.duration = Self.spinnerDuration
        animation.repeatCount = .infinity
        spinner.layer.add(animation, forKey: Self.spinKey)
    }

    private func stopSpin() {
        spinner.layer.removeAnimation(forKey: Self.spinKey)
    }

    private static let spinKey = "roomEnteringSpin"
}

extension RoomEnteringView {

    public func setShown(_ shown: Bool) {
        if shown {
            superview?.bringSubviewToFront(self)
            isHidden = false
            startSpin()
        }
        UIView.animate(withDuration: 0.2, animations: {
            self.alpha = shown ? 1 : 0
        }, completion: { _ in
            if !shown, self.alpha == 0 {
                self.isHidden = true
                self.stopSpin()
            }
        })
        isUserInteractionEnabled = shown
    }

    @objc private func handleLanguageChanged() {
        textLabel.text = .enteringText
    }
}

extension String {
    fileprivate static var enteringText: String { RoomKitResources.localizedString("roomkit.main.entering") }
}
