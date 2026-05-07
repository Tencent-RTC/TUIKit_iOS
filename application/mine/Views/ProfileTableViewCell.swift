//
//  ProfileTableViewCell.swift
//  mine
//

import UIKit
import AtomicX
import Kingfisher
import SnapKit

class ProfileTableViewCell: UITableViewCell {
    
    static let cellIdentifier = "ProfileTableViewCell"
    
    let profTitleLabel: UILabel = {
        let label = UILabel()
        label.textColor = ThemeStore.shared.colorTokens.textColorPrimary
        label.font = ThemeStore.shared.typographyTokens.Regular16
        return label
    }()
    
    let profDetailLabel: UILabel = {
        let label = UILabel()
        label.textAlignment = .right
        label.textColor = ThemeStore.shared.colorTokens.textColorPrimary
        label.font = ThemeStore.shared.typographyTokens.Regular16
        return label
    }()
    
    let profImage: UIImageView = {
        let imageView = UIImageView(frame: .zero)
        return imageView
    }()
    
    let arrowImage: UIImageView = {
        let imageView = UIImageView(frame: .zero)
        imageView.image = UIImage(named: "main_entrance_pusharrow")
        imageView.sizeToFit()
        return imageView
    }()
    
    let intervalLine: UIView = {
        let view = UIView(frame: .zero)
        view.backgroundColor = ThemeStore.shared.colorTokens.bgColorDefault
        return view
    }()
    
    override func prepareForReuse() {
        super.prepareForReuse()
        profImage.image = nil
    }
    
    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        backgroundColor = ThemeStore.shared.colorTokens.bgColorOperate
        constructViewHierarchy()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}

extension ProfileTableViewCell {
    func constructViewHierarchy() {
        contentView.addSubview(profTitleLabel)
        contentView.addSubview(profImage)
        contentView.addSubview(profDetailLabel)
        contentView.addSubview(arrowImage)
        contentView.addSubview(intervalLine)
    }
    
    func activateConstraints() {
        profTitleLabel.snp.makeConstraints { make in
            make.centerY.equalToSuperview()
            make.left.equalToSuperview().offset(convertPixel(w: 16))
        }
        profImage.snp.makeConstraints { make in
            make.right.equalTo(arrowImage.snp.left)
            make.centerY.equalToSuperview()
            make.size.equalTo(CGSize(width: convertPixel(w: 46), height: convertPixel(h: 46)))
        }
        arrowImage.snp.makeConstraints { make in
            make.centerY.equalToSuperview()
            make.width.equalTo(convertPixel(w: 18))
            make.right.equalToSuperview().offset(convertPixel(w: -16))
        }
        profDetailLabel.snp.makeConstraints { make in
            make.centerY.equalToSuperview()
            make.leading.equalTo(profTitleLabel.snp.trailing).offset(convertPixel(w: 10))
            make.right.equalTo(arrowImage.snp.left)
        }
        intervalLine.snp.makeConstraints { make in
            make.left.right.equalToSuperview().inset(convertPixel(w: 16))
            make.bottom.equalToSuperview()
            make.height.equalTo(convertPixel(h: 1))
        }
    }
}

extension ProfileTableViewCell {
    func config(with model: ProfileInfoModel) {
        profTitleLabel.text = model.title
        if let imageName = model.imageName {
            if let url = URL(string: imageName) {
                profImage.kf.setImage(with: url, placeholder: UIImage(named: "room_default_avatar"))
            } else {
                profImage.image = UIImage(named: "room_default_avatar")
            }
        }
        profDetailLabel.text = model.detail
        arrowImage.isHidden = (model.selectHandler == nil)
        arrowImage.snp.updateConstraints { make in
            make.width.equalTo(convertPixel(w: arrowImage.isHidden ? 0 : 18))
        }
        activateConstraints()
    }
}
