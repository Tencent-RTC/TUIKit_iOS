//
//  AnchorOverlayView.swift
//  TUILiveKit
//
//  Created by WesleyLei on 2023/10/19.
//

import AtomicXCore
import Combine
import Foundation
import RTCRoomEngine
import TUICore
import AtomicX

public enum AnchorUserEnterRoomNotifyStrategy {
    case always  
    case merge   
}

public class AnchorOverlayView: UIView {
    private let store: AnchorStore
    private let routerManager: AnchorRouterManager
    private lazy var netWorkInfoManager = NetWorkInfoManager(liveID: store.liveID)
    private var cancellableSet: Set<AnyCancellable> = []
    private var isPortrait: Bool = WindowUtils.isPortrait

    private let giftCacheService = GiftManager.shared.giftCacheService

    private var enterRoomNotifyStrategy: AnchorUserEnterRoomNotifyStrategy = .always
    private var intervalSecondOnMerge: TimeInterval = 60
    private var enterRoomUserTimestamps: [String: Date] = [:]

    // MARK: - Node Replace Infrastructure

    private var slotMap: [AnchorNode: AnchorNodeSlot] = [:]
    private var pendingReplacements: [AnchorNode: UIView?] = [:]
    
    private lazy var liveInfoView: LiveInfoView = {
        let view = LiveInfoView(enableFollow: VideoLiveKit.createInstance().enableFollow)
        return view
    }()
    
    private lazy var topRightBar: AnchorTopRightView = {
        let view = AnchorTopRightView(store: store, routerManager: routerManager)
        return view
    }()
    
    private lazy var bottomMenu: AnchorBottomMenuView = {
        let view = AnchorBottomMenuView(store: store, routerManager: routerManager)
        return view
    }()
    
    private lazy var floatView: LinkMicAnchorFloatView = {
        let view = LinkMicAnchorFloatView(store: store, routerManager: routerManager)
        view.isHidden = true
        return view
    }()
    
    lazy var barrageDisplayView: BarrageStreamView = {
        let view = BarrageStreamView(liveID: store.liveID)
        view.delegate = self
        return view
    }()
    
    lazy var giftDisplayView: GiftPlayView = {
        let view = GiftPlayView(roomId: store.liveID)
        view.delegate = self
        return view
    }()
    
    lazy var barrageSendView: BarrageInputView = {
        var view = BarrageInputView(roomId: store.liveID)
        view.layer.cornerRadius = 20.scale375Height()
        view.layer.masksToBounds = true
        return view
    }()
    
    private lazy var netWorkInfoButton: NetworkInfoButton = {
        let button = NetworkInfoButton(liveId: store.liveID)
        button.onNetWorkInfoButtonClicked = { [weak self] in
            guard let self = self else { return }
            let isScreenShareLive = store.liveListState.currentLive.seatTemplate == .videoLandscape4Seats
                && store.liveListState.currentLive.keepOwnerOnSeat
            let panel = NetWorkInfoView(liveID: store.liveID, manager: netWorkInfoManager, isAudience: !store.liveListState.currentLive.keepOwnerOnSeat, isScreenShareLive: isScreenShareLive)
            panel.onRequestDismissNetworkPanel = { [weak self] completion in
                guard let self = self else { return }
                routerManager.dismiss(completion: completion)
            }
            routerManager.present(view: panel, config: .bottomDefault())
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
    
    
    init(store: AnchorStore, routerManager: AnchorRouterManager) {
        self.store = store
        self.routerManager = routerManager
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
    public override func didMoveToWindow() {
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
        setUserEnterRoomNotifyStrategy(.always)
        setupAudienceEnterRoomEvent()
    }
    
    public func setUserEnterRoomNotifyStrategy(_ strategy: AnchorUserEnterRoomNotifyStrategy, intervalSecondOnMerge: TimeInterval = 60) {
        self.enterRoomNotifyStrategy = strategy
        self.intervalSecondOnMerge = intervalSecondOnMerge
    }
    
    private func setupAudienceEnterRoomEvent() {
        store.audienceStore.liveAudienceEventPublisher
            .receive(on: RunLoop.main)
            .sink { [weak self] event in
                guard let self = self else { return }
                switch event {
                case .onAudienceJoined(audience: let audience):
                    guard shouldNotifyEnterRoom(userID: audience.userID) else { return }
                    var barrage = Barrage()
                    barrage.liveID = store.liveID
                    barrage.sender = audience
                    barrage.textContent = " \(String.comingText)"
                    barrage.timestampInSecond = Date().timeIntervalSince1970
                    store.barrageStore.appendLocalTip(message: barrage)
                default: break
                }
            }
            .store(in: &cancellableSet)
    }
    
    private func shouldNotifyEnterRoom(userID: String) -> Bool {
        switch enterRoomNotifyStrategy {
        case .always:
            return true
        case .merge:
            let now = Date()
            cleanExpiredEnterRoomRecords(now: now)
            if enterRoomUserTimestamps[userID] != nil {
                return false
            }
            enterRoomUserTimestamps[userID] = now
            return true
        }
    }
    
    private func cleanExpiredEnterRoomRecords(now: Date) {
        enterRoomUserTimestamps = enterRoomUserTimestamps.filter { _, lastTime in
            now.timeIntervalSince(lastTime) < intervalSecondOnMerge
        }
    }
    
    private func subscribeState() {
        netWorkInfoManager
            .subscribe(StatePublisherSelector(keyPath: \NetWorkInfoState.showToast))
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
    }
    
    public override func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
        let view = super.hitTest(point, with: event)
        return view == self ? nil : view
    }
}

// MARK: - Node Replace

extension AnchorOverlayView {
    func perform(_ action: AnchorAction) {
        switch action {
        case .showLiveInfo:
            liveInfoView.showInfoPanel()
        case .showAudienceList:
            topRightBar.showAudienceList()
        case .showCoHostPanel:
            bottomMenu.showCoHostPanel()
        case .requestBattle:
            bottomMenu.requestBattle()
        case .showCoGuestPanel:
            bottomMenu.showCoGuestPanel()
        case .showMorePanel:
            bottomMenu.showMorePanel()
        case .endLive:
            topRightBar.requestEndLive()
        case .showFloatWindow:
            topRightBar.requestFloatWindow()
        }
    }
    
    func updateBottomItems(_ items: [AnchorBottomItem]) {
        bottomMenu.updateItems(items)
    }

    func updateTopRightItems(_ items: [AnchorTopRightItem]) {
        topRightBar.updateItems(items)
    }
    
    func replace(node: AnchorNode, with view: UIView?) {
        guard isViewReady else {
            pendingReplacements.updateValue(view, forKey: node)
            return
        }
        slotMap[node]?.replace(with: view)
    }

    func restoreNode(_ node: AnchorNode) {
        slotMap[node]?.restore()
    }

    private func flushAllPendingReplacements() {
        for (node, view) in pendingReplacements {
            slotMap[node]?.replace(with: view)
        }
        pendingReplacements.removeAll()
    }
}

// MARK: Layout

extension AnchorOverlayView {
    func constructViewHierarchy() {
        backgroundColor = .clear
        addSubview(barrageDisplayView)
        addSubview(giftDisplayView)
        addSubview(topRightBar)
        addSubview(liveInfoView)
        addSubview(bottomMenu)
        addSubview(floatView)
        addSubview(barrageSendView)
        addSubview(netWorkInfoButton)
        addSubview(netWorkStatusToastView)
        setupSlots()
        flushAllPendingReplacements()
    }
    
    func updateRootViewOrientation(isPortrait: Bool) {
        self.isPortrait = isPortrait
        activateConstraints()
    }
    
    private func setupSlots() {
        slotMap[.liveInfo] = AnchorNodeSlot(defaultView: liveInfoView, in: self)
        slotMap[.topRightButtons] = AnchorNodeSlot(defaultView: topRightBar, in: self)
        slotMap[.networkInfo] = AnchorNodeSlot(defaultView: netWorkInfoButton, in: self)
        slotMap[.bottomRightBar] = AnchorNodeSlot(defaultView: bottomMenu, in: self)
        slotMap[.barrageInput] = AnchorNodeSlot(defaultView: barrageSendView, in: self)
    }

    func activateConstraints() {
        giftDisplayView.snp.remakeConstraints { make in
            make.edges.equalToSuperview()
        }
        
        barrageDisplayView.snp.remakeConstraints { make in
            make.leading.equalToSuperview().offset(12.scale375())
            make.trailing.equalToSuperview().offset(-126.scale375())
            make.height.equalTo(212.scale375Height())
            if let barrageInputGuide = slotMap[.barrageInput]?.guide {
                make.bottom.equalTo(barrageInputGuide.snp.top).offset(-16.scale375Height())
            }
        }

        activateSlotGuides()

        floatView.snp.remakeConstraints { make in
            if let topRightGuide = slotMap[.topRightButtons]?.guide {
                make.top.equalTo(topRightGuide.snp.bottom).offset(34.scale375())
            }
            make.height.equalTo(86.scale375())
            make.width.equalTo(114.scale375())
            make.trailing.equalToSuperview().offset(-8.scale375())
        }

        netWorkStatusToastView.snp.remakeConstraints { make in
            make.centerX.equalToSuperview()
            make.top.equalToSuperview().offset(386.scale375())
            make.width.equalTo(262.scale375())
            make.height.equalTo(40.scale375())
        }
    }

    private func activateSlotGuides() {
        let horizontalGap = 20.scale375()
        let topInset = (self.isPortrait ? 70 : 24).scale375Height()
        let sideInset = (self.isPortrait ? 16 : 45).scale375()

        let topRightSlot = slotMap[.topRightButtons]
        let liveInfoSlot = slotMap[.liveInfo]
        let networkSlot = slotMap[.networkInfo]
        let bottomRightSlot = slotMap[.bottomRightBar]
        let barrageInputSlot = slotMap[.barrageInput]
        
        topRightSlot?.guide.snp.remakeConstraints { make in
            make.top.equalToSuperview().inset(topInset)
            make.trailing.equalToSuperview().inset(sideInset)
        }
        
        liveInfoSlot?.guide.snp.remakeConstraints { make in
            make.leading.equalToSuperview().inset(sideInset)
            if let topRightGuide = topRightSlot?.guide {
                make.centerY.equalTo(topRightGuide)
                make.trailing.lessThanOrEqualTo(topRightGuide.snp.leading).offset(-horizontalGap)
            }
            make.width.equalTo(0).priority(.low)
        }

        networkSlot?.guide.snp.remakeConstraints { make in
            if let topRightGuide = topRightSlot?.guide {
                make.top.equalTo(topRightGuide.snp.bottom).offset(10.scale375())
            }
            make.trailing.equalToSuperview().offset(-8.scale375())
        }

        bottomRightSlot?.guide.snp.remakeConstraints { make in
            make.bottom.equalToSuperview().offset(-38.scale375Height())
            make.trailing.equalToSuperview()
        }

        barrageInputSlot?.guide.snp.remakeConstraints { make in
            make.leading.equalToSuperview().offset(12.scale375())
            make.bottom.equalToSuperview().offset(-38.scale375Height())
            if let bottomRightGuide = bottomRightSlot?.guide {
                make.trailing.lessThanOrEqualTo(bottomRightGuide.snp.leading).offset(-horizontalGap)
            }
            make.width.equalTo(0).priority(.low)
        }
    }
}

extension AnchorOverlayView {
    func showLinkMicFloatView(isPresent: Bool) {
        floatView.isHidden = !isPresent
    }
}

extension AnchorOverlayView: BarrageStreamViewDelegate {
    public func barrageDisplayView(_ barrageDisplayView: BarrageStreamView, createCustomCell barrage: Barrage) -> UIView? {
        guard let extensionInfo = barrage.extensionInfo,
              let typeValue = extensionInfo["TYPE"],
              typeValue == "GIFTMESSAGE"
        else {
            return nil
        }
        return GiftBarrageCell(barrage: barrage)
    }

    public func onBarrageClicked(user: LiveUserInfo) {
        if user.userID == store.selfUserID { return }
        let panel = AnchorUserManagePanelView(user: user, store: store, routerManager: routerManager, type: .messageAndKickOut)
        routerManager.present(view: panel, config: .bottomDefault())
    }
}

extension AnchorOverlayView: GiftPlayViewDelegate {
    public func giftPlayView(_ giftPlayView: GiftPlayView, onReceiveGift gift: Gift, giftCount: Int, sender: LiveUserInfo) {
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
    
    public func giftPlayView(_ giftPlayView: GiftPlayView, onPlayGiftAnimation gift: Gift) {
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

// MARK: - NodeSlot

final class AnchorNodeSlot {

    // MARK: Properties
    private(set) var guide: UILayoutGuide

    private let defaultView: UIView
    private weak var hostView: UIView?
    private var customView: UIView?

    // MARK: Init
    init(defaultView: UIView, in hostView: UIView) {
        self.defaultView = defaultView
        self.hostView = hostView
        self.guide = UILayoutGuide()
        hostView.addLayoutGuide(guide)
        constrainToGuide(defaultView)
    }

    // MARK: - Public API

    func replace(with view: UIView?) {
        customView?.removeFromSuperview()
        customView = nil

        if let newView = view {
            guard newView !== defaultView else {
                restore()
                return
            }
            guard let hostView = hostView else { return }
            defaultView.isHidden = true
            newView.removeFromSuperview()
            hostView.insertSubview(newView, aboveSubview: defaultView)
            constrainToGuide(newView)
            customView = newView
        } else {
            defaultView.isHidden = true
        }
    }

    func restore() {
        customView?.removeFromSuperview()
        customView = nil
        defaultView.isHidden = false
        constrainToGuide(defaultView)
    }

    // MARK: - Private
    private func constrainToGuide(_ view: UIView) {
        view.snp.remakeConstraints { make in
            make.edges.equalTo(guide)
        }
    }
}

private extension String {
    static let meText = internalLocalized("common_gift_me")
    static let comingText = internalLocalized("common_entered_room")
}
