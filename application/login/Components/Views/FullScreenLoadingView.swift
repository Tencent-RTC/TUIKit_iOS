//
//  FullScreenLoadingView.swift
//  login
//

import UIKit
import SnapKit
import AtomicX

public class FullScreenLoadingView: UIView {

    // MARK: - Properties

    private let containerView: UIView = {
        let view = UIView()
        view.backgroundColor = ThemeStore.shared.colorTokens.bgColorMask
        return view
    }()

    private lazy var blurEffectView: UIVisualEffectView = {
        if #available(iOS 13.0, *) {
            let blurEffect = UIBlurEffect(style: .systemUltraThinMaterialDark)
            let view = UIVisualEffectView(effect: blurEffect)
            return view
        } else {
            return UIVisualEffectView()
        }
    }()

    private let contentContainerView: UIView = {
        let view = UIView()
        return view
    }()

    private let loadingImageView: UIImageView = {
        let imageView = UIImageView()
        imageView.image = UIImage.loginImage(named: "loading")
        imageView.contentMode = .scaleAspectFit
        imageView.alpha = 0.9
        return imageView
    }()

    private let loadingLabel: UILabel = {
        let label = UILabel()
        label.textColor = .white
        label.font = ThemeStore.shared.typographyTokens.Regular14
        label.textAlignment = .left
        label.text = LoginLocalize("Demo.TRTC.Login.loading")
        return label
    }()

    // MARK: - Initialization

    public override init(frame: CGRect) {
        super.init(frame: frame)
        setupUI()
        startRotationAnimation()
        isHidden = true
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    // MARK: - Setup

    private func setupUI() {
        addSubview(containerView)
        containerView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }

        if #available(iOS 13.0, *) {
            containerView.addSubview(blurEffectView)
            blurEffectView.snp.makeConstraints { make in
                make.edges.equalToSuperview()
            }
            blurEffectView.alpha = 0.3
        }

        containerView.addSubview(contentContainerView)
        contentContainerView.addSubview(loadingImageView)
        contentContainerView.addSubview(loadingLabel)

        setupConstraints()
    }

    private func setupConstraints() {
        contentContainerView.snp.makeConstraints { make in
            make.center.equalToSuperview()
            make.height.equalTo(22)
        }

        loadingImageView.snp.makeConstraints { make in
            make.leading.equalToSuperview()
            make.centerY.equalToSuperview()
            make.width.height.equalTo(20)
        }

        loadingLabel.snp.makeConstraints { make in
            make.leading.equalTo(loadingImageView.snp.trailing).offset(8)
            make.trailing.equalToSuperview()
            make.centerY.equalToSuperview()
            make.height.equalTo(22)
        }
    }

    private func startRotationAnimation() {
        let rotation = CABasicAnimation(keyPath: "transform.rotation.z")
        rotation.toValue = NSNumber(value: Double.pi * 2)
        rotation.duration = 1.0
        rotation.isCumulative = true
        rotation.repeatCount = Float.greatestFiniteMagnitude
        loadingImageView.layer.add(rotation, forKey: "rotationAnimation")
    }

    private func setMessage(_ message: String?) {
        loadingLabel.text = message ?? LoginLocalize("Demo.TRTC.Login.ioaLoading")
    }

    // MARK: - Public Methods

    public func show(with message: String? = nil) {
        if let message = message {
            setMessage(message)
        }
        isHidden = false
    }

    public func hide() {
        isHidden = true
    }
}
