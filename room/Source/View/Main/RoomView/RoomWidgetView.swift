//
//  RoomWidgetView.swift
//  TUIRoomKit
//
//  Created by adamsfliu on 2026/4/2.
//

import UIKit
import AtomicXCore

class RoomWidgetView: UIView {
    
    private lazy var avatarBackgroundView: UIView = {
        let view = UIView(frame: .zero)
        view.backgroundColor = RoomColors.avatarBackgroundColor
        return view
    }()
    
    private lazy var avatarImageView: UIImageView = {
        let imageView = UIImageView(frame: .zero)
        imageView.layer.cornerRadius = 32
        imageView.layer.masksToBounds = true
        return imageView
    }()
    
    init() {
        super.init(frame: .zero)
        setupViews()
        setupConstraints()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    private func setupViews() {
        addSubview(avatarBackgroundView)
        avatarBackgroundView.addSubview(avatarImageView)
    }
    
    private func setupConstraints() {
        avatarBackgroundView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }
        
        avatarImageView.snp.makeConstraints { make in
            make.center.equalToSuperview()
            make.size.equalTo(CGSize(width: 64, height: 64))
        }
    }
    
    public func setParticipant(participant: RoomParticipant) {
        RoomKitLog.info("setParticipant: \(participant)")
        if participant.cameraStatus == .off {
            avatarImageView.kf.setImage(with: URL(string: participant.avatarURL),
                                        placeholder: ResourceLoader.loadImage("avatar_placeholder"))
            isHidden = false
        } else {
            isHidden = true
        }
    }

}
