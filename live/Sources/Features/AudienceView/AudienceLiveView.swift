//
//  AudienceLiveView.swift
//  TUILiveKit
//
//  Created by krabyu on 2023/10/19.
//

import AtomicX
import AtomicXCore
import Combine
import Foundation
import RTCRoomEngine
import TUICore

public protocol RotateScreenDelegate: AnyObject {
    func rotateScreen(isPortrait: Bool)
}

protocol AudienceLiveViewDelegate: AnyObject {
    func handleScrollToNewRoom(roomId: String,
                               ownerId: String,
                               manager: AudienceStore,
                               liveView: AudienceLiveView,
                               relayoutCoreViewClosure: @escaping () -> Void)
    func showFloatWindow()
    func showAtomicToast(message: String, toastStyle: ToastStyle)
    func disableScrolling()
    func enableScrolling()
    func scrollToNextPage()
    func onRoomDismissed(roomId: String, avatarUrl: String, userName: String)
}

public class AudienceLiveView: RTCBaseView {
    let liveInfo: LiveInfo
    weak var delegate: AudienceLiveViewDelegate?
    weak var rotateScreenDelegate: RotateScreenDelegate?
    
    // MARK: - Public API

    public var barrageStreamView: BarrageStreamView { overlayView.barrageDisplayView }

    public var barrageInput: BarrageInputView { overlayView.barrageSendView }

    public var bottomItems: [AudienceBottomItem] = [.gift, .coGuest, .like, .more] {
        didSet {
            guard isViewReady else { return }
            refreshBottomItems()
        }
    }

    public var topRightItems: [AudienceTopRightItem] = [.audienceCount, .floatWindow, .close] {
        didSet {
            guard isViewReady else { return }
            overlayView.updateTopRightItems(topRightItems)
        }
    }

    public func replace(node: AudienceNode, with view: UIView?) {
        overlayView.replace(node: node, with: view)
    }

    public func perform(_ action: AudienceAction) {
        overlayView.perform(action)
    }

    public private(set) var coreView: LiveCoreView
    
    public lazy var overlayView: AudienceOverlayView = {
        let view = AudienceOverlayView(manager: manager, routerManager: routerManager)
        view.rotateScreenDelegate = self
        return view
    }()

    // MARK: - Private Properties

    let manager: AudienceStore
    private let routerManager: AudienceRouterManager
    private var cancellableSet: Set<AnyCancellable> = []
    private var defaultVideoViewDelegate: AudienceVideoDelegate?
    private var isViewReady: Bool = false
    private var isCurrentShowCell: Bool = false
    private var currentLiveOwner: LiveUserInfo?
    
    private var panDirection: PanDirection = .none
    enum PanDirection {
        case left, right, none
    }
    
    private var roomId: String {
        return liveInfo.liveID
    }
    
    private func muteImageName(isLandscape: Bool) -> String {
        let isEn = getPreferredLanguage() == "en"
        if isLandscape {
            return isEn ? "live_muteImage_en_land" : "live_muteImage_land"
        } else {
            return isEn ? "live_muteImage_en" : "live_muteImage"
        }
    }
    
    private var hostAbsentCancellable: AnyCancellable?
    private var showHostAbsentWorkItem: DispatchWorkItem?
    
    lazy var blurView = UIVisualEffectView(effect: UIBlurEffect(style: .light))
    
    lazy var coverBgView: UIImageView = {
        let imageView = UIImageView(frame: .zero)
        imageView.isUserInteractionEnabled = true
        blurView.isHidden = true
        imageView.addSubview(blurView)
        blurView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }
        return imageView
    }()
    
    lazy var topGradientView: UIView = {
        var view = UIView()
        view.isUserInteractionEnabled = false
        return view
    }()
    
    lazy var bottomGradientView: UIView = {
        var view = UIView()
        view.isUserInteractionEnabled = false
        return view
    }()
    
    private lazy var hostAbsentView: UIImageView = {
        let imageView = UIImageView()
        imageView.image = internalImage(muteImageName(isLandscape: false))
        imageView.contentMode = .scaleAspectFill
        imageView.isHidden = true
        return imageView
    }()
    
    private var gameView: AudienceGameView?

    private func createGameViewIfNeeded() {
        guard gameView == nil else { return }
        let view = AudienceGameView(liveID: roomId, manager: manager, routerManager: routerManager)
        gameView = view
        insertSubview(view, aboveSubview: coreView)
        view.snp.remakeConstraints { make in
            make.centerX.centerY.equalToSuperview()
            make.leading.trailing.equalToSuperview()
        }
    }
    
    private func removeGameView() {
        gameView?.removeFromSuperview()
        gameView = nil
    }
    
    private var disabledBottomItems: Set<AudienceBottomItem> = [] {
        didSet {
            guard isViewReady else { return }
            refreshBottomItems()
        }
    }

    private func refreshBottomItems() {
        let effectiveItems = bottomItems.filter { !disabledBottomItems.contains($0) }
        overlayView.updateBottomItems(effectiveItems)
    }
    
    init(liveInfo: LiveInfo, routerManager: AudienceRouterManager) {
        self.liveInfo = liveInfo
        self.manager = AudienceStore(liveID: liveInfo.liveID)
        self.routerManager = routerManager
        self.currentLiveOwner = liveInfo.liveOwner
        self.coreView = LiveCoreView.getCachedCoreView(liveID: liveInfo.liveID, type: .playView)
        super.init(frame: .zero)
        coreView.setLiveID(roomId)
        KeyMetrics.setComponent(Constants.ComponentType.liveRoom.rawValue)
        backgroundColor = .black
        debugPrint("init:\(self)")
    }
    
    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    deinit {
        stopPreview()
        NotificationCenter.default.removeObserver(self)
        LiveKitLog.info("\(#file)", "\(#line)", "deinit AudienceLiveView \(self)")
    }
    
    // MARK: - Setup
    
    func setupLiveID(_ liveId: String) {
        coreView.setLiveID(liveId)
    }
    
    // MARK: - Slide Lifecycle
    
    func onViewWillSlideIn() {
        LiveKitLog.info("\(#file)", "\(#line)", "onViewWillSlideIn roomId: \(roomId)")
        overlayView.isHidden = true
        startPreview()
    }
    
    func onViewDidSlideIn() {
        LiveKitLog.info("\(#file)", "\(#line)", "onViewDidSlideIn roomId: \(roomId)")
        enterRoom()
        overlayView.startGiftObserving()
        isCurrentShowCell = true
    }
    
    func onViewSlideInCancelled() {
        LiveKitLog.info("\(#file)", "\(#line)", "onViewSlideInCancelled roomId: \(roomId)")
        stopPreview()
    }
    
    func onViewWillSlideOut() {
        LiveKitLog.info("\(#file)", "\(#line)", "onViewWillSlideOut roomId: \(roomId)")
    }
    
    func onViewDidSlideOut() {
        LiveKitLog.info("\(#file)", "\(#line)", "onViewDidSlideOut roomId: \(roomId)")
        overlayView.stopGiftObserving()
        restoreOverlay()
        if !FloatWindow.shared.isShowingFloatWindow() {
            stopPreview()
            if isCurrentShowCell { leaveRoom() }
        }
        isCurrentShowCell = false
    }
    
    func onViewSlideOutCancelled() {
        LiveKitLog.info("\(#file)", "\(#line)", "onViewSlideOutCancelled roomId: \(roomId)")
    }
    
    private func enterRoom() {
        setupVideoViewDelegate()
        delegate?.handleScrollToNewRoom(roomId: roomId,
                                        ownerId: manager.liveListState.currentLive.liveOwner.userID,
                                        manager: manager,
                                        liveView: self) { [weak self] in
            guard let self = self else { return }
            relayoutCoreView()
        }
        delegate?.disableScrolling()
        joinLiveStream { [weak self] result in
            guard let self = self else { return }
            if case .success = result {
                overlayView.isHidden = false
                delegate?.enableScrolling()
                currentLiveOwner = manager.liveListState.currentLive.liveOwner
                showSeatListIfNeeded()
                subscribeHostAbsentState()
            }
        }
    }

    private func setupVideoViewDelegate() {
        if coreView.videoViewDelegate == nil {
            let delegate = AudienceVideoDelegate(manager: manager, routerManager: routerManager, coreView: coreView)
            defaultVideoViewDelegate = delegate
            coreView.videoViewDelegate = delegate
        }
    }
    
    public override func constructViewHierarchy() {
        addSubview(coverBgView)
        addSubview(coreView)
        addSubview(hostAbsentView)
        addSubview(topGradientView)
        addSubview(bottomGradientView)
        addSubview(overlayView)
    }
    
    public override func activateConstraints() {
        coverBgView.snp.remakeConstraints { make in
            make.edges.equalToSuperview()
        }
        
        updateCoreViewLayout()
        
        overlayView.snp.remakeConstraints { make in
            make.edges.equalToSuperview()
        }
        
        if WindowUtils.isPortrait {
            topGradientView.snp.remakeConstraints { make in
                make.top.leading.trailing.equalToSuperview()
                make.height.equalTo(142.scale375Height())
            }
            bottomGradientView.snp.remakeConstraints { make in
                make.bottom.leading.trailing.equalToSuperview()
                make.height.equalTo(246.scale375Height())
            }
        }
    }
    
    public override func bindInteraction() {
        subscribeOrientationChange()
        setupSlideToClear()
    }

    public override func setupViewStyle() {
        isViewReady = true
        refreshBottomItems()
        overlayView.updateTopRightItems(topRightItems)
    }
    
    public override func draw(_ rect: CGRect) {
        super.draw(rect)
        topGradientView.gradient(colors: [
            UIColor.g1.withAlphaComponent(0.3),
            UIColor.clear
        ], isVertical: true)
        
        bottomGradientView.gradient(colors: [
            UIColor.clear,
            UIColor.g1.withAlphaComponent(0.3)
        ], isVertical: true)
    }
    
    func startPreview() {
        KeyMetrics.setComponent(Constants.ComponentType.liveRoom.rawValue)
        coreView.startPreviewLiveStream(roomId: roomId, isMuteAudio: true)
    }
    
    func stopPreview() {
        coreView.stopPreviewLiveStream(roomId: roomId)
    }
    
    func relayoutCoreView() {
        addSubview(coreView)
        updateCoreViewLayout()
        sendSubviewToBack(coreView)
        sendSubviewToBack(coverBgView)
        overlayView.updateRootViewOrientation(isPortrait: WindowUtils.isPortrait)
    }
    
    private func updateCoreViewLayout() {
        if coreView.superview == nil {
            insertSubview(coreView, aboveSubview: coverBgView)
        }
        guard !manager.liveListState.currentLive.isEmpty,
              manager.liveListState.currentLive.seatTemplate == .videoLandscape4Seats,
              WindowUtils.isPortrait,
              coreView.superview != nil
        else {
            coreView.backgroundColor = .clear
            coreView.snp.remakeConstraints { make in
                make.edges.equalToSuperview()
            }
            hostAbsentView.snp.remakeConstraints { make in
                make.edges.equalTo(coreView)
            }
            return
        }
        coreView.backgroundColor = .black
        coreView.snp.remakeConstraints { make in
            make.leading.trailing.equalToSuperview()
            make.top.equalToSuperview().offset(110)
            make.height.equalTo(Screen_Width * 720 / 1280)
        }
        hostAbsentView.snp.remakeConstraints { make in
            make.edges.equalTo(coreView)
        }
    }
    
    private func updateLiveViewLayout() {
        let currentLive = manager.liveListState.currentLive
        if currentLive.seatTemplate == .videoLandscape4Seats && !currentLive.keepOwnerOnSeat {
            disabledBottomItems.insert(.coGuest)
        }
        showSeatListIfNeeded()
    }
    
    private func updateBackground() {
        let currentLive = manager.liveListState.currentLive
        if !currentLive.backgroundURL.isEmpty {
            coverBgView.kf.setImage(with: URL(string: currentLive.backgroundURL), placeholder: internalImage("live_edit_info_default_cover_image"))
            blurView.isHidden = false
        } else if !currentLive.coverURL.isEmpty {
            coverBgView.kf.setImage(with: URL(string: currentLive.coverURL), placeholder: internalImage("live_edit_info_default_cover_image"))
            blurView.isHidden = false
        }
    }
}

extension AudienceLiveView {
    private func subscribeOrientationChange() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleOrientationChange),
            name: Notification.Name.TUILiveKitRotateScreenNotification,
            object: nil
        )
    }
    
    private func subscribeStates() {
        guard cancellableSet.isEmpty else { return }
        subscribeRoomState()
        subscribeMediaState()
        subscribeEvent()
        subscribeDelegateSubjects()
        subscribeScrollState()
        subscribeVideoStreamOrientation()
        subscribeExitLiveRequest()
    }

    private func subscribeExitLiveRequest() {
        manager.exitLiveRequestSubject
            .receive(on: RunLoop.main)
            .sink { [weak self] in
                guard let self = self else { return }
                leaveButtonClick()
            }
            .store(in: &cancellableSet)
    }

    private func subscribeHostAbsentState() {
        hostAbsentCancellable?.cancel()
        hostAbsentCancellable = nil
        showHostAbsentWorkItem?.cancel()
        showHostAbsentWorkItem = nil
        
        hostAbsentCancellable = manager.subscribeState(StatePublisherSelector(keyPath: \LiveSeatState.seatList))
            .receive(on: RunLoop.main)
            .sink { [weak self] seatList in
                guard let self = self else { return }
                let hasHost = !seatList.isEmpty && seatList.contains { !$0.userInfo.userID.isEmpty }
                
                showHostAbsentWorkItem?.cancel()
                showHostAbsentWorkItem = nil
                
                if hasHost {
                    hostAbsentView.isHidden = true
                    hostAbsentCancellable?.cancel()
                    hostAbsentCancellable = nil
                } else {
                    let workItem = DispatchWorkItem { [weak self] in
                        guard let self = self else { return }
                        self.hostAbsentView.isHidden = false
                        let isLandscape = self.manager.liveListState.currentLive.seatTemplate == .videoLandscape4Seats
                        self.hostAbsentView.image = internalImage(self.muteImageName(isLandscape: isLandscape))
                    }
                    showHostAbsentWorkItem = workItem
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.0, execute: workItem)
                }
            }
    }
    
    private func showSeatListIfNeeded() {
        let currentLive = manager.liveListState.currentLive
        let isScreenShareLive = currentLive.seatTemplate == .videoLandscape4Seats
            && currentLive.keepOwnerOnSeat
        if isScreenShareLive {
            createGameViewIfNeeded()
        } else {
            removeGameView()
        }
    }
    
    private func subscribeDelegateSubjects() {
        manager.toastSubject
            .receive(on: RunLoop.main)
            .sink { [weak self] message, style in
                guard let self = self, let delegate = delegate else { return }
                delegate.showAtomicToast(message: message, toastStyle: style)
            }.store(in: &cancellableSet)
        
        manager.floatWindowSubject
            .receive(on: RunLoop.main)
            .sink { [weak self] in
                guard let self = self, let delegate = delegate else { return }
                delegate.showFloatWindow()
            }
            .store(in: &cancellableSet)
    }
    
    private func subscribeScrollState() {
        manager.subscribeState(StatePublisherSelector(keyPath: \CoGuestState.connected))
            .removeDuplicates()
            .combineLatest(manager.subscribeState(StatePublisherSelector(keyPath: \AudienceState.isApplying)).removeDuplicates())
            .receive(on: RunLoop.main)
            .dropFirst()
            .sink { [weak self] connected, isApplying in
                guard let self = self, let delegate = delegate else { return }
                if isApplying || connected.isOnSeat() {
                    delegate.disableScrolling()
                } else {
                    delegate.enableScrolling()
                }
            }
            .store(in: &cancellableSet)
    }
    

    
    private func subscribeVideoStreamOrientation() {
        manager.subscribeState(StatePublisherSelector(keyPath: \AudienceState.roomVideoStreamIsLandscape))
            .receive(on: RunLoop.main)
            .removeDuplicates()
            .sink { [weak self] videoStreamIsLandscape in
                guard let self = self else { return }
                if !videoStreamIsLandscape, isCurrentShowCell {
                    self.rotateScreen(isPortrait: true)
                }
            }
            .store(in: &cancellableSet)
    }
    
    private func subscribeRoomState() {
        manager.subscribeState(StatePublisherSelector(keyPath: \LiveListState.currentLive))
            .removeDuplicates()
            .dropFirst()
            .receive(on: RunLoop.main)
            .sink { [weak self] currentLive in
                guard let self = self else { return }
                if currentLive.isEmpty {
                    routeToAudienceView()
                    return
                }
                guard currentLive.liveID == manager.liveID else { return }
                updateCoreViewLayout()
                updateLiveViewLayout()
                updateBackground()
            }
            .store(in: &cancellableSet)
        
        manager.subscribeState(StatePublisherSelector(keyPath: \LiveSeatState.canvas))
            .removeDuplicates()
            .receive(on: RunLoop.main)
            .sink { [weak self] canvas in
                guard let self = self else { return }
                guard canvas.w * canvas.h > 0 else { return }
                manager.updateVideoStreamIsLandscape(canvas.w >= canvas.h)
            }
            .store(in: &cancellableSet)
    }
    
    private func subscribeMediaState() {
        manager.seatStore.liveSeatEventPublisher
            .receive(on: RunLoop.main)
            .sink { [weak self] event in
                guard let self = self else { return }
                let text: String
                switch event {
                case .onLocalCameraClosedByAdmin:
                    text = .mutedVideoText
                case .onLocalCameraOpenedByAdmin(policy: _):
                    text = .unmutedVideoText
                case .onLocalMicrophoneClosedByAdmin:
                    text = .mutedAudioText
                case .onLocalMicrophoneOpenedByAdmin(policy: _):
                    text = .unmutedAudioText
                }
                manager.toastSubject.send((text, .info))
            }
            .store(in: &cancellableSet)
    }
    
    private func subscribeEvent() {
        manager.liveListStore.liveListEventPublisher
            .receive(on: RunLoop.main)
            .sink { [weak self] event in
                guard let self = self else { return }
                switch event {
                case .onLiveEnded(liveID: let liveID, reason: _, message: _):
                    guard liveID == self.roomId else { return }
                    routeToAudienceView()
                    delegate?.onRoomDismissed(roomId: liveID,
                                              avatarUrl: currentLiveOwner?.avatarURL ?? "",
                                              userName: currentLiveOwner?.userName ?? "")
                    
                case .onKickedOutOfLive(liveID: let liveID, reason: _, message: _):
                    guard liveID == self.roomId else { return }
                    routeToAudienceView()
                    onKickedByAdmin()
                }
            }
            .store(in: &cancellableSet)
        
        manager.coGuestStore.guestEventPublisher
            .receive(on: RunLoop.main)
            .sink { [weak self] event in
                guard let self = self else { return }
                switch event {
                case .onGuestApplicationResponded(isAccept: let isAccept, hostUser: _):
                    if !isAccept {
                        showAtomicToast(text: .takeSeatApplicationRejected, style: .info)
                    }
                case .onGuestApplicationNoResponse(reason: let reason):
                    switch reason {
                    case .timeout:
                        showAtomicToast(text: .takeSeatApplicationTimeout, style: .info)
                    default: break
                    }
                case .onKickedOffSeat(seatIndex: _, hostUser: _):
                    showAtomicToast(text: .kickedOutOfSeat, style: .info)
                default: break
                }
            }
            .store(in: &cancellableSet)
        
        manager.liveAudienceStore.liveAudienceEventPublisher
            .receive(on: RunLoop.main)
            .sink { [weak self] event in
                guard let self = self else { return }
                switch event {
                case .onAudienceMessageDisabled(audience: let user, isDisable: let isDisable):
                    guard user.userID == manager.selfUserID else { break }
                    if isDisable {
                        showAtomicToast(text: .disableChatText, style: .info)
                    } else {
                        showAtomicToast(text: .enableChatText, style: .info)
                    }
                default: break
                }
            }
            .store(in: &cancellableSet)
        
        manager.coGuestStore.guestEventPublisher
            .receive(on: RunLoop.main)
            .sink { [weak self] event in
                guard let self = self else { return }
                switch event {
                case .onKickedOffSeat(seatIndex: _, hostUser: _):
                    manager.deviceStore.closeLocalCamera()
                    manager.deviceStore.closeLocalMicrophone()
                default: break
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
    
    private func routeToAudienceView() {
        routerManager.router(action: .dismiss())
    }
        
    private func onKickedByAdmin() {
        manager.toastSubject.send((.kickedOutText, .info))
        isUserInteractionEnabled = false
        DispatchQueue.main.asyncAfter(deadline: .now() + 1) { [weak self] in
            guard let self = self else { return }
            isUserInteractionEnabled = true
            routerManager.router(action: .exit)
        }
    }
    
    @objc func handleOrientationChange() {
        activateConstraints()
        topGradientView.isHidden = !WindowUtils.isPortrait
        bottomGradientView.isHidden = !WindowUtils.isPortrait
    }
    
    func leaveButtonClick() {
        rotateScreenDelegate?.rotateScreen(isPortrait: true)

        if !manager.coGuestState.connected.isOnSeat() {
            leaveRoom(exitController: true)
            return
        }
        var items: [AlertButtonConfig] = []
        
        let title: String = .endLiveOnLinkMicText
        let endLinkMicItem = AlertButtonConfig(text: .endLiveLinkMicDisconnectText, type: .red) { [weak self] _ in
            guard let self = self else { return }
            manager.coGuestStore.disConnect { [weak self] result in
                guard let self = self else { return }
                switch result {
                case .success(()):
                    manager.deviceStore.closeLocalCamera()
                    manager.deviceStore.closeLocalMicrophone()
                default: break
                }
            }
            routerManager.dismiss()
        }
        items.append(endLinkMicItem)
        
        let endLiveItem = AlertButtonConfig(text: .confirmCloseText, type: .primary) { [weak self] _ in
            guard let self = self else { return }
            routerManager.dismiss()
            leaveRoom(exitController: true)
        }
        items.append(endLiveItem)
        
        let cancelItem = AlertButtonConfig(text: .cancelText, type: .primary) { [weak self] _ in
            guard let self = self else { return }
            self.routerManager.dismiss()
        }
        items.append(cancelItem)

        let alertView = AtomicAlertView(config: AlertViewConfig(title: title, items: items))
        routerManager.present(view: alertView, config: .centerDefault())
    }
    
    func leaveRoom(exitController: Bool = false) {
        removeGameView()
        manager.liveListStore.leaveLive(completion: nil)
        clearHostAbsentState()
        cancellableSet.removeAll()
        if exitController {
            stopPreview()
            routerManager.router(action: .exit)
        }
        TUICore.notifyEvent(TUICore_PrivacyService_ROOM_STATE_EVENT_CHANGED,
                            subKey: TUICore_PrivacyService_ROOM_STATE_EVENT_SUB_KEY_END,
                            object: nil,
                            param: nil)
    }
    
    private func clearHostAbsentState() {
        hostAbsentView.isHidden = true
        hostAbsentCancellable?.cancel()
        hostAbsentCancellable = nil
        showHostAbsentWorkItem?.cancel()
        showHostAbsentWorkItem = nil
    }
}

// MARK: - Slide to clear

extension AudienceLiveView {
    private func setupSlideToClear() {
        let panGesture = UIPanGestureRecognizer(target: self, action: #selector(handlePan(_:)))
        panGesture.delegate = self
        addGestureRecognizer(panGesture)
    }
    
    @objc private func handlePan(_ gesture: UIPanGestureRecognizer) {
        let translation = gesture.translation(in: self)
        let velocity = gesture.velocity(in: self)
        
        switch gesture.state {
        case .began:
            panDirection = velocity.x > 0 ? .right : .left
        case .changed:
            guard isValidPan() else { return }
            if panDirection == .left {
                overlayView.applyClearTranslation(bounds.width + translation.x)
            } else if translation.x > 0 {
                overlayView.applyClearTranslation(translation.x)
            }
        case .ended, .cancelled:
            guard isValidPan() else { return }
            let isSameDirection = velocity.x > 0 && panDirection == .right || velocity.x < 0 && panDirection == .left
            let shouldComplete = isSameDirection && (abs(translation.x) > 100 || abs(velocity.x) > 800)
            if shouldComplete {
                panDirection == .right ? hideOverlay() : restoreOverlay()
            } else {
                resetOverlay()
            }
            panDirection = .none
        default: break
        }
    }
    
    private func isValidPan() -> Bool {
        return (panDirection == .right && !overlayView.isClearModeActive) || (panDirection == .left && overlayView.isClearModeActive)
    }
    
    private func hideOverlay() {
        let offset = max(UIScreen.main.bounds.width, UIScreen.main.bounds.height)
        UIView.animate(withDuration: 0.3, animations: { [weak self] in
            guard let self = self else { return }
            overlayView.applyClearTranslation(offset)
        })
        overlayView.completeClear()
    }
    
    private func restoreOverlay() {
        UIView.animate(withDuration: 0.3, animations: { [weak self] in
            guard let self = self else { return }
            overlayView.cancelClear()
        }, completion: { [weak self] _ in
            guard let self = self else { return }
            overlayView.isClearModeActive = false
        })
        overlayView.restoreClearButton.isHidden = true
    }
        
    private func resetOverlay() {
        UIView.animate(withDuration: 0.3) { [weak self] in
            guard let self = self else { return }
            if panDirection == .right {
                overlayView.cancelClear()
            } else {
                let offset = max(bounds.width, bounds.height)
                overlayView.applyClearTranslation(offset)
            }
        }
    }
}

extension AudienceLiveView {
    func joinLiveStream(onComplete: @escaping (Result<Void, InternalError>) -> Void) {
        coreView
            .setLocalVideoMuteImage(
                bigImage: internalImage(muteImageName(isLandscape: false)) ?? UIImage(),
                smallImage: internalImage("live_muteImage_small") ?? UIImage()
            )
        subscribeStates()
        KeyMetrics.reportAtomicMetrics(platform: Constants.DataReport.kDataReportLiveIntegrationSuccessful)
        LiveListStore.shared.joinLive(liveID: roomId) { [weak self] result in
            guard let self = self else { return }
            switch result {
            case .success(let liveInfo):
                onComplete(.success(()))
            case .failure(let err):
                let error = InternalError(code: err.code, message: err.message)
                manager.onError(error)
                DispatchQueue.main.asyncAfter(deadline: .now() + 1) { [weak self] in
                    guard let self = self else { return }
                    routerManager.router(action: .exit)
                }
                onComplete(.failure(error))
            }
        }
    }
}

extension AudienceLiveView: UIGestureRecognizerDelegate {
    public override func gestureRecognizerShouldBegin(_ gesture: UIGestureRecognizer) -> Bool {
        guard let pan = gesture as? UIPanGestureRecognizer else { return true }
        let velocity = pan.velocity(in: self)
        return abs(velocity.x) > abs(velocity.y) * 1.5
    }
    
    public func gestureRecognizer(
        _ gestureRecognizer: UIGestureRecognizer,
        shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer
    ) -> Bool {
        return otherGestureRecognizer is UIPanGestureRecognizer
    }
}

extension AudienceLiveView: RotateScreenDelegate {
    public func rotateScreen(isPortrait: Bool) {
        rotateScreenDelegate?.rotateScreen(isPortrait: isPortrait)
    }
}

private extension String {
    static let kickedOutText = internalLocalized("common_kicked_out_of_room_by_owner")
    static let mutedAudioText = internalLocalized("common_mute_audio_by_master")
    static let unmutedAudioText = internalLocalized("common_un_mute_audio_by_master")
    static let mutedVideoText = internalLocalized("common_mute_video_by_owner")
    static let unmutedVideoText = internalLocalized("common_un_mute_video_by_master")
    static let endLiveOnLinkMicText = internalLocalized("common_audience_end_link_tips")
    static let endLiveLinkMicDisconnectText = internalLocalized("common_end_link")
    static let confirmCloseText = internalLocalized("common_exit_live")
    static let cancelText = internalLocalized("common_cancel")
    static let takeSeatApplicationRejected = internalLocalized("common_voiceroom_take_seat_rejected")
    static let takeSeatApplicationTimeout = internalLocalized("common_voiceroom_take_seat_timeout")
    static let disableChatText = internalLocalized("common_send_message_disabled")
    static let enableChatText = internalLocalized("common_send_message_enable")
    static let kickedOutOfSeat = internalLocalized("common_voiceroom_kicked_out_of_seat")
}
