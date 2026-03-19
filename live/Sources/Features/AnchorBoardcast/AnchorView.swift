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
        var liveInfo = LiveInfo(seatTemplate: prepareState.templateMode.toSeatLayoutTemplate())
        liveInfo.liveID = liveID
        liveInfo.liveName = prepareState.roomName
        liveInfo.coverURL = prepareState.coverUrl
        liveInfo.isPublicVisible = prepareState.privacyMode == .public
        // Default set background image to cover
        liveInfo.backgroundURL = prepareState.coverUrl
        
        // Default setting
        liveInfo.seatMode = .apply
        
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
        
    private let store: AnchorStore
    private lazy var routerManager: AnchorRouterManager = .init()
    private lazy var routerCenter = AnchorRouterControlCenter(rootViewController: getCurrentViewController() ?? (TUITool.applicationKeywindow().rootViewController ?? UIViewController()), routerManager: routerManager, store: store, coreView: videoView)
    
    private lazy var isInWaitingPublisher = store.subscribeState(StatePublisherSelector(keyPath: \AnchorBattleState.isInWaiting))
    private var cancellableSet = Set<AnyCancellable>()
    
    private let videoView: LiveCoreView
    
    private lazy var livingView: AnchorLivingView = {
        let view = AnchorLivingView(store: store, routerManager: routerManager, coreView: videoView)
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
    
    private var needPresentAlertConfig: AlertViewConfig?
    private var defaultVideoViewDelegate: AnchorVideoDelegate?
    
    public init(liveInfo: LiveInfo, coreView: LiveCoreView, behavior: RoomBehavior = .createRoom) {
        self.liveInfo = liveInfo
        self.videoView = coreView
        self.store = AnchorStore(liveID: liveInfo.liveID)
        super.init(frame: .zero)
        store.prepareLiveInfoBeforeEnterRoom(pkTemplateMode: .verticalGridDynamic)
        initialize(behavior: behavior)
    }
    
    public init(liveParams: LiveParams, coreView: LiveCoreView, behavior: RoomBehavior = .createRoom) {
        self.liveInfo = liveParams.liveInfo
        self.videoView = coreView
        self.store = AnchorStore(liveID: liveParams.liveID)
        super.init(frame: .zero)
        store.prepareLiveInfoBeforeEnterRoom(pkTemplateMode: liveParams.prepareState.pkTemplateMode)
        initialize(behavior: behavior)
    }
    
    private func initialize(behavior: RoomBehavior) {
        videoView.setLiveID(liveID)
        backgroundColor = .black
        
        if videoView.videoViewDelegate == nil {
            let defaultDelegate = AnchorVideoDelegate(store: store, routerManager: routerManager)
            defaultVideoViewDelegate = defaultDelegate
            videoView.videoViewDelegate = defaultDelegate
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
    
    func updateRootViewOrientation(isPortrait: Bool) {
        livingView.updateRootViewOrientation(isPortrait: isPortrait)
    }
    
    func relayoutCoreView() {
        addSubview(videoView)
        updateCoreViewLayout()
        sendSubviewToBack(videoView)
    }
    
    private func updateCoreViewLayout() {
        guard !store.liveListState.currentLive.isEmpty,
              store.liveListState.currentLive.seatTemplate == .videoLandscape4Seats,
              WindowUtils.isPortrait,
              videoView.superview != nil
        else {
            videoView.snp.remakeConstraints { make in
                make.leading.trailing.equalToSuperview()
                make.top.equalToSuperview().inset(36.scale375Height())
                make.bottom.equalToSuperview().inset(96.scale375Height())
            }
            return
        }
        videoView.snp.remakeConstraints { make in
            make.leading.trailing.equalToSuperview()
            make.top.equalToSuperview().offset(150)
            make.height.equalTo(Screen_Width * 720 / 1280)
        }
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
        updateCoreViewLayout()
        
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
        subscribeState()
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
        routerManager.dismiss(dismissType: .alert, completion: nil)
        if liveInfo.keepOwnerOnSeat, store.deviceState.cameraStatus == .off {
            openLocalCamera()
            openLocalMicrophone()
        }
        store.liveListStore.createLive(liveInfo) { [weak self] result in
            guard let self = self else { return }
            switch result {
            case .success:
                startLiveBlock?()
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
        store.liveListStore.joinLive(liveID: liveID) { [weak self] result in
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
        videoView.setLocalVideoMuteImage(
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

        store.onEndLivingSubject
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
                guard let self = self, !isShow, let alertConfig = needPresentAlertConfig else { return }
                let alertView = AtomicAlertView(config: alertConfig)
                routerManager.present(view: alertView, config: .centerDefault())
                needPresentAlertConfig = nil
            }
            .store(in: &cancellableSet)
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
    static let connectionInviteText = internalLocalized("common_connect_inviting_append")
    static let rejectText = internalLocalized("common_reject")
    static let acceptText = internalLocalized("common_receive")
    static let battleInvitationText = internalLocalized("common_battle_inviting")
    static let rejectBattleText = internalLocalized("common_battle_invitee_reject")
    static let cancelBattleText = internalLocalized("common_battle_inviter_cancel")
    static let battleRequestTimeoutText = internalLocalized("common_battle_invitation_timeout")
}
