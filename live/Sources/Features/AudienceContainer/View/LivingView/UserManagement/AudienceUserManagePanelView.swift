//
//  AudienceUserManagePanelView.swift
//  TUILiveKit
//
//  Created by jeremiawang on 2025/2/17.
//

import AtomicXCore
import Combine
import ImSDK_Plus
import RTCCommon
import AtomicX

class AudienceUserManagePanelView: RTCBaseView {
    private let manager: AudienceStore
    private let routerManager: AudienceRouterManager
    private weak var coreView: LiveCoreView?
    private let userManagePanelType: AudienceUserManagePanelType
    private var user: SeatInfo
    @Published private var isFollow: Bool = false
    
    private var isSelf: Bool {
        user.userInfo.userID == manager.loginState.loginUserInfo?.userID
    }

    private var isOwner: Bool {
        user.userInfo.userID == manager.liveListState.currentLive.liveOwner.userID
    }

    private var isSelfMuted: Bool {
        if let selfInfo = manager.seatState.seatList.filter({ $0.userInfo.userID == manager.selfUserID }).first {
            return selfInfo.userInfo.microphoneStatus == .off
        }
        return true
    }

    private var isSelfCameraOpened: Bool {
        if let selfInfo = manager.seatState.seatList.filter({ $0.userInfo.userID == manager.selfUserID }).first {
            return selfInfo.userInfo.cameraStatus == .on
        }
        return false
    }

    private var isSelfOnSeat: Bool {
        manager.coGuestState.connected.isOnSeat()
    }

    private var isAudioLocked: Bool {
        !(manager.coGuestState.connected.filter { $0.userID == user.userInfo.userID }.first?.allowOpenMicrophone ?? true)
    }

    private var isCameraLocked: Bool {
        !(manager.coGuestState.connected.filter { $0.userID == user.userInfo.userID }.first?.allowOpenCamera ?? true)
    }

    private var cancellableSet = Set<AnyCancellable>()
    
    init(user: SeatInfo, manager: AudienceStore, routerManager: AudienceRouterManager, coreView: LiveCoreView, type: AudienceUserManagePanelType) {
        self.user = user
        self.manager = manager
        self.routerManager = routerManager
        self.coreView = coreView
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
        label.text = user.userInfo.userName.isEmpty ? user.userInfo.userID : user.userInfo.userName
        label.font = .customFont(ofSize: 16)
        label.textColor = .g7
        return label
    }()
    
    private lazy var idLabel: UILabel = {
        let label = UILabel()
        label.font = .customFont(ofSize: 12)
        label.text = "ID: " + user.userInfo.userID
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
    
    private lazy var featureClickPanel: AudienceFeatureClickPanel = {
        let model = generateFeatureClickPanelModel()
        let featureClickPanel = AudienceFeatureClickPanel(model: model)
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
        avatarView.setContent(.url(user.userInfo.avatarURL, placeholder: UIImage.avatarPlaceholderImage))
        checkFollowStatus()
    }
    
    private func subscribeState() {
        $isFollow.receive(on: RunLoop.main)
            .removeDuplicates()
            .sink { [weak self] isFollow in
                guard let self = self else { return }
                if isFollow {
                    followButton.setButtonContent(.iconOnly(icon: internalImage("live_user_followed_icon")))
                } else {
                    followButton.setButtonContent(.textOnly(text: .followText))
                }
            }
            .store(in: &cancellableSet)
        
        let isCameraOpenedPublisher = manager.subscribeState(StatePublisherSelector(keyPath: \DeviceState.cameraStatus))
        let isMicrophoneMutedPublisher = manager.subscribeState(StatePublisherSelector(keyPath: \DeviceState.microphoneStatus))
        isCameraOpenedPublisher.removeDuplicates()
            .combineLatest(isMicrophoneMutedPublisher.removeDuplicates())
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in
                guard let self = self else { return }
                updateFeatureItems()
            }
            .store(in: &cancellableSet)
        
        manager.subscribeState(StatePublisherSelector(keyPath: \CoGuestState.connected))
            .removeDuplicates()
            .receive(on: RunLoop.main)
            .sink { [weak self] seatList in
                guard let self = self else { return }
                updateFeatureItems()
                guard userManagePanelType == .mediaAndSeat,
                      user.userInfo.userID != manager.liveListState.currentLive.liveOwner.userID else { return }
                if !seatList.contains(where: { $0.userID == self.user.userInfo.userID }) {
                    routerManager.router(action: .dismiss())
                }
            }
            .store(in: &cancellableSet)
    }
    
    private func checkFollowStatus() {
        V2TIMManager.sharedInstance().checkFollowType(userIDList: [user.userInfo.userID]) { [weak self] checkResultList in
            guard let self = self, let result = checkResultList?.first else { return }
            if result.followType == .FOLLOW_TYPE_IN_BOTH_FOLLOWERS_LIST || result.followType == .FOLLOW_TYPE_IN_MY_FOLLOWING_LIST {
                self.isFollow = true
            } else {
                self.isFollow = false
            }
        } fail: { _, _ in
        }
    }
    
    private func generateFeatureClickPanelModel() -> AudienceFeatureClickPanelModel {
        let model = AudienceFeatureClickPanelModel()
        model.itemSize = CGSize(width: 56.scale375(), height: 56.scale375Height())
        model.itemDiff = 12.scale375()
        switch userManagePanelType {
        case .mediaAndSeat:
            if isSelf {
                model.items.append(muteSelfAudioItem)
                model.items.append(closeSelfCameraItem)
                if isSelfCameraOpened {
                    model.items.append(flipItem)
                }
                if !isOwner && isSelfOnSeat {
                    model.items.append(leaveSeatItem)
                }
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
        }
        let newItems = generateFeatureClickPanelModel().items
        featureClickPanel.updateFeatureItems(newItems: newItems)
    }
    
    private lazy var designConfig: AudienceFeatureItemDesignConfig = {
        var designConfig = AudienceFeatureItemDesignConfig()
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
    
    private lazy var muteSelfAudioItem: AudienceFeatureItem = .init(normalTitle: .muteAudioText,
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
    
    private lazy var closeSelfCameraItem: AudienceFeatureItem = .init(normalTitle: .closeCameraText,
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
    
    private lazy var flipItem: AudienceFeatureItem = .init(normalTitle: .filpText,
                                                           normalImage: internalImage("live_video_setting_flip"),
                                                           designConfig: designConfig,
                                                           actionClosure: { [weak self] _ in
                                                               guard let self = self else { return }
                                                               self.flipClick()
                                                           })
    
    private lazy var leaveSeatItem: AudienceFeatureItem = .init(normalTitle: .disconnectText,
                                                                normalImage: internalImage("live_leave_seat_icon"),
                                                                designConfig: designConfig,
                                                                actionClosure: { [weak self] _ in
                                                                    guard let self = self else { return }
                                                                    self.leaveSeatClick()
                                                                })
}

// MARK: - Action

extension AudienceUserManagePanelView {
    private func followButtonClick() {
        if isFollow {
            V2TIMManager.sharedInstance().unfollowUser(userIDList: [user.userInfo.userID]) { [weak self] followResultList in
                guard let self = self, let result = followResultList?.first else { return }
                if result.resultCode == 0 {
                    isFollow = false
                } else {
                    manager.toastSubject.send(("code: \(result.resultCode), message: \(String(describing: result.resultInfo))",.error))
                }
            } fail: { [weak self] code, message in
                guard let self = self else { return }
                manager.toastSubject.send(("code: \(code), message: \(String(describing: message))",.error))
            }
        } else {
            V2TIMManager.sharedInstance().followUser(userIDList: [user.userInfo.userID]) { [weak self] followResultList in
                guard let self = self, let result = followResultList?.first else { return }
                if result.resultCode == 0 {
                    isFollow = true
                } else {
                    manager.toastSubject.send(("code: \(result.resultCode), message: \(String(describing: result.resultInfo))",.error))
                }
            } fail: { [weak self] code, message in
                guard let self = self else { return }
                manager.toastSubject.send(("code: \(code), message: \(String(describing: message))",.error))
            }
        }
    }
    
    private func muteSelfAudioClick(_ sender: AudienceFeatureItemButton) {
        if isSelfMuted {
            manager.seatStore.unmuteMicrophone { [weak sender, weak self] result in
                guard let self = self else { return }
                switch result {
                case .success(()):
                    guard let sender = sender else { break }
                    sender.isSelected = isSelfMuted
                case .failure(let err):
                    let err = InternalError(code: err.code, message: err.message)
                    manager.toastSubject.send((err.localizedMessage,.error))
                }
            }
        } else {
            manager.seatStore.muteMicrophone()
            sender.isSelected = !sender.isSelected
        }
        routerManager.router(action: .dismiss())
    }
    
    private func closeSelfCameraClick(_ sender: AudienceFeatureItemButton) {
        if isSelfCameraOpened {
            manager.deviceStore.closeLocalCamera()
            sender.isSelected = !sender.isSelected
        } else {
            manager.deviceStore.openLocalCamera(isFront: manager.deviceState.isFrontCamera) { [weak sender, weak self] result in
                guard let self = self else { return }
                switch result {
                case .success(()):
                    guard let sender = sender else { break }
                    sender.isSelected = !isSelfCameraOpened
                case .failure(let err):
                    let err = InternalError(code: err.code, message: err.message)
                    manager.toastSubject.send((err.localizedMessage,.error))
                }
            }
        }
        routerManager.router(action: .dismiss())
    }
    
    private func flipClick() {
        manager.deviceStore.switchCamera(isFront: !manager.deviceState.isFrontCamera)
        routerManager.router(action: .dismiss())
    }
    
    private func leaveSeatClick() {
        let cancelButton = AlertButtonConfig(text: .cancelText, type: .grey) { alertView in
            alertView.dismiss()
        }
        
        let confirmButton = AlertButtonConfig(text: .disconnectText, type: .red) { [weak self] alertView in
            guard let self = self else { return }
            manager.coGuestStore.disConnect(completion: nil)
            alertView.dismiss()
            routerManager.dismiss()
        }
        
        let alertConfig = AlertViewConfig(title: .leaveSeatAlertText,
                                          cancelButton: cancelButton,
                                          confirmButton: confirmButton)
        let alertView = AtomicAlertView(config: alertConfig)
        alertView.show()
    }
}

private extension String {
    static let followText = internalLocalized("Follow")
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
