//
//  AnchorLivingView.swift
//  TUILiveKit
//
//  Created by WesleyLei on 2023/10/19.
//

import AtomicXCore
import Combine
import Foundation
import RTCCommon
import RTCRoomEngine
import TUICore

class AnchorLivingView: UIView {
    private let manager: AnchorManager
    private let routerManager: AnchorRouterManager
    private let coreView: LiveCoreView
    private let netWorkInfoManager = NetWorkInfoManager(
        service: NetWorkInfoService(
            trtcCloud: TUIRoomEngine.sharedInstance().getTRTCCloud()
        )
    )
    private var cancellableSet: Set<AnyCancellable> = []
    private var isPortrait: Bool = WindowUtils.isPortrait

    private let giftCacheService = GiftManager.shared.giftCacheService
    
    private let liveInfoView: LiveInfoView = {
        let view = LiveInfoView(enableFollow: VideoLiveKit.createInstance().enableFollow)
        view.mm_h = 40.scale375()
        view.backgroundColor = UIColor.g1.withAlphaComponent(0.4)
        view.layer.cornerRadius = view.mm_h * 0.5
        return view
    }()
    
    private lazy var closeButton: UIButton = {
        let view = UIButton(frame: .zero)
        view.setImage(internalImage("live_end_live_icon"), for: .normal)
        view.addTarget(self, action: #selector(closeButtonClick), for: .touchUpInside)
        view.imageEdgeInsets = UIEdgeInsets(top: 2.scale375(), left: 2.scale375(), bottom: 2.scale375(), right: 2.scale375())
        return view
    }()
    
    private lazy var audienceListView: AudienceListView = {
        let view = AudienceListView()
        view.onUserManageButtonClicked = { [weak self] user in
            guard let self = self else { return }
            routerManager.router(action: .present(.userManagement(SeatInfo(userInfo: user), type: .messageAndKickOut)))
        }
        return view
    }()
    
    private lazy var bottomMenu: AnchorBottomMenuView = {
        let view = AnchorBottomMenuView(manager: manager, routerManager: routerManager, coreView: coreView)
        return view
    }()
    
    private lazy var floatView: LinkMicAnchorFloatView = {
        let view = LinkMicAnchorFloatView(manager: manager, routerManager: routerManager)
        view.isHidden = true
        return view
    }()
    
    private lazy var barrageDisplayView: BarrageStreamView = {
        let view = BarrageStreamView(liveID: manager.liveID)
        view.delegate = self
        return view
    }()
    
    private lazy var giftDisplayView: GiftPlayView = {
        let view = GiftPlayView(roomId: manager.liveID)
        view.delegate = self
        return view
    }()
    
    private lazy var barrageSendView: BarrageInputView = {
        var view = BarrageInputView(roomId: manager.liveID)
        view.layer.cornerRadius = 20.scale375Height()
        view.layer.masksToBounds = true
        return view
    }()
    
    private lazy var floatWindowButton: UIButton = {
        let button = UIButton(type: .custom)
        button.setImage(internalImage("live_floatwindow_open_icon"), for: .normal)
        button.addTarget(self, action: #selector(onFloatWindowButtonClick), for: .touchUpInside)
        button.imageEdgeInsets = UIEdgeInsets(top: 2.scale375(), left: 2.scale375(), bottom: 2.scale375(), right: 2.scale375())
        return button
    }()
    
    private lazy var netWorkInfoButton: NetworkInfoButton = {
        let button = NetworkInfoButton(liveId: manager.liveID, manager: netWorkInfoManager)
        button.onNetWorkInfoButtonClicked = { [weak self] in
            guard let self = self else { return }
            routerManager.router(action: .present(.netWorkInfo(netWorkInfoManager, isAudience: !manager.liveListState.currentLive.keepOwnerOnSeat)))
        }
        return button
    }()

    private lazy var netWorkStatusToastView: NetworkStatusToastView = {
        let view = NetworkStatusToastView()
        view.onCloseButtonTapped = { [weak self] in
            guard let self = self else { return }
            netWorkStatusToastView.isHidden = true
            self.netWorkInfoManager.onNetWorkInfoStatusToastViewClosed()
        }
        view.isHidden = true
        return view
    }()
    
    private var anchorObserverState = ObservableState<AnchorState>(initialState: AnchorState())
    
    init(manager: AnchorManager, routerManager: AnchorRouterManager, coreView: LiveCoreView) {
        self.manager = manager
        self.routerManager = routerManager
        self.coreView = coreView
        super.init(frame: .zero)
    }
    
    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    deinit {
        if manager.coGuestState.connected.isOnSeat() {
            manager.liveListStore.leaveLive(completion: nil)
        }
        print("deinit \(type(of: self))")
    }
    
    private var isViewReady: Bool = false
    override func didMoveToWindow() {
        super.didMoveToWindow()
        guard !isViewReady else { return }
        backgroundColor = .clear
        constructViewHierarchy()
        activateConstraints()
        bindInteraction()
        isViewReady = true
    }
    
    private func bindInteraction() {
        subscribeState()
        subscribeSubject()
    }
    
    private func subscribeState() {
        manager.subscribeState(StatePublisherSelector(keyPath: \CoGuestState.applicants))
            .receive(on: RunLoop.main)
            .removeDuplicates()
            .sink { [weak self] applicants in
                guard let self = self else { return }
                if manager.coHostState.applicant != nil
                    || !manager.coHostState.invitees.isEmpty
                    || !manager.coHostState.connected.isEmpty
                {
                    // If received connection request first, reject all linkmic auto.
                    for applicant in applicants {
                        manager.coGuestStore.rejectApplication(userID: applicant.userID, completion: nil)
                    }
                    return
                }
                showLinkMicFloatView(isPresent: applicants.count > 0)
            }
            .store(in: &cancellableSet)
        manager.subscribeState(StatePublisherSelector(keyPath: \LiveListState.currentLive))
            .removeDuplicates()
            .receive(on: RunLoop.main)
            .sink { [weak self] currentLive in
                guard let self = self else { return }
                if !currentLive.isEmpty {
                    didEnterRoom()
                    initComponentView(liveInfo: currentLive)
                    barrageDisplayView.setOwnerId(currentLive.liveOwner.userID)
                }
            }
            .store(in: &cancellableSet)

        netWorkInfoManager
            .subscribe(StateSelector(keyPath: \NetWorkInfoState.showToast))
            .receive(on: RunLoop.main)
            .sink { [weak self] showToast in
                guard let self = self else { return }
                if showToast {
                    self.netWorkStatusToastView.isHidden = false
                } else {
                    self.netWorkStatusToastView.isHidden = true
                }
            }
            .store(in: &cancellableSet)
        
        manager.subscribeState(StatePublisherSelector(keyPath: \LoginState.loginStatus))
            .dropFirst()
            .removeDuplicates()
            .receive(on: RunLoop.main)
            .sink { [weak self] loginStatus in
                switch loginStatus {
                case .unlogin:
                    if FloatWindow.shared.isShowingFloatWindow() {
                        FloatWindow.shared.releaseFloatWindow()
                    } else {
                        guard let self = self else { return }
                        LiveListStore.shared.leaveLive { [weak self] result in
                            guard let self = self else { return }
                            switch result {
                            case .success(()):
                                routerManager.router(action: .exit)
                            default: break
                            }
                        }
                    }
                default: break
                }
            }
            .store(in: &cancellableSet)
    }
    
    private func subscribeSubject() {
        manager.kickedOutSubject
            .receive(on: RunLoop.main)
            .sink { [weak self] isDismissed in
                guard let self = self else { return }
                isUserInteractionEnabled = false
                coreView.isUserInteractionEnabled = false
                routerManager.router(action: .dismiss())
                if isDismissed {
                    makeToast(message: .roomDismissText)
                } else {
                    makeToast(message: .kickedOutText)
                }
                DispatchQueue.main.asyncAfter(deadline: .now() + 1) { [weak self] in
                    guard let self = self else { return }
                    isUserInteractionEnabled = true
                    coreView.isUserInteractionEnabled = true
                    routerManager.router(action: .exit)
                }
            }.store(in: &cancellableSet)
    }
    
    private func didEnterRoom() {
        TUICore.notifyEvent(TUICore_PrivacyService_ROOM_STATE_EVENT_CHANGED,
                            subKey: TUICore_PrivacyService_ROOM_STATE_EVENT_SUB_KEY_START,
                            object: nil,
                            param: nil)
    }
    
    func initComponentView(liveInfo: LiveInfo) {
        audienceListView.initialize(liveId: liveInfo.liveID)
        liveInfoView.initialize(liveInfo: liveInfo)
    }
    
    @objc func onFloatWindowButtonClick() {
        manager.floatWindowSubject.send()
    }
    
    override func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
        let view = super.hitTest(point, with: event)
        return view == self ? nil : view
    }
}

extension AnchorLivingView {
    func disableFeature(_ feature: AnchorViewFeature, isDisable: Bool) {
        switch feature {
        case .liveData:
            liveInfoView.isHidden = isDisable
        case .visitorCnt:
            audienceListView.isHidden = isDisable
        case .coGuest:
            bottomMenu.disableFeature(.coGuest, isDisable: isDisable)
        case .coHost:
            bottomMenu.disableFeature(.coHost, isDisable: isDisable)
        case .battle:
            bottomMenu.disableFeature(.battle, isDisable: isDisable)
        case .soundEffect:
            bottomMenu.disableFeature(.soundEffect, isDisable: isDisable)
        }
    }
}

// MARK: Layout

extension AnchorLivingView {
    func constructViewHierarchy() {
        backgroundColor = .clear
        addSubview(barrageDisplayView)
        addSubview(giftDisplayView)
        addSubview(closeButton)
        addSubview(audienceListView)
        addSubview(liveInfoView)
        addSubview(bottomMenu)
        addSubview(floatView)
        addSubview(barrageSendView)
        addSubview(floatWindowButton)
        addSubview(netWorkInfoButton)
        addSubview(netWorkStatusToastView)
    }
    
    func updateRootViewOrientation(isPortrait: Bool) {
        self.isPortrait = isPortrait
        activateConstraints()
    }
    
    func activateConstraints() {
        giftDisplayView.snp.remakeConstraints { make in
            make.edges.equalToSuperview()
        }
        
        barrageDisplayView.snp.remakeConstraints { make in
            make.left.equalToSuperview().offset(12.scale375())
            make.width.equalTo(305.scale375())
            make.height.equalTo(212.scale375Height())
            make.bottom.equalTo(barrageSendView.snp.top).offset(-16.scale375Height())
        }
        
        closeButton.snp.remakeConstraints { make in
            make.height.equalTo(24.scale375())
            make.width.equalTo(24.scale375())
            make.trailing.equalToSuperview().inset((self.isPortrait ? 16 : 45).scale375())
            make.top.equalToSuperview().inset((self.isPortrait ? 70 : 24).scale375Height())
        }
        
        floatWindowButton.snp.makeConstraints { make in
            make.trailing.equalTo(closeButton.snp.leading).offset(-8.scale375())
            make.centerY.equalTo(closeButton)
            make.width.equalTo(24.scale375Width())
            make.height.equalTo(24.scale375Width())
        }
        
        audienceListView.snp.remakeConstraints { make in
            make.centerY.equalTo(closeButton)
            make.trailing.equalTo(floatWindowButton.snp.leading).offset(-8.scale375())
            make.leading.greaterThanOrEqualTo(liveInfoView.snp.trailing).offset(20.scale375())
        }
        
        liveInfoView.snp.remakeConstraints { make in
            make.centerY.equalTo(closeButton)
            make.height.equalTo(liveInfoView.mm_h)
            make.leading.equalToSuperview().inset((self.isPortrait ? 16 : 45).scale375())
            make.width.lessThanOrEqualTo(160.scale375())
        }
        
        bottomMenu.snp.makeConstraints { make in
            make.bottom.equalToSuperview().offset(-38.scale375Height())
            make.trailing.equalToSuperview()
            make.height.equalTo(46.scale375Height())
        }
        
        floatView.snp.makeConstraints { make in
            make.top.equalTo(audienceListView.snp.bottom).offset(34.scale375())
            make.height.equalTo(86.scale375())
            make.width.equalTo(114.scale375())
            make.trailing.equalToSuperview().offset(-8.scale375())
        }
        
        barrageSendView.snp.makeConstraints { make in
            make.leading.equalToSuperview().offset(12.scale375())
            make.width.equalTo(120.scale375())
            make.height.equalTo(40.scale375Height())
            make.centerY.equalTo(bottomMenu)
        }

        netWorkInfoButton.snp.makeConstraints { make in
            make.top.equalTo(floatWindowButton.snp.bottom).offset(10.scale375())
            make.height.equalTo(20.scale375())
            make.width.equalTo(74.scale375())
            make.trailing.equalToSuperview().offset(-8.scale375())
        }

        netWorkStatusToastView.snp.makeConstraints { make in
            make.centerX.equalToSuperview()
            make.top.equalToSuperview().offset(386.scale375())
            make.width.equalTo(262.scale375())
            make.height.equalTo(40.scale375())
        }
    }
}

// MARK: Action

extension AnchorLivingView {
    @objc
    func closeButtonClick() {
        var title = ""
        var items: [ActionItem] = []
        let lineConfig = ActionItemDesignConfig(lineWidth: 1, titleColor: .warningTextColor)
        lineConfig.backgroundColor = .bgOperateColor
        lineConfig.lineColor = .g3.withAlphaComponent(0.3)

        let selfUserId = manager.selfUserID
        let isSelfInCoGuestConnection = manager.coGuestState.connected.count > 1
        let isSelfInCoHostConnection = manager.coHostState.connected.count > 1
        let isSelfInBattle = manager.battleState.battleUsers.contains(where: { $0.userID == selfUserId }) && isSelfInCoHostConnection
        
        if isSelfInBattle {
            title = .endLiveOnBattleText
            let endBattleItem = ActionItem(title: .endLiveBattleText, designConfig: lineConfig, actionClosure: { [weak self] _ in
                guard let self = self else { return }
                exitBattle()
                self.routerManager.router(action: .dismiss())
            })
            items.append(endBattleItem)
        } else if isSelfInCoHostConnection {
            title = .endLiveOnConnectionText
            let endConnectionItem = ActionItem(title: .endLiveDisconnectText, designConfig: lineConfig, actionClosure: { [weak self] _ in
                guard let self = self else { return }
                manager.coHostStore.exitHostConnection()
                routerManager.router(action: .dismiss())
            })
            items.append(endConnectionItem)
        } else if isSelfInCoGuestConnection {
            title = .endLiveOnLinkMicText
        } else {
            let alertInfo = AnchorAlertInfo(description: .confirmEndLiveText,
                                            imagePath: nil,
                                            cancelButtonInfo: (String.cancelText, .cancelTextColor),
                                            defaultButtonInfo: (String.confirmCloseText, .warningTextColor))
            { _ in
                self.routerManager.router(action: .dismiss(.alert))
            } defaultClosure: { [weak self] _ in
                guard let self = self else { return }
                self.stopLiveStream()
                routerManager.router(action: .dismiss(.alert, completion: nil))
            }
            routerManager.router(action: .present(.alert(info: alertInfo)))
            return
        }

        let designConfig = ActionItemDesignConfig(lineWidth: 1, titleColor: title == .endLiveOnLinkMicText ? .warningTextColor : .defaultTextColor)
        designConfig.backgroundColor = .bgOperateColor
        designConfig.lineColor = .g3.withAlphaComponent(0.3)
        let text: String = manager.liveListState.currentLive.keepOwnerOnSeat ? .confirmCloseText : .confirmExitText
        let endLiveItem = ActionItem(title: text, designConfig: designConfig, actionClosure: { [weak self] _ in
            guard let self = self else { return }
            self.exitBattle()
            self.stopLiveStream()
            self.routerManager.router(action: .dismiss())
        })
        items.append(endLiveItem)
        routerManager.router(action: .present(.listMenu(ActionPanelData(title: title, items: items, cancelText: .cancelText, cancelColor: .bgOperateColor,
                                                                        cancelTitleColor: .defaultTextColor), .center)))
    }
    
    private func exitBattle() {
        manager.battleStore.exitBattle(battleID: manager.battleState.currentBattleInfo?.battleID ?? "", completion: nil)
    }
    
    func stopLiveStream() {
        if manager.liveListState.currentLive.keepOwnerOnSeat {
            manager.liveListStore.endLive { [weak self] result in
                guard let self = self else { return }
                switch result {
                case .success(let statisticsData):
                    showEndView(with: statisticsData)
                case .failure(let err):
                    let error = InternalError(code: err.code, message: err.message)
                    manager.onError(error)
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1) { [weak self] in
                        guard let self = self else { return }
                        routerManager.router(action: .exit)
                    }
                }
            }
        } else {
            manager.liveListStore.leaveLive { [weak self] result in
                guard let self = self else { return }
                switch result {
                case .success(()):
                    routerManager.router(action: .exit)
                case .failure(let err):
                    let error = InternalError(code: err.code, message: err.message)
                    manager.onError(error)
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1) { [weak self] in
                        guard let self = self else { return }
                        routerManager.router(action: .exit)
                    }
                }
            }
        }
    }

    func showEndView(with statisticsData: TUILiveStatisticsData) {
        anchorObserverState.update { [weak self] state in
            guard let self = self else { return }
            state.duration = statisticsData.liveDuration / 1000
            state.viewCount = statisticsData.totalViewers
            state.giftTotalCoins = statisticsData.totalGiftCoins
            state.giftTotalUniqueSender = statisticsData.totalUniqueGiftSenders
            state.likeTotalUniqueSender = statisticsData.totalLikesReceived
            state.messageCount = barrageDisplayView.getBarrageCount()
            manager.onEndLivingSubject.send(state)
        }
    }
}

extension AnchorLivingView {
    func showLinkMicFloatView(isPresent: Bool) {
        floatView.isHidden = !isPresent
    }
    
    func getBarrageCount() -> Int {
        barrageDisplayView.getBarrageCount()
    }
}

extension AnchorLivingView: BarrageStreamViewDelegate {
    func barrageDisplayView(_ barrageDisplayView: BarrageStreamView, createCustomCell barrage: Barrage) -> UIView? {
        guard let extensionInfo = barrage.extensionInfo,
              let typeValue = extensionInfo["TYPE"],
              typeValue == "GIFTMESSAGE"
        else {
            return nil
        }
        return GiftBarrageCell(barrage: barrage)
    }

    func onBarrageClicked(user: LiveUserInfo) {
        if user.userID == manager.selfUserID { return }
        routerManager.router(action: .present(.userManagement(SeatInfo(userInfo: user), type: .messageAndKickOut)))
    }
}

extension AnchorLivingView: GiftPlayViewDelegate {
    func giftPlayView(_ giftPlayView: GiftPlayView, onReceiveGift gift: Gift, giftCount: Int, sender: LiveUserInfo) {
        var userName = manager.liveListState.currentLive.liveOwner.userName
        if manager.liveListState.currentLive.liveOwner.userID == manager.selfUserID {
            userName = .meText
        }
        var barrage = Barrage()
        barrage.textContent = "gift"
        barrage.sender = sender
        barrage.extensionInfo = [
            "TYPE": "GIFTMESSAGE",
            "gift_name": gift.name,
            "gift_count": "\(giftCount)",
            "gift_icon_url": gift.iconURL,
            "gift_receiver_username": userName
        ]
        manager.barrageStore.appendLocalTip(message: barrage)
    }
    
    func giftPlayView(_ giftPlayView: GiftPlayView, onPlayGiftAnimation gift: Gift) {
        guard let url = URL(string: gift.resourceURL) else { return }
        giftCacheService.request(withURL: url) { error, fileUrl in
            if error == 0 {
                DispatchQueue.main.async {
                    giftPlayView.playGiftAnimation(playUrl: fileUrl)
                }
            }
        }
    }
}

private extension String {
    static let confirmCloseText = internalLocalized("End Live")
    static let confirmEndLiveText = internalLocalized("Are you sure you want to End Live?")
    static let confirmExitText = internalLocalized("Exit Live")
    static let confirmExitLiveText = internalLocalized("Are you sure you want ro Exit Live?")
    static let meText = internalLocalized("Me")
    
    static let endLiveOnConnectionText = internalLocalized("You are currently co-hosting with other streamers. Would you like to [End Co-host] or [End Live] ?")
    static let endLiveDisconnectText = internalLocalized("End Co-host")
    static let endLiveOnLinkMicText = internalLocalized("You are currently co-guesting with other streamers. Would you like to [End Live] ?")
    static let endLiveOnBattleText = internalLocalized("You are currently in PK mode. Would you like to [End PK] or [End Live] ?")
    static let endLiveBattleText = internalLocalized("End PK")
    static let cancelText = internalLocalized("Cancel")
    static let kickedOutText = internalLocalized("You have been kicked out of the room")
    static let roomDismissText = internalLocalized("Broadcast has been ended")
}
