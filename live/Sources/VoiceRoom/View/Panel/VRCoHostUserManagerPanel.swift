//
//  VRCoHostUserManagerPanel.swift
//  Pods
//
//  Created by ssc on 2025/10/10.
//

import UIKit
import AtomicXCore
import ImSDK_Plus
import Combine
import RTCRoomEngine
import RTCCommon
import TUICore

enum VRCoHostUserManagerPanelType {
    case muteAndKick
    case mute
    case userInfo
    case inviteAndLockSeat
}

class VRCoHostUserManagerPanel: UIView{

    private let routerManager: VRRouterManager
    private let toastService: VRToastService
    private let liveID: String
    private let userManagePanelType: VRCoHostUserManagerPanelType
    @Published private var seatInfo: SeatInfo
    @Published private var isFollow: Bool = false
    private var isMessageDisabled = false

    private var isSelf: Bool {
        seatInfo.userInfo.userID == TUIRoomEngine.getSelfInfo().userId
    }
    private var isOwner: Bool {
        seatInfo.userInfo.role == .owner
    }
    private var isSelfOwner: Bool {
        TUIRoomEngine.getSelfInfo().userId == liveListStore.state.value.currentLive.liveOwner.userID
    }
    private var isSelfMuted: Bool {
        seatInfo.userInfo.microphoneStatus == .off
    }

    private var isAudioLocked: Bool {
        return !seatInfo.userInfo.allowOpenMicrophone
    }
    private var isSeatLocked: Bool {
        return seatInfo.isLocked
    }

    private var cancellableSet = Set<AnyCancellable>()

    public init(liveID: String, seatInfo: SeatInfo, routerManager: VRRouterManager, type: VRCoHostUserManagerPanelType, toastService: VRToastService) {
        self.liveID = liveID
        self.seatInfo = seatInfo
        self.routerManager = routerManager
        self.userManagePanelType = type
        self.toastService = toastService
        super.init(frame: .zero)
    }

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

    private lazy var avatarImageView: UIImageView = {
        let imageView = UIImageView()
        imageView.layer.cornerRadius = 20.scale375()
        imageView.layer.masksToBounds = true
        return imageView
    }()

    private lazy var userNameLabel: UILabel = {
        let label = UILabel()
        label.text = seatInfo.userInfo.userName.isEmpty ? seatInfo.userInfo.userID : seatInfo.userInfo.userName
        label.font = .customFont(ofSize: 16)
        label.textColor = .g7
        return label
    }()

    private lazy var idLabel: UILabel = {
        let label = UILabel()
        label.font = .customFont(ofSize: 12)
        label.text = "ID: " + seatInfo.userInfo.userID
        label.textColor = .greyColor
        return label
    }()

    private lazy var titleLabel: UILabel = {
        let label = UILabel()
        label.font = .customFont(ofSize: 16)
        label.text = "连麦管理"
        label.textColor = .greyColor
        label.isHidden = true
        return label
    }()

    private lazy var followButton: UIButton = {
        let button = UIButton()
        button.backgroundColor = .deepSeaBlueColor
        button.titleLabel?.font = .customFont(ofSize: 14)
        button.setTitle(.followText, for: .normal)
        button.setTitleColor(.g7, for: .normal)
        button.setImage(internalImage("live_user_followed_icon"), for: .selected)
        button.layer.cornerRadius = 16
        button.isHidden = isSelf
        return button
    }()

    private lazy var featureClickPanel: VRFeatureClickPanel = {
        let model = generateFeatureClickPanelModel()
        let featureClickPanel = VRFeatureClickPanel(model: model)
        return featureClickPanel
    }()

    private var isViewReady: Bool = false
    override func didMoveToWindow() {
        super.didMoveToWindow()
        guard !isViewReady else { return }
        isViewReady = true
        backgroundColor = .clear
        constructViewHierarchy()
        activateConstraints()
        bindInteraction()
        setupViewStyle()
    }

    private func constructViewHierarchy() {
        self.layer.masksToBounds = true
        addSubview(userInfoView)
        userInfoView.addSubview(avatarImageView)
        userInfoView.addSubview(userNameLabel)
        userInfoView.addSubview(idLabel)
        userInfoView.addSubview(followButton)
        addSubview(featureClickPanel)
        addSubview(titleLabel)
    }

    private func activateConstraints() {
        userInfoView.snp.makeConstraints { make in
            make.leading.trailing.top.equalToSuperview().inset(24)
            make.height.equalTo(43.scale375())
        }
        avatarImageView.snp.makeConstraints { make in
            make.leading.centerY.equalToSuperview()
            make.width.height.equalTo(40.scale375())
        }
        userNameLabel.snp.makeConstraints { make in
            make.top.equalToSuperview()
            make.leading.equalTo(avatarImageView.snp.trailing).offset(12.scale375())
            make.height.equalTo(20.scale375())
            make.width.lessThanOrEqualTo(170.scale375())
        }
        idLabel.snp.makeConstraints { make in
            make.leading.equalTo(userNameLabel)
            make.top.equalTo(userNameLabel.snp.bottom).offset(5.scale375())
            make.height.equalTo(17.scale375())
            make.width.lessThanOrEqualTo(200.scale375())
        }
        followButton.snp.makeConstraints{ make in
            make.trailing.centerY.equalToSuperview()
            make.width.equalTo(67.scale375())
            make.height.equalTo(32.scale375())
        }
        featureClickPanel.snp.makeConstraints{ make in
            make.top.equalTo(userInfoView.snp.bottom).offset(21.scale375())
            make.leading.equalTo(userInfoView)
            make.bottom.equalToSuperview()
        }
        titleLabel.snp.makeConstraints { make in
            make.top.equalToSuperview().offset(20.scale375())
            make.centerX.equalToSuperview()
        }
    }

    private func bindInteraction() {
        subscribeState()
        followButton.addTarget(self, action: #selector(followButtonClick), for: .touchUpInside)
    }

    private func setupViewStyle() {
        backgroundColor = .g2
        layer.cornerRadius = 12
        layer.maskedCorners = [.layerMinXMinYCorner, .layerMaxXMinYCorner]
        avatarImageView.kf.setImage(with: URL(string: seatInfo.userInfo.avatarURL), placeholder: UIImage.avatarPlaceholderImage)
        checkFollowStatus()
    }

    private func subscribeState() {
        $isFollow.receive(on: RunLoop.main)
            .removeDuplicates()
            .sink { [weak self] isFollow in
                guard let self = self else { return }
                if isFollow {
                    followButton.backgroundColor = .g5
                    followButton.setTitle("", for: .normal)
                    followButton.setImage(internalImage("live_user_followed_icon"), for: .normal)
                } else {
                    followButton.backgroundColor = .deepSeaBlueColor
                    followButton.setTitle(.followText, for: .normal)
                    followButton.setImage(nil, for: .normal)
                }
            }
            .store(in: &cancellableSet)

        $seatInfo.receive(on: RunLoop.main)
            .sink { [weak self] user in
                guard let self = self else { return }
                userNameLabel.text = seatInfo.userInfo.userName.isEmpty ? seatInfo.userInfo.userID : seatInfo.userInfo.userName
                avatarImageView.kf.setImage(with: URL(string: seatInfo.userInfo.avatarURL), placeholder: UIImage.avatarPlaceholderImage)
                updateFeatureItems()
            }
            .store(in: &cancellableSet)

        coGuestStore.state.subscribe(StatePublisherSelector(keyPath: \CoGuestState.connected))
            .removeDuplicates()
            .receive(on: RunLoop.main)
            .sink { [weak self] seatList in
                guard let self = self, userManagePanelType == .mute,seatInfo.userInfo.userID != liveListStore.state.value.currentLive.liveOwner.userID else {
                    return
                }
                if !seatList.contains(where: { $0.userID == self.seatInfo.userInfo.userID }) {
                    routerManager.router(action: .dismiss())
                }
            }
            .store(in: &cancellableSet)

        toastService.subscribeToast { [weak self] message in
            guard let self = self else { return }
            self.makeToast(message: message)
        }
    }

    private func checkFollowStatus() {
        V2TIMManager.sharedInstance().checkFollowType(userIDList: [seatInfo.userInfo.userID]) { [weak self] checkResultList in
            guard let self = self, let result = checkResultList?.first else { return }
            if result.followType == .FOLLOW_TYPE_IN_BOTH_FOLLOWERS_LIST || result.followType == .FOLLOW_TYPE_IN_MY_FOLLOWING_LIST {
                self.isFollow = true
            } else {
                self.isFollow = false
            }
        } fail: { _, _ in
        }
    }

    private func generateFeatureClickPanelModel() -> VRFeatureClickPanelModel {
        let model = VRFeatureClickPanelModel()
        model.itemSize = CGSize(width: 56.scale375(), height: 56.scale375Height())
        model.itemDiff = 12.scale375()
        switch userManagePanelType {
            case .inviteAndLockSeat:
                model.items.append(lockSeatItem)
                if !isSeatLocked {
                    model.items.append(inviteItem)
                }
                userInfoView.isHidden = true
                titleLabel.isHidden = false
                break
            case .mute:
                model.items.append(muteSelfAudioItem)
                model.items.append(leaveSeatItem)
                break
            case .muteAndKick:
                if isSelf {
                    model.items.append(muteSelfAudioItem)
                    if !isOwner {
                        model.items.append(leaveSeatItem)
                    }
                } else if isSelfOwner {
                    model.items.append(disableAudioItem)
                    model.items.append(kickOffSeatItem)
                }
                break
            case .userInfo:
                break
        }
        return model
    }

    private func updateFeatureItems() {
        if isSelf {
            muteSelfAudioItem.isSelected = isSelfMuted
            muteSelfAudioItem.isDisabled = isAudioLocked
        } else {
            disableAudioItem.isSelected = isAudioLocked
        }

        let newItems = generateFeatureClickPanelModel().items
        featureClickPanel.updateVRFeatureItems(newItems: newItems)
    }

    private lazy var designConfig: VRFeatureItemDesignConfig = {
        var designConfig = VRFeatureItemDesignConfig()
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

    private lazy var kickOutItem: VRFeatureItem = {
        VRFeatureItem(normalTitle: .kickOutOfRoomText,
                          normalImage: internalImage("live_anchor_kickout_icon"),
                          designConfig: designConfig,
                          actionClosure: { [weak self] _ in
            guard let self = self else { return }
            self.kickOutOfRoomClick()
        })
    }()

    private lazy var muteSelfAudioItem: VRFeatureItem = {
        VRFeatureItem(normalTitle: .muteAudioText,
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
    }()

    private lazy var leaveSeatItem: VRFeatureItem = {
        VRFeatureItem(normalTitle: .disconnectText,
                          normalImage: internalImage("live_leave_seat_icon"),
                          designConfig: designConfig,
                          actionClosure: { [weak self] _ in
            guard let self = self else { return }
            self.leaveSeatClick()
        })
    }()

    private lazy var disableAudioItem: VRFeatureItem = {
        VRFeatureItem(normalTitle: .disableAudioText,
                          normalImage: internalImage("live_anchor_unmute_icon"),
                          selectedTitle: .enableAudioText,
                          selectedImage: internalImage("live_disable_audio_icon"),
                          isSelected: isAudioLocked,
                          designConfig: designConfig,
                          actionClosure: { [weak self] sender in
            guard let self = self else { return }
            self.disableAudioClick(sender)
        })
    }()

    private lazy var kickOffSeatItem: VRFeatureItem = {
        VRFeatureItem(normalTitle: .hangupText,
                          normalImage: internalImage("seat_kick_seat"),
                          designConfig: designConfig,
                          actionClosure: { [weak self] _ in
            guard let self = self else { return }
            self.kickOffSeatClick()
        })
    }()

    private lazy var lockSeatItem: VRFeatureItem = {
        VRFeatureItem(normalTitle: .lockSeat,
                          normalImage: internalImage("seat_locked_icon"),
                          selectedTitle: .unlockSeat,
                          selectedImage: internalImage("seat_unlock"),
                          isSelected: isSeatLocked,
                          designConfig: designConfig,
                          actionClosure: { [weak self] sender in
            guard let self = self else { return }
            self.lockSeat(sender)
        })
    }()

    private lazy var inviteItem: VRFeatureItem = {
        VRFeatureItem(normalTitle: .inviteText,
                          normalImage: internalImage("live_anchor_invite_icon"),
                          designConfig: designConfig,
                          actionClosure: { [weak self] _ in
            guard let self = self else { return }
            self.invite()
        })
    }()
}

// MARK: - Action
extension VRCoHostUserManagerPanel {
    @objc private func followButtonClick() {
        if isFollow {
            V2TIMManager.sharedInstance().unfollowUser(userIDList: [seatInfo.userInfo.userID]) { [weak self] followResultList in
                guard let self = self, let result = followResultList?.first else { return }
                if result.resultCode == 0 {
                    isFollow = false
                } else {
                    toastService.showToast(String(describing: result.resultInfo))
                }
            } fail: { [weak self] code, message in
                guard let self = self else { return }
                toastService.showToast(String(describing: message))
            }
        } else {
            V2TIMManager.sharedInstance().followUser(userIDList: [seatInfo.userInfo.userID]) { [weak self] followResultList in
                guard let self = self, let result = followResultList?.first else { return }
                if result.resultCode == 0 {
                    isFollow = true
                } else {
                    toastService.showToast(String(describing: result.resultInfo))
                }
            } fail: { [weak self] code, message in
                guard let self = self else { return }
                toastService.showToast(String(describing: message))
            }
        }
    }

    private func kickOutOfRoomClick() {
        let alertInfo = VRAlertInfo(description: .localizedReplace(.kickOutAlertText, replace: seatInfo.userInfo.userName.isEmpty ? seatInfo.userInfo.userID : seatInfo.userInfo.userName),
                                        imagePath: nil,
                                        cancelButtonInfo: (.cancelText, .cancelTextColor),
                                        defaultButtonInfo: (.kickOutOfRoomConfirmText, .warningTextColor)) { alertPanel in
            alertPanel.dismiss()
        } defaultClosure: { [weak self] alertPanel in
            guard let self = self else { return }
            alertPanel.dismiss()
            routerManager.router(action: .dismiss())
        }
        let alertPanel = VRAlertPanel(alertInfo: alertInfo)
        alertPanel.show()
    }

    private func muteSelfAudioClick(_ sender: VRFeatureItemButton) {
        if isSelfMuted {
            seatStore.unmuteMicrophone(completion: { [weak self] result in
                guard let self = self else {return}
                switch result {
                    case .success():
                        sender.isSelected = isSelfMuted
                        break
                    case .failure(let error):
                        let err = InternalError(errorInfo: error)
                        toastService.showToast(err.localizedMessage)
                        break
                }
            })
        } else {
            seatStore.muteMicrophone()
            sender.isSelected = !sender.isSelected
        }
        routerManager.router(action: .dismiss())
    }

    private func leaveSeatClick() {
        let alertInfo = VRAlertInfo(description: .leaveSeatAlertText, imagePath: nil,
                                        cancelButtonInfo: (.cancelText, .cancelTextColor),
                                        defaultButtonInfo: (.disconnectText, .warningTextColor)) { alertPanel in
            alertPanel.dismiss()
        } defaultClosure: { [weak self] alertPanel in
            guard let self = self else { return }
            coGuestStore.disConnect(completion: nil)
            deviceStore.closeLocalMicrophone()
            alertPanel.dismiss()
            routerManager.router(action: .dismiss())
        }
        let alertPanel = VRAlertPanel(alertInfo: alertInfo)
        alertPanel.show()
    }

    private func disableAudioClick(_ sender: VRFeatureItemButton) {
        sender.isSelected = seatInfo.userInfo.allowOpenMicrophone

        if sender.isSelected {
            seatStore.closeRemoteMicrophone(userID: seatInfo.userInfo.userID, completion: { result in
                sender.isSelected = !sender.isSelected
            })
        } else {
            seatStore.openRemoteMicrophone(userID: seatInfo.userInfo.userID, policy: .unlockOnly, completion: { result in
                sender.isSelected = !sender.isSelected
            })
        }

        routerManager.router(action: .dismiss())
    }

    private func kickOffSeatClick() {
        let alertInfo = VRAlertInfo(description: .localizedReplace(.hangupAlertText, replace: seatInfo.userInfo.userName.isEmpty ? seatInfo.userInfo.userID : seatInfo.userInfo.userName),
                                        imagePath: nil,
                                        cancelButtonInfo: (.cancelText, .cancelTextColor),
                                        defaultButtonInfo: (.disconnectText, .warningTextColor)) { alertPanel in
            alertPanel.dismiss()
        } defaultClosure: { [weak self] alertPanel in
            guard let self = self else { return }
            seatStore.kickUserOutOfSeat(userID: seatInfo.userInfo.userID) { [weak self] result in
                guard let self = self else { return }
                switch result {
                    case .success():
                        break
                    case .failure(let error):
                        let err = InternalError(errorInfo: error)
                        toastService.showToast(err.localizedMessage)
                        break
                }
            }
            routerManager.router(action: .dismiss())
            alertPanel.dismiss()
        }
        let alertPanel = VRAlertPanel(alertInfo: alertInfo)
        alertPanel.show()
    }

    private func lockSeat(_ sender: VRFeatureItemButton) {
        let lockSeat = TUISeatLockParams()
        lockSeat.lockAudio = !seatInfo.userInfo.allowOpenMicrophone
        lockSeat.lockVideo = !seatInfo.userInfo.allowOpenCamera
        lockSeat.lockSeat = !seatInfo.isLocked

        TUIRoomEngine.sharedInstance().lockSeatByAdmin(seatInfo.index, lockMode: lockSeat) { [weak self] in
            guard let self = self else {return }
        } onError: { [weak self] error, message in
            guard let self = self else { return }
            let err = InternalError(errorInfo: ErrorInfo(code: error.rawValue, message: message))
            toastService.showToast(err.localizedMessage)
        }
        routerManager.router(action: .dismiss())
    }

    private func actionItemDesignConfig() -> ActionItemDesignConfig {
        let designConfig = ActionItemDesignConfig(lineWidth: 1, titleColor: .g2)
        designConfig.backgroundColor = .white
        designConfig.lineColor = .g8
        return designConfig
    }

    private func invite() {
        routerManager.router(action:.present(.linkInviteControl(seatInfo.index)))
    }
}

extension VRCoHostUserManagerPanel {
    var deviceStore: DeviceStore {
        return DeviceStore.shared
    }

    var liveListStore: LiveListStore {
        return LiveListStore.shared
    }

    var audienceStore: LiveAudienceStore {
        return LiveAudienceStore.create(liveID: liveID)
    }

    var coGuestStore: CoGuestStore {
        return CoGuestStore.create(liveID: liveID)
    }

    var seatStore: LiveSeatStore {
        return LiveSeatStore.create(liveID: liveID)
    }

    var barrageStore: BarrageStore {
        return BarrageStore.create(liveID: liveID)
    }

    var coHostStore: CoHostStore {
        return CoHostStore.create(liveID: liveID)
    }

    var battleStore: BattleStore {
        return BattleStore.create(liveID: liveID)
    }
}

fileprivate extension String {
    static let followText = internalLocalized("Follow")
    static let disableChatText = internalLocalized("Disable Chat")
    static let enableChatText = internalLocalized("Enable Chat")
    static let kickOutOfRoomText = internalLocalized("Kick Out")
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
    static let inviteText = internalLocalized("Invite")
    static let lockSeat = internalLocalized("Lock Seat")
    static let unlockSeat = internalLocalized("UnLock Seat")
}
