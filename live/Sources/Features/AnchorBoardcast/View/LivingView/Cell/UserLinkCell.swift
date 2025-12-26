//
//  UserLinkCell.swift
//  TUILiveKit
//
//  Created by WesleyLei on 2023/10/27.
//

import Foundation
import AtomicXCore
import AtomicX

class UserLinkCell: LinkMicBaseCell {
    var kickoffEventClosure: ((SeatUserInfo) -> Void)?
    
    private lazy var hangUpButton: AtomicButton = {
        let button = AtomicButton(
            variant: .outlined,
            colorType: .danger,
            size: .xsmall,
            content: .textOnly(text: .anchorHangUpTitle)
        )
        button.setClickAction { [weak self] _ in
            self?.hangUpButtonClick()
        }
        return button
    }()
    
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
        contentView.addSubview(hangUpButton)
        contentView.addSubview(lineView)
    }
    
    func activateConstraints() {
        avatarView.snp.makeConstraints { (make) in
            make.centerY.equalToSuperview()
            make.leading.equalToSuperview().inset(24)
            make.size.equalTo(40.scale375())
        }
        
        nameLabel.snp.makeConstraints { (make) in
            make.centerY.equalToSuperview()
            make.height.equalToSuperview()
            make.leading.equalTo(avatarView.snp.trailing).offset(14.scale375())
            make.trailing.equalTo(hangUpButton.snp.leading).offset(-14.scale375())
        }
        
        hangUpButton.snp.makeConstraints { (make) in
            make.centerY.equalToSuperview()
            make.trailing.equalToSuperview().inset(24)
            make.width.equalTo(64.scale375())
            make.height.equalTo(24.scale375())
        }
        
        lineView.snp.makeConstraints { (make) in
            make.bottom.equalToSuperview()
            make.leading.equalTo(nameLabel)
            make.trailing.equalToSuperview().inset(24)
            make.height.equalTo(1)
        }
        
    }
    
}

// MARK: Action

extension UserLinkCell {
    func hangUpButtonClick() {
        guard let seatInfo = seatInfo, let kickoffEventClosure = kickoffEventClosure else { return }
        kickoffEventClosure(seatInfo)
    }
}


private extension String {
    static var anchorHangUpTitle: String {
        internalLocalized("End")
    }
}
