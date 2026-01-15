//
//  AudienceView.swift
//  TUILiveKit
//
//  Created by krabyu on 2023/10/19.
//

import AtomicXCore
import Combine
import Foundation
import RTCCommon
import RTCRoomEngine
import TUICore
import AtomicX

public protocol RotateScreenDelegate: AnyObject {
    func rotateScreen(isPortrait: Bool)
}

class AudienceView: RTCBaseView {
    let roomId: String
    
    weak var rotateScreenDelegate: RotateScreenDelegate?
    
    // MARK: - private property

    private let manager: AudienceStore
    private let routerManager: AudienceRouterManager
    private var cancellableSet: Set<AnyCancellable> = []
    
    // MARK: - property: view

    private let videoView: LiveCoreView
    
    private var panDirection: PanDirection = .none
    enum PanDirection {
        case left, right, none
    }
    
    lazy var livingView: AudienceLivingView = {
        let view = AudienceLivingView(manager: manager, routerManager: routerManager, coreView: videoView)
        view.rotateScreenDelegate = self
        return view
    }()
    
    lazy var leaveButton: UIButton = {
        let button = UIButton()
        button.setImage(internalImage("live_leave_icon"), for: .normal)
        button.imageEdgeInsets = UIEdgeInsets(top: 2.scale375(), left: 2.scale375(), bottom: 2.scale375(), right: 2.scale375())
        return button
    }()
    
    lazy var restoreClearButton: UIButton = {
        let button = UIButton()
        button.backgroundColor = .black.withAlphaComponent(0.2)
        button.setImage(internalImage("live_restore_clean_icon"), for: .normal)
        button.layer.cornerRadius = 20.scale375()
        button.isHidden = true
        return button
    }()
    
    lazy var coverBgView: UIImageView = {
        let imageView = UIImageView(frame: .zero)
        let effect = UIBlurEffect(style: .light)
        let blurView = UIVisualEffectView(effect: effect)
        imageView.addSubview(blurView)
        blurView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }
        imageView.image = internalImage("live_edit_info_default_cover_image")
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
    
    init(roomId: String, manager: AudienceStore, routerManager: AudienceRouterManager, coreView: LiveCoreView) {
        self.roomId = roomId
        self.manager = manager
        self.routerManager = routerManager
        self.videoView = coreView
        super.init(frame: .zero)
        videoView.setLiveID(roomId)
        videoView.videoViewDelegate = self
    }
    
    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
        LiveKitLog.info("\(#file)", "\(#line)", "deinit AudienceView \(self)")
    }
    
    override func constructViewHierarchy() {
        addSubview(coverBgView)
        addSubview(videoView)
        addSubview(topGradientView)
        addSubview(bottomGradientView)
        addSubview(livingView)
        addSubview(leaveButton)
        addSubview(restoreClearButton)
    }
    
    override func activateConstraints() {
        coverBgView.snp.remakeConstraints { make in
            make.edges.equalToSuperview()
        }
        videoView.snp.remakeConstraints { make in
            make.edges.equalToSuperview()
        }
        livingView.snp.remakeConstraints { make in
            make.edges.equalToSuperview()
        }
        
        if WindowUtils.isPortrait {
            leaveButton.snp.remakeConstraints { make in
                make.trailing.equalToSuperview().inset(20.scale375Width())
                make.top.equalToSuperview().offset(70.scale375Height())
                make.width.equalTo(24.scale375Width())
                make.height.equalTo(24.scale375Width())
            }
            restoreClearButton.snp.remakeConstraints { make in
                make.trailing.equalToSuperview().inset(16.scale375())
                make.bottom.equalToSuperview().inset(40.scale375Height())
                make.width.height.equalTo(40.scale375())
            }
            topGradientView.snp.remakeConstraints { make in
                make.top.leading.trailing.equalToSuperview()
                make.height.equalTo(142.scale375Height())
            }
            bottomGradientView.snp.remakeConstraints { make in
                make.bottom.leading.trailing.equalToSuperview()
                make.height.equalTo(246.scale375Height())
            }
        } else {
            leaveButton.snp.remakeConstraints { make in
                make.trailing.equalToSuperview().inset(20.scale375())
                make.top.equalToSuperview().offset(20.scale375())
                make.width.equalTo(24.scale375())
                make.height.equalTo(24.scale375())
            }
            restoreClearButton.snp.remakeConstraints { make in
                make.trailing.equalToSuperview().inset(16.scale375())
                make.bottom.equalToSuperview().inset(40.scale375())
                make.width.height.equalTo(40.scale375())
            }
            topGradientView.snp.remakeConstraints { make in
                make.top.leading.trailing.equalToSuperview()
                make.height.equalTo(142.scale375())
            }
            bottomGradientView.snp.remakeConstraints { make in
                make.bottom.leading.trailing.equalToSuperview()
                make.height.equalTo(246.scale375())
            }
        }
    }
    
    override func bindInteraction() {
        subscribeOrientationChange()
        subscribeRoomState()
        subscribeMediaState()
        subscribeEvent()
        setupSlideToClear()
        leaveButton.addTarget(self, action: #selector(leaveButtonClick), for: .touchUpInside)
        restoreClearButton.addTarget(self, action: #selector(restoreLivingView), for: .touchUpInside)
    }
    
    override func layoutSubviews() {
        super.layoutSubviews()
        topGradientView.gradient(colors: [.g1.withAlphaComponent(0.3), .clear], isVertical: true)
        bottomGradientView.gradient(colors: [.clear, .g1.withAlphaComponent(0.3)], isVertical: true)
    }
    
    func relayoutCoreView() {
        addSubview(videoView)
        videoView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }
        sendSubviewToBack(videoView)
        sendSubviewToBack(coverBgView)
    }
}

extension AudienceView {
    private func subscribeOrientationChange() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleOrientationChange),
            name: Notification.Name.TUILiveKitRotateScreenNotification,
            object: nil
        )
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
                } else if !currentLive.backgroundURL.isEmpty {
                    coverBgView.kf.setImage(with: URL(string: currentLive.backgroundURL), placeholder: internalImage("live_edit_info_default_cover_image"))
                } else if !currentLive.coverURL.isEmpty {
                    coverBgView.kf.setImage(with: URL(string: currentLive.coverURL), placeholder: internalImage("live_edit_info_default_cover_image"))
                }
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
                case .onLiveEnded:
                    routeToAudienceView()
                case .onKickedOutOfLive:
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
        routerManager.router(action: .routeTo(.audience))
    }
        
    private func onKickedByAdmin() {
        manager.toastSubject.send((.kickedOutText,.info))
        isUserInteractionEnabled = false
        DispatchQueue.main.asyncAfter(deadline: .now() + 1) { [weak self] in
            guard let self = self else { return }
            isUserInteractionEnabled = true
            routerManager.router(action: .exit)
        }
    }
    
    @objc func handleOrientationChange() {
        activateConstraints()
    }
    
    @objc func leaveButtonClick() {
        rotateScreenDelegate?.rotateScreen(isPortrait: true)

        if !manager.coGuestState.connected.isOnSeat() {
            leaveRoom()
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
            leaveRoom()
        }
        items.append(endLiveItem)
        
        let cancelItem = AlertButtonConfig(text: .cancelText, type: .primary) { [weak self] _ in
            guard let self = self else { return }
            self.routerManager.dismiss()
        }
        items.append(cancelItem)

        let alertView = AtomicAlertView(config: AlertViewConfig(title: title, items: items))
        routerManager.present(view: alertView)
    }
    
    func leaveRoom() {
        videoView.stopPreviewLiveStream(roomId: roomId)
        manager.liveListStore.leaveLive(completion: nil)
        routerManager.router(action: .exit)
        TUICore.notifyEvent(TUICore_PrivacyService_ROOM_STATE_EVENT_CHANGED,
                            subKey: TUICore_PrivacyService_ROOM_STATE_EVENT_SUB_KEY_END,
                            object: nil,
                            param: nil)
    }
}

// MARK: - Slide to clear

extension AudienceView {
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
                livingView.transform = CGAffineTransform(translationX: bounds.width + translation.x, y: 0)
            } else if translation.x > 0 {
                livingView.transform = CGAffineTransform(translationX: translation.x, y: 0)
            }
        case .ended, .cancelled:
            guard isValidPan() else { return }
            let isSameDirection = velocity.x > 0 && panDirection == .right || velocity.x < 0 && panDirection == .left
            let shouldComplete = isSameDirection && (abs(translation.x) > 100 || abs(velocity.x) > 800)
            if shouldComplete {
                panDirection == .right ? hideLivingView() : restoreLivingView()
            } else {
                resetLivingView()
            }
            panDirection = .none
        default: break
        }
    }
    
    private func isValidPan() -> Bool {
        return (panDirection == .right && !isLivingViewMoved()) || (panDirection == .left && isLivingViewMoved())
    }
    
    private func hideLivingView() {
        UIView.animate(withDuration: 0.3, animations: { [weak self] in
            guard let self = self else { return }
            livingView.transform = CGAffineTransform(translationX: max(UIScreen.main.bounds.width, UIScreen.main.bounds.height), y: 0)
        })
        restoreClearButton.isHidden = false
        livingView.setGiftPureMode(true)
    }
    
    @objc private func restoreLivingView() {
        UIView.animate(withDuration: 0.3) { [weak self] in
            guard let self = self else { return }
            livingView.transform = .identity
        }
        restoreClearButton.isHidden = true
        livingView.setGiftPureMode(false)
    }
        
    private func resetLivingView() {
        UIView.animate(withDuration: 0.3) { [weak self] in
            guard let self = self else { return }
            if panDirection == .right {
                livingView.transform = .identity
            } else {
                livingView.transform = CGAffineTransform(translationX: max(bounds.width, bounds.height), y: 0)
            }
        }
    }
    
    private func isLivingViewMoved() -> Bool {
        !restoreClearButton.isHidden
    }
}

extension AudienceView {
    func joinLiveStream(onComplete: @escaping (Result<Void, InternalError>) -> Void) {
        let imageName = getPreferredLanguage() == "en" ? "live_muteImage_en" : "live_muteImage"
        videoView
            .setLocalVideoMuteImage(
                bigImage: internalImage(imageName) ?? UIImage(),
                smallImage: internalImage("live_muteImage_small") ?? UIImage()
            )
        LiveListStore.shared.joinLive(liveID: roomId) { [weak self] result in
            guard let self = self else { return }
            switch result {
            case .success(let liveInfo):
                livingView.initComponentView(liveInfo: liveInfo)
                livingView.isHidden = false
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

extension AudienceView: VideoViewDelegate {
    func createCoGuestView(seatInfo: SeatInfo, viewLayer: ViewLayer) -> UIView? {
        switch viewLayer {
        case .foreground:
            if !seatInfo.userInfo.userID.isEmpty {
                return AudienceCoGuestView(seatInfo: seatInfo, manager: manager, routerManager: routerManager)
            }
            return AudienceEmptySeatView(seatInfo: seatInfo, manager: manager, routerManager: routerManager, coreView: videoView)
        case .background:
            if !seatInfo.userInfo.userID.isEmpty {
                return AudienceBackgroundWidgetView(avatarUrl: seatInfo.userInfo.avatarURL)
            }
            return nil
        }
    }
    
    func createCoHostView(seatInfo: SeatInfo, viewLayer: ViewLayer) -> UIView? {
        switch viewLayer {
        case .foreground:
            if !seatInfo.userInfo.userID.isEmpty {
                return AudienceCoHostView(seatInfo: seatInfo, manager: manager)
            }
            return AudienceEmptySeatView(seatInfo: seatInfo, manager: manager, routerManager: routerManager, coreView: videoView)
        case .background:
            if !seatInfo.userInfo.userID.isEmpty {
                return AudienceBackgroundWidgetView(avatarUrl: seatInfo.userInfo.avatarURL)
            }
            return nil
        }
    }
    
    func createBattleView(seatInfo: SeatInfo) -> UIView? {
        return AudienceBattleMemberInfoView(manager: manager, userId: seatInfo.userInfo.userID)
    }
    
    func createBattleContainerView() -> UIView? {
        return AudienceBattleInfoView(manager: manager, routerManager: routerManager, isOwner: true, coreView: videoView)
    }
}

extension AudienceView: UIGestureRecognizerDelegate {
    override func gestureRecognizerShouldBegin(_ gesture: UIGestureRecognizer) -> Bool {
        guard let pan = gesture as? UIPanGestureRecognizer else { return true }
        let velocity = pan.velocity(in: self)
        return abs(velocity.x) > abs(velocity.y)
    }
}

extension AudienceView: RotateScreenDelegate {
    func rotateScreen(isPortrait: Bool) {
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
