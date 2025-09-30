//
//  MainCollectionCell.swift
//  App-UIKit
//
//  Created by yukiwwwang on 2025/8/7.
//

import UIKit
import Kingfisher
import RTCCommon
import TUICore

class MainCollectionCell: UICollectionViewCell {
    private var gradientColors: [UIColor] = []

    let containerView: UIView = {
        let containerView = UIView()
        containerView.layer.cornerRadius = 6
        containerView.layer.masksToBounds = true
        containerView.backgroundColor = .white
        return containerView
    }()
    
    private let titleLabel: UILabel = {
        let label = UILabel(frame: .zero)
        label.textColor = UIColor("262B32")
        label.textAlignment = .left
        label.adjustsFontSizeToFitWidth = true
        label.minimumScaleFactor = 0.5
        return label
    }()
    
    private let iconImageView: UIImageView = {
        let imageView = UIImageView(frame: .zero)
        imageView.contentMode = .scaleAspectFit
        return imageView
    }()
    
    private let descLabel: UILabel = {
        let label = UILabel(frame: .zero)
        label.font = UIFont(name: "PingFangSC-Regular", size: convertPixel(w: 12))
        label.textColor = UIColor("626E84")
        label.textAlignment = .left
        label.numberOfLines = 0
        label.adjustsFontSizeToFitWidth = true
        label.minimumScaleFactor = 0.8
        return label
    }()
    
    private let uiComIconView: UIView = {
        let view = UIView(frame: .zero)
        view.backgroundColor = UIColor(hex: "73A1F0")
        view.layer.cornerRadius = 2
        view.layer.masksToBounds = true
        return view
    }()
    
    private let uiComLabel: UILabel = {
        let label = UILabel()
        label.text = ""
        label.textColor = .white
        label.textAlignment = .center
        return label
    }()
    
    private let arrowImageView: UIImageView = {
        let imageView = UIImageView(frame: .zero)
        imageView.image = UIImage(named: "main_pusharrow")
        imageView.contentMode = .scaleAspectFit
        imageView.isHidden = true
        return imageView
    }()
    
    private let backgroundImageView: UIImageView = {
        let imageView = UIImageView(frame: .zero)
        imageView.contentMode = .scaleAspectFit
        imageView.image = UIImage(named: "main_scenarios")
        imageView.isHidden = true
        return imageView
    }()
    
    func constructViewHierarchy() {
        contentView.addSubview(containerView)
        containerView.addSubview(backgroundImageView)
        containerView.addSubview(titleLabel)
        containerView.addSubview(iconImageView)
        uiComIconView.addSubview(uiComLabel)
        containerView.addSubview(uiComIconView)
        containerView.addSubview(arrowImageView)
        containerView.addSubview(descLabel)
    }

    private func activateConstraints() {
        containerView.snp.makeConstraints { make in
            make.top.left.equalToSuperview().offset(4.scale375Width())
            make.bottom.right.equalToSuperview().offset(-2.scale375Width())
        }

        backgroundImageView.snp.makeConstraints { make in
            make.trailing.equalToSuperview()
            make.top.equalToSuperview()
        }

        iconImageView.snp.makeConstraints { make in
            make.top.left.equalToSuperview().offset(16.scale375Width())
            make.width.height.equalTo(24.scale375Height())
        }

        titleLabel.snp.makeConstraints { make in
            make.left.equalTo(iconImageView.snp.right).offset(2.scale375Width())
            make.right.equalTo(uiComIconView.snp.left).offset(-6.scale375Width())
            make.centerY.equalTo(iconImageView)
        }

        arrowImageView.snp.makeConstraints { make in
            make.centerY.equalTo(iconImageView)
            make.right.equalToSuperview().offset(-16.scale375Width())
            make.size.equalTo(CGSize(width: 16.scale375Width(), height: 16.scale375Height()))
        }

        uiComLabel.snp.makeConstraints { make in
            make.top.bottom.equalToSuperview()
            make.leading.trailing.equalToSuperview().inset(4.scale375Width())
        }

        uiComIconView.snp.makeConstraints { make in
            make.left.equalTo(uiComLabel).offset(6.scale375Width())
            make.bottom.top.equalTo(uiComLabel)
            make.centerY.equalTo(titleLabel)
        }

        descLabel.snp.makeConstraints { make in
            make.left.equalToSuperview().offset(14.scale375Width())
            make.right.equalToSuperview().offset(-14.scale375Width())
            make.top.equalTo(iconImageView.snp.bottom).offset(12.scale375Height()).priority(.high)
            make.bottom.lessThanOrEqualToSuperview().offset(-14.scale375Height())
        }

        titleLabel.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
    }
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        constructViewHierarchy()
        activateConstraints()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func draw(_ rect: CGRect) {
        super.draw(rect)
        let gradientLayer = containerView.gradient(colors: gradientColors)
        gradientLayer.startPoint = CGPoint(x: 0.5, y: 0.0)
        gradientLayer.endPoint = CGPoint(x: 0.5, y: 1.0)
    }
}

extension MainCollectionCell {
    public func setupDefaultConfig(_ model: MainMenuItemModel) {
        titleLabel.text = model.title
        titleLabel.textColor = UIColor("262B32")
        titleLabel.font = UIFont(name: "PingFangSC-Medium", size: convertPixel(w: 17.0 - getEnglishOffet()))
        descLabel.text = model.content
        uiComLabel.font = UIFont(name: "PingFangSC-Semibold", size: convertPixel(w: 12.0 - getEnglishOffet()))
        if model.imageName.hasPrefix("http") {
            if let imageURL = URL(string: model.imageName) {
                iconImageView.kf.setImage(with: .network(imageURL))
            }
        } else {
            iconImageView.image = model.iconImage
        }
        arrowImageView.isHidden = true
        backgroundImageView.isHidden = true
        uiComIconView.isHidden = (screenWidth <= 375.0 && isEnglish())
    }
}

extension MainCollectionCell {
    private func getEnglishOffet() -> CGFloat {
        return isEnglish() ? 2 : 0
    }
    
    private func isEnglish() -> Bool {
        guard let language = TUIGlobalization.getPreferredLanguage() else {
            return false
        }
        return !language.contains("zh")
    }
}
