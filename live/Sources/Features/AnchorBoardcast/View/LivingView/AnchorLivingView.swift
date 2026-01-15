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
import AtomicX

class AnchorLivingView: UIView {
    private let store: AnchorStore
    private let routerManager: AnchorRouterManager
    private let coreView: LiveCoreView
    private lazy var netWorkInfoManager = NetWorkInfoManager(liveID: store.liveID)
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
        let view = AnchorBottomMenuView(store: store, routerManager: routerManager, coreView: coreView)
        return view
    }()
    
    private lazy var floatView: LinkMicAnchorFloatView = {
        let view = LinkMicAnchorFloatView(store: store, routerManager: routerManager)
        view.isHidden = true
        return view
    }()
    
    private lazy var barrageDisplayView: BarrageStreamView = {
        let view = BarrageStreamView(liveID: store.liveID)
        view.delegate = self
        return view
    }()
    
    private lazy var giftDisplayView: GiftPlayView = {
        let view = GiftPlayView(roomId: store.liveID)
        view.delegate = self
        return view
    }()
    
    private lazy var barrageSendView: BarrageInputView = {
        var view = BarrageInputView(roomId: store.liveID)
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
        let button = NetworkInfoButton(liveId: store.liveID)
        button.onNetWorkInfoButtonClicked = { [weak self] in
            guard let self = self else { return }
            routerManager.router(action: .present(.netWorkInfo(netWorkInfoManager, isAudience: !store.liveListState.currentLive.keepOwnerOnSeat)))
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
    
    init(store: AnchorStore, routerManager: AnchorRouterManager, coreView: LiveCoreView) {
        self.store = store
        self.routerManager = routerManager
        self.coreView = coreView
        super.init(frame: .zero)
    }
    
    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    deinit {
        if store.coGuestState.connected.isOnSeat() {
            store.liveListStore.leaveLive(completion: nil)
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
        store.subscribeState(StatePublisherSelector(keyPath: \CoGuestState.applicants))
            .receive(on: RunLoop.main)
            .removeDuplicates()
            .sink { [weak self] applicants in
                guard let self = self else { return }
                if store.coHostState.applicant != nil
                    || !store.coHostState.invitees.isEmpty
                    || !store.coHostState.connected.isEmpty
                {
                    // If received connection request first, reject all linkmic auto.
                    for applicant in applicants {
                        store.coGuestStore.rejectApplication(userID: applicant.userID, completion: nil)
                    }
                    return
                }
                showLinkMicFloatView(isPresent: applicants.count > 0)
            }
            .store(in: &cancellableSet)
        store.subscribeState(StatePublisherSelector(keyPath: \LiveListState.currentLive))
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
        
        store.subscribeState(StatePublisherSelector(keyPath: \LoginState.loginStatus))
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

        store.liveListStore.liveListEventPublisher
            .receive(on: RunLoop.main)
            .sink { [weak self] event in
                guard let self = self else { return }
                switch event {
                    case .onLiveEnded(let liveID, let liveEndedReason, let message):
                        if liveEndedReason == .endedByServer && liveID == store.liveID{
                            onLiveEndedByService()
                        }
                    case .onKickedOutOfLive(let liveID, let reason, let message):
                        break
                }
            }
            .store(in: &cancellableSet)
    }
    
    private func subscribeSubject() {
        store.kickedOutSubject
            .receive(on: RunLoop.main)
            .sink { [weak self] isDismissed in
                guard let self = self else { return }
                isUserInteractionEnabled = false
                coreView.isUserInteractionEnabled = false
                routerManager.router(action: .dismiss())
                if isDismissed {
                    showAtomicToast(text: .roomDismissText, style: .warning)
                } else {
                    showAtomicToast(text: .kickedOutText, style: .warning)
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
        store.floatWindowSubject.send()
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
            make.leading.equalToSuperview().offset(12.scale375())
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
        var items: [AlertButtonConfig] = []

        let selfUserId = store.selfUserID
        let isSelfInCoGuestConnection = store.coGuestState.connected.count > 1
        let isSelfInCoHostConnection = store.coHostState.connected.count > 1
        let isSelfInBattle = store.battleState.battleUsers.contains(where: { $0.userID == selfUserId }) && isSelfInCoHostConnection
        
        if isSelfInBattle {
            title = .endLiveOnBattleText
            let endBattleItem = AlertButtonConfig(text: .endLiveBattleText, type: .red) { [weak self] _ in
                guard let self = self else { return }
                exitBattle()
                routerManager.dismiss()
            }
            items.append(endBattleItem)
        } else if isSelfInCoHostConnection {
            title = .endLiveOnConnectionText
            let endConnectionItem = AlertButtonConfig(text: .endLiveDisconnectText, type: .red) { [weak self] _ in
                guard let self = self else { return }
                store.coHostStore.exitHostConnection()
                routerManager.dismiss()
            }
            items.append(endConnectionItem)
        } else if isSelfInCoGuestConnection {
            title = .endLiveOnLinkMicText
        } else {
            let cancelButton = AlertButtonConfig(text: String.cancelText, type: .grey) { [weak self] _ in
                guard let self = self else { return }
                self.routerManager.dismiss(dismissType: .alert)
            }
            let confirmButton = AlertButtonConfig(text: String.confirmCloseText, type: .red) { [weak self] _ in
                guard let self = self else { return }
                self.stopLiveStream()
                self.routerManager.dismiss(dismissType: .alert)
            }
            let alertConfig = AlertViewConfig(title: .confirmEndLiveText,
                                              cancelButton: cancelButton,
                                              confirmButton: confirmButton)
            routerManager.present(view: AtomicAlertView(config: alertConfig))
            return
        }
        
        let text: String = store.liveListState.currentLive.keepOwnerOnSeat ? .confirmCloseText : .confirmExitText
        let colorType: TextColorPreset = title == .endLiveOnLinkMicText ? .red : .primary
        let endLiveItem = AlertButtonConfig(text: text, type: colorType) { [weak self] _ in
            guard let self = self else { return }
            self.exitBattle()
            self.stopLiveStream()
            self.routerManager.dismiss()
        }
        items.append(endLiveItem)
        
        let cancelItem = AlertButtonConfig(text: .cancelText, type: .primary) { [weak self] _ in
            guard let self = self else { return }
            self.routerManager.dismiss()
        }
        items.append(cancelItem)

        let alertConfig = AlertViewConfig(title: title, items: items)
        routerManager.present(view: AtomicAlertView(config: alertConfig))
    }
    
    private func exitBattle() {
        store.battleStore.exitBattle(battleID: store.battleState.currentBattleInfo?.battleID ?? "", completion: nil)
    }
    
    func stopLiveStream() {
        if store.liveListState.currentLive.keepOwnerOnSeat {
            store.liveListStore.endLive { [weak self] result in
                guard let self = self else { return }
                switch result {
                case .success(let statisticsData):
                    showEndView(with: statisticsData)
                case .failure(let err):
                    let error = InternalError(code: err.code, message: err.message)
                    store.onError(error)
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1) { [weak self] in
                        guard let self = self else { return }
                        routerManager.router(action: .exit)
                    }
                }
            }
        } else {
            store.liveListStore.leaveLive { [weak self] result in
                guard let self = self else { return }
                switch result {
                case .success(()):
                    routerManager.router(action: .exit)
                case .failure(let err):
                    let error = InternalError(code: err.code, message: err.message)
                    store.onError(error)
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
            store.onEndLivingSubject.send(state)
        }
    }

    func onLiveEndedByService() {
        let date = store.summaryStore.state.value.summaryData
        anchorObserverState.update { [weak self] state in
            guard let self = self else { return }
            state.duration = Int(date.totalDuration / 1000)
            state.viewCount = Int(date.totalViewers)
            state.giftTotalCoins = Int(date.totalGiftCoins)
            state.giftTotalUniqueSender = Int(date.totalGiftUniqueSenders)
            state.likeTotalUniqueSender = Int(date.totalLikesReceived)
            state.messageCount = barrageDisplayView.getBarrageCount()
            store.onEndLivingSubject.send(state)
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
        if user.userID == store.selfUserID { return }
        routerManager.router(action: .present(.userManagement(SeatInfo(userInfo: user), type: .messageAndKickOut)))
    }
}

extension AnchorLivingView: GiftPlayViewDelegate {
    func giftPlayView(_ giftPlayView: GiftPlayView, onReceiveGift gift: Gift, giftCount: Int, sender: LiveUserInfo) {
        var userName = store.liveListState.currentLive.liveOwner.userName
        if store.liveListState.currentLive.liveOwner.userID == store.selfUserID {
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
        store.barrageStore.appendLocalTip(message: barrage)
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
    static let confirmCloseText = internalLocalized("common_end_live")
    static let confirmEndLiveText = internalLocalized("live_end_live_tips")
    static let confirmExitText = internalLocalized("common_exit_live")
    static let meText = internalLocalized("common_gift_me")
    
    static let endLiveOnConnectionText = internalLocalized("common_end_connection_tips")
    static let endLiveDisconnectText = internalLocalized("common_end_connection")
    static let endLiveOnLinkMicText = internalLocalized("common_anchor_end_link_tips")
    static let endLiveOnBattleText = internalLocalized("common_end_pk_tips")
    static let endLiveBattleText = internalLocalized("common_end_pk")
    static let cancelText = internalLocalized("common_cancel")
    static let kickedOutText = internalLocalized("common_kicked_out_of_room_by_owner")
    static let roomDismissText = internalLocalized("common_room_destroy")
}
