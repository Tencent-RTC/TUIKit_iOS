//
//  UserRequestLinkCell.swift
//  TUILiveKit
//
//  Created by WesleyLei on 2023/10/24.
//

import Foundation
import AtomicXCore
import AtomicX

class UserRequestLinkCell: LinkMicBaseCell {
    var respondEventClosure: ((LiveUserInfo, Bool, @escaping () -> Void) -> Void)?
    private var isPending = false
    
    private lazy var acceptButton: AtomicButton = {
        let button = AtomicButton(
            variant: .filled,
            colorType: .primary,
            size: .xsmall,
            content: .textOnly(text: .anchorLinkAgreeTitle)
        )
        button.setClickAction { [weak self] _ in
            self?.acceptButtonClick()
        }
        return button
    }()
    
    private lazy var rejectButton: AtomicButton = {
        let button = AtomicButton(
            variant: .outlined,
            colorType: .primary,
            size: .xsmall,
            content: .textOnly(text: .anchorLinkRejectTitle)
        )
        button.setClickAction { [weak self] _ in
            self?.rejectButtonClick()
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
        contentView.addSubview(acceptButton)
        contentView.addSubview(rejectButton)
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
            make.trailing.equalTo(acceptButton.snp.leading).offset(-14.scale375())
        }
        
        rejectButton.snp.makeConstraints { (make) in
            make.centerY.equalToSuperview()
            make.trailing.equalToSuperview().inset(24)
            make.width.equalTo(64.scale375())
            make.height.equalTo(24.scale375())
        }
        
        acceptButton.snp.makeConstraints { (make) in
            make.centerY.equalToSuperview()
            make.trailing.equalTo(rejectButton.snp.leading).offset(-14.scale375())
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

extension UserRequestLinkCell {
    func acceptButtonClick() {
        guard let seatApplication = seatApplication, let respondEventClosure = respondEventClosure, !isPending else { return }
        isPending = true
        respondEventClosure(seatApplication, true) { [weak self] in
            guard let self = self else { return }
            isPending = false
        }
    }
    
    func rejectButtonClick() {
        guard let seatApplication = seatApplication, let respondEventClosure = respondEventClosure, !isPending else { return }
        isPending = true
        respondEventClosure(seatApplication, false) { [weak self] in
            guard let self = self else { return }
            isPending = false
        }
    }
}

private extension String {
    static var anchorLinkAgreeTitle: String {
        internalLocalized("live_barrage_agree")
    }
    
    static var anchorLinkRejectTitle: String {
        internalLocalized("common_reject")
    }

}
