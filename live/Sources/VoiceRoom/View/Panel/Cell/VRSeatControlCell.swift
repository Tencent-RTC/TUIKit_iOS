//
//  VRSeatControlCell.swift
//  TUILiveKit
//
//  Created by adamsfliu on 2024/7/16.
//

import UIKit
import RTCRoomEngine
import AtomicXCore
import AtomicX

class VRSeatControlCell: UITableViewCell {
    lazy var avatarView: AtomicAvatar = {
        let avatar = AtomicAvatar(
            content: .url("", placeholder: UIImage.avatarPlaceholderImage),
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
        label.adjustsFontSizeToFitWidth = false
        label.minimumScaleFactor = 1
        return label
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
    }
    
    func bindInteraction() {}
}

class VRTheSeatCell: VRSeatControlCell {
    static let identifier = "VRTheSeatCell"
    var kickoffEventClosure: ((SeatInfo) -> Void)?
    var seatInfo: SeatInfo?
    
    let seatIndexLabel: UILabel = {
        let label = UILabel(frame: .zero)
        label.textColor = .white
        label.font = UIFont.customFont(ofSize: 12)
        label.backgroundColor = .g1
        label.alpha = 0.8
        label.textAlignment = .center
        return label
    }()
    
    let kickoffSeatButton: AtomicButton = {
        let button = AtomicButton(
            variant: .outlined,
            colorType: .danger,
            size: .xsmall,
            content: .textOnly(text: .endTitleText)
        )
        return button
    }()
    
    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func draw(_ rect: CGRect) {
        super.draw(rect)
        seatIndexLabel.roundedRect(.allCorners, withCornerRatio: 8.scale375())
    }
    
    override func constructViewHierarchy() {
        super.constructViewHierarchy()
        contentView.addSubview(seatIndexLabel)
        contentView.addSubview(kickoffSeatButton)
    }
    
    override func activateConstraints() {
        super.activateConstraints()
        seatIndexLabel.snp.makeConstraints { make in
            make.trailing.bottom.equalTo(avatarView)
            make.size.equalTo(16.scale375())
        }
        
        kickoffSeatButton.snp.makeConstraints { make in
            make.trailing.equalToSuperview().offset(-24.scale375())
            make.centerY.equalToSuperview()
            make.size.equalTo(CGSize(width: 60.scale375(), height: 24.scale375()))
        }
    }
    
    override func bindInteraction() {
        super.bindInteraction()
        kickoffSeatButton.setClickAction { [weak self] _ in
            self?.kickoffSeatButtonClick()
        }
    }
    
    func updateSeatInfo(seatInfo: SeatInfo) {
        self.seatInfo = seatInfo
        avatarView.setContent(.url(seatInfo.userInfo.avatarURL, placeholder: UIImage.avatarPlaceholderImage))
        userNameLabel.text = seatInfo.userInfo.userName
        seatIndexLabel.text = "\(seatInfo.index + 1)"
    }
    
    private func kickoffSeatButtonClick() {
        if let kickoffEventClosure = kickoffEventClosure, let seatInfo = seatInfo {
            kickoffEventClosure(seatInfo)
        }
    }
}

class VRApplyTakeSeatCell: VRSeatControlCell {
    static let identifier = "VRApplyTakeSeatCell"
    var approveEventClosure: ((LiveUserInfo) -> Void)?
    var rejectEventClosure: ((LiveUserInfo) -> Void)?
    var seatApplication: LiveUserInfo?
    
    let approveButton: AtomicButton = {
        let button = AtomicButton(
            variant: .filled,
            colorType: .primary,
            size: .xsmall,
            content: .textOnly(text: .approveText)
        )
        return button
    }()
    
    let rejectButton: AtomicButton = {
        let button = AtomicButton(
            variant: .outlined,
            colorType: .primary,
            size: .xsmall,
            content: .textOnly(text: .rejectText)
        )
        return button
    }()
    
    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func constructViewHierarchy() {
        super.constructViewHierarchy()
        contentView.addSubview(approveButton)
        contentView.addSubview(rejectButton)
    }
    
    override func activateConstraints() {
        super.activateConstraints()
        
        userNameLabel.snp.remakeConstraints { make in
            make.centerY.equalToSuperview()
            make.leading.equalTo(avatarView.snp.trailing).offset(12.scale375())
            make.trailing.equalTo(approveButton.snp.leading).offset(-4.scale375())
        }
        
        approveButton.snp.makeConstraints { make in
            make.trailing.equalTo(rejectButton.snp.leading).offset(-10.scale375())
            make.centerY.equalToSuperview()
            make.size.equalTo(CGSize(width: 60.scale375(), height: 24.scale375()))
        }
        
        rejectButton.snp.makeConstraints { make in
            make.trailing.equalToSuperview().offset(-24.scale375())
            make.centerY.equalToSuperview()
            make.size.equalTo(CGSize(width: 60.scale375(), height: 24.scale375()))
        }
    }
    
    override func bindInteraction() {
        super.bindInteraction()
        approveButton.setClickAction { [weak self] _ in
            self?.approveButtonClick()
        }
        rejectButton.setClickAction { [weak self] _ in
            self?.rejectButtonClick()
        }
    }
    
    func updateSeatApplication(seatApplication: LiveUserInfo) {
        self.seatApplication = seatApplication
        avatarView.setContent(.url(seatApplication.avatarURL, placeholder: UIImage.avatarPlaceholderImage))
        userNameLabel.text = seatApplication.userName
    }
    
    private func approveButtonClick() {
        if let approveEventClosure = approveEventClosure, let seatApplication = seatApplication {
            approveEventClosure(seatApplication)
        }
    }
    
    private func rejectButtonClick() {
        if let rejectEventClosure = rejectEventClosure, let seatApplication = seatApplication {
            rejectEventClosure(seatApplication)
        }
    }
}

class VRInviteTakeSeatCell: VRSeatControlCell {
    static let identifier = "VRInviteTakeSeatCell"
    var inviteEventClosure: ((LiveUserInfo) -> Void)?
    var cancelEventClosure: ((LiveUserInfo) -> Void)?
    var user: LiveUserInfo?
    var lastClickTime: Date?
    let clickInterval = 0.5
    private var isInvited: Bool = false
    
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
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func constructViewHierarchy() {
        super.constructViewHierarchy()
        contentView.addSubview(inviteButton)
    }
    
    override func activateConstraints() {
        super.activateConstraints()
        inviteButton.snp.makeConstraints { make in
            make.trailing.equalToSuperview().offset(-24.scale375())
            make.centerY.equalToSuperview()
            make.size.equalTo(CGSize(width: 60.scale375(), height: 24.scale375()))
        }
    }
    
    override func bindInteraction() {
        super.bindInteraction()
        inviteButton.setClickAction { [weak self] _ in
            self?.inviteButtonClick()
        }
    }
    
    func updateUser(user: LiveUserInfo) {
        self.user = user
        avatarView.setContent(.url(user.avatarURL, placeholder: UIImage.avatarPlaceholderImage))
        userNameLabel.text = user.userName
    }
    
    func updateButtonView(isSelected: Bool) {
        self.isInvited = isSelected
        
        if isSelected {
            inviteButton.setVariant(.outlined)
            inviteButton.setColorType(.danger)
        } else {
            inviteButton.setVariant(.filled)
            inviteButton.setColorType(.primary)
        }
        
        inviteButton.isSelected = isSelected
    }
    
    private func inviteButtonClick() {
        guard isClickable() else  { return }
        
        if isInvited {
            if let cancelEventClosure = cancelEventClosure, let user = user {
                cancelEventClosure(user)
            }
        } else {
            if let inviteEventClosure = inviteEventClosure, let user = user {
                inviteEventClosure(user)
            }
        }
    }
    
    private func isClickable() -> Bool {
        let now = Date()
        if let lastClick = lastClickTime, now.timeIntervalSince(lastClick) < clickInterval {
            return false
        }
        lastClickTime = now
        return true
    }
}

fileprivate extension String {
    static let endTitleText = internalLocalized("common_end_user")
    static let approveText = internalLocalized("live_barrage_agree")
    static let rejectText = internalLocalized("common_reject")
    static let inviteText = internalLocalized("common_voiceroom_invite")
    static let cancelText = internalLocalized("common_cancel")
}
