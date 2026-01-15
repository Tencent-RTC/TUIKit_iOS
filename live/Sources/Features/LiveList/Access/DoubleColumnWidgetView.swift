//
//  DoubleColumnWidgetView.swift
//  TUILiveKit
//
//  Created by jeremiawang on 2025/4/16.
//

import RTCCommon
import AtomicXCore
import AtomicX

class DoubleColumnWidgetView: RTCBaseView {
    private var liveInfo: LiveInfo
    
    init(liveInfo: LiveInfo) {
        self.liveInfo = liveInfo
        super.init(frame: .zero)
    }
    
    private lazy var watchingLabel: UILabel = {
        let label = UILabel(frame: .zero)
        label.textColor = .textPrimaryColor
        label.font = .customFont(ofSize: 14, weight: .semibold)
        return label
    }()
    
    private lazy var watchingIcon: UIImageView = {
        let icon = UIImageView(frame: .zero)
        icon.image = internalImage("watching")
        return icon
    }()
    
    private lazy var roomNameLabel: UILabel = {
        let label = UILabel(frame: .zero)
        label.textColor = .textPrimaryColor
        label.textAlignment = .left
        label.font = .customFont(ofSize: 16, weight: .semibold)
        return label
    }()
    
    private lazy var ownerAvatarView: AtomicAvatar = {
        let avatar = AtomicAvatar(
            content: .url("",placeholder: UIImage.avatarPlaceholderImage),
            size: .xxs,
            shape: .round
        )
        return avatar
    }()
    
    private lazy var roomOwnerNameLabel: UILabel = {
        let label = UILabel(frame: .zero)
        label.textColor = .textSecondaryColor
        label.textAlignment = .left
        label.font = UIFont.customFont(ofSize: 12)
        return label
    }()
    
    override func constructViewHierarchy() {
        addSubview(watchingIcon)
        addSubview(watchingLabel)
        addSubview(roomNameLabel)
        addSubview(ownerAvatarView)
        addSubview(roomOwnerNameLabel)
    }
    
    override func activateConstraints() {
        watchingIcon.snp.makeConstraints { make in
            make.leading.equalToSuperview().offset(8.scale375())
            make.centerY.equalTo(watchingLabel.snp.centerY)
            make.width.height.equalTo(8.scale375())
        }
        
        watchingLabel.snp.makeConstraints { make in
            make.top.equalToSuperview().offset(6.scale375Height())
            make.leading.equalTo(watchingIcon.snp.trailing).offset(5.scale375())
            make.trailing.equalToSuperview().offset(-8.scale375())
        }
        
        roomNameLabel.snp.makeConstraints { make in
            make.bottom.equalTo(roomOwnerNameLabel.snp.top).offset(-4.scale375Height())
            make.leading.equalTo(ownerAvatarView)
            make.trailing.lessThanOrEqualToSuperview().inset(8.scale375())
            make.height.equalTo(22.scale375Height())
        }
        
        ownerAvatarView.snp.makeConstraints { make in
            make.leading.equalToSuperview().offset(8.scale375())
            make.centerY.equalTo(roomOwnerNameLabel)
        }
        
        roomOwnerNameLabel.snp.makeConstraints { make in
            make.bottom.equalToSuperview().inset(6.scale375Height())
            make.leading.equalTo(ownerAvatarView.snp.trailing).offset(4.scale375())
            make.height.equalTo(20.scale375Height())
            make.trailing.lessThanOrEqualToSuperview().inset(8.scale375())
        }
    }
    
    override func setupViewStyle() {
        updateView(liveInfo: liveInfo)
    }
    
    func updateView(liveInfo: LiveInfo) {
        self.liveInfo = liveInfo
        watchingLabel.text = String.localizedReplace(.watching, replace: "\(liveInfo.totalViewerCount)")
        roomNameLabel.text = liveInfo.liveName.isEmpty ? liveInfo.liveID : liveInfo.liveName
        ownerAvatarView.setContent(.url(liveInfo.liveOwner.avatarURL, placeholder: .avatarPlaceholderImage))
        roomOwnerNameLabel.text = liveInfo.liveOwner.userName.isEmpty ? liveInfo.liveOwner.userID : liveInfo.liveOwner.userName
    }
}

extension String {
    static let watching = internalLocalized("livelist_viewed_audience_count")
}
