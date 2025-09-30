//
//  MineSettingsTableViewCell.swift
//  App-UIKit
//
//  Created by yukiwwwang on 2025/8/13.
//

import UIKit

class MineSettingsTableViewCell: UITableViewCell {
    let titleLabel: UILabel = {
        let label = UILabel(frame: .zero)
        label.font = UIFont(name: "PingFangSC-Regular", size: 16)
        label.textColor = UIColor("333333")
        return label
    }()
    
    private let lineView: UIView = {
        let view = UIView(frame: .zero)
        view.backgroundColor = UIColor("EEEEEE")
        return view
    }()
    
    private let detailImageView: UIImageView = {
        let imageView = UIImageView(image: UIImage(named: "mine_detail"))
        return imageView
    }()
    
    let avatarImageView: UIImageView = {
        let imageView = UIImageView(frame: .zero)
        imageView.contentMode = .scaleAspectFill
        imageView.layer.cornerRadius = 18
        imageView.clipsToBounds = true
        imageView.isHidden = true
        return imageView
    }()
    
    let nicknameLabel: UILabel = {
        let label = UILabel(frame: .zero)
        label.font = UIFont(name: "PingFangSC-Regular", size: 15)
        label.textColor = UIColor("333333")
        label.isHidden = true
        label.textAlignment = .right
        return label
    }()
    
    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        selectionStyle = .none
        backgroundColor = .clear
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    private var isViewReady = false
    override func didMoveToWindow() {
        super.didMoveToWindow()
        guard !isViewReady else {
            return
        }
        isViewReady = true
        constructViewHierarchy()
        activateConstraints()
    }
    
    private func constructViewHierarchy() {
        contentView.addSubview(titleLabel)
        contentView.addSubview(avatarImageView)
        contentView.addSubview(nicknameLabel)
        contentView.addSubview(detailImageView)
        contentView.addSubview(lineView)
    }
    
    private func activateConstraints() {
        titleLabel.snp.makeConstraints { (make) in
            make.leading.equalToSuperview().offset(20.scale375Width())
            make.centerY.equalToSuperview()
        }
        avatarImageView.snp.makeConstraints { (make) in
            make.centerY.equalToSuperview()
            make.trailing.equalTo(detailImageView.snp.leading).offset(-10.scale375Width())
            make.width.height.equalTo(36)
        }
        nicknameLabel.snp.makeConstraints { (make) in
            make.centerY.equalToSuperview()
            make.trailing.equalTo(detailImageView.snp.leading).offset(-10.scale375Width())
            make.height.equalTo(22)
            make.width.lessThanOrEqualTo(120)
        }
        detailImageView.snp.makeConstraints { (make) in
            make.trailing.equalToSuperview().offset(-20.scale375Width())
            make.centerY.equalToSuperview()
        }
        lineView.snp.makeConstraints { (make) in
            make.leading.equalTo(titleLabel)
            make.trailing.equalToSuperview().offset(-20.scale375Width())
            make.bottom.equalToSuperview()
            make.height.equalTo(1.scale375Height())
        }
    }
}
