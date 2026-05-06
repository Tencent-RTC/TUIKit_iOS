//
//  AudienceOverlayView.swift
//  TUILiveKit
//
//  Created by krabyu on 2023/12/15.
//

import AtomicXCore
import Combine
import AtomicX
import RTCRoomEngine
import TUICore
import UIKit

public enum AudienceUserEnterRoomNotifyStrategy {
    case always  
    case merge  
}

public class AudienceOverlayView: UIView {
    weak var rotateScreenDelegate: RotateScreenDelegate?

    // MARK: - Node Replace Infrastructure
    private var slotMap: [AudienceNode: AudienceNodeSlot] = [:]
    private var pendingReplacements: [AudienceNode: UIView?] = [:]

    // MARK: - Private Properties

    lazy var barrageStore: BarrageStore = .create(liveID: manager.liveID)
    private let manager: AudienceStore
    private let routerManager: AudienceRouterManager
    private lazy var netWorkInfoManager = NetWorkInfoManager(liveID: manager.liveID)
    private var cancellableSet = Set<AnyCancellable>()
    private var inRoomCancellableSet = Set<AnyCancellable>()
    private var isInRoom: Bool = false
    private let giftCacheService = GiftManager.shared.giftCacheService
    private var isPortrait: Bool = WindowUtils.isPortrait

    private var playbackQuality: VideoQuality?

    private var enterRoomNotifyStrategy: AudienceUserEnterRoomNotifyStrategy = .always
    private var intervalSecondOnMerge: TimeInterval = 60
    private var enterRoomUserTimestamps: [String: Date] = [:]

    // MARK: - Subviews

    private lazy var liveInfoView: LiveInfoView = {
        let view = LiveInfoView(enableFollow: VideoLiveKit.createInstance().enableFollow)
        return view
    }()

    private lazy var topRightBar: AudienceTopRightView = {
        let view = AudienceTopRightView(manager: manager, routerManager: routerManager)
        return view
    }()

    private lazy var rotateScreenButton: UIButton = {
        let button = UIButton()
        button.setImage(internalImage("live_rotate_screen"), for: .normal)
        button.addTarget(self, action: #selector(rotateScreenClick), for: .touchUpInside)
        button.imageEdgeInsets = UIEdgeInsets(top: 2.scale375(), left: 2.scale375(), bottom: 2.scale375(), right: 2.scale375())
        button.isHidden = true
        return button
    }()

    lazy var barrageSendView: BarrageInputView = {
        var view = BarrageInputView(roomId: manager.liveID)
        view.layer.cornerRadius = 20.scale375Height()
        view.layer.masksToBounds = true
        return view
    }()

    private lazy var bottomMenu: AudienceBottomMenuView = {
        let view = AudienceBottomMenuView(manager: manager, routerManager: routerManager)
        return view
    }()

    private lazy var floatView: LinkMicAudienceFloatView = {
        let view = LinkMicAudienceFloatView(manager: manager, routerManager: routerManager)
        view.isHidden = true
        return view
    }()

    lazy var barrageDisplayView: BarrageStreamView = {
        let view = BarrageStreamView(liveID: manager.liveID)
        view.delegate = self
        return view
    }()

    private lazy var giftDisplayView: GiftPlayView = {
        let view = GiftPlayView(roomId: manager.liveID)
        view.delegate = self
        return view
    }()

    private lazy var netWorkInfoButton: NetworkInfoButton = {
        let button = NetworkInfoButton(liveId: manager.liveID)
        button.onNetWorkInfoButtonClicked = { [weak self] in
            guard let self = self, WindowUtils.isPortrait else { return }
            let isScreenShareLive = manager.liveListState.currentLive.seatTemplate == .videoLandscape4Seats
            && manager.liveListState.currentLive.keepOwnerOnSeat
            let panel = NetWorkInfoView(liveID: manager.liveID, manager: netWorkInfoManager, isAudience: !manager.coGuestState.connected.isOnSeat(), isScreenShareLive: isScreenShareLive)
            panel.onRequestDismissNetworkPanel = { [weak self] completion in
                guard let self = self else { return }
                routerManager.dismiss(completion: completion)
            }
            routerManager.present(view: panel)
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

    lazy var restoreClearButton: UIButton = {
        let button = UIButton()
        button.backgroundColor = .black.withAlphaComponent(0.2)
        button.setImage(internalImage("live_restore_clean_icon"), for: .normal)
        button.layer.cornerRadius = 20.scale375()
        button.isHidden = true
        button.addTarget(self, action: #selector(onRestoreClearButtonClick), for: .touchUpInside)
        return button
    }()

    var isClearModeActive: Bool = false

    // MARK: - Init

    init(manager: AudienceStore, routerManager: AudienceRouterManager) {
        self.manager = manager
        self.routerManager = routerManager
        super.init(frame: .zero)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
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

    public override func layoutSubviews() {
        super.layoutSubviews()
        let anchorY = barrageDisplayView.convert(CGPoint.zero, to: giftDisplayView).y
        guard anchorY != giftDisplayView.giftBulletBottomAnchorY else { return }
        giftDisplayView.updateBulletViewsLayout(bottomAnchorY: anchorY)
    }

    public override func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
        let view = super.hitTest(point, with: event)
        return view == self ? nil : view
    }


    // MARK: - Slide to Clear

    private var fixedViews: [UIView] {
        return [restoreClearButton]
    }
    
    func applyClearTranslation(_ translationX: CGFloat) {
            let transform = CGAffineTransform(translationX: translationX, y: 0)
            
            for subview in self.subviews {
                if fixedViews.contains(subview) { continue }
                
                if let clearableView = subview as? AudienceTopRightView {
                    clearableView.applyClearTranslation(translationX)
                }
                else {
                    subview.transform = transform
                }
            }
        }

    func completeClear() {
        isClearModeActive = true
        restoreClearButton.isHidden = false
    }

    func cancelClear() {
        applyClearTranslation(0)
    }

    func restoreFromClear() {
        isClearModeActive = false
        cancelClear()
        restoreClearButton.isHidden = true
    }

    @objc private func onRestoreClearButtonClick() {
        UIView.animate(withDuration: 0.3) { [weak self] in
            guard let self = self else { return }
            cancelClear()
        }
        restoreClearButton.isHidden = true
        isClearModeActive = false
    }

    func startGiftObserving() {
        giftDisplayView.startObserving()
    }

    func stopGiftObserving() {
        giftDisplayView.stopObserving()
    }
}

// MARK: - Node Replace

extension AudienceOverlayView {
    func perform(_ action: AudienceAction) {
        switch action {
        case .showLiveInfo:
            liveInfoView.showInfoPanel()
        case .showAudienceList:
            topRightBar.showAudienceList()
        case .showGiftPanel:
            bottomMenu.showGiftPanel()
        case .showCoGuestPanel:
            bottomMenu.showCoGuestPanel()
        case .showFloatWindow:
            topRightBar.requestFloatWindow()
        case .exitLive:
            topRightBar.requestExitLive()
        case  .showMorePanel:
            bottomMenu.showMorePanel()
        }
    }

    func updateBottomItems(_ items: [AudienceBottomItem]) {
        bottomMenu.updateItems(items)
    }

    func updateTopRightItems(_ items: [AudienceTopRightItem]) {
        topRightBar.updateItems(items)
    }

    func replace(node: AudienceNode, with view: UIView?) {
        guard isViewReady else {
            pendingReplacements.updateValue(view, forKey: node)
            return
        }
        slotMap[node]?.replace(with: view)
    }

    func restoreNode(_ node: AudienceNode) {
        slotMap[node]?.restore()
    }

    private func flushAllPendingReplacements() {
        for (node, view) in pendingReplacements {
            slotMap[node]?.replace(with: view)
        }
        pendingReplacements.removeAll()
    }
}

// MARK: - Layout

extension AudienceOverlayView {
    private func constructViewHierarchy() {
        addSubview(barrageDisplayView)
        addSubview(giftDisplayView)
        addSubview(liveInfoView)
        addSubview(topRightBar)
        addSubview(bottomMenu)
        addSubview(floatView)
        addSubview(barrageSendView)
        addSubview(netWorkInfoButton)
        addSubview(netWorkStatusToastView)
        addSubview(rotateScreenButton)
        addSubview(restoreClearButton)
        setupSlots()
        flushAllPendingReplacements()
    }

    private func setupSlots() {
        slotMap[.liveInfo] = AudienceNodeSlot(defaultView: liveInfoView, in: self)
        slotMap[.topRightButtons] = AudienceNodeSlot(defaultView: topRightBar, in: self)
        slotMap[.networkInfo] = AudienceNodeSlot(defaultView: netWorkInfoButton, in: self)
        slotMap[.bottomRightBar] = AudienceNodeSlot(defaultView: bottomMenu, in: self)
        slotMap[.barrageInput] = AudienceNodeSlot(defaultView: barrageSendView, in: self)
    }

    func updateRootViewOrientation(isPortrait: Bool) {
        self.isPortrait = isPortrait
        activateConstraints()

        if isPortrait {
            bottomMenu.isHidden = false
            barrageSendView.isHidden = false
        } else {
            bottomMenu.isHidden = true
            barrageSendView.isHidden = true
        }
    }

    private func activateConstraints() {
        giftDisplayView.snp.remakeConstraints { make in
            make.edges.equalToSuperview()
        }

        barrageDisplayView.snp.remakeConstraints { make in
            if isPortrait {
                make.leading.equalToSuperview().offset(12.scale375())
                make.trailing.equalToSuperview().offset(-126.scale375())
                make.height.equalTo(212.scale375Height())
                if let barrageInputGuide = slotMap[.barrageInput]?.guide {
                    make.bottom.equalTo(barrageInputGuide.snp.top).offset(-12.scale375Height())
                }

            } else {
                make.leading.equalTo(safeAreaLayoutGuide).offset(12.scale375())
                make.trailing.equalToSuperview().offset(-126.scale375())
                make.top.equalTo(snp.bottom).multipliedBy(0.45)
                make.bottom.equalToSuperview().offset(-12.scale375Height())
            }
        }

        activateSlotGuides()

        floatView.snp.remakeConstraints { make in
            if let topRightGuide = slotMap[.topRightButtons]?.guide {
                make.top.equalTo(topRightGuide.snp.bottom).offset(34.scale375Width())
            }
            make.height.width.equalTo(86.scale375())
            make.trailing.equalToSuperview().offset(-8.scale375())
        }
        
        netWorkStatusToastView.snp.remakeConstraints { make in
            make.centerX.equalToSuperview()
            make.top.equalToSuperview().offset(386.scale375())
            make.width.equalTo(262.scale375())
            make.height.equalTo(40.scale375())
        }

        if isPortrait {
            restoreClearButton.snp.remakeConstraints { make in
                make.trailing.equalToSuperview().inset(16.scale375())
                make.bottom.equalToSuperview().inset(40.scale375Height())
                make.width.height.equalTo(40.scale375())
            }
        } else {
            restoreClearButton.snp.remakeConstraints { make in
                make.trailing.equalToSuperview().inset(16.scale375())
                make.bottom.equalToSuperview().inset(40.scale375())
                make.width.height.equalTo(40.scale375())
            }
        }

        updateRotateScreenButtonLayout()
    }

    private func activateSlotGuides() {
        let horizontalGap = 20.scale375()
        let topInset = (self.isPortrait ? 70 : 20).scale375Height()
        let sideInset = 20.scale375()

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

    private func updateRotateScreenButtonLayout() {
        if !manager.liveListState.currentLive.isEmpty,
            manager.liveListState.currentLive.seatTemplate == .videoLandscape4Seats,
            isPortrait {
            let coreViewHeight = Screen_Width * 720 / 1280
            rotateScreenButton.snp.remakeConstraints { make in
                make.trailing.equalToSuperview().offset(-10.scale375Width())
                make.top.equalToSuperview().offset(130 + coreViewHeight - 32.scale375Width() - 8)
                make.width.equalTo(32.scale375Width())
                make.height.equalTo(32.scale375Width())
            }
            return
        }

        if isPortrait {
            rotateScreenButton.snp.remakeConstraints { make in
                make.trailing.equalToSuperview().offset(-10.scale375Width())
                make.top.equalToSuperview().offset(475.scale375Height())
                make.width.equalTo(32.scale375Width())
                make.height.equalTo(32.scale375Width())
            }
        } else {
            rotateScreenButton.snp.remakeConstraints { make in
                make.trailing.equalToSuperview().offset(-20.scale375Width())
                make.top.equalToSuperview().offset(185.scale375Height())
                make.width.equalTo(32.scale375Width())
                make.height.equalTo(32.scale375Width())
            }
        }
    }
}

// MARK: - Binding

extension AudienceOverlayView {
    private func bindInteraction() {
        subscribeOrientationChange()
        subscribeInRoomLifecycle()
        setUserEnterRoomNotifyStrategy(.always)
    }

    public func setUserEnterRoomNotifyStrategy(_ strategy: AudienceUserEnterRoomNotifyStrategy, intervalSecondOnMerge: TimeInterval = 60) {
        self.enterRoomNotifyStrategy = strategy
        self.intervalSecondOnMerge = intervalSecondOnMerge
    }

    private func subscribeInRoomLifecycle() {
        manager.subscribeState(StatePublisherSelector(keyPath: \LiveListState.currentLive))
            .map { !$0.isEmpty }
            .removeDuplicates()
            .receive(on: RunLoop.main)
            .sink { [weak self] inRoom in
                guard let self = self else { return }
                if inRoom {
                    onEnterRoom()
                } else {
                    onLeaveRoom()
                }
            }
            .store(in: &cancellableSet)
    }

    private func onEnterRoom() {
        guard !isInRoom else { return }
        isInRoom = true
        subscribeRoomState()
        subscribeMediaState()
        subscribeSeatSubject()
        subscribeNetWorkInfoSubject()
        setupAudienceEnterRoomEvent()
    }

    private func onLeaveRoom() {
        guard isInRoom else { return }
        isInRoom = false
        inRoomCancellableSet.removeAll()
        playbackQuality = nil
    }

    private func setupAudienceEnterRoomEvent() {
        manager.liveAudienceStore.liveAudienceEventPublisher
            .receive(on: RunLoop.main)
            .sink { [weak self] event in
                guard let self = self else { return }
                switch event {
                case .onAudienceJoined(audience: let audience):
                    guard shouldNotifyEnterRoom(userID: audience.userID) else { return }
                    var barrage = Barrage()
                    barrage.liveID = manager.liveID
                    barrage.sender = audience
                    barrage.textContent = " \(String.comingText)"
                    barrage.timestampInSecond = Date().timeIntervalSince1970
                    barrageStore.appendLocalTip(message: barrage)
                default: break
                }
            }
            .store(in: &inRoomCancellableSet)
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

    private func subscribeOrientationChange() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleOrientationChange),
            name: Notification.Name.TUILiveKitRotateScreenNotification,
            object: nil
        )
    }

    private func subscribeRoomState() {
        manager.subscribeState(StatePublisherSelector(keyPath: \AudienceState.roomVideoStreamIsLandscape))
            .receive(on: RunLoop.main)
            .removeDuplicates()
            .sink { [weak self] videoStreamIsLandscape in
                guard let self = self else { return }
                let isScreenShareLive = manager.liveListState.currentLive.seatTemplate == .videoLandscape4Seats
                    && manager.liveListState.currentLive.keepOwnerOnSeat
                rotateScreenButton.isHidden = !videoStreamIsLandscape || isScreenShareLive
            }
            .store(in: &inRoomCancellableSet)
    }

    private func subscribeMediaState() {
        manager.subscribeState(StatePublisherSelector(keyPath: \AudienceMediaState.playbackQuality))
            .receive(on: RunLoop.main)
            .removeDuplicates()
            .sink { [weak self] playbackQuality in
                guard let self = self else { return }
                defer { self.playbackQuality = playbackQuality }
                guard let quality = playbackQuality else { return }
                guard self.playbackQuality != nil else { return }
                showAtomicToast(text: .resolutionChangedText + .videoQualityToString(quality: quality), style: .success)
            }
            .store(in: &inRoomCancellableSet)
    }

    private func subscribeSeatSubject() {
        manager.subscribeState(StatePublisherSelector(keyPath: \LiveListState.currentLive))
            .receive(on: RunLoop.main)
            .sink { [weak self] currentLive in
                guard let self = self, !currentLive.isEmpty else { return }
                barrageDisplayView.setOwnerId(currentLive.liveOwner.userID)
                updateRotateScreenButtonLayout()
            }
            .store(in: &inRoomCancellableSet)
    }

    private func subscribeNetWorkInfoSubject() {
        netWorkInfoManager
            .subscribe(StatePublisherSelector(keyPath: \NetWorkInfoState.showToast))
            .receive(on: RunLoop.main)
            .sink { [weak self] showToast in
                guard let self = self else { return }
                netWorkStatusToastView.isHidden = !showToast
            }
            .store(in: &inRoomCancellableSet)
    }
}

// MARK: - View Action

extension AudienceOverlayView {
    @objc private func rotateScreenClick() {
        rotateScreenDelegate?.rotateScreen(isPortrait: !WindowUtils.isPortrait)
    }

    @objc private func handleOrientationChange() {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            isPortrait = WindowUtils.isPortrait
            activateConstraints()

            if isPortrait {
                bottomMenu.isHidden = false
                barrageSendView.isHidden = false
            } else {
                bottomMenu.isHidden = true
                barrageSendView.isHidden = true
            }
        }
    }
}

// MARK: - BarrageStreamViewDelegate

extension AudienceOverlayView: BarrageStreamViewDelegate {
    public func barrageDisplayView(_ barrageDisplayView: BarrageStreamView, createCustomCell barrage: Barrage) -> UIView? {
        guard let type = barrage.extensionInfo?["TYPE"], type == "GIFTMESSAGE" else {
            return nil
        }
        return GiftBarrageCell(barrage: barrage)
    }

    public func onBarrageClicked(user: LiveUserInfo) {
        if user.userID == manager.loginState.loginUserInfo?.userID { return }
        let seatInfo = SeatInfo(userInfo: user)
        let panel = AudienceUserManagePanelView(user: seatInfo, manager: manager, routerManager: routerManager, type: .userInfo)
        routerManager.present(view: panel)
    }
}

// MARK: - GiftPlayViewDelegate

extension AudienceOverlayView: GiftPlayViewDelegate {
    public func giftPlayView(_ giftPlayView: GiftPlayView, onReceiveGift gift: Gift, giftCount: Int, sender: LiveUserInfo) {
        var receiverUserName = manager.liveListState.currentLive.liveOwner.userName
        if manager.liveListState.currentLive.liveOwner.userID == manager.loginState.loginUserInfo?.userID {
            receiverUserName = .meText
        }

        var barrage = Barrage()
        barrage.textContent = "gift"
        barrage.sender = sender
        barrage.extensionInfo = [
            "TYPE": "GIFTMESSAGE",
            "gift_name": gift.name,
            "gift_count": "\(giftCount)",
            "gift_icon_url": gift.iconURL,
            "gift_receiver_username": receiverUserName
        ]
        barrageStore.appendLocalTip(message: barrage)
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

final class AudienceNodeSlot {

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
    static let resolutionChangedText = internalLocalized("live_video_resolution_changed")

    static func videoQualityToString(quality: VideoQuality) -> String {
        switch quality {
        case .quality1080P:
            return "1080P"
        case .quality720P:
            return "720P"
        case .quality540P:
            return "540P"
        case .quality360P:
            return "360P"
        }
    }
}
