//
//  CoHostUserCell.swift
//  TUILiveKit
//
//  Created by chensshi on 2025/9/18.
//

import Foundation
import RTCRoomEngine
import AtomicXCore
import AtomicX

class CoHostUserCell: UITableViewCell {
    static let identifier = "CoHostUserCell"
    private var userInfo: SeatUserInfo?
    var inviteEventClosure: ((SeatUserInfo) -> Void)?
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
                            font: theme.typography.Regular16)
        }
        return label
    }()
    
    let inviteButton: AtomicButton = {
        let button = AtomicButton(
            variant: .filled,
            colorType: .primary,
            size: .xsmall,
            content: .textOnly(text: "")
        )
        return button
    }()

    private lazy var selectionIndicator: UIView = {
        let view = UIView()
        view.backgroundColor = .g3.withAlphaComponent(0.3)
        return view
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
        contentView.addSubview(selectionIndicator)
    }
    
    func activateConstraints() {
        avatarView.snp.makeConstraints { make in
            make.centerY.equalToSuperview()
            make.leading.equalToSuperview().offset(16.scale375())
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

        selectionIndicator.snp.makeConstraints { make in
            make.bottom.equalToSuperview()
            make.height.equalTo(1.scale375())
            make.left.equalTo(userNameLabel.snp.left)
            make.right.equalTo(inviteButton.snp.right)
        }
    }

    func bindInteraction() {
        inviteButton.setClickAction { [weak self] _ in
            self?.inviteButtonClick()
        }
    }
    
    func updateUser(_ user: SeatUserInfo, isBattle: Bool, isEnable: Bool) {
        self.userInfo = user
        avatarView.setContent(.url(user.avatarURL, placeholder: UIImage.avatarPlaceholderImage))
        userNameLabel.text = user.userName.isEmpty ? user.userID : user.userName
        
        let titleText = isBattle ? String.inviteBattleText : String.inviteCoHostText
        
        if isEnable {
            inviteButton.setButtonContent(.textOnly(text: titleText))
            inviteButton.setVariant(.filled)
            inviteButton.setColorType(.primary)
        } else {
            inviteButton.setButtonContent(.textOnly(text: .invitingCancelText))
            inviteButton.setVariant(.outlined)
            inviteButton.setColorType(.secondary)
        }

        inviteButton.isSelected = !isEnable
        
        inviteButton.isUserInteractionEnabled = false
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
            self?.inviteButton.isUserInteractionEnabled = true
        }
    }
}

// MARK: - Action
extension CoHostUserCell {
    private func inviteButtonClick() {
        guard let user = userInfo else { return }
        inviteEventClosure?(user)
    }
}

fileprivate extension String {
    static let inviteCoHostText = internalLocalized("Invite Host")
    static let inviteBattleText = internalLocalized("Invite Battle")
    static let invitingCancelText = internalLocalized("Cancel invite")
}
