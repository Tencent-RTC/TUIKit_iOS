//
//  OverseasCollectionCell.swift
//  main
//

import UIKit
import SnapKit
import Kingfisher
import AppAssembly
import AtomicX

class OverseasCollectionCell: UICollectionViewCell {

    // MARK: - UI Elements

    let containerView: UIView = {
        let view = UIView(frame: .zero)
        view.backgroundColor = ThemeStore.shared.colorTokens.bgColorOperate
        return view
    }()

    private let iconImageView: UIImageView = {
        let imageView = UIImageView(frame: .zero)
        imageView.contentMode = .scaleAspectFill
        return imageView
    }()

    private let titleLabel: UILabel = {
        let label = UILabel(frame: .zero)
        label.font = .boldSystemFont(ofSize: 20)
        label.textColor = ThemeStore.shared.colorTokens.textColorPrimary
        label.textAlignment = .left
        label.numberOfLines = 2
        label.adjustsFontSizeToFitWidth = true
        return label
    }()

    private let descLabel: UILabel = {
        let label = UILabel(frame: .zero)
        label.font = ThemeStore.shared.typographyTokens.Regular12
        label.textColor = ThemeStore.shared.colorTokens.textColorSecondary
        label.textAlignment = .left
        label.numberOfLines = 0
        label.adjustsFontSizeToFitWidth = true
        label.minimumScaleFactor = 0.8
        return label
    }()

    private let uiComIconView: UIView = {
        let view = UIView(frame: .zero)
        view.backgroundColor = ThemeStore.shared.colorTokens.textColorLink
        view.layer.cornerRadius = 2
        view.layer.masksToBounds = true
        return view
    }()

    private let uiComLabel: UILabel = {
        let label = UILabel()
        label.text = ""
        label.textColor = .white
        label.textAlignment = .center
        label.font = UIFont(name: "PingFangSC-Medium", size: convertPixel(h: 12))
        return label
    }()

    private let hotLabel: UILabel = {
        let label = UILabel()
        label.text = MainLocalize("Demo.TRTC.Portal.Main.HotComponent")
        label.textColor = .white
        label.textAlignment = .center
        label.isHidden = true
        label.font = UIFont(name: "PingFangSC-Medium", size: convertPixel(h: 12))
        label.backgroundColor = ThemeStore.shared.colorTokens.textColorWarning
        label.layer.cornerRadius = 2
        label.layer.masksToBounds = true
        return label
    }()

    private let arrowImageView: UIImageView = {
        let imageView = UIImageView(frame: .zero)
        imageView.image = UIImage(named: "main_entrance_pusharrow")
        imageView.contentMode = .scaleAspectFit
        return imageView
    }()

    private let unreadImageView: UIImageView = {
        let imageView = UIImageView(image: UIImage(named: "main_chat_unread"))
        imageView.contentMode = .scaleAspectFit
        imageView.isHidden = true
        return imageView
    }()

    // MARK: - Init

    override init(frame: CGRect) {
        super.init(frame: frame)
        constructViewHierarchy()
        activateConstraints()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    // MARK: - Draw

    override func draw(_ rect: CGRect) {
        super.draw(rect)
        containerView.roundedRect(
            rect: containerView.bounds,
            byRoundingCorners: .allCorners,
            cornerRadii: CGSize(width: 10, height: 10)
        )
    }

    // MARK: - Setup

    private func constructViewHierarchy() {
        contentView.addSubview(containerView)
        containerView.addSubview(iconImageView)
        containerView.addSubview(titleLabel)
        containerView.addSubview(descLabel)
        containerView.addSubview(arrowImageView)
        uiComIconView.addSubview(uiComLabel)
        containerView.addSubview(uiComIconView)
        containerView.addSubview(hotLabel)
        containerView.addSubview(unreadImageView)
    }

    private func activateConstraints() {
        containerView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }

        iconImageView.snp.makeConstraints { make in
            make.left.equalToSuperview().offset(convertPixel(w: 16))
            make.topMargin.equalToSuperview().offset(convertPixel(h: 12))
            make.size.equalTo(CGSize(width: convertPixel(w: 24), height: convertPixel(h: 24)))
        }

        titleLabel.snp.makeConstraints { make in
            make.left.equalTo(iconImageView.snp.right).offset(convertPixel(w: 6))
            make.centerY.equalTo(iconImageView)
        }

        arrowImageView.snp.makeConstraints { make in
            make.centerY.equalTo(iconImageView)
            make.right.equalToSuperview().offset(-22)
            make.size.equalTo(CGSize(width: convertPixel(w: 16), height: convertPixel(w: 16)))
        }

        uiComLabel.snp.makeConstraints { make in
            make.top.bottom.equalToSuperview()
            make.leading.trailing.equalToSuperview().inset(convertPixel(w: 4))
        }

        uiComIconView.snp.makeConstraints { make in
            make.left.equalTo(uiComLabel).offset(convertPixel(w: 6))
            make.leading.equalTo(titleLabel.snp.trailing).offset(convertPixel(w: 10))
            make.bottom.top.equalTo(uiComLabel)
            make.centerY.equalTo(titleLabel)
        }

        hotLabel.snp.makeConstraints { make in
            make.leading.equalTo(titleLabel.snp.trailing).offset(convertPixel(w: 10))
            make.centerY.equalTo(titleLabel)
            make.height.equalTo(18)
            make.width.equalTo(32)
        }

        descLabel.snp.makeConstraints { make in
            make.top.equalTo(iconImageView.snp.bottom).offset(convertPixel(h: 8))
            make.left.equalToSuperview().offset(convertPixel(w: 15))
            make.right.equalToSuperview().offset(convertPixel(w: -15))
            make.bottom.equalToSuperview().offset(convertPixel(h: -12))
        }

        unreadImageView.snp.makeConstraints { make in
            make.centerY.equalTo(iconImageView)
            make.right.equalTo(arrowImageView.snp.left).offset(-8)
            make.width.height.equalTo(8)
        }
    }

    // MARK: - Public Config

    func config(_ module: ResolvedModule) {
        let config = module.config

        setIconImage(name: config.iconName, preloaded: config.iconImage)

        titleLabel.text = config.title
        descLabel.text = config.description

        let showUIKit = config.cardStyle == .uiComponent
        uiComIconView.isHidden = !showUIKit
        if showUIKit {
            uiComLabel.text = MainLocalize("Demo.TRTC.Portal.Main.UIkit")
        }

        hotLabel.isHidden = !config.isHot

        unreadImageView.isHidden = module.badgeCount == 0
    }

    // MARK: - Helpers

    private func setIconImage(name: String, preloaded: UIImage? = nil) {
        if let preloaded = preloaded {
            iconImageView.image = preloaded
        } else if name.hasPrefix("http"), let imageURL = URL(string: name) {
            iconImageView.kf.setImage(with: imageURL)
        } else {
            iconImageView.image = UIImage(named: name)
        }
    }
}
