//
//  RoomAIRecordFloatingView.swift
//  TUIRoomKit
//
//  Created by adamsfliu on 2026/3/25.
//

import UIKit

class RoomAIRecordFloatingView: UIView {

    private let contentView: UIView = {
        let view = UIView()
        view.backgroundColor = RoomColors.g2
        view.layer.cornerRadius = 10
        view.layer.borderWidth = 1
        view.layer.borderColor = RoomColors.aiRecordBorderColor.withAlphaComponent(0.3).cgColor
        return view
    }()
    
    private let iconImageView: UIImageView = {
        let imageView = UIImageView(image: ResourceLoader.loadImage("room_ai_record"))
        return imageView
    }()
    
    private let descLabel: RoomIconButton = {
        let label = RoomIconButton()
        label.setTitle("记录中...")
        label.setTitleFont(RoomFonts.pingFangSCFont(size: 12, weight: .regular))
        label.setTitleColor(RoomColors.g8)
        label.setIcon(ResourceLoader.loadImage("room_ai_record_right_arrow"))
        label.setIconPosition(.right, spacing: 0)
        label.isUserInteractionEnabled = false
        return label
    }()
    
    public var onTap: ((RoomAIRecordFloatingView) -> Void)?
    
    init() {
        super.init(frame: .zero)
        setupViews()
        setupConstraints()
        setupBindings()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    // MARK: - Setup
    
    private func setupViews() {
        addSubview(contentView)
        contentView.addSubview(iconImageView)
        contentView.addSubview(descLabel)
    }
    
    private func setupConstraints() {
        contentView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }
        
        iconImageView.snp.makeConstraints { make in
            make.top.equalToSuperview().offset(8)
            make.centerX.equalToSuperview()
        }
        
        descLabel.snp.makeConstraints { make in
            make.top.equalTo(iconImageView.snp.bottom).offset(2)
            make.left.equalToSuperview().offset(5)
            make.right.equalToSuperview().offset(-5)
        }
    }
    
    private func setupBindings() {
        let tap = UITapGestureRecognizer(target: self, action: #selector(tapGestureEvent))
        addGestureRecognizer(tap)
    }
}

extension RoomAIRecordFloatingView {
    @objc private func tapGestureEvent(_ gesture: UITapGestureRecognizer) {
       onTap?(self)
    }
}


