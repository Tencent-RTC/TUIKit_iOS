//
//  VRCoHostUserCell.swift
//  TUILiveKit
//
//  Created by chensshi on 2025/9/18.
//

import Foundation
import RTCRoomEngine
import AtomicXCore

class VRCoHostUserCell: UITableViewCell {
    static let identifier = "VRCoHostUserCell"
    private var userInfo: SeatUserInfo?
    var inviteEventClosure: ((SeatUserInfo) -> Void)?
    let avatarImageView: UIImageView = {
        let imageView = UIImageView(frame: .zero)
        return imageView
    }()
    
    let userNameLabel: UILabel = {
        let label = UILabel(frame: .zero)
        label.font = UIFont.customFont(ofSize: 16)
        label.textColor = .grayColor
        return label
    }()
    
    let inviteButton: UIButton = {
        let button = UIButton()
        button.layer.cornerRadius = 12.scale375()
        button.titleLabel?.font = UIFont.customFont(ofSize: 12)
        button.setTitleColor(.white, for: .normal)
        button.backgroundColor = .b1
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
    
    override func draw(_ rect: CGRect) {
        super.draw(rect)
        avatarImageView.roundedRect(.allCorners, withCornerRatio: 20.scale375())
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
        contentView.addSubview(avatarImageView)
        contentView.addSubview(userNameLabel)
        contentView.addSubview(inviteButton)
        contentView.addSubview(selectionIndicator)
    }
    
    func activateConstraints() {
        avatarImageView.snp.makeConstraints { make in
            make.centerY.equalToSuperview()
            make.leading.equalToSuperview().offset(16.scale375())
            make.size.equalTo(CGSize(width: 40.scale375(), height: 40.scale375()))
        }
        
        userNameLabel.snp.makeConstraints { make in
            make.centerY.equalToSuperview()
            make.leading.equalTo(avatarImageView.snp.trailing).offset(12.scale375())
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
        inviteButton.addTarget(self, action: #selector(inviteButtonClick(sender:)), for: .touchUpInside)
    }
    
    func updateUser(_ user: SeatUserInfo,isBattle: Bool,isEnable: Bool) {
        self.userInfo = user
        avatarImageView.kf.setImage(with: URL(string: user.avatarURL), placeholder: UIImage.avatarPlaceholderImage)
        userNameLabel.text = user.userName.isEmpty ? user.userID : user.userName
        let titleText = isBattle ? String.inviteBattleText : String.inviteCoHostText
        inviteButton.setTitle(isEnable ? titleText : .invitingCancelText, for: .normal)
        inviteButton.backgroundColor = isEnable ? .b1 : .clear
        inviteButton.layer.borderColor = UIColor.g3.withAlphaComponent(0.3).cgColor
        inviteButton.layer.borderWidth = isEnable ? 0 : 1
        inviteButton.isUserInteractionEnabled = false
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
            self?.inviteButton.isUserInteractionEnabled = true
        }
    }
}

// MARK: - Action
extension VRCoHostUserCell {
    @objc private func inviteButtonClick(sender: UIButton) {
        guard let user = userInfo else { return }
        inviteEventClosure?(user)
    }
}

fileprivate extension String {
    static let inviteCoHostText = internalLocalized("Invite Host")
    static let inviteBattleText = internalLocalized("Invite Battle")
    static let invitingCancelText = internalLocalized("Cancel invite")
}
