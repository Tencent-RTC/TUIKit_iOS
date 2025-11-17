//
//  VRCoHostEmptyView.swift
//  Pods
//
//  Created by ssc on 2025/9/23.
//

import RTCRoomEngine
import SnapKit
import Combine
import AtomicXCore
import RTCCommon

class VRCoHostEmptyView: UIView {
    var didTap: (() -> Void)?
    private let seatInfo: SeatInfo
    private lazy var imageView : UIImageView = {
        let imageView = UIImageView()
        imageView.image = internalImage("seat_empty_icon")
        return imageView
    }()

    private lazy var titleLabel: UILabel = {
        let titleLabel = UILabel(frame: .zero)
        titleLabel.font = .customFont(ofSize: 12, weight: .regular)
        titleLabel.textColor = .white.withAlphaComponent(0.55)
        titleLabel.text = .emptySeatText
        titleLabel.numberOfLines = 0
        titleLabel.textAlignment = .center
        return titleLabel
    }()

    init(seatInfo: SeatInfo) {
        self.seatInfo = seatInfo
        super.init(frame: .zero)

        setupGradientBackground()
        layer.borderWidth = 1
        layer.borderColor = UIColor.white.withAlphaComponent(0.14).cgColor

        addSubview(titleLabel)
        addSubview(imageView)
        imageView.snp.makeConstraints { make in
            make.top.equalToSuperview().offset(27.scale375())
            make.centerX.equalToSuperview()
            make.height.width.equalTo(18.scale375())
        }
        titleLabel.snp.makeConstraints { make in
            make.top.equalTo(imageView.snp.bottom).offset(10)
            make.leading.trailing.equalToSuperview()
        }

        imageView.image = seatInfo.isLocked == true ? internalImage("seat_locked_icon") : internalImage("seat_empty_icon")
        titleLabel.text = seatInfo.isLocked == true ? .locKSeat : .noOneOnSeatText

        self.isUserInteractionEnabled = true
        let tap = UITapGestureRecognizer(target: self, action: #selector(handleTap))
        addGestureRecognizer(tap)
    }

    private func designConfig() -> ActionItemDesignConfig {
        let designConfig = ActionItemDesignConfig(lineWidth: 1, titleColor: .g2)
        designConfig.backgroundColor = .white
        designConfig.lineColor = .g8
        return designConfig
    }

    @objc private func handleTap() {
        didTap?()
    }

    private func setupGradientBackground() {
        let gradientLayer = CAGradientLayer()
        gradientLayer.colors = [
            UIColor.pinkColor.withAlphaComponent(0.2).cgColor,
            UIColor.pinkColor.withAlphaComponent(0.1).cgColor
        ]

        gradientLayer.startPoint = CGPoint(x: 0.5, y: 0)
        gradientLayer.endPoint   = CGPoint(x: 0.5, y: 1)
        gradientLayer.frame = bounds
        gradientLayer.cornerRadius = layer.cornerRadius

        layer.insertSublayer(gradientLayer, at: 0)
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        if let gradientLayer = layer.sublayers?.first(where: { $0 is CAGradientLayer }) as? CAGradientLayer {
            gradientLayer.frame = bounds
            gradientLayer.cornerRadius = layer.cornerRadius
        }
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}

class VRCoHostInviteView: UIView {
    var didTap: (() -> Void)?
    private let userInfo: SeatInfo
    private let imageView : UIImageView = {
        let imageView = UIImageView()
        imageView.image = internalImage("add")
        return imageView
    }()

    private let titleLabel: UILabel = {
        let titleLabel = UILabel(frame: .zero)
        titleLabel.font = .customFont(ofSize: 12, weight: .regular)
        titleLabel.textColor = .white.withAlphaComponent(0.55)
        titleLabel.text = .emptySeatText
        titleLabel.numberOfLines = 0
        titleLabel.textAlignment = .center
        return titleLabel
    }()

    init(seatInfo: SeatInfo) {
        userInfo = seatInfo
        super.init(frame: .zero)

        setupGradientBackground()
        layer.borderWidth = 1
        layer.borderColor = UIColor.white.withAlphaComponent(0.14).cgColor

        addSubview(titleLabel)
        addSubview(imageView)
        imageView.snp.makeConstraints { make in
            make.top.equalToSuperview().offset(27.scale375())
            make.centerX.equalToSuperview()
            make.height.width.equalTo(18.scale375())
        }
        titleLabel.snp.makeConstraints { make in
            make.top.equalTo(imageView.snp.bottom).offset(10)
            make.leading.trailing.equalToSuperview()
        }

        imageView.image = seatInfo.isLocked == true ? internalImage("seat_locked_icon") : internalImage("add")
        titleLabel.text = seatInfo.isLocked == true ? .locKSeat : .emptySeatText

        self.isUserInteractionEnabled = true
        let tap = UITapGestureRecognizer(target: self, action: #selector(handleTap))
        addGestureRecognizer(tap)
    }

    private func setupGradientBackground() {
        let gradientLayer = CAGradientLayer()
        gradientLayer.colors = [
            UIColor.b1.withAlphaComponent(0.2).cgColor,
            UIColor.b1.withAlphaComponent(0.1).cgColor
        ]

        gradientLayer.startPoint = CGPoint(x: 0.5, y: 0)
        gradientLayer.endPoint   = CGPoint(x: 0.5, y: 1)
        gradientLayer.frame = bounds
        gradientLayer.cornerRadius = layer.cornerRadius

        layer.insertSublayer(gradientLayer, at: 0)
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        if let gradientLayer = layer.sublayers?.first(where: { $0 is CAGradientLayer }) as? CAGradientLayer {
            gradientLayer.frame = bounds
            gradientLayer.cornerRadius = layer.cornerRadius
        }
    }

    @objc private func handleTap() {
        didTap?()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}

fileprivate extension String {
    static let emptySeatText: String = internalLocalized("Conn Wait")
    static let inviteText = internalLocalized("Invite")
    static let locKSeat = internalLocalized("Locked")
    static let noOneOnSeatText = internalLocalized("No guests")
}
