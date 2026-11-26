import UIKit
import SnapKit

public final class MeetingLoadingView: UIView {

    private let spinnerHolder = UIView()
    private let spinner = UIImageView()
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
        if window == nil {
            stopSpin()
        }
    }

    private func setupViews() {
        spinnerHolder.addSubview(spinner)
        addSubview(spinnerHolder)
        addSubview(textLabel)
    }

    private func setupConstraints() {
        spinnerHolder.snp.makeConstraints {
            $0.centerX.equalToSuperview()
            $0.centerY.equalToSuperview().offset(-20)
            $0.size.equalTo(44)
        }
        spinner.snp.makeConstraints { $0.edges.equalToSuperview() }
        textLabel.snp.makeConstraints {
            $0.centerX.equalToSuperview()
            $0.centerY.equalToSuperview().offset(32)
        }
    }

    private func setupStyles() {
        isHidden = true
        alpha = 0
        backgroundColor = UIColor.roomKitBgCanvas

        spinner.image = RoomKitResources.image(named: "roomkit_loading_spinner")
        spinner.contentMode = .scaleAspectFit

        textLabel.text = .enteringText
        textLabel.font = .systemFont(ofSize: 15, weight: .medium)
        textLabel.textAlignment = .center
        textLabel.textColor = UIColor.roomKitFgSecondary

        NotificationCenter.default.addObserver(self, selector: #selector(handleLanguageChanged),
                                               name: RoomKitResources.languageDidChangeNotification, object: nil)
    }

    private func startSpin() {
        guard spinner.layer.animation(forKey: Self.spinKey) == nil else { return }
        let animation = CABasicAnimation(keyPath: "transform.rotation.z")
        animation.fromValue = 0
        animation.toValue = CGFloat.pi * 2
        animation.duration = 0.75
        animation.repeatCount = .infinity
        spinner.layer.add(animation, forKey: Self.spinKey)
    }

    private func stopSpin() {
        spinner.layer.removeAnimation(forKey: Self.spinKey)
    }

    private static let spinKey = "roomEnteringSpin"
}

extension MeetingLoadingView {

    public func show() {
        superview?.bringSubviewToFront(self)
        isHidden = false
        startSpin()
        UIView.animate(withDuration: 0.2) {
            self.alpha = 1
        }
        isUserInteractionEnabled = true
    }

    public func hide() {
        UIView.animate(withDuration: 0.2, animations: {
            self.alpha = 0
        }, completion: { _ in
            if self.alpha == 0 {
                self.isHidden = true
                self.stopSpin()
            }
        })
        isUserInteractionEnabled = false
    }

    @objc private func handleLanguageChanged() {
        textLabel.text = .enteringText
    }
}

extension String {
    fileprivate static var enteringText: String { RoomKitResources.localizedString("roomkit.main.entering") }
}
