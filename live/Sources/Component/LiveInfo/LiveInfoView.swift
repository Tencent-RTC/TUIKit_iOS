//
//  LiveInfoView.swift
//  TUILiveKit
//
//  Created by WesleyLei on 2024/5/8.
//

import Foundation
import Combine
import RTCCommon
import RTCRoomEngine
import AtomicXCore
import AtomicX

public class LiveInfoView: UIView {
    private let service = LiveInfoService()
    public var state: LiveInfoState {
        service.state
    }
    public var isOwner: Bool {
        state.selfUserId == state.ownerId
    }
    private lazy var roomInfoPanelView = RoomInfoPanelView(service: service, enableFollow: enableFollow)
    private var cancellableSet = Set<AnyCancellable>()
    private let enableFollow: Bool
    private weak var popupViewController: UIViewController?
    
    private lazy var roomOwnerNameLabel: UILabel = {
        let view = UILabel()
        view.font = .customFont(ofSize: 14, weight: .semibold)
        view.textColor = .g8
        view.textAlignment = .left
        view.isUserInteractionEnabled = false
        return view
    }()

    private lazy var avatarView: AtomicAvatar = {
        let avatarSize = AtomicAvatarSize.s
        let avatar = AtomicAvatar(
            content: .icon(image: UIImage()),
            size: avatarSize,
            shape: .round
        )
        return avatar
    }()
    
    private lazy var followButton: AtomicButton = {
        let button = AtomicButton(
            variant: .filled,
            colorType: .primary,
            size: .xsmall,
            content: .textOnly(text: .followText)
        )
        return button
    }()
    
    public func initialize(liveInfo: AtomicXCore.LiveInfo) {
        service.initLiveInfo(liveInfo: liveInfo)
    }
    
    public init(enableFollow: Bool = true, frame: CGRect = .zero) {
        self.enableFollow = enableFollow
        super.init(frame: frame)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    private var isViewReady = false
    public override func didMoveToWindow() {
        super.didMoveToWindow()
        guard !isViewReady else { return }
        constructViewHierarchy()
        activateConstraints()
        bindInteraction()
        isViewReady = true
    }

    private func constructViewHierarchy() {
        addSubview(roomOwnerNameLabel)
        addSubview(avatarView)
        if !isOwner && enableFollow {
            addSubview(followButton)
        }
    }

    private func activateConstraints() {
        avatarView.snp.makeConstraints { make in
            make.leading.equalToSuperview().inset(4.scale375())
            make.centerY.equalToSuperview()
        }

        roomOwnerNameLabel.snp.makeConstraints { make in
            make.leading.equalTo(avatarView.snp.trailing).offset(8.scale375())
            if state.selfUserId != state.ownerId {
                make.trailing.equalTo(followButton.snp.leading).offset(-8.scale375())
            } else {
                make.trailing.equalToSuperview().inset(8.scale375())
            }
            make.centerY.equalToSuperview()
            make.height.equalToSuperview()
        }
        if !isOwner && enableFollow {
            followButton.snp.makeConstraints { make in
                make.trailing.equalToSuperview().inset(8.scale375())
                make.centerY.equalToSuperview()
            }
        }
    }
    
    private func bindInteraction() {
        followButton.setClickAction { [weak self] _ in
            self?.followButtonClick()
        }
        
        subscribeRoomInfoState()
    }
    
    public override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        super.touchesBegan(touches, with: event)
        containerTapAction()
    }
    
    private func followButtonClick() {
        if state.followingList.contains(where: { $0.userId == state.ownerId }) {
            service.unfollowUser(userId: state.ownerId)
        } else {
            service.followUser(userId: state.ownerId)
        }
    }
    
    private func subscribeRoomInfoState() {
        state.$followingList
            .receive(on: RunLoop.main)
            .sink { [weak self] userList in
                guard let self = self else { return }
                let userIdList = userList.map { $0.userId }
                let isFollowing = userIdList.contains(state.ownerId)
                
                if isFollowing {
                    self.followButton.setButtonContent(.iconOnly(icon: internalImage("live_user_followed_icon")))
                    self.followButton.setColorType(.secondary)
                } else {
                    self.followButton.setButtonContent(.textOnly(text: .followText))
                    self.followButton.setColorType(.primary)
                }
                
                self.followButton.isSelected = isFollowing
            }
            .store(in: &cancellableSet)
   
        state.$ownerAvatarUrl
            .receive(on: RunLoop.main)
            .sink { [weak self] avatarUrl in
                guard let self = self else { return }
                self.avatarView.setContent(.url(avatarUrl, placeholder: avatarPlaceholderImage))
            }
            .store(in: &cancellableSet)
        
        state.$ownerName
            .receive(on: RunLoop.main)
            .sink { [weak self] name in
                guard let self = self else { return }
                self.roomOwnerNameLabel.text = name
            }
            .store(in: &cancellableSet)
        
        state.$ownerId
            .receive(on: RunLoop.main)
            .sink { [weak self] ownerId in
                guard let self = self else { return }
                self.updateFollowButtonVisibility(visible: ownerId != self.state.selfUserId)
                self.checkIsFollow(userId: ownerId)
            }
            .store(in: &cancellableSet)
        state.roomDismissedSubject
            .receive(on: RunLoop.main)
            .sink { [weak self] dismissedRoomId in
                guard let self = self, dismissedRoomId == state.roomId else { return }
                popupViewController?.dismiss(animated: true)
                popupViewController = nil
            }
            .store(in: &cancellableSet)
    }
    
    private func checkIsFollow(userId: String) {
        service.isFollow(userId: userId)
    }
    
    private func updateFollowButtonVisibility(visible: Bool) {
        if !enableFollow {
            return
        }
        if visible {
            addSubview(followButton)
            followButton.snp.remakeConstraints { make in
                make.trailing.equalToSuperview().inset(8.scale375())
                make.centerY.equalToSuperview()
            }
            roomOwnerNameLabel.snp.remakeConstraints { make in
                make.leading.equalTo(avatarView.snp.trailing).offset(8.scale375())
                make.trailing.equalTo(followButton.snp.leading).offset(-8.scale375())
                make.centerY.equalToSuperview()
                make.height.equalToSuperview()
            }
        } else {
            followButton.safeRemoveFromSuperview()
            roomOwnerNameLabel.snp.remakeConstraints { make in
                make.leading.equalTo(avatarView.snp.trailing).offset(8.scale375())
                make.trailing.equalToSuperview().inset(8.scale375())
                make.centerY.equalToSuperview()
                make.height.equalToSuperview()
            }
        }
    }
}

extension LiveInfoView {
    @objc func containerTapAction() {
        if !WindowUtils.isPortrait { return }
        if let vc = WindowUtils.getCurrentWindowViewController() {
            popupViewController = vc
            let menuContainerView = MenuContainerView(contentView: roomInfoPanelView)
            menuContainerView.blackAreaClickClosure = { [weak self] in
                guard let self = self else { return }
                popupViewController?.dismiss(animated: true)
                popupViewController = nil
            }
            let viewController = PopupViewController(contentView: menuContainerView)
            popupViewController?.present(viewController, animated: true)
        }
    }
}


fileprivate extension String {
    static let followText = internalLocalized("common_follow_anchor")
}
