//
//  AnchorCoHostUserCell.swift
//  TUILiveKit
//
//  Created by jack on 2024/8/7.
//

import Foundation
import AtomicXCore
import AtomicX

class AnchorCoHostUserCell: UITableViewCell {
    static let identifier = "AnchorCoHostUserCell"

    private var connectionUser:AnchorCoHostUserInfo?
    var inviteEventClosure: ((AnchorCoHostUserInfo) -> Void)?
    
    private lazy var avatarView: AtomicAvatar = {
        let avatar = AtomicAvatar(
            content: .url("",placeholder: UIImage.avatarPlaceholderImage),
            size: .m,
            shape: .round
        )
        return avatar
    }()
    
    let userNameLabel: AtomicLabel = {
        let label = AtomicLabel("") { theme in
            LabelAppearance(textColor: theme.color.textColorPrimary,
                            font: theme.typography.Medium16)
        }
        return label
    }()
    
    let inviteButton: AtomicButton = {
        let button = AtomicButton(
            variant: .filled,
            colorType: .primary,
            size: .xsmall,
            content: .textOnly(text: .inviteText)
        )
        return button
    }()
    
    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        backgroundColor = .clear
        contentView.backgroundColor = .clear
        selectionStyle = .none
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func draw(_ rect: CGRect) {
        super.draw(rect)
    }
    
    private var isViewReady = false
    override func didMoveToWindow() {
        super.didMoveToWindow()
        guard !isViewReady else { return }
        constructViewHierarchy()
        activateConstraints()
        bindInteraction()
        isViewReady = true
    }
    
    func constructViewHierarchy() {
        contentView.addSubview(avatarView)
        contentView.addSubview(userNameLabel)
        contentView.addSubview(inviteButton)
    }
    
    func activateConstraints() {
        avatarView.snp.makeConstraints { make in
            make.centerY.equalToSuperview()
            make.leading.equalToSuperview().offset(24.scale375())
        }
        
        userNameLabel.snp.makeConstraints { make in
            make.centerY.equalToSuperview()
            make.leading.equalTo(avatarView.snp.trailing).offset(12.scale375())
            make.width.lessThanOrEqualTo(120.scale375())
        }
        
        inviteButton.snp.makeConstraints { make in
            make.trailing.equalToSuperview().offset(-24.scale375())
            make.centerY.equalToSuperview()
            make.size.equalTo(CGSize(width: 72.scale375(), height: 24.scale375()))
        }
    }
    
    func bindInteraction() {
        inviteButton.setClickAction { [weak self] _ in
            self?.inviteButtonClick()
        }
    }
    
    func updateUser(_ user: AnchorCoHostUserInfo) {
        self.connectionUser = user
        avatarView.setContent(.url(user.userInfo.avatarURL, placeholder: UIImage.avatarPlaceholderImage))
        userNameLabel.text = user.userInfo.userName.isEmpty ? user.userInfo.userID : user.userInfo.userName
        
        inviteButton.isHidden = user.connectionStatus == .connected
        updateButtonView(isEnabled: user.connectionStatus == .none)
    }
    
    func updateButtonView(isEnabled: Bool) {
        if isEnabled {
            inviteButton.setButtonContent(.textOnly(text: .inviteText))
            inviteButton.setVariant(.filled)
            inviteButton.setColorType(.primary)
            inviteButton.isUserInteractionEnabled = true
        } else {
            inviteButton.setButtonContent(.textOnly(text: .invitingTest))
            inviteButton.setVariant(.outlined)
            inviteButton.setColorType(.secondary)
            inviteButton.isUserInteractionEnabled = false
        }
    }
}

// MARK: - Action
extension AnchorCoHostUserCell {
    private func inviteButtonClick() {
        if let user = connectionUser {
            inviteEventClosure?(user)
        }
    }
    
}

fileprivate extension String {
    static let inviteText = internalLocalized("Invite")
    static let invitingTest = internalLocalized("Waiting")
}
