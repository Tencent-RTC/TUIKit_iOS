//
//  UserManagePanelView.swift
//  TUILiveKit
//
//  Created by jeremiawang on 2025/2/17.
//

import AtomicXCore
import Combine
import ImSDK_Plus
import RTCCommon
import RTCRoomEngine
import AtomicX

class AnchorUserManagePanelView: RTCBaseView {
    private let store: AnchorStore
    private let routerManager: AnchorRouterManager
    private let userManagePanelType: AnchorUserManagePanelType
    private let user: LiveUserInfo
    @Published private var isFollow: Bool = false
    private var isMessageDisabled = false
    
    private var isSelf: Bool {
        user.userID == store.selfUserID
    }

    private var isOwner: Bool {
        user.userID == store.liveListState.currentLive.liveOwner.userID
    }

    private var isSelfOwner: Bool {
        store.selfUserID == store.liveListState.currentLive.liveOwner.userID
    }

    private var isSelfMuted: Bool {
        if let selfInfo = store.seatState.seatList.filter({ $0.userInfo.userID == store.selfUserID }).first {
            return selfInfo.userInfo.microphoneStatus == .off
        }
        return true
    }

    private var isSelfCameraOpened: Bool {
        if let selfInfo = store.seatState.seatList.filter({ $0.userInfo.userID == store.selfUserID }).first {
            return selfInfo.userInfo.cameraStatus == .on
        }
        return false
    }

    private var isSelfOnSeat: Bool {
        store.coGuestState.connected.isOnSeat()
    }

    private var isAudioLocked: Bool {
        !(store.coGuestState.connected.filter { $0.userID == user.userID }.first?.allowOpenMicrophone ?? true)
    }

    private var isCameraLocked: Bool {
        !(store.coGuestState.connected.filter { $0.userID == user.userID }.first?.allowOpenCamera ?? true)
    }

    private var cancellableSet = Set<AnyCancellable>()
    
    init(user: LiveUserInfo, store: AnchorStore, routerManager: AnchorRouterManager, type: AnchorUserManagePanelType) {
        self.user = user
        self.store = store
        self.routerManager = routerManager
        self.userManagePanelType = type
        super.init(frame: .zero)
    }
    
    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    deinit {
        debugPrint("deinit \(self)")
    }
    
    private lazy var userInfoView: UIView = {
        let view = UIView()
        return view
    }()
    
    private lazy var avatarView: AtomicAvatar = {
        let avatar = AtomicAvatar(
            content: .url("",placeholder: UIImage.avatarPlaceholderImage),
            size: .m,
            shape: .round
        )
        return avatar
    }()
    
    private lazy var userNameLabel: UILabel = {
        let label = UILabel()
        label.text = user.userName.isEmpty ? user.userID : user.userName
        label.font = .customFont(ofSize: 16)
        label.textColor = .g7
        return label
    }()
    
    private lazy var idLabel: UILabel = {
        let label = UILabel()
        label.font = .customFont(ofSize: 12)
        label.text = "ID: " + user.userID
        label.textColor = .greyColor
        return label
    }()
    
    private lazy var followButton: AtomicButton = {
        let button = AtomicButton(
            variant: .filled,
            colorType: .primary,
            size: .medium,
            content: .textOnly(text: .followText)
        )
        button.isHidden = isSelf
        return button
    }()
    
    private lazy var featureClickPanel: AnchorFeatureClickPanel = {
        let model = generateFeatureClickPanelModel()
        let featureClickPanel = AnchorFeatureClickPanel(model: model)
        return featureClickPanel
    }()

    override func constructViewHierarchy() {
        layer.masksToBounds = true
        addSubview(userInfoView)
        userInfoView.addSubview(avatarView)
        userInfoView.addSubview(userNameLabel)
        userInfoView.addSubview(idLabel)
        userInfoView.addSubview(followButton)
        addSubview(featureClickPanel)
    }
    
    override func activateConstraints() {
        userInfoView.snp.makeConstraints { make in
            make.leading.trailing.top.equalToSuperview().inset(24)
            make.height.equalTo(43.scale375())
        }
        avatarView.snp.makeConstraints { make in
            make.leading.centerY.equalToSuperview()
        }
        userNameLabel.snp.makeConstraints { make in
            make.top.equalToSuperview()
            make.leading.equalTo(avatarView.snp.trailing).offset(12.scale375())
            make.height.equalTo(20.scale375())
            make.width.lessThanOrEqualTo(170.scale375())
        }
        idLabel.snp.makeConstraints { make in
            make.leading.equalTo(userNameLabel)
            make.top.equalTo(userNameLabel.snp.bottom).offset(5.scale375())
            make.height.equalTo(17.scale375())
            make.width.lessThanOrEqualTo(200.scale375())
        }
        followButton.snp.makeConstraints { make in
            make.trailing.centerY.equalToSuperview()
            make.width.equalTo(67.scale375())
            make.height.equalTo(32.scale375())
        }
        featureClickPanel.snp.makeConstraints { make in
            make.top.equalTo(userInfoView.snp.bottom).offset(21.scale375())
            make.leading.equalTo(userInfoView)
            make.bottom.equalToSuperview()
        }
    }
    
    override func bindInteraction() {
        subscribeState()
        followButton.setClickAction { [weak self] _ in
            self?.followButtonClick()
        }
    }
    
    override func setupViewStyle() {
        backgroundColor = .g2
        layer.cornerRadius = 12
        layer.maskedCorners = [.layerMinXMinYCorner, .layerMaxXMinYCorner]
        userNameLabel.text = user.userName.isEmpty ? user.userID : user.userName
        avatarView.setContent(.url(user.avatarURL, placeholder: UIImage.avatarPlaceholderImage))
        checkFollowStatus()
    }
    
    private func subscribeState() {
        $isFollow.receive(on: RunLoop.main)
            .removeDuplicates()
            .sink { [weak self] isFollow in
                guard let self = self else { return }
                if isFollow {
                    followButton.setButtonContent(.iconOnly(icon: internalImage("live_user_followed_icon")))
                    followButton.setVariant(.filled)
                    followButton.setColorType(.secondary)
                } else {
                    followButton.setButtonContent(.textOnly(text: .followText))
                    followButton.setVariant(.filled)
                    followButton.setColorType(.primary)
                }
            }
            .store(in: &cancellableSet)
        
        store.audienceStore.state.subscribe(StatePublisherSelector(keyPath: \LiveAudienceState.messageBannedUserList))
            .removeDuplicates()
            .receive(on: RunLoop.main)
            .sink { [weak self] userList in
                guard let self = self else { return }
                let userID = user.userID
                isMessageDisabled = userList.contains(where: { $0.userID == userID })
                updateFeatureItems()
            }
            .store(in: &cancellableSet)
        
        let microphoneStatusPublisher = store.subscribeState(StatePublisherSelector(keyPath: \DeviceState.microphoneStatus))
        let guestConnectedPublisher = store.subscribeState(StatePublisherSelector(keyPath: \CoGuestState.connected))
        let hostConnectedPublisher = store.subscribeState(StatePublisherSelector(keyPath: \CoHostState.connected))
        
        store.subscribeState(StatePublisherSelector(keyPath: \DeviceState.cameraStatus))
            .removeDuplicates()
            .combineLatest(microphoneStatusPublisher.removeDuplicates(),
                           guestConnectedPublisher.removeDuplicates(),
                           hostConnectedPublisher.removeDuplicates())
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in
                guard let self = self else { return }
                updateFeatureItems()
            }
            .store(in: &cancellableSet)
        
        store.subscribeState(StatePublisherSelector(keyPath: \CoGuestState.connected))
            .removeDuplicates()
            .receive(on: RunLoop.main)
            .sink { [weak self] seatList in
                guard let self = self else { return }
                let currentUserID = user.userID
                guard userManagePanelType == .mediaAndSeat,
                      currentUserID != store.liveListState.currentLive.liveOwner.userID else { return }
                if !seatList.contains(where: { $0.userID == currentUserID }) {
                    routerManager.router(action: .dismiss())
                }
            }
            .store(in: &cancellableSet)
    }
    
    private func checkFollowStatus() {
        V2TIMManager.sharedInstance().checkFollowType(userIDList: [user.userID]) { [weak self] checkResultList in
            guard let self = self, let result = checkResultList?.first else { return }
            if result.followType == .FOLLOW_TYPE_IN_BOTH_FOLLOWERS_LIST || result.followType == .FOLLOW_TYPE_IN_MY_FOLLOWING_LIST {
                self.isFollow = true
            } else {
                self.isFollow = false
            }
        } fail: { _, _ in
        }
    }
    
    private func generateFeatureClickPanelModel() -> AnchorFeatureClickPanelModel {
        let model = AnchorFeatureClickPanelModel()
        model.itemSize = CGSize(width: 56.scale375(), height: 56.scale375Height())
        model.itemDiff = 12.scale375()
        switch userManagePanelType {
        case .messageAndKickOut:
            model.items.append(disableChatItem)
            model.items.append(kickOutItem)
        case .mediaAndSeat:
            if isSelf {
                model.items.append(muteSelfAudioItem)
                if !isOwner {
                    model.items.append(closeSelfCameraItem)
                }
                if isSelfCameraOpened {
                    model.items.append(flipItem)
                }
                if !isOwner && isSelfOnSeat {
                    model.items.append(leaveSeatItem)
                }
            } else if isSelfOwner {
                model.items.append(disableAudioItem)
                model.items.append(disableCameraItem)
                model.items.append(kickOffSeatItem)
            }
        case .userInfo:
            break
        }
        return model
    }
    
    private func updateFeatureItems() {
        if isSelf {
            muteSelfAudioItem.isSelected = isSelfMuted
            muteSelfAudioItem.isDisabled = isAudioLocked
            closeSelfCameraItem.isSelected = !isSelfCameraOpened
            closeSelfCameraItem.isDisabled = isCameraLocked
        } else {
            debugPrint("test: isAudioLocked:\(isAudioLocked), videoLock:\(isCameraLocked)")
            disableAudioItem.isSelected = isAudioLocked
            disableCameraItem.isSelected = isCameraLocked
        }
        if userManagePanelType == .messageAndKickOut {
            disableChatItem.isSelected = isMessageDisabled
        }
        let newItems = generateFeatureClickPanelModel().items
        featureClickPanel.updateFeatureItems(newItems: newItems)
    }
    
    private lazy var designConfig: AnchorFeatureItemDesignConfig = {
        var designConfig = AnchorFeatureItemDesignConfig()
        designConfig.type = .imageAboveTitleBottom
        designConfig.imageTopInset = 14.scale375()
        designConfig.imageLeadingInset = 14.scale375()
        designConfig.imageSize = CGSize(width: 28.scale375(), height: 28.scale375())
        designConfig.titileColor = .g7
        designConfig.titleFont = .customFont(ofSize: 12)
        designConfig.backgroundColor = .g3.withAlphaComponent(0.3)
        designConfig.cornerRadius = 8.scale375Width()
        designConfig.titleHeight = 20.scale375Height()
        return designConfig
    }()
    
    private lazy var disableChatItem: AnchorFeatureItem = .init(normalTitle: .disableChatText,
                                                                normalImage: internalImage("live_enable_chat_icon"),
                                                                selectedTitle: .enableChatText,
                                                                selectedImage: internalImage("live_disable_chat_icon"),
                                                                isSelected: isMessageDisabled,
                                                                designConfig: designConfig,
                                                                actionClosure: { [weak self] sender in
                                                                    guard let self = self else { return }
                                                                    self.disableChatClick(sender)
                                                                })
    
    private lazy var kickOutItem: AnchorFeatureItem = .init(normalTitle: .kickOutOfRoomText,
                                                            normalImage: internalImage("live_anchor_kickout_icon"),
                                                            designConfig: designConfig,
                                                            actionClosure: { [weak self] _ in
                                                                guard let self = self else { return }
                                                                self.kickOutOfRoomClick()
                                                            })
    
    private lazy var muteSelfAudioItem: AnchorFeatureItem = .init(normalTitle: .muteAudioText,
                                                                  normalImage: internalImage("live_anchor_unmute_icon"),
                                                                  selectedTitle: .unmuteAudioText,
                                                                  selectedImage: internalImage("live_anchor_mute_icon"),
                                                                  isSelected: isSelfMuted,
                                                                  isDisabled: isAudioLocked,
                                                                  designConfig: designConfig,
                                                                  actionClosure: { [weak self] sender in
                                                                      guard let self = self else { return }
                                                                      self.muteSelfAudioClick(sender)
                                                                  })
    
    private lazy var closeSelfCameraItem: AnchorFeatureItem = .init(normalTitle: .closeCameraText,
                                                                    normalImage: internalImage("live_open_camera_icon"),
                                                                    selectedTitle: .opneCameraText,
                                                                    selectedImage: internalImage("live_close_camera_icon"),
                                                                    isSelected: !isSelfCameraOpened,
                                                                    isDisabled: isCameraLocked,
                                                                    designConfig: designConfig,
                                                                    actionClosure: { [weak self] sender in
                                                                        guard let self = self else { return }
                                                                        self.closeSelfCameraClick(sender)
                                                                    })
    
    private lazy var flipItem: AnchorFeatureItem = .init(normalTitle: .filpText,
                                                         normalImage: internalImage("live_video_setting_flip"),
                                                         designConfig: designConfig,
                                                         actionClosure: { [weak self] _ in
                                                             guard let self = self else { return }
                                                             self.flipClick()
                                                         })
    
    private lazy var leaveSeatItem: AnchorFeatureItem = .init(normalTitle: .disconnectText,
                                                              normalImage: internalImage("live_leave_seat_icon"),
                                                              designConfig: designConfig,
                                                              actionClosure: { [weak self] _ in
                                                                  guard let self = self else { return }
                                                                  self.leaveSeatClick()
                                                              })
    
    private lazy var disableAudioItem: AnchorFeatureItem = .init(normalTitle: .disableAudioText,
                                                                 normalImage: internalImage("live_anchor_unmute_icon"),
                                                                 selectedTitle: .enableAudioText,
                                                                 selectedImage: internalImage("live_disable_audio_icon"),
                                                                 isSelected: isAudioLocked,
                                                                 designConfig: designConfig,
                                                                 actionClosure: { [weak self] _ in
                                                                     guard let self = self else { return }
                                                                     self.disableAudioClick()
                                                                 })
    
    private lazy var disableCameraItem: AnchorFeatureItem = .init(normalTitle: .disableCameraText,
                                                                  normalImage: internalImage("live_open_camera_icon"),
                                                                  selectedTitle: .enableCameraText,
                                                                  selectedImage: internalImage("live_disable_camera_icon"),
                                                                  isSelected: isCameraLocked,
                                                                  designConfig: designConfig,
                                                                  actionClosure: { [weak self] _ in
                                                                      guard let self = self else { return }
                                                                      self.disableCameraClick()
                                                                  })
    
    private lazy var kickOffSeatItem: AnchorFeatureItem = .init(normalTitle: .hangupText,
                                                                normalImage: internalImage("live_leave_seat_icon"),
                                                                designConfig: designConfig,
                                                                actionClosure: { [weak self] _ in
                                                                    guard let self = self else { return }
                                                                    self.kickOffSeatClick()
                                                                })
}

// MARK: - Action

extension AnchorUserManagePanelView {
    private func followButtonClick() {
        if isFollow {
            V2TIMManager.sharedInstance().unfollowUser(userIDList: [user.userID]) { [weak self] followResultList in
                guard let self = self, let result = followResultList?.first else { return }
                if result.resultCode == 0 {
                    isFollow = false
                } else {
                    store.toastSubject.send(("code: \(result.resultCode), message: \(String(describing: result.resultInfo))",.error))
                }
            } fail: { [weak self] code, message in
                guard let self = self else { return }
                store.toastSubject.send(("code: \(code), message: \(String(describing: message))",.error))
            }
        } else {
            V2TIMManager.sharedInstance().followUser(userIDList: [user.userID]) { [weak self] followResultList in
                guard let self = self, let result = followResultList?.first else { return }
                if result.resultCode == 0 {
                    isFollow = true
                } else {
                    store.toastSubject.send(("code: \(result.resultCode), message: \(String(describing: result.resultInfo))",.error))
                }
            } fail: { [weak self] code, message in
                guard let self = self else { return }
                store.toastSubject.send(("code: \(code), message: \(String(describing: message))",.error))
            }
        }
    }
    
    private func disableChatClick(_ sender: AnchorFeatureItemButton) {
        store.audienceStore.disableSendMessage(userID: user.userID, isDisable: !isMessageDisabled) { [weak self, weak sender] result in
            guard let self = self else { return }
            switch result {
            case .success(()):
                isMessageDisabled = !isMessageDisabled
                sender?.isSelected = isMessageDisabled
            case .failure(let err):
                let error = InternalError(code: err.code, message: err.message)
                    store.toastSubject.send((error.localizedMessage, .error))
            }
        }
        routerManager.router(action: .dismiss())
    }
    
    private func kickOutOfRoomClick() {
        let cancelButton = AlertButtonConfig(text: .cancelText, type: .grey) { alertView in
            alertView.dismiss()
        }
        
        let confirmButton = AlertButtonConfig(text: .kickOutOfRoomConfirmText, type: .red) { [weak self] alertView in
            guard let self = self else { return }
            store.audienceStore.kickUserOutOfRoom(userID: user.userID) { [weak self] result in
                guard let self = self else { return }
                switch result {
                case .failure(let err):
                    let error = InternalError(code: err.code, message: err.message)
                    store.toastSubject.send((error.localizedMessage, .error))
                default: break
                }
            }
            alertView.dismiss()
            routerManager.dismiss()
        }
        let alertConfig = AlertViewConfig(title: .localizedReplace(.kickOutAlertText,
                                                                   replace: user.userName.isEmpty ? user.userID : user.userName),
                                          cancelButton: cancelButton,
                                          confirmButton: confirmButton)
        let alertView = AtomicAlertView(config: alertConfig)
        alertView.show()
    }
    
    private func muteSelfAudioClick(_ sender: AnchorFeatureItemButton) {
        if isSelfMuted {
            store.seatStore.unmuteMicrophone { [weak self, weak sender] result in
                guard let self = self else { return }
                switch result {
                case .success(()):
                    sender?.isSelected = isSelfMuted
                case .failure(let err):
                    let err = InternalError(code: err.code, message: err.message)
                    store.toastSubject.send((err.localizedMessage, .error))
                }
            }
        } else {
            store.seatStore.muteMicrophone()
            sender.isSelected = !sender.isSelected
        }
        routerManager.router(action: .dismiss())
    }
    
    private func closeSelfCameraClick(_ sender: AnchorFeatureItemButton) {
        if isSelfCameraOpened {
            store.deviceStore.closeLocalCamera()
            sender.isSelected = !sender.isSelected
        } else {
            store.deviceStore.openLocalCamera(isFront: store.deviceState.isFrontCamera) { [weak self, weak sender] result in
                guard let self = self else { return }
                switch result {
                case .success(()):
                    sender?.isSelected = !isSelfCameraOpened
                case .failure(let err):
                    let err = InternalError(code: err.code, message: err.message)
                    store.toastSubject.send((err.localizedMessage, .error))
                }
            }
        }
        routerManager.router(action: .dismiss())
    }
    
    private func flipClick() {
        store.deviceStore.switchCamera(isFront: !store.deviceState.isFrontCamera)
        routerManager.router(action: .dismiss())
    }
    
    private func leaveSeatClick() {
        let cancelButton = AlertButtonConfig(text: .cancelText, type: .grey) { alertView in
            alertView.dismiss()
        }
        
        let confirmButton = AlertButtonConfig(text: .disconnectText, type: .red) { [weak self] alertview in
            guard let self = self else { return }
            store.coGuestStore.disConnect { [weak self] result in
                guard let self = self else { return }
                switch result {
                case .success(()):
                    store.deviceStore.closeLocalCamera()
                    store.deviceStore.closeLocalMicrophone()
                case .failure(let err):
                    let err = InternalError(code: err.code, message: err.message)
                    store.toastSubject.send((err.localizedMessage, .error))
                }
            }
            alertview.dismiss()
            routerManager.dismiss()
        }
        
        let alertConfig = AlertViewConfig(title: .leaveSeatAlertText,
                                          cancelButton: cancelButton,
                                          confirmButton: confirmButton)
        let alertView = AtomicAlertView(config: alertConfig)
        alertView.show()
    }
    
    private func disableAudioClick() {
        if isAudioLocked {
            store.seatStore.openRemoteMicrophone(userID: user.userID, policy: .unlockOnly) { [weak self] result in
                guard let self = self else { return }
                switch result {
                case .failure(let err):
                    let error = InternalError(code: err.code, message: err.message)
                    store.toastSubject.send((error.localizedMessage, .error))
                default: break
                }
            }
        } else {
            store.seatStore.closeRemoteMicrophone(userID: user.userID) { [weak self] result in
                guard let self = self else { return }
                switch result {
                case .failure(let err):
                    let error = InternalError(code: err.code, message: err.message)
                    store.toastSubject.send((error.localizedMessage, .error))
                default: break
                }
            }
        }
        routerManager.router(action: .dismiss())
    }
    
    private func disableCameraClick() {
        if isCameraLocked {
            store.seatStore.openRemoteCamera(userID: user.userID, policy: .unlockOnly) { [weak self] result in
                guard let self = self else { return }
                switch result {
                case .failure(let err):
                    let error = InternalError(code: err.code, message: err.message)
                    store.toastSubject.send((error.localizedMessage, .error))
                default: break
                }
            }
        } else {
            store.seatStore.closeRemoteCamera(userID: user.userID) { [weak self] result in
                guard let self = self else { return }
                switch result {
                case .failure(let err):
                    let error = InternalError(code: err.code, message: err.message)
                    store.toastSubject.send((error.localizedMessage, .error))
                default: break
                }
            }
        }
        routerManager.router(action: .dismiss())
    }
    
    private func kickOffSeatClick() {
        let cancelButton = AlertButtonConfig(text: .cancelText, type: .grey) { alertView in
            alertView.dismiss()
        }
        
        let confirmButton = AlertButtonConfig(text: .disconnectText, type: .red) { [weak self] alertView in
            guard let self = self else { return }
            store.seatStore.kickUserOutOfSeat(userID: user.userID) { [weak self] result in
                guard let self = self else { return }
                switch result {
                case .success(()):
                    routerManager.dismiss()
                case .failure(let err):
                    let error = InternalError(code: err.code, message: err.message)
                    store.toastSubject.send((error.localizedMessage, .error))
                }
            }
            alertView.dismiss()
        }
        
        let alertConfig = AlertViewConfig(title: .localizedReplace(.hangupAlertText,
                                                                   replace: user.userName.isEmpty ? user.userID : user.userName),
                                          cancelButton: cancelButton,
                                          confirmButton: confirmButton)
        let alertView = AtomicAlertView(config: alertConfig)
        alertView.show()
    }
}

private extension String {
    static let followText = internalLocalized("Follow")
    static let disableChatText = internalLocalized("Disable Chat")
    static let enableChatText = internalLocalized("Enable Chat")
    static let kickOutOfRoomText = internalLocalized("Remove")
    static let kickOutOfRoomConfirmText = internalLocalized("Remove")
    static let kickOutAlertText = internalLocalized("Are you sure you want to remove xxx?")
    static let muteAudioText = internalLocalized("Mute")
    static let unmuteAudioText = internalLocalized("Unmute")
    static let opneCameraText = internalLocalized("Start Video")
    static let closeCameraText = internalLocalized("Stop Video")
    static let filpText = internalLocalized("Flip")
    static let leaveSeatAlertText = internalLocalized("Are you sure you want to disconnect?")
    static let cancelText = internalLocalized("Cancel")
    static let disableAudioText = internalLocalized("Disable Audio")
    static let enableAudioText = internalLocalized("Enable Audio")
    static let disableCameraText = internalLocalized("Disable Video")
    static let enableCameraText = internalLocalized("Enable Video")
    static let hangupText = internalLocalized("End")
    static let hangupAlertText = internalLocalized("Are you sure you want to disconnect xxx?")
    static let disconnectText = internalLocalized("End Co-guest")
}
