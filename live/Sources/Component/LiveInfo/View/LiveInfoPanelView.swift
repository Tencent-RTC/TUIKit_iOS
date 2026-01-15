//
//  LiveInfoPanelView.swift
//  TUILiveKit
//
//  Created by krabyu on 2024/5/22.
//

import Foundation
import Combine
import RTCCommon
import RTCRoomEngine
import AtomicX

class RoomInfoPanelView: RTCBaseView {
    private var cancellableSet = Set<AnyCancellable>()
    private let service: LiveInfoService
    private let state: LiveInfoState
    private var isOwner: Bool {
        state.ownerId == state.selfUserId
    }
    private let enableFollow: Bool
    
    private lazy var avatarView: AtomicAvatar = {
        let avatarSize = AtomicAvatarSize.l
        let avatar = AtomicAvatar(
            content: .icon(image: UIImage()),
            size: avatarSize,
            shape: .round
        )
        return avatar
    }()
    
    private let backgroundView: UIView = {
        let view = UIView()
        view.backgroundColor = .g2
        view.layer.cornerRadius = 12.scale375()
        view.layer.maskedCorners = [.layerMinXMinYCorner, .layerMaxXMinYCorner]
        return view
    }()
    
    private lazy var titleLabel: AtomicLabel = {
        let label = AtomicLabel("") { theme in
            LabelAppearance(textColor: theme.color.textColorPrimary,
                            font: theme.typography.Regular16)
        }
        label.textAlignment = .center
        return label
    }()
    
    private lazy var roomIdLabel: AtomicLabel = {
        let label = AtomicLabel(.localizedReplace(.roomIdText, replace: state.roomId)) { theme in
            LabelAppearance(textColor: theme.color.textColorSecondary,
                            font: theme.typography.Regular12)
        }
        return label
    }()
    
    // TODO: gg 这个label RTL方向始终不对，后面再看
    private lazy var fansLabel: AtomicLabel = {
        let label = AtomicLabel("") { theme in
            LabelAppearance(textColor: theme.color.textColorSecondary,
                            font: theme.typography.Regular12)
        }
        return label
    }()
    
    private lazy var followButton: AtomicButton = {
        let button = AtomicButton(
            variant: .filled,
            colorType: .primary,
            size: .large,
            content: .textOnly(text: .followText)
        )
        return button
    }()
    
    init(service: LiveInfoService, enableFollow: Bool) {
        self.service = service
        self.state = service.state
        self.enableFollow = enableFollow
        super.init(frame: .zero)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    deinit {
        print("deinit \(type(of: self))")
    }
    
    override func constructViewHierarchy() {
        addSubview(backgroundView)
        addSubview(titleLabel)
        addSubview(roomIdLabel)
        if enableFollow {
            addSubview(fansLabel)
        }
        if !isOwner && enableFollow {
            addSubview(followButton)
        }
        addSubview(avatarView)
    }
    
    override func activateConstraints() {
        avatarView.snp.makeConstraints { make in
            make.top.centerX.equalToSuperview()
        }
        var totalHeight = isOwner ? 159 : 212
        if !enableFollow {
            totalHeight = 132
        }
        backgroundView.snp.makeConstraints { make in
            make.top.equalToSuperview().offset(29.scale375Height())
            make.leading.trailing.bottom.equalToSuperview()
            make.height.equalTo(totalHeight.scale375Height())
        }
        titleLabel.snp.makeConstraints { make in
            make.top.equalToSuperview().offset(65.scale375Height())
            make.leading.trailing.equalToSuperview()
            make.height.equalTo(24.scale375Height())
        }
        roomIdLabel.snp.makeConstraints { make in
            make.top.equalTo(titleLabel.snp.bottom).offset(10.scale375Height())
            make.centerX.equalToSuperview()
            make.height.equalTo(17.scale375Height())
        }
        if enableFollow {
            fansLabel.snp.makeConstraints { make in
                make.top.equalTo(roomIdLabel.snp.bottom).offset(10.scale375Height())
                make.centerX.equalToSuperview()
                make.height.equalTo(17.scale375Height())
            }
        }
        if !isOwner && enableFollow {
            followButton.snp.makeConstraints { make in
                make.top.equalTo(fansLabel.snp.bottom).offset(24.scale375Height())
                make.leading.equalToSuperview().offset(15.scale375Width())
                make.trailing.equalToSuperview().offset(-16.scale375Width())
                make.height.equalTo(40.scale375Height())
            }
        }
    }
    
    override func bindInteraction() {
        followButton.setClickAction { [weak self] _ in
            self?.followButtonClick()
        }

        subscribeRoomInfoPanelState()
    }
    
    override func layoutSubviews() {
        super.layoutSubviews()
        updateFansView()
    }
    
    private func updateFansView() {
        service.getFansNumber()
    }
    
    private func followButtonClick() {
        if state.followingList.contains(where: { $0.userId == state.ownerId }) {
            service.unfollowUser(userId: state.ownerId)
        } else {
            service.followUser(userId: state.ownerId)
        }
    }
    
    private func updateFollowButtonVisibility(visible: Bool) {
        if !enableFollow {
            return
        }
        if visible {
            addSubview(followButton)
            followButton.snp.makeConstraints { make in
                make.top.equalTo(fansLabel.snp.bottom).offset(24.scale375Height())
                make.leading.equalToSuperview().offset(15.scale375Width())
                make.trailing.equalToSuperview().offset(-16.scale375Width())
                make.height.equalTo(40.scale375Height())
            }
        } else {
            followButton.safeRemoveFromSuperview()
        }
    }
    
    private func subscribeRoomInfoPanelState() {
        state.$ownerAvatarUrl
            .receive(on: RunLoop.main)
            .sink { [weak self] avatarUrl in
                guard let self = self else { return }
                self.avatarView.setContent(.url(avatarUrl, placeholder: UIImage.avatarPlaceholderImage))
            }
            .store(in: &cancellableSet)
        
        state.$ownerName
            .receive(on: RunLoop.main)
            .sink { [weak self] name in
                guard let self = self else { return }
                self.titleLabel.text = name
            }
            .store(in: &cancellableSet)
        
        state.$fansNumber
            .receive(on: RunLoop.main)
            .sink { [weak self] count in
                guard let self = self else { return }
                self.fansLabel.text = .localizedReplace(.fansCountText, replace: "\(count)")
            }
            .store(in: &cancellableSet)
        
        state.$followingList
            .receive(on: RunLoop.main)
            .sink { [weak self] userList in
                guard let self = self else { return }
                let userIdList = userList.map { $0.userId }
                let isFollowing = userIdList.contains(self.state.ownerId)
                
                if isFollowing {
                    self.followButton.setButtonContent(.textOnly(text: .unfollowText))
                    self.followButton.setColorType(.secondary)
                } else {
                    self.followButton.setButtonContent(.textOnly(text: .followText))
                    self.followButton.setColorType(.primary)
                }
                
                self.followButton.isSelected = isFollowing
            }
            .store(in: &cancellableSet)
        
        state.$ownerId
            .receive(on: RunLoop.main)
            .sink { [weak self] ownerId in
                guard let self = self else { return }
                self.updateFollowButtonVisibility(visible: ownerId != self.state.selfUserId)
            }
            .store(in: &cancellableSet)
    }
}

// MARK: Action

fileprivate extension String {
    static let roomIdText = internalLocalized("common_roominfo_liveroom_id")
    static let fansCountText = internalLocalized("xxx Fans")
    static let followText = internalLocalized("common_follow_anchor")
    static let unfollowText = internalLocalized("common_unfollow_anchor")
}
