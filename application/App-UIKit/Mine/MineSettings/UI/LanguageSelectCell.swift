//
//  LanguageSelectCell.swift
//  App-UIKit
//
//  Created by yukiwwwang on 2025/8/19.
//

import UIKit

class LanguageSelectCell: UITableViewCell {
    
    let nameLabel: UILabel = {
        let label = UILabel(frame: .zero)
        label.font = UIFont(name: "PingFangSC-Regular", size: 16)
        label.textColor = UIColor("333333")
        return label
    }()
    
    let chooseIconView: UIImageView = {
        let imageView = UIImageView(image: UIImage(named: "main_mine_choose"))
        return imageView
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
        contentView.addSubview(nameLabel)
        contentView.addSubview(chooseIconView)
    }
    
    private func activateConstraints() {
        nameLabel.snp.makeConstraints { (make) in
            make.leading.equalToSuperview().offset(20.scale375Width())
            make.centerY.equalToSuperview()
        }
        chooseIconView.snp.makeConstraints { (make) in
            make.right.equalToSuperview().offset(-20.scale375Width())
            make.centerY.equalToSuperview()
            make.width.height.equalTo(20.scale375Height())
        }
    }
    
}

