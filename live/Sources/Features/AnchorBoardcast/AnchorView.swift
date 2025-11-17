//
//  File.swift
//  TUILiveKit
//
//  Created by WesleyLei on 2023/12/14.
//

import AtomicXCore
import Combine
import Foundation
import RTCCommon
import RTCRoomEngine
import TUICore

public enum AnchorViewFeature {
    case liveData
    case visitorCnt
    case coGuest
    case coHost
    case battle
    
    // Settings
    case soundEffect
}

public struct LiveParams {
    var liveID: String
    var prepareState: PrepareState
    var liveInfo: LiveInfo {
        var liveInfo = LiveInfo()
        liveInfo.liveID = liveID
        liveInfo.liveName = prepareState.roomName
        liveInfo.coverURL = prepareState.coverUrl
        liveInfo.isPublicVisible = prepareState.privacyMode == .public
        liveInfo.seatLayoutTemplateID = UInt(prepareState.templateMode.rawValue)
        // Default set background image to cover
        liveInfo.backgroundURL = prepareState.coverUrl
        
        // Default setting
        liveInfo.isSeatEnabled = true
        liveInfo.seatMode = .apply
        liveInfo.keepOwnerOnSeat = true
        if liveInfo.seatLayoutTemplateID == 0 {
            liveInfo.maxSeatCount = 9
        }
        
        return liveInfo
    }
}

public class AnchorView: UIView {
    public var startLiveBlock: (() -> Void)?
    public weak var delegate: AnchorViewDelegate?

    private let liveInfo: LiveInfo
    private var liveID: String {
        liveInfo.liveID
    }
        
    private let manager: AnchorManager
    private lazy var routerManager: AnchorRouterManager = .init()
    private lazy var routerCenter = AnchorRouterControlCenter(rootViewController: getCurrentViewController() ?? (TUITool.applicationKeywindow().rootViewController ?? UIViewController()), rootRoute: .anchor, routerManager: routerManager, manager: manager, coreView: videoView)
    
    private lazy var isInWaitingPublisher = manager.subscribeState(StateSelector(keyPath: \AnchorBattleState.isInWaiting))
    private var cancellableSet = Set<AnyCancellable>()
    
    private let videoView: LiveCoreView
    
    private lazy var livingView: AnchorLivingView = {
        let view = AnchorLivingView(manager: manager, routerManager: routerManager, coreView: videoView)
        return view
    }()
    
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
    
    private var needPresentAlertInfo: AnchorAlertInfo?
    
    public init(liveInfo: LiveInfo, coreView: LiveCoreView, behavior: RoomBehavior = .createRoom) {
        self.liveInfo = liveInfo
        self.videoView = coreView
        self.manager = AnchorManager(liveID: liveInfo.liveID)
        super.init(frame: .zero)
        manager.prepareLiveInfoBeforeEnterRoom(pkTemplateMode: .verticalGridDynamic)
        initialize(behavior: behavior)
    }
    
    public init(liveParams: LiveParams, coreView: LiveCoreView, behavior: RoomBehavior = .createRoom) {
        self.liveInfo = liveParams.liveInfo
        self.videoView = coreView
        self.manager = AnchorManager(liveID: liveParams.liveID)
        super.init(frame: .zero)
        manager.prepareLiveInfoBeforeEnterRoom(pkTemplateMode: liveParams.prepareState.pkTemplateMode)
        initialize(behavior: behavior)
    }
    
    private func initialize(behavior: RoomBehavior) {
        videoView.setLiveID(liveID)
        backgroundColor = .black
        videoView.videoViewDelegate = self
        
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
        manager.deviceStore.reset()
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
    
    override public func layoutSubviews() {
        super.layoutSubviews()
        topGradientView.gradient(colors: [.g1.withAlphaComponent(0.3), .clear], isVertical: true)
        bottomGradientView.gradient(colors: [.clear, .g1.withAlphaComponent(0.3)], isVertical: true)
    }
    
    func updateRootViewOrientation(isPortrait: Bool) {
        livingView.updateRootViewOrientation(isPortrait: isPortrait)
    }
    
    func relayoutCoreView() {
        addSubview(videoView)
        videoView.snp.makeConstraints { make in
            make.leading.trailing.equalToSuperview()
            make.top.equalToSuperview().inset(36.scale375Height())
            make.bottom.equalToSuperview().inset(96.scale375Height())
        }
        sendSubviewToBack(videoView)
    }
}

public extension AnchorView {
    func disableHeaderLiveData(_ isDisable: Bool) {
        disableFeature(.liveData, isDisable: isDisable)
    }
    
    func disableHeaderVisitorCnt(_ isDisable: Bool) {
        disableFeature(.visitorCnt, isDisable: isDisable)
    }
    
    func disableFooterCoGuest(_ isDisable: Bool) {
        disableFeature(.coGuest, isDisable: isDisable)
    }
    
    func disableFooterCoHost(_ isDisable: Bool) {
        disableFeature(.coHost, isDisable: isDisable)
    }
    
    func disableFooterBattle(_ isDisable: Bool) {
        disableFeature(.battle, isDisable: isDisable)
    }
    
    func disableFooterSoundEffect(_ isDisable: Bool) {
        disableFeature(.soundEffect, isDisable: isDisable)
    }
    
    internal func setIcon(_ icon: UIImage, for feature: AnchorViewFeature) {
        // TODO: (gg) need to implementation
    }
    
    private func disableFeature(_ feature: AnchorViewFeature, isDisable: Bool) {
        livingView.disableFeature(feature, isDisable: isDisable)
    }
}

extension AnchorView {
    private func constructViewHierarchy() {
        addSubview(videoView)
        addSubview(topGradientView)
        addSubview(bottomGradientView)
        addSubview(livingView)
    }
    
    private func activateConstraints() {
        videoView.snp.makeConstraints { make in
            make.leading.trailing.equalToSuperview()
            make.top.equalToSuperview().inset(36.scale375Height())
            make.bottom.equalToSuperview().inset(96.scale375Height())
        }
        
        livingView.snp.makeConstraints { make in
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
        subscribeCoHostState()
        subscribeBattleState()
        subscribeSubjects()
    }
    
    private func setupViewStyle() {
        videoView.layer.cornerRadius = 16.scale375()
        videoView.layer.masksToBounds = true
    }
}

// MARK: Action

extension AnchorView {
    func startLiveStream() {
        setLocalVideoMuteImage()
        routerManager.router(action: .dismiss(.alert, completion: nil))
        if liveInfo.keepOwnerOnSeat, manager.deviceState.cameraStatus == .off {
            openLocalCamera()
            openLocalMicrophone()
        }
        manager.liveListStore.createLive(liveInfo) { [weak self] result in
            guard let self = self else { return }
            switch result {
            case .success:
                startLiveBlock?()
            case .failure(let err):
                let error = InternalError(code: err.code, message: err.message)
                manager.onError(error)
                DispatchQueue.main.asyncAfter(deadline: .now() + 2) { [weak self] in
                    guard let self = self else { return }
                    routerManager.router(action: .exit)
                }
            }
        }
    }
    
    func joinSelfCreatedRoom() {
        setLocalVideoMuteImage()
        manager.liveListStore.joinLive(liveID: liveID) { [weak self] result in
            guard let self = self else { return }
            switch result {
            case .success(let liveInfo):
                if liveInfo.keepOwnerOnSeat {
                    openLocalCamera()
                    openLocalMicrophone()
                }
                startLiveBlock?()
            case .failure(let err):
                let error = InternalError(code: err.code, message: err.message)
                manager.onError(error)
                DispatchQueue.main.asyncAfter(deadline: .now() + 2) { [weak self] in
                    guard let self = self else { return }
                    routerManager.router(action: .exit)
                }
            }
        }
    }
    
    private func subscribeCoHostState() {
        manager.subscribeState(StatePublisherSelector(keyPath: \CoHostState.applicant))
            .receive(on: RunLoop.main)
            .removeDuplicates()
            .sink { [weak self] applicant in
                guard let self = self else { return }
                if let applicantUser = applicant {
                    let selfUserID = manager.selfUserID
                    if !manager.coGuestState.applicants.isEmpty
                        || !manager.coGuestState.connected.filter({ $0.userID != selfUserID }).isEmpty
                        || !manager.coGuestState.invitees.isEmpty
                    {
                        // If received linkmic request first, reject connection auto.
                        manager.coHostStore.rejectHostConnection(fromHostLiveID: applicantUser.liveID, completion: nil)
                        return
                    }
                    let alertInfo = AnchorAlertInfo(description: String.localizedReplace(.connectionInviteText, replace: "\(applicantUser.userName)"),
                                                    imagePath: applicantUser.avatarURL,
                                                    cancelButtonInfo: (String.rejectText, .cancelTextColor),
                                                    defaultButtonInfo: (String.acceptText, .white))
                    { [weak self] _ in
                        guard let self = self else { return }
                        manager.coHostStore.rejectHostConnection(fromHostLiveID: applicantUser.liveID) { [weak self] result in
                            guard let self = self else { return }
                            switch result {
                            case .failure(let err):
                                let error = InternalError(code: err.code, message: err.message)
                                manager.onError(error)
                            default: break
                            }
                        }
                        routerManager.router(action: .dismiss(.alert, completion: nil))
                    } defaultClosure: { [weak self] _ in
                        guard let self = self else { return }
                        manager.coHostStore.acceptHostConnection(fromHostLiveID: applicantUser.liveID) { [weak self] result in
                            guard let self = self else { return }
                            switch result {
                            case .failure(let err):
                                let error = InternalError(code: err.code, message: err.message)
                                manager.onError(error)
                            default: break
                            }
                        }
                        routerManager.router(action: .dismiss(.alert, completion: nil))
                    }
                    if FloatWindow.shared.isShowingFloatWindow() {
                        needPresentAlertInfo = alertInfo
                    } else {
                        routerManager.router(action: .present(.alert(info: alertInfo)))
                    }
                } else {
                    routerManager.router(action: .dismiss(.alert, completion: nil))
                }
            }
            .store(in: &cancellableSet)
    }

    private func setLocalVideoMuteImage() {
        let imageName = TUIGlobalization.getPreferredLanguage() == "en" ? "live_muteImage_en" : "live_muteImage"
        videoView.setLocalVideoMuteImage(
            bigImage: internalImage(imageName) ?? UIImage(),
            smallImage: internalImage("live_muteImage_small") ?? UIImage()
        )
    }

    private func openLocalCamera() {
        guard manager.deviceState.cameraStatus == .off else { return }
        manager.deviceStore.openLocalCamera(isFront: manager.deviceState.isFrontCamera) { [weak self] result in
            guard let self = self else { return }
            switch result {
            case .failure(let err):
                let error = InternalError(code: err.code, message: err.message)
                manager.onError(error)
                DispatchQueue.main.asyncAfter(deadline: .now() + 2) { [weak self] in
                    guard let self = self else { return }
                    routerManager.router(action: .exit)
                }
            default: break
            }
        }
    }

    private func openLocalMicrophone() {
        guard manager.deviceState.microphoneStatus == .off else { return }
        manager.deviceStore.openLocalMicrophone { [weak self] result in
            guard let self = self else { return }
            switch result {
            case .failure(let err):
                let error = InternalError(code: err.code, message: err.message)
                manager.onError(error)
                DispatchQueue.main.asyncAfter(deadline: .now() + 2) { [weak self] in
                    guard let self = self else { return }
                    routerManager.router(action: .exit)
                }
            default: break
            }
        }
    }

    private func subscribeBattleState() {
        manager.battleStore.battleEventPublisher
            .receive(on: RunLoop.main)
            .sink { [weak self] event in
                guard let self = self else { return }
                switch event {
                case .onBattleStarted(battleInfo: _, inviter: _, invitees: _):
                    routerManager.router(action: .dismiss(AnchorDismissType.panel, completion: nil))
                case .onBattleRequestCancelled(battleID: _, inviter: _, invitee: _),
                     .onBattleRequestTimeout(battleID: _, inviter: _, invitee: _):
                    routerManager.router(action: .dismiss(.alert, completion: nil))
                case .onBattleRequestReject(battleID: _, inviter: _, invitee: let invitee):
                    makeToast(message: .rejectBattleText.replacingOccurrences(of: "xxx", with: invitee.displayName))
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
        manager.toastSubject
            .receive(on: RunLoop.main)
            .sink { [weak self] message in
                guard let self = self else { return }
                makeToast(message: message)
            }.store(in: &cancellableSet)
        
        manager.floatWindowSubject
            .receive(on: RunLoop.main)
            .sink { [weak self] in
                guard let self = self else { return }
                delegate?.onClickFloatWindow()
            }
            .store(in: &cancellableSet)

        manager.onEndLivingSubject
            .receive(on: RunLoop.main)
            .sink { [weak self] state in
                guard let self = self else { return }
                delegate?.onEndLiving(state: state)
            }
            .store(in: &cancellableSet)
        
        FloatWindow.shared.subscribeShowingState()
            .receive(on: RunLoop.main)
            .dropFirst()
            .sink { [weak self] isShow in
                guard let self = self, !isShow, let alertInfo = needPresentAlertInfo else { return }
                routerManager.router(action: .present(.alert(info: alertInfo)))
                needPresentAlertInfo = nil
            }
            .store(in: &cancellableSet)
    }
}

extension AnchorView {
    private func onReceivedBattleRequestChanged(battleID: String, inviter: SeatUserInfo) {
        let alertInfo = AnchorAlertInfo(description: .localizedReplace(.battleInvitationText, replace: inviter.userName),
                                        imagePath: inviter.avatarURL,
                                        cancelButtonInfo: (String.rejectText, .cancelTextColor),
                                        defaultButtonInfo: (String.acceptText, .white))
        { [weak self] _ in
            guard let self = self else { return }
            manager.battleStore.rejectBattle(battleID: battleID) { [weak self] result in
                guard let self = self else { return }
                switch result {
                case .failure(let err):
                    let error = InternalError(code: err.code, message: err.message)
                    manager.onError(error)
                default: break
                }
            }
            routerManager.router(action: .dismiss(.alert, completion: nil))
        } defaultClosure: { [weak self] _ in
            guard let self = self else { return }
            manager.battleStore.acceptBattle(battleID: battleID) { [weak self] result in
                guard let self = self else { return }
                switch result {
                case .failure(let err):
                    let error = InternalError(code: err.code, message: err.message)
                    manager.onError(error)
                default: break
                }
            }
            routerManager.router(action: .dismiss(.alert, completion: nil))
        }
        if FloatWindow.shared.isShowingFloatWindow() {
            needPresentAlertInfo = alertInfo
        } else {
            routerManager.router(action: .present(.alert(info: alertInfo)))
        }
    }
    
    private func onInWaitingChanged(inWaiting: Bool) {
        if inWaiting {
            routerManager.router(action: .present(.battleCountdown(anchorBattleRequestTimeout)))
        } else {
            let topRoute = routerManager.routerState.routeStack.last
            switch topRoute {
            case .battleCountdown:
                routerManager.router(action: .dismiss())
            default:
                break
            }
        }
    }
}

extension AnchorView: VideoViewDelegate {
    public func createCoGuestView(seatInfo: TUISeatFullInfo, viewLayer: ViewLayer) -> UIView? {
        switch viewLayer {
        case .foreground:
            if let userId = seatInfo.userId, !userId.isEmpty {
                return AnchorCoGuestView(seatInfo: SeatInfo(seatFullInfo: seatInfo), manager: manager, routerManager: routerManager)
            }
            return AnchorEmptySeatView(seatInfo: SeatInfo(seatFullInfo: seatInfo))
        case .background:
            if let userId = seatInfo.userId, !userId.isEmpty {
                return AnchorBackgroundWidgetView(avatarUrl: seatInfo.userAvatar ?? "")
            }
            return nil
        }
    }
    
    public func createCoHostView(seatInfo: TUISeatFullInfo, viewLayer: ViewLayer) -> UIView? {
        switch viewLayer {
        case .foreground:
            if let userId = seatInfo.userId, !userId.isEmpty {
                return AnchorCoHostView(seatInfo: SeatInfo(seatFullInfo: seatInfo), manager: manager)
            }
            return AnchorEmptySeatView(seatInfo: SeatInfo(seatFullInfo: seatInfo))
        case .background:
            if let userId = seatInfo.userId, !userId.isEmpty {
                return AnchorBackgroundWidgetView(avatarUrl: seatInfo.userAvatar ?? "")
            }
            return nil
        }
    }
    
    public func createBattleView(battleUser: TUIBattleUser) -> UIView? {
        let battleView = AnchorBattleMemberInfoView(manager: manager, userId: battleUser.userId)
        battleView.isUserInteractionEnabled = false
        return battleView
    }
    
    public func createBattleContainerView() -> UIView? {
        return AnchorBattleInfoView(manager: manager, routerManager: routerManager)
    }
}

// ** Only should use for test **
extension AnchorView {
    @objc func disableHeaderLiveDataForTest(_ isDisable: NSNumber) {
        disableHeaderLiveData(isDisable.boolValue)
    }
    
    @objc func disableHeaderVisitorCntForTest(_ isDisable: NSNumber) {
        disableHeaderVisitorCnt(isDisable.boolValue)
    }
    
    @objc func disableFooterCoGuestForTest(_ isDisable: NSNumber) {
        disableFooterCoGuest(isDisable.boolValue)
    }
    
    @objc func disableFooterCoHostForTest(_ isDisable: NSNumber) {
        disableFooterCoHost(isDisable.boolValue)
    }
    
    @objc func disableFooterBattleForTest(_ isDisable: NSNumber) {
        disableFooterBattle(isDisable.boolValue)
    }
    
    @objc func disableFooterSoundEffectForTest(_ isDisable: NSNumber) {
        disableFooterSoundEffect(isDisable.boolValue)
    }
}

private extension String {
    static let connectionInviteText = internalLocalized("xxx invite you to host together")
    static let rejectText = internalLocalized("Reject")
    static let acceptText = internalLocalized("Accept")
    static let battleInvitationText = internalLocalized("xxx invite you to battle together")
    static let rejectBattleText = internalLocalized("xxx rejected battle")
}
