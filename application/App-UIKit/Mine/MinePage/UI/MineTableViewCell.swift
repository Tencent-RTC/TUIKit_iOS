//
//  MainTableViewCell.swift
//  App-UIKit
//
//  Created by yukiwwwang on 2025/8/12.
//

import Foundation
import UIKit

class MineTableViewCell: UITableViewCell {
    
    private let titleImageView: UIImageView = {
        let imageV = UIImageView(frame: .zero)
        return imageV
    }()
    
    private let titleLabel: UILabel = {
        let label = UILabel(frame: .zero)
        label.font = UIFont(name: "PingFangSC-Semibold", size: 14)
        label.textColor = UIColor("000000")
        return label
    }()
    
    private let detailLabel: UILabel = {
        let label = UILabel(frame: .zero)
        label.font = UIFont(name: "PingFangSC-Regular", size: 12)
        label.isHidden = true
        label.textColor = UIColor("727A8A")
        label.textAlignment = .left
        return label
    }()
    
    private let detailImageView: UIImageView = {
        let imageV = UIImageView(image: UIImage(named: "mine_detail"))
        return imageV
    }()
    
    var model: MineTableViewCellModel? {
        didSet {
            guard let model = model else {
                return
            }
            titleImageView.image = model.image
            titleLabel.text = model.title
        }
    }
    
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
        contentView.addSubview(titleImageView)
        contentView.addSubview(titleLabel)
        contentView.addSubview(detailImageView)
        contentView.addSubview(detailLabel)
    }
    
    private func activateConstraints() {
        titleImageView.snp.makeConstraints { make in
            make.left.equalTo(contentView).offset(20.scale375Width())
            make.centerY.equalTo(contentView)
            make.width.height.equalTo(24.scale375Width())
        }
        
        detailImageView.snp.makeConstraints { make in
            make.right.equalTo(contentView).offset(-20.scale375Width())
            make.centerY.equalTo(titleImageView)
            make.width.height.equalTo(18.scale375Width())
        }
        
        titleLabel.snp.makeConstraints { make in
            make.centerY.equalTo(titleImageView)
            make.left.equalTo(titleImageView.snp.right).offset(20.scale375Width())
            make.right.lessThanOrEqualTo(detailImageView.snp.left).offset(-10.scale375Width())
        }
        
        detailLabel.snp.makeConstraints { make in
            make.right.equalTo(detailImageView.snp.left).offset(-4.scale375Width())
            make.centerY.equalTo(titleImageView)
        }
    }
}
