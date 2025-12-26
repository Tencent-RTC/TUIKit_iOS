//
//  AudienceMemberCell.swift
//  TUILiveKit
//
//  Created by WesleyLei on 2023/10/24.
//

import Foundation
import AtomicXCore
import RTCCommon
import AtomicX

class AudienceMemberCell: UITableViewCell {
    var onUserManageButtonClicked: ((LiveUserInfo) -> Void)? {
        didSet {
            if onUserManageButtonClicked != nil {
                setupUserManageButton()
            }
        }
    }
    
    var user: LiveUserInfo? {
        didSet {
            guard let user = user else {
                return
            }
            
            avatarView.setContent(.url(user.avatarURL, placeholder: avatarPlaceholderImage))
            
            nameLabel.text = user.userName.isEmpty ? user.userID : user.userName
        }
    }
    
    private lazy var avatarView: AtomicAvatar = {
        let avatar = AtomicAvatar(
            content: .url("", placeholder: avatarPlaceholderImage),
            size: .m,
            shape: .round
        )
        contentView.addSubview(avatar)
        return avatar
    }()
    
    lazy var nameLabel: UILabel = {
        let label = UILabel(frame: .zero)
        label.font = .customFont(ofSize: 16)
        label.textColor = .white
        return label
    }()
    
    let lineView: UIView = {
        let view = UIView()
        view.backgroundColor = .g3.withAlphaComponent(0.3)
        return view
    }()
    
    lazy var userManageButton: UIButton = {
        let button = UIButton()
        button.setImage(internalImage("live_more_icon"), for: .normal)
        button.addTarget(self, action: #selector(userManageButtonClick), for: .touchUpInside)
        return button
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
    
    func constructViewHierarchy() {
        contentView.addSubview(avatarView)
        contentView.addSubview(nameLabel)
        contentView.addSubview(lineView)
    }
    
    func activateConstraints() {
        avatarView.snp.makeConstraints { make in
            make.leading.equalToSuperview().inset(24)
            make.centerY.equalToSuperview()
            make.size.equalTo(40.scale375())
        }
        
        nameLabel.snp.makeConstraints { (make) in
            make.centerY.equalToSuperview()
            make.height.equalToSuperview()
            make.leading.equalTo(avatarView.snp.trailing).offset(14.scale375())
            make.trailing.equalToSuperview().inset(24)
        }
        
        lineView.snp.makeConstraints { (make) in
            make.bottom.equalToSuperview()
            make.leading.equalTo(nameLabel)
            make.trailing.equalToSuperview().inset(24)
            make.height.equalTo(1)
        }
    }
    
    private func setupUserManageButton() {
        guard userManageButton.superview == nil else { return }
        contentView.addSubview(userManageButton)
        userManageButton.snp.makeConstraints { make in
            make.bottom.equalToSuperview()
            make.centerY.equalToSuperview()
            make.trailing.equalToSuperview().offset(-24)
            make.width.equalTo(24)
        }
        nameLabel.snp.remakeConstraints { make in
            make.centerY.equalToSuperview()
            make.height.equalToSuperview()
            make.leading.equalTo(avatarView.snp.trailing).offset(14.scale375())
            make.trailing.equalTo(userManageButton).offset(-10)
        }
    }
}

// MARK: Action
extension AudienceMemberCell {
    @objc func userManageButtonClick() {
        guard let user = user, let onUserManageButtonClicked = onUserManageButtonClicked else { return }
        onUserManageButtonClicked(user)
    }
}
