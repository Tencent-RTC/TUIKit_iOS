//
//  VRUserManagerPanel.swift
//  TUILiveKit
//
//  Created by adamsfliu on 2024/7/31.
//

import UIKit
import RTCCommon
import Combine
import RTCRoomEngine
import AtomicXCore

class VRUserManagerPanel: RTCBaseView {
    private let liveID: String
    private let toastService: VRToastService
    private let imStore: VoiceRoomIMStore
    private let routerManager: VRRouterManager
    private var cancellableSet: Set<AnyCancellable> = []
    private var seatInfo: TUISeatInfo
    private var isOwner: Bool {
        guard !currentLive.isEmpty else {
            return false
        }
        return currentLive.liveOwner.userID == TUIRoomEngine.getSelfInfo().userId
    }
    
    private let avatarImageView: UIImageView = {
        let imageView = UIImageView(frame: .zero)
        imageView.layer.cornerRadius = 20.scale375()
        imageView.layer.masksToBounds = true
        return imageView
    }()
    
    private let userContentView: UIView = {
        let view = UIView(frame: .zero)
        return view
    }()
    
    private let userNameLabel: UILabel = {
        let label = UILabel(frame: .zero)
        label.textColor = .grayColor
        label.font = .customFont(ofSize: 16, weight: .medium)
        label.adjustsFontSizeToFitWidth = true
        return label
    }()
    
    private let userIdLabel: UILabel = {
        let label = UILabel(frame: .zero)
        label.textColor = .greyColor
        label.font = .customFont(ofSize: 12, weight: .regular)
        return label
    }()
    
    private let followButton: UIButton = {
        let button = UIButton()
        button.backgroundColor = .b1
        button.titleLabel?.font = .customFont(ofSize: 14, weight: .medium)
        button.setTitle(.followText, for: .normal)
        button.setTitleColor(.white, for: .normal)
        button.setImage(internalImage("live_user_followed_icon"), for: .selected)
        button.layer.cornerRadius = 16.scale375Height()
        button.isHidden = true
        return button
    }()
    
    private lazy var featureClickPanel: VRFeatureClickPanel = {
        var designConfig = VRFeatureItemDesignConfig()
        designConfig.backgroundColor = .g3.withAlphaComponent(0.3)
        designConfig.cornerRadius = 10
        designConfig.titleFont = .customFont(ofSize: 12)
        designConfig.type = .imageAboveTitleBottom
        
        let model = VRFeatureClickPanelModel()
        model.itemSize = CGSize(width: 56.scale375(), height: 50.scale375())
        model.itemDiff = 25.scale375()
        model.items.append(VRFeatureItem(normalTitle: .muteText,
                                       normalImage: internalImage("live_anchor_mute_icon"),
                                       selectedTitle: .unmuteText,
                                       selectedImage: internalImage("live_anchor_unmute_icon"),
                                       isSelected: seatInfo.isAudioLocked,
                                       designConfig: designConfig,
                                       actionClosure: { [weak self] button in
            guard let self = self else { return }
            self.muteClick(sender: button)
        }))
        model.items.append(VRFeatureItem(normalTitle: .kickoffText,
                                       normalImage: internalImage("live_anchor_kickoff_icon"),
                                       designConfig: designConfig,
                                       actionClosure: { [weak self] button in
            guard let self = self else { return }
            self.kickoffClick()
        }))
        let featureClickPanel = VRFeatureClickPanel(model: model)
        featureClickPanel.isHidden = !isOwner
        return featureClickPanel
    }()
    
    init(liveID: String,
         imStore: VoiceRoomIMStore,
         toastService:VRToastService,
         routerManager: VRRouterManager,
         seatInfo: TUISeatInfo) {
        self.liveID = liveID
        self.imStore = imStore
        self.toastService = toastService
        self.routerManager = routerManager
        self.seatInfo = seatInfo
        super.init(frame: .zero)
        backgroundColor = .g2
        layer.cornerRadius = 16
        layer.maskedCorners = [.layerMinXMinYCorner, .layerMaxXMinYCorner]
    }
    
    override func constructViewHierarchy() {
        addSubview(avatarImageView)
        addSubview(userContentView)
        userContentView.addSubview(userNameLabel)
        userContentView.addSubview(userIdLabel)
        addSubview(followButton)
        if isOwner {
            addSubview(featureClickPanel)
        }
    }
    
    override func activateConstraints() {
        avatarImageView.snp.makeConstraints { make in
            make.leading.top.equalToSuperview().offset(24.scale375())
            make.size.equalTo(CGSize(width: 40.scale375(), height: 40.scale375()))
            if !isOwner {
                make.bottom.equalToSuperview().offset(-24.scale375())
            }
        }
        
        userContentView.snp.makeConstraints { make in
            make.leading.equalTo(avatarImageView.snp.trailing).offset(12.scale375())
            make.top.bottom.equalTo(avatarImageView)
        }
        
        userNameLabel.snp.makeConstraints { make in
            make.leading.equalToSuperview()
            make.top.equalToSuperview()
            make.width.lessThanOrEqualTo(150.scale375())
        }
        
        userIdLabel.snp.makeConstraints { make in
            make.leading.bottom.equalToSuperview()
            make.width.lessThanOrEqualTo(150.scale375())
        }
        
        followButton.snp.makeConstraints { make in
            make.trailing.equalToSuperview().offset(-24.scale375())
            make.centerY.equalTo(userContentView.snp.centerY)
            make.size.equalTo(CGSizeMake(70.scale375(), 32.scale375Height()))
        }
        
        if isOwner {
            featureClickPanel.snp.makeConstraints { make in
                make.top.equalTo(avatarImageView.snp.bottom).offset(30.scale375Height())
                make.leading.equalTo(avatarImageView.snp.leading)
                make.bottom.equalToSuperview().offset(-24.scale375())
            }
        }
    }
    
    override func bindInteraction() {
        subscribeMyFollowListState()
        subscribeSeatInfoState()
        followButton.addTarget(self, action:#selector(followButtonClick(sender:)), for: .touchUpInside)
    }
    
    override func setupViewStyle() {
        avatarImageView.kf.setImage(with: URL(string: seatInfo.avatarUrl ?? ""), placeholder: UIImage.avatarPlaceholderImage)
        userNameLabel.text = seatInfo.userName
        userIdLabel.text = "ID: " + (seatInfo.userId ?? "")
    }
    
    deinit {
        cancellableSet.forEach { $0.cancel() }
        cancellableSet.removeAll()
    }
}

extension VRUserManagerPanel {
    private func subscribeMyFollowListState() {
        imStore.subscribeState(StateSelector(keyPath: \VoiceRoomIMState.myFollowingUserList))
            .receive(on: RunLoop.main)
            .sink { [weak self] followUserList in
                guard let self = self else { return }
                self.followButton.isHidden = false
                if followUserList.map({ $0.userId }).contains(where: { [weak self] in
                    guard let self = self else { return false }
                    return $0 == self.seatInfo.userId
                }) {
                    self.followButton.isSelected = true
                    self.followButton.backgroundColor = .g3.withAlphaComponent(0.3)
                    self.followButton.setTitle("", for: .normal)
                } else {
                    self.followButton.isSelected = false
                    self.followButton.backgroundColor = .deepSeaBlueColor
                    self.followButton.setTitle(.followText, for: .normal)
                }
            }
            .store(in: &cancellableSet)
    }
    
    private func subscribeSeatInfoState() {
        seatStore.state
            .subscribe(StatePublisherSelector(keyPath: \LiveSeatState.seatList))
            .removeDuplicates()
            .receive(on: RunLoop.main)
            .sink { [weak self] seatInfoList in
                guard let self = self else { return }
                guard seatInfo.index >= 0 && seatInfo.index < seatInfoList.count else {
                    routerManager.router(action: .dismiss())
                    return
                }
                self.seatInfo = TUISeatInfo(from: seatInfoList[seatInfo.index])
                if (seatInfo.userId ?? "").isEmpty {
                    routerManager.router(action: .dismiss())
                }
            }
            .store(in: &cancellableSet)
    }
}

extension VRUserManagerPanel {
    @objc
    private func followButtonClick(sender: UIButton) {
        if sender.isSelected {
            imStore.unfollowUser(TUIUserInfo(seatInfo: seatInfo), completion: nil)
        } else {
            imStore.followUser(TUIUserInfo(seatInfo: seatInfo), completion: nil)
        }
    }
    
    @objc
    private func muteClick(sender: VRFeatureItemButton) {
        seatInfo.isAudioLocked = !seatInfo.isAudioLocked
        sender.isSelected = seatInfo.isAudioLocked
        
        let lockSeat = TUISeatLockParams()
        lockSeat.lockAudio = seatInfo.isAudioLocked
        lockSeat.lockVideo = seatInfo.isVideoLocked
        lockSeat.lockSeat = seatInfo.isLocked
        
        TUIRoomEngine.sharedInstance().lockSeatByAdmin(seatInfo.index, lockMode: lockSeat) {
        } onError: { [weak self] error, message in
            guard let self = self else { return }
            let err = InternalError(code: error.rawValue, message: message)
            toastService.showToast(err.localizedMessage)
        }
    }
    
    @objc
    private func kickoffClick() {
        seatStore.kickUserOutOfSeat(userID:  seatInfo.userId ?? "") { [weak self] result in
            guard let self = self else { return }
            if case .failure(let error) = result {
                let err = InternalError(errorInfo: error)
                toastService.showToast(err.localizedMessage)
            }
        }
        routerManager.router(action: .dismiss())
    }
}

extension VRUserManagerPanel {
    var currentLive: AtomicLiveInfo {
        return LiveListStore.shared.state.value.currentLive
    }
    
    var seatStore: LiveSeatStore {
        return LiveSeatStore.create(liveID: liveID)
    }
}

fileprivate extension String {
    static let followText = internalLocalized("Follow")
    static let muteText = internalLocalized("Mute")
    static let unmuteText = internalLocalized("Unmute")
    static let kickoffText = internalLocalized("End")
}
