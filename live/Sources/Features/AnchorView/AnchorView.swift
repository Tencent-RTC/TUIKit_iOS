//
//  File.swift
//  TUILiveKit
//
//  Created by WesleyLei on 2023/12/14.
//

import AtomicX
import AtomicXCore
import Combine
import Foundation
import Kingfisher
import RTCRoomEngine
import TUICore
#if canImport(TXLiteAVSDK_TRTC)
import TXLiteAVSDK_TRTC
#elseif canImport(TXLiteAVSDK_Professional)
import TXLiteAVSDK_Professional
#endif

public struct LiveParams {
    public var liveID: String
    public var prepareState: PrepareState
    public var liveInfo: LiveInfo {
        var liveInfo = LiveInfo(seatTemplate: prepareState.templateMode.toSeatLayoutTemplate())
        liveInfo.liveID = liveID
        liveInfo.liveName = prepareState.roomName
        liveInfo.coverURL = prepareState.coverUrl
        liveInfo.isPublicVisible = prepareState.privacyMode == .public
        if prepareState.videoStreamSource == .screenShare {
            liveInfo.backgroundURL = Constants.URL.defaultBackground
        } else {
            liveInfo.backgroundURL = prepareState.coverUrl
        }
        
        // Default setting
        liveInfo.seatMode = .apply
        
        return liveInfo
    }

    public var videoStreamSource: VideoStreamSource {
        prepareState.videoStreamSource
    }

    public init(liveID: String, prepareState: PrepareState) {
        self.liveID = liveID
        self.prepareState = prepareState
    }
}

public class AnchorView: UIView {
    public weak var delegate: AnchorViewDelegate?

    // MARK: - Public API

    public var barrageStreamView: BarrageStreamView {
        overlayView.barrageDisplayView
    }

    public var bottomItems: [AnchorBottomItem] = [.coHost, .battle, .coGuest, .more] {
        didSet {
            guard isViewReady else { return }
            refreshBottomItems()
        }
    }

    public var topRightItems: [AnchorTopRightItem] = [.audienceCount, .floatWindow, .close] {
        didSet {
            guard isViewReady else { return }
            refreshTopRightItems()
        }
    }

    public func replace(node: AnchorNode, with view: UIView?) {
        overlayView.replace(node: node, with: view)
    }

    public func perform(_ action: AnchorAction) {
        overlayView.perform(action)
    }
    
    public private(set) var coreView: LiveCoreView
    
    public private(set) lazy var overlayView: AnchorOverlayView = {
        let view = AnchorOverlayView(store: store, routerManager: routerManager)
        return view
    }()

    // MARK: - Private Properties

    private let liveInfo: LiveInfo
    private var liveID: String {
        liveInfo.liveID
    }
        
    let store: AnchorStore
    private lazy var routerManager: AnchorRouterManager = .init()
    private lazy var routerCenter = AnchorRouterControlCenter(rootViewController: getCurrentViewController() ?? (TUITool.applicationKeywindow().rootViewController ?? UIViewController()), routerManager: routerManager, store: store, coreView: coreView)
    
    private lazy var isInWaitingPublisher = store.subscribeState(StatePublisherSelector(keyPath: \AnchorBattleState.isInWaiting))
    private var cancellableSet = Set<AnyCancellable>()
    
    private lazy var topGradientView: UIView = {
        var view = UIView()
        view.isUserInteractionEnabled = false
        return view
    }()
    
    private lazy var bottomGradientView: UIView = {
        var view = UIView()
        view.isUserInteractionEnabled = false
        return view
    }()
    
    private var needPresentAlertConfig: AlertViewConfig?
    private var defaultVideoViewDelegate: AnchorVideoDelegate?
    private var videoStreamSource: VideoStreamSource = .camera
    
    private var isScreenShareLive: Bool {
        videoStreamSource == .screenShare
    }
    
    private var disabledBottomItems: Set<AnchorBottomItem> = [] {
        didSet {
            guard isViewReady else { return }
            refreshBottomItems()
        }
    }
    
    private var disabledTopRightItems: Set<AnchorTopRightItem> = [] {
        didSet {
            guard isViewReady else { return }
            refreshTopRightItems()
        }
    }
    
    private func refreshBottomItems() {
        let effectiveItems = bottomItems.filter { !disabledBottomItems.contains($0) }
        overlayView.updateBottomItems(effectiveItems)
    }
    
    private func refreshTopRightItems() {
        let effectiveItems = topRightItems.filter { !disabledTopRightItems.contains($0) }
        overlayView.updateTopRightItems(effectiveItems)
    }
    
    private var gameView: AnchorGameView?

    private func createGameViewIfNeeded() {
        guard isScreenShareLive, gameView == nil else { return }
        let view = AnchorGameView(liveID: liveID, store: store, routerManager: routerManager)
        view.onStopLive = { [weak self] in
            self?.stopLive()
        }
        gameView = view
    }
    
    public init(liveInfo: LiveInfo, coreView: LiveCoreView, behavior: RoomBehavior = .createRoom) {
        self.liveInfo = liveInfo
        self.coreView = coreView
        self.store = AnchorStore(liveID: liveInfo.liveID)
        super.init(frame: .zero)
        store.prepareLiveInfoBeforeEnterRoom(pkTemplateMode: .verticalGridDynamic)
        initialize(behavior: behavior)
    }
    
    public init(liveParams: LiveParams, coreView: LiveCoreView, behavior: RoomBehavior = .createRoom) {
        self.liveInfo = liveParams.liveInfo
        self.coreView = coreView
        self.store = AnchorStore(liveID: liveParams.liveID)
        self.videoStreamSource = liveParams.videoStreamSource
        super.init(frame: .zero)
        store.prepareLiveInfoBeforeEnterRoom(pkTemplateMode: liveParams.prepareState.pkTemplateMode)
        initialize(behavior: behavior)
    }
    
    private func initialize(behavior: RoomBehavior) {
        coreView.setLiveID(liveID)
        backgroundColor = .black
        
        if coreView.videoViewDelegate == nil {
            let defaultDelegate = AnchorVideoDelegate(store: store, routerManager: routerManager)
            defaultVideoViewDelegate = defaultDelegate
            coreView.videoViewDelegate = defaultDelegate
        }
        
        if isScreenShareLive {
            coreView.isHidden = true
            createGameViewIfNeeded()
        }
        
        switch behavior {
            case .createRoom:
                startLiveStream()
            case .enterRoom:
                joinSelfCreatedRoom()
        }
    }
    
    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    deinit {
        store.deviceStore.reset()
        TUICore.notifyEvent(TUICore_PrivacyService_ROOM_STATE_EVENT_CHANGED,
                            subKey: TUICore_PrivacyService_ROOM_STATE_EVENT_SUB_KEY_END,
                            object: nil,
                            param: nil)
        LiveKitLog.info("\(#file)", "\(#line)", "deinit AnchorView \(self)")
    }
    
    private var isViewReady: Bool = false
    override public func didMoveToWindow() {
        super.didMoveToWindow()
        guard !isViewReady else { return }
        isViewReady = true
        constructViewHierarchy()
        activateConstraints()
        bindInteraction()
        setupViewStyle()
        routerCenter.subscribeRouter()
    }
    
    override public func draw(_ rect: CGRect) {
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
    
    public func updateRootViewOrientation(isPortrait: Bool) {
        overlayView.updateRootViewOrientation(isPortrait: isPortrait)
    }
    
    public func relayoutCoreView() {
        addSubview(coreView)
        updateCoreViewLayout()
        sendSubviewToBack(coreView)
    }
    
    private func updateCoreViewLayout() {
        guard !store.liveListState.currentLive.isEmpty,
              store.liveListState.currentLive.seatTemplate == .videoLandscape4Seats,
              WindowUtils.isPortrait,
              coreView.superview != nil
        else {
            coreView.snp.remakeConstraints { make in
                make.leading.trailing.equalToSuperview()
                make.top.equalToSuperview().inset(36.scale375Height())
                make.bottom.equalToSuperview().inset(96.scale375Height())
            }
            return
        }
        coreView.snp.remakeConstraints { make in
            make.leading.trailing.equalToSuperview()
            make.top.equalToSuperview().offset(150)
            make.height.equalTo(Screen_Width * 3 / 4)
        }
    }
}

extension AnchorView {
    private func updateBottomItemsForTemplate() {
        let currentLive = store.liveListState.currentLive
        guard currentLive.seatTemplate == .videoLandscape4Seats else { return }
        if currentLive.keepOwnerOnSeat {
            disabledBottomItems = [.coHost, .battle, .more]
            disabledTopRightItems = [.floatWindow]
            gameView?.showSeatList(true)
        } else {
            disabledBottomItems = [.coHost, .battle, .coGuest, .more]
            gameView?.showSeatList(false)
        }
    }
}

extension AnchorView {
    private func constructViewHierarchy() {
        addSubview(coreView)
        createGameViewIfNeeded()
        if let gameView = gameView {
            addSubview(gameView)
        }
        addSubview(topGradientView)
        addSubview(bottomGradientView)
        addSubview(overlayView)
    }
    
    private func activateConstraints() {
        updateCoreViewLayout()
        
        gameView?.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }
        
        overlayView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }
        
        topGradientView.snp.makeConstraints { make in
            make.top.leading.trailing.equalToSuperview()
            make.height.equalTo(142.scale375Height())
        }
        
        bottomGradientView.snp.makeConstraints { make in
            make.bottom.leading.trailing.equalToSuperview()
            make.height.equalTo(246.scale375Height())
        }
    }
    
    private func bindInteraction() {
        subscribeState()
        subscribeCoGuestState()
        subscribeCoHostState()
        subscribeBattleState()
        subscribeSubjects()
    }
    
    private func setupViewStyle() {
        if store.liveListState.currentLive.seatTemplate != .videoLandscape4Seats {
            coreView.layer.cornerRadius = 16.scale375()
            coreView.layer.masksToBounds = true
        }
        refreshBottomItems()
        refreshTopRightItems()
    }
}

// MARK: Action

extension AnchorView {
    func startLiveStream() {
        setLocalVideoMuteImage()
        routerManager.dismiss(dismissType: .alert, completion: nil)
        if liveInfo.keepOwnerOnSeat, store.deviceState.cameraStatus == .off, !isScreenShareLive {
            openLocalCamera()
            openLocalMicrophone()
        }
        if isScreenShareLive {
            openLocalMicrophone()
        }
        KeyMetrics.reportAtomicMetrics(platform: Constants.DataReport.kDataReportLiveIntegrationSuccessful)
        store.liveListStore.startLive(liveInfo) { [weak self] result in
            guard let self = self else { return }
            switch result {
                case .success:
                    delegate?.onStartLiving()
                    if isScreenShareLive {
                        DispatchQueue.main.async { [weak self] in
                            guard let self = self else { return }
                            gameView?.startScreenShare()
                        }
                    }
                case .failure(let err):
                    let error = InternalError(code: err.code, message: err.message)
                    store.onError(error)
                    DispatchQueue.main.asyncAfter(deadline: .now() + 2) { [weak self] in
                        guard let self = self else { return }
                        routerManager.router(action: .exit)
                    }
            }
        }
    }
    
    func joinSelfCreatedRoom() {
        setLocalVideoMuteImage()
        KeyMetrics.reportAtomicMetrics(platform: Constants.DataReport.kDataReportLiveIntegrationSuccessful)
        store.liveListStore.joinLive(liveID: liveID) { [weak self] result in
            guard let self = self else { return }
            switch result {
                case .success(let liveInfo):
                    if liveInfo.seatTemplate == .videoLandscape4Seats, liveInfo.keepOwnerOnSeat {
                        videoStreamSource = .screenShare
                    }
                    if isScreenShareLive {
                        restoreGameViewForScreenShare()
                    } else if liveInfo.keepOwnerOnSeat {
                        openLocalCamera()
                        openLocalMicrophone()
                    }
                    delegate?.onStartLiving()
                case .failure(let err):
                    let error = InternalError(code: err.code, message: err.message)
                    store.onError(error)
                    DispatchQueue.main.asyncAfter(deadline: .now() + 2) { [weak self] in
                        guard let self = self else { return }
                        routerManager.router(action: .exit)
                    }
            }
        }
    }
    
    private func subscribeState() {
        store.subscribeState(StatePublisherSelector(keyPath: \LiveListState.currentLive))
            .dropFirst()
            .removeDuplicates()
            .receive(on: RunLoop.main)
            .sink { [weak self] currentLive in
                guard let self = self, !currentLive.isEmpty else { return }
                updateCoreViewLayout()
                updateBottomItemsForTemplate()
                didEnterRoom()
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
                    case .onLiveEnded(let liveID, let liveEndedReason, _):
                        if liveEndedReason == .endedByServer, liveID == store.liveID {
                            onLiveEnded(liveEndedReason: .endedByServer)
                        }
                    case .onKickedOutOfLive(let liveID, _, _):
                        if liveID == store.liveID {
                            onLiveEnded(liveEndedReason: .endedByHost)
                        }
                }
            }
            .store(in: &cancellableSet)
    }
    
    private func subscribeCoGuestState() {
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
                overlayView.showLinkMicFloatView(isPresent: applicants.count > 0)
            }
            .store(in: &cancellableSet)
    }

    private func subscribeCoHostState() {
        store.subscribeState(StatePublisherSelector(keyPath: \CoHostState.applicant))
            .receive(on: RunLoop.main)
            .removeDuplicates()
            .sink { [weak self] applicant in
                guard let self = self else { return }
                if let applicantUser = applicant {
                    let selfUserID = store.selfUserID
                    if !store.coGuestState.applicants.isEmpty
                        || !store.coGuestState.connected.filter({ $0.userID != selfUserID }).isEmpty
                        || !store.coGuestState.invitees.isEmpty
                    {
                        // If received linkmic request first, reject connection auto.
                        store.coHostStore.rejectHostConnection(fromHostLiveID: applicantUser.liveID, completion: nil)
                        return
                    }
                    let cancelButton = AlertButtonConfig(text: String.rejectText, type: .grey) { [weak self] _ in
                        guard let self = self else { return }
                        store.coHostStore.rejectHostConnection(fromHostLiveID: applicantUser.liveID) { [weak self] result in
                            guard let self = self else { return }
                            switch result {
                                case .failure(let err):
                                    let error = InternalError(code: err.code, message: err.message)
                                    store.onError(error)
                                default: break
                            }
                        }
                        routerManager.dismiss(dismissType: .alert, completion: nil)
                    }
                    let confirmButton = AlertButtonConfig(text: String.acceptText, type: .primary) { [weak self] _ in
                        guard let self = self else { return }
                        store.coHostStore.acceptHostConnection(fromHostLiveID: applicantUser.liveID) { [weak self] result in
                            guard let self = self else { return }
                            switch result {
                                case .failure(let err):
                                    let error = InternalError(code: err.code, message: err.message)
                                    store.onError(error)
                                default: break
                            }
                        }
                        routerManager.dismiss(dismissType: .alert, completion: nil)
                    }
                    let alertConfig = AlertViewConfig(title: String.localizedReplace(.connectionInviteText,
                                                                                     replace: "\(applicantUser.userName)"),
                                                      iconUrl: applicantUser.avatarURL,
                                                      cancelButton: cancelButton,
                                                      confirmButton: confirmButton)
                    if FloatWindow.shared.isShowingFloatWindow() {
                        needPresentAlertConfig = alertConfig
                    } else {
                        let alertView = AtomicAlertView(config: alertConfig)
                        routerManager.present(view: alertView, config: .centerDefault())
                    }
                } else {
                    routerManager.dismiss(dismissType: .alert, completion: nil)
                }
            }
            .store(in: &cancellableSet)
    }

    private func setLocalVideoMuteImage() {
        let imageName = getPreferredLanguage() == "en" ? "live_muteImage_en" : "live_muteImage"
        coreView.setLocalVideoMuteImage(
            bigImage: internalImage(imageName) ?? UIImage(),
            smallImage: internalImage("live_muteImage_small") ?? UIImage()
        )
    }

    private func openLocalCamera() {
        guard store.deviceState.cameraStatus == .off else { return }
        store.deviceStore.openLocalCamera(isFront: store.deviceState.isFrontCamera) { [weak self] result in
            guard let self = self else { return }
            switch result {
                case .failure(let err):
                    let error = InternalError(code: err.code, message: err.message)
                    store.onError(error)
                    DispatchQueue.main.asyncAfter(deadline: .now() + 2) { [weak self] in
                        guard let self = self else { return }
                        routerManager.router(action: .exit)
                    }
                default: break
            }
        }
    }

    private func openLocalMicrophone() {
        guard store.deviceState.microphoneStatus == .off else { return }
        store.deviceStore.openLocalMicrophone { [weak self] result in
            guard let self = self else { return }
            switch result {
                case .failure(let err):
                    let error = InternalError(code: err.code, message: err.message)
                    store.onError(error)
                    DispatchQueue.main.asyncAfter(deadline: .now() + 2) { [weak self] in
                        guard let self = self else { return }
                        routerManager.router(action: .exit)
                    }
                default: break
            }
        }
    }

    // MARK: - Game View Helpers

    private func restoreGameViewForScreenShare() {
        openLocalMicrophone()
        coreView.isHidden = true
        createGameViewIfNeeded()
        if let gameView = gameView, gameView.superview == nil {
            insertSubview(gameView, belowSubview: topGradientView)
            gameView.snp.makeConstraints { make in
                make.edges.equalToSuperview()
            }
        }
        gameView?.restoreScreenShare()
    }

    private func subscribeBattleState() {
        store.battleStore.battleEventPublisher
            .receive(on: RunLoop.main)
            .sink { [weak self] event in
                guard let self = self else { return }
                switch event {
                    case .onBattleStarted(battleInfo: _, inviter: _, invitees: _):
                        routerManager.router(action: .dismiss(AnchorDismissType.panel, completion: nil))
                    case .onBattleRequestCancelled(battleID: _, inviter: let inviter, invitee: _):
                        routerManager.dismiss(dismissType: .alert, completion: nil)
                        showAtomicToast(text: .cancelBattleText.replacingOccurrences(of: "xxx", with: inviter.displayName), style: .info)
                    case .onBattleRequestTimeout(battleID: _, inviter: _, invitee: _):
                        routerManager.dismiss(dismissType: .alert, completion: nil)
                        showAtomicToast(text: .battleRequestTimeoutText, style: .info)
                    case .onBattleRequestReject(battleID: _, inviter: _, invitee: let invitee):
                        showAtomicToast(text: .rejectBattleText.replacingOccurrences(of: "xxx", with: invitee.displayName), style: .info)
                    case .onBattleRequestReceived(battleID: let battleID, inviter: let inviter, invitee: _):
                        onReceivedBattleRequestChanged(battleID: battleID, inviter: inviter)
                    default: break
                }
            }
            .store(in: &cancellableSet)
        
        isInWaitingPublisher
            .removeDuplicates()
            .receive(on: RunLoop.main)
            .sink { [weak self] inWaiting in
                guard let self = self else { return }
                self.onInWaitingChanged(inWaiting: inWaiting)
            }
            .store(in: &cancellableSet)
    }
    
    private func subscribeSubjects() {
        store.toastSubject
            .receive(on: RunLoop.main)
            .sink { [weak self] message, style in
                guard let self = self else { return }
                showAtomicToast(text: message, style: style)
            }.store(in: &cancellableSet)
        
        store.floatWindowSubject
            .receive(on: RunLoop.main)
            .sink { [weak self] in
                guard let self = self else { return }
                delegate?.onClickFloatWindow()
            }
            .store(in: &cancellableSet)

        store.endLiveRequestSubject
            .receive(on: RunLoop.main)
            .sink { [weak self] in
                guard let self = self else { return }
                endLiveStream()
            }
            .store(in: &cancellableSet)
        
        FloatWindow.shared.subscribeShowingState()
            .receive(on: RunLoop.main)
            .dropFirst()
            .sink { [weak self] isShow in
                guard let self = self, !isShow, let alertConfig = needPresentAlertConfig else { return }
                let alertView = AtomicAlertView(config: alertConfig)
                routerManager.present(view: alertView, config: .centerDefault())
                needPresentAlertConfig = nil
            }
            .store(in: &cancellableSet)
        
        store.kickedOutSubject
            .receive(on: RunLoop.main)
            .sink { [weak self] isDismissed in
                guard let self = self else { return }
                overlayView.isUserInteractionEnabled = false
                coreView.isUserInteractionEnabled = false
                routerManager.router(action: .dismiss())
                if isDismissed {
                    showAtomicToast(text: .roomDismissText, style: .warning)
                } else {
                    showAtomicToast(text: .kickedOutText, style: .warning)
                }
                DispatchQueue.main.asyncAfter(deadline: .now() + 1) { [weak self] in
                    guard let self = self else { return }
                    overlayView.isUserInteractionEnabled = true
                    coreView.isUserInteractionEnabled = true
                    routerManager.router(action: .exit)
                }
            }.store(in: &cancellableSet)
    }
}

extension AnchorView {
    private func onReceivedBattleRequestChanged(battleID: String, inviter: SeatUserInfo) {
        let cancelButton = AlertButtonConfig(text: String.rejectText, type: .grey) { [weak self] _ in
            guard let self = self else { return }
            store.battleStore.rejectBattle(battleID: battleID) { [weak self] result in
                guard let self = self else { return }
                switch result {
                    case .failure(let err):
                        let error = InternalError(code: err.code, message: err.message)
                        store.onError(error)
                    default: break
                }
            }
            routerManager.dismiss(dismissType: .alert, completion: nil)
        }
        let confirmButton = AlertButtonConfig(text: String.acceptText, type: .primary) { [weak self] _ in
            guard let self = self else { return }
            store.battleStore.acceptBattle(battleID: battleID) { [weak self] result in
                guard let self = self else { return }
                switch result {
                    case .failure(let err):
                        let error = InternalError(code: err.code, message: err.message)
                        store.onError(error)
                    default: break
                }
            }
            routerManager.dismiss(dismissType: .alert, completion: nil)
        }
        
        let alertConfig = AlertViewConfig(title: .localizedReplace(.battleInvitationText, replace: inviter.userName),
                                          iconUrl: inviter.avatarURL,
                                          cancelButton: cancelButton,
                                          confirmButton: confirmButton)
        if FloatWindow.shared.isShowingFloatWindow() {
            needPresentAlertConfig = alertConfig
        } else {
            let alertView = AtomicAlertView(config: alertConfig)
            routerManager.present(view: alertView, config: .centerDefault())
        }
    }
    
    private func onInWaitingChanged(inWaiting: Bool) {
        if inWaiting {
            let countdownPanel = AnchorBattleCountDownView(countdownTime: anchorBattleRequestTimeout, store: store)
            routerManager.present(view: countdownPanel, config: .centerTransparent())
        } else {
            if let topRoute = routerManager.routerState.routeStack.last,
               topRoute.view is AnchorBattleCountDownView
            {
                routerManager.router(action: .dismiss())
            }
        }
    }
    
    private func didEnterRoom() {
        TUICore.notifyEvent(TUICore_PrivacyService_ROOM_STATE_EVENT_CHANGED,
                            subKey: TUICore_PrivacyService_ROOM_STATE_EVENT_SUB_KEY_START,
                            object: nil,
                            param: nil)
    }
    
    private func onLiveEnded(liveEndedReason: LiveEndedReason) {
        let data = store.summaryStore.state.value.summaryData
        let state = AnchorState()
        state.totalDuration = Int(data.totalDuration / 1000)
        state.totalViewers = Int(data.totalViewers)
        state.totalGiftCoins = Int(data.totalGiftCoins)
        state.totalGiftUniqueSenders = Int(data.totalGiftUniqueSenders)
        state.totalLikesReceived = Int(data.totalLikesReceived)
        state.totalMessageSent = Int(data.totalMessageSent)
        state.liveEndedReason = liveEndedReason
        delegate?.onEndLiving(state: state)
    }
}

// MARK: - End Live

extension AnchorView {
    func endLiveStream() {
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
                self.stopLive()
                self.routerManager.dismiss(dismissType: .alert)
            }
            let alertConfig = AlertViewConfig(title: .confirmEndLiveText,
                                              cancelButton: cancelButton,
                                              confirmButton: confirmButton)
            routerManager.present(view: AtomicAlertView(config: alertConfig), config: .centerDefault())
            return
        }

        let text: String = store.liveListState.currentLive.keepOwnerOnSeat ? .confirmCloseText : .confirmExitText
        let colorType: TextColorPreset = title == .endLiveOnLinkMicText ? .red : .primary
        let endLiveItem = AlertButtonConfig(text: text, type: colorType) { [weak self] _ in
            guard let self = self else { return }
            self.exitBattle()
            self.stopLive()
            self.routerManager.dismiss()
        }
        items.append(endLiveItem)

        let cancelItem = AlertButtonConfig(text: .cancelText, type: .primary) { [weak self] _ in
            guard let self = self else { return }
            self.routerManager.dismiss()
        }
        items.append(cancelItem)

        let alertConfig = AlertViewConfig(title: title, items: items)
        routerManager.present(view: AtomicAlertView(config: alertConfig), config: .centerDefault())
    }

    private func exitBattle() {
        store.battleStore.exitBattle(battleID: store.battleState.currentBattleInfo?.battleID ?? "", completion: nil)
    }

    private func stopLive() {
        gameView?.stopScreenShare()
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

    private func showEndView(with statisticsData: TUILiveStatisticsData) {
        let state = AnchorState()
        state.totalDuration = statisticsData.liveDuration / 1000
        state.totalViewers = statisticsData.totalViewers
        state.totalGiftCoins = statisticsData.totalGiftCoins
        state.totalGiftUniqueSenders = statisticsData.totalUniqueGiftSenders
        state.totalLikesReceived = statisticsData.totalLikesReceived
        state.totalMessageSent = statisticsData.totalMessageCount
        delegate?.onEndLiving(state: state)
    }
}

private extension String {
    static let connectionInviteText = internalLocalized("common_connect_inviting_append")
    static let rejectText = internalLocalized("common_reject")
    static let acceptText = internalLocalized("common_receive")
    static let battleInvitationText = internalLocalized("common_battle_inviting")
    static let rejectBattleText = internalLocalized("common_battle_invitee_reject")
    static let cancelBattleText = internalLocalized("common_battle_inviter_cancel")
    static let battleRequestTimeoutText = internalLocalized("common_battle_invitation_timeout")
    static let roomDismissText = internalLocalized("common_room_destroy")
    static let kickedOutText = internalLocalized("common_kicked_out_of_room_by_owner")

    // End Live
    static let confirmCloseText = internalLocalized("common_end_live")
    static let confirmEndLiveText = internalLocalized("live_end_live_tips")
    static let confirmExitText = internalLocalized("common_exit_live")
    static let endLiveOnConnectionText = internalLocalized("common_end_connection_tips")
    static let endLiveDisconnectText = internalLocalized("common_end_connection")
    static let endLiveOnLinkMicText = internalLocalized("common_anchor_end_link_tips")
    static let endLiveOnBattleText = internalLocalized("common_end_pk_tips")
    static let endLiveBattleText = internalLocalized("common_end_pk")
    static let cancelText = internalLocalized("common_cancel")
}
