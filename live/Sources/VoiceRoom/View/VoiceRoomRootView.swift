//
//  VoiceRoomRootView.swift
//  VoiceRoom
//
//  Created by aby on 2024/3/4.
//

import Combine
import Kingfisher
import SnapKit
import TUICore
import RTCCommon
import RTCRoomEngine
import AtomicXCore
import AtomicX

protocol VoiceRoomRootViewDelegate: AnyObject {
    func rootView(_ view: VoiceRoomRootView, showEndView endInfo: [String:Any], isAnchor: Bool)
}

class VoiceRoomRootView: RTCBaseView {
    weak var delegate: VoiceRoomRootViewDelegate?
    
    private let prepareStore: VoiceRoomPrepareStore
    private let toastService: VRToastService
    private let liveID: String
    private let seatGridView: SeatGridView
    private let routerManager: VRRouterManager
    private let kTimeoutValue: TimeInterval = 60
    private let isOwner: Bool
    private let giftCacheService = GiftManager.shared.giftCacheService
    private let imStore = VoiceRoomIMStore()
    private let viewStore = VoiceRoomViewStore()
    private var cancellableSet = Set<AnyCancellable>()
    private var isExited: Bool = false
    private let defaultTemplateId: UInt = 70
    private let summaryStore: LiveSummaryStore
    
    @Published private var isLinked: Bool = false
    
    private let backgroundImageView: UIImageView = {
        let backgroundImageView = UIImageView(frame: .zero)
        backgroundImageView.contentMode = .scaleAspectFill
        return backgroundImageView
    }()
    
    private lazy var karaokeManager: KaraokeManager = {
        let manager = KaraokeManager(roomId: liveID)
        return manager
    }()
    
    private var ktvView: KtvView?
    
    private var selfInfo: UserProfile {
        LoginStore.shared.state.value.loginUserInfo ?? UserProfile(userID: "")
    }
    
    private let backgroundGradientView: UIView = {
        var view = UIView()
        return view
    }()
    
    private lazy var topView: VRTopView = {
        let view = VRTopView(routerManager: routerManager,isOwner: isOwner)
        return view
    }()
    
    private lazy var bottomMenu : VRBottomMenuView = {
        let view = VRBottomMenuView(liveID: liveID, routerManager: routerManager, viewStore: viewStore, toastService: toastService, isOwner: isOwner)
        view.songListButtonAction = { [weak self] in
            guard let self = self , let vc = WindowUtils.getCurrentWindowViewController() else { return }
            let isKTV = prepareStore.state.layoutType == .KTVRoom
            let songListView = SongListViewController(karaokeManager: self.karaokeManager,isOwner: isOwner,isKTV: isKTV)
            vc.present(songListView, animated: true)
        }
        return view
    }()
    
    private let muteMicrophoneButton: UIButton = {
        let button = UIButton(frame: .zero)
        button.setImage(internalImage("live_open_mic_icon"), for: .normal)
        button.setImage(internalImage("live_close_mic_icon"), for: .selected)
        button.layer.borderColor = UIColor.g3.withAlphaComponent(0.3).cgColor
        button.layer.borderWidth = 1
        button.layer.cornerRadius = 16.scale375Height()
        return button
    }()
    
    private lazy var barrageButton: BarrageInputView = {
        let view = BarrageInputView(roomId: liveID)
        view.layer.borderColor = UIColor.flowKitWhite.withAlphaComponent(0.14).cgColor
        view.layer.borderWidth = 1
        view.layer.cornerRadius = 18.scale375Height()
        view.backgroundColor = .pureBlackColor.withAlphaComponent(0.25)
        return view
    }()
    
    private lazy var barrageDisplayView: BarrageStreamView = {
        let view = BarrageStreamView(liveID: liveID)
        view.delegate = self
        return view
    }()
    
    private lazy var giftDisplayView: GiftPlayView = {
        let view = GiftPlayView(roomId: liveID)
        view.delegate = self
        return view
    }()
    
    private var selfId: String {
        TUIRoomEngine.getSelfInfo().userId
    }
    
    init(frame: CGRect,
         liveID: String,
         backgroundURL: String,
         seatGridView: SeatGridView,
         prepareStore: VoiceRoomPrepareStore,
         routerManager: VRRouterManager,
         toastService: VRToastService,
         isCreate: Bool) {
        self.liveID = liveID
        self.prepareStore = prepareStore
        self.backgroundImageView.kf.setImage(with: URL(string: backgroundURL), placeholder: UIImage.placeholderImage)
        self.routerManager = routerManager
        self.toastService = toastService
        self.isOwner = isCreate
        self.seatGridView = seatGridView
        self.summaryStore = LiveSummaryStore.create(liveID: liveID)
        super.init(frame: frame)
        self.seatGridView.sgDelegate = self
        if isCreate {
            start(liveID: liveID)
        } else {
            join(roomId: liveID)
        }
        seatGridView.addObserver(observer: self)
        //TODO: store不支持error事件，暂时直接监听roomEngine回调
        TUIRoomEngine.sharedInstance().addObserver(self)
    }
    
    deinit {
        seatGridView.removeObserver(observer: self)
        TUIRoomEngine.sharedInstance().removeObserver(self)
        TUICore.notifyEvent(TUICore_PrivacyService_ROOM_STATE_EVENT_CHANGED,
                            subKey: TUICore_PrivacyService_ROOM_STATE_EVENT_SUB_KEY_END,
                            object: nil,
                            param: nil)
        print("deinit \(type(of: self))")
    }
    
    override func constructViewHierarchy() {
        addSubview(backgroundImageView)
        addSubview(backgroundGradientView)
        addSubview(barrageDisplayView)
        addSubview(seatGridView)
        addSubview(giftDisplayView)
        addSubview(topView)
        addSubview(bottomMenu)
        addSubview(barrageButton)
        addSubview(muteMicrophoneButton)
    }
    
    override func activateConstraints() {
        backgroundImageView.snp.makeConstraints { (make) in
            make.edges.equalToSuperview()
        }
        backgroundGradientView.snp.makeConstraints { (make) in
            make.edges.equalToSuperview()
        }
        topView.snp.makeConstraints { make in
            make.left.right.equalToSuperview()
            make.top.equalToSuperview().offset(54.scale375Height())
        }

        seatGridView.snp.makeConstraints { make in
            make.top.equalTo(topView.snp.bottom).offset(40.scale375())
            make.height.equalTo(230.scale375())
            make.left.right.equalToSuperview()
        }

        bottomMenu.snp.makeConstraints { make in
            make.bottom.equalToSuperview().offset(-34.scale375Height())
            make.trailing.equalToSuperview()
            make.height.equalTo(36)
        }
        barrageDisplayView.snp.makeConstraints { make in
            make.leading.equalToSuperview().offset(16)
            make.bottom.equalTo(barrageButton.snp.top).offset(-20)
            make.width.equalTo(305.scale375())
            make.height.equalTo(212.scale375Height())
        }
        barrageButton.snp.makeConstraints { make in
            make.leading.equalToSuperview().offset(16.scale375())
            make.centerY.equalTo(bottomMenu.snp.centerY)
            make.width.equalTo(130.scale375())
            make.height.equalTo(36.scale375Height())
        }
        muteMicrophoneButton.snp.makeConstraints { make in
            make.leading.equalTo(barrageButton.snp.trailing).offset(8.scale375())
            make.centerY.equalTo(barrageButton.snp.centerY)
            make.size.equalTo(CGSize(width: 32.scale375Height(), height: 32.scale375Height()))
        }
        giftDisplayView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }
    }
    
    override func bindInteraction() {
        // Top view interaction.
        topView.delegate = self
        subscribeRoomState()
        subscribeUserState()
        subscribeCoHostState()
        subscribeBattleState()
        muteMicrophoneButton.addTarget(self, action: #selector(muteMicrophoneButtonClick(sender:)), for: .touchUpInside)
        setupliveEventListener()
        setupGuestEventListener()
    }
}

extension VoiceRoomRootView {
    @objc
    func muteMicrophoneButtonClick(sender: UIButton) {
        muteMicrophone(mute: !sender.isSelected)
    }
    
    func muteMicrophone(mute: Bool) {
        if mute {
            seatStore.muteMicrophone()
        } else {
            seatStore.unmuteMicrophone { [weak self] result in
                guard let self = self else { return }
                if case .failure(let error) = result {
                    let error = InternalError(errorInfo: error)
                    handleErrorMessage(error.localizedMessage)
                }
            }
        }
    }
    
    func startMicrophone() {
        deviceStore.openLocalMicrophone { [weak self] result in
            guard let self = self else { return }
            if case .failure(let error) = result {
                if error.code == TUIError.openMicrophoneNeedSeatUnlock.rawValue {
                    // Seat muted will pops up in unmuteMicrophone, so no processing is needed here
                    return
                }
                let error = InternalError(errorInfo: error)
                handleErrorMessage(error.localizedMessage)
            }
        }
    }
    
    func stopMicrophone() {
        deviceStore.closeLocalMicrophone()
    }
}

extension VoiceRoomRootView {
    private func start(liveID: String) {
        var liveInfo = prepareStore.state.liveInfo
        let params = prepareStore.roomParams
        liveInfo.seatMode = TakeSeatMode(from: params.seatMode)
        liveInfo.maxSeatCount = params.maxSeatCount
        
        liveListStore.createLive(liveInfo) { [weak self] result in
            guard let self = self else { return }
            switch result {
            case .success(_):
                handleAbnormalExitedSence()
                onStartVoiceRoom()
                didEnterRoom()
            case .failure(_):
                handleErrorMessage(.enterRoomFailedText)
            }
        }
    }
    
    private func join(roomId: String) {
        liveListStore.joinLive(liveID: roomId) { [weak self] result in
            guard let self = self else { return }
            switch result {
            case .success(let liveInfo):
                onJoinVoiceRoom(liveInfo: liveInfo)
                didEnterRoom()
            case .failure(let error):
                let error = InternalError(errorInfo: error)
                handleErrorMessage(error.localizedMessage)
                DispatchQueue.main.asyncAfter(deadline: .now() + 1) { [weak self] in
                    guard let self = self else { return }
                    routerManager.router(action: .exit)
                }
            }
        }
    }
    
    private func onStartVoiceRoom() {
        audienceStore.fetchAudienceList(completion: nil)
        addEnterBarrage()
    }
    
    private func addEnterBarrage() {
        var barrage = Barrage()
        barrage.liveID = liveID
        barrage.sender = LiveUserInfo.selfInfo
        barrage.textContent = " \(String.comingText)"
        barrage.timestampInSecond = Date().timeIntervalSince1970
        barrageStore.appendLocalTip(message: barrage)
    }
    
    
    func onJoinVoiceRoom(liveInfo: AtomicLiveInfo) {
        audienceStore.fetchAudienceList(completion: nil)
        guard selfId != liveInfo.liveOwner.userID else { return }
        imStore.checkFollowType(liveInfo.liveOwner.userID) { [weak self] result in
            guard let self = self else { return }
            if case .failure(let error) = result {
                handleErrorMessage(error.localizedMessage)
            }
        }
    }
    
    func didEnterRoom() {
        if isOwner {
            TUICore.notifyEvent(TUICore_PrivacyService_ROOM_STATE_EVENT_CHANGED,
                                subKey: TUICore_PrivacyService_ROOM_STATE_EVENT_SUB_KEY_START,
                                object: nil,
                                param: nil)
        }
        initComponentView()
        karaokeManager.synchronizeMetadata(isOwner: isOwner)
#if !RTCube_APPSTORE
        handleRoomLayoutType()
#endif
    }

    func handleRoomLayoutType() {
        func setupKTVView(isOwner: Bool, isKTV: Bool) {
            ktvView = KtvView(
                karaokeManager: karaokeManager,
                isOwner: isOwner,
                isKTV: isKTV
            )

            guard let ktvView = ktvView else { return }
            addSubview(ktvView)

            if isKTV {
                seatGridView.snp.remakeConstraints { make in
                    make.top.equalTo(ktvView.snp.bottom).offset(20.scale375())
                    make.height.equalTo(230.scale375())
                    make.left.right.equalToSuperview()
                }

                ktvView.snp.remakeConstraints { make in
                    make.top.equalTo(topView.snp.bottom).offset(20.scale375())
                    make.height.equalTo(168.scale375())
                    make.left.equalToSuperview().offset(16.scale375())
                    make.right.equalToSuperview().offset(-16.scale375())
                }
            } else {
                seatGridView.snp.remakeConstraints { make in
                    make.top.equalTo(topView.snp.bottom).offset(40.scale375())
                    make.height.equalTo(230.scale375())
                    make.left.right.equalToSuperview()
                }

                ktvView.snp.remakeConstraints { make in
                    make.top.equalTo(seatGridView.snp.bottom).offset(20.scale375())
                    make.trailing.equalToSuperview().inset(20.scale375())
                    make.width.equalTo(160.scale375())
                    make.height.equalTo(137.scale375())
                }
            }
        }

        if isOwner {
            let isKTV = prepareStore.state.layoutType == .KTVRoom
            let layoutType = isKTV ? "KTVRoom" : "ChatRoom"
            let metadata = ["LayoutType": layoutType]

            TUIRoomEngine.sharedInstance().setRoomMetadataByAdmin(metadata, onSuccess: { [weak self] in
                guard let self = self else { return }
                setupKTVView(isOwner: true, isKTV: isKTV)
            }, onError: { error, message in
            })
        }
        else {
            TUIRoomEngine.sharedInstance().getRoomMetadata(["LayoutType"], onSuccess: { [weak self] response in
                guard let self = self else { return }
                guard let layoutType = response["LayoutType"] else {
                    return
                }
                setupKTVView(isOwner: false, isKTV: layoutType == "KTVRoom")
            }, onError: { error, message in
            })
        }
    }


    func onExit() {
        isExited = true
    }
    
    private func handleAbnormalExitedSence() {
        if isExited {
            liveListStore.endLive(completion: nil)
        }
    }
    
    func initComponentView() {
        initTopView()
    }
    
    func initTopView() {
        topView.initialize(roomId: liveID)
    }
}

// MARK: - Audience Route
extension VoiceRoomRootView {
    private func routeToAudienceView() {
        routerManager.router(action: .routeTo(.audience))
    }
    
    private func routeToAnchorView() {
        routerManager.router(action: .routeTo(.anchor))
    }
}

// MARK: - EndView

extension VoiceRoomRootView {
    
    func stopVoiceRoom() {
        liveListStore.endLive { [weak self] result in
            guard let self = self else { return }
            switch result {
            case .success(_):
                karaokeManager.exit()
                showAnchorEndView()
            case .failure(let error):
                let err = InternalError(errorInfo: error)
                handleErrorMessage(err.localizedMessage)
            }
        }
    }
    
    private func showAnchorEndView() {
        let summaryData = summaryStore.state.value.summaryData
        let liveDataModel = AnchorEndStatisticsViewInfo(roomId: liveID,
                                                        liveDuration: Int(summaryData.totalDuration / 1000),
                                                        viewCount: Int(summaryData.totalViewers),
                                                        messageCount: Int(summaryData.totalMessageSent),
                                                        giftTotalCoins: Int(summaryData.totalGiftCoins),
                                                        giftTotalUniqueSender: Int(summaryData.totalGiftUniqueSenders),
                                                        likeTotalUniqueSender: Int(summaryData.totalLikesReceived))
        delegate?.rootView(self, showEndView: ["data": liveDataModel], isAnchor: true)
    }
    
    private func showAudienceEndView() {
        if !isOwner {
            let info: [String: Any] = [
                "roomId": liveID,
                "avatarUrl": liveListStore.state.value.currentLive.liveOwner.avatarURL,
                "userName": selfInfo.nickname ?? ""
            ]
            delegate?.rootView(self, showEndView: info, isAnchor: false)
        }
    }
}

// MARK: - Private

extension VoiceRoomRootView {
    private func subscribeRoomState() {
        subscribeRoomBackgroundState()
        subscribeRoomOwnerState()
    }
    
    private func subscribeUserState() {
        subscribeUserIsOnSeatState()
        subscribeLinkStatus()
        subscribeAudienceState()
    }
}

// MARK: - SubscribeRoomState

extension VoiceRoomRootView {
    private func subscribeRoomBackgroundState() {
        liveListStore.state
            .subscribe(StatePublisherSelector(keyPath: \LiveListState.currentLive.backgroundURL))
            .filter { !$0.isEmpty }
            .receive(on: RunLoop.main)
            .sink(receiveValue: { [weak self] url in
                guard let self = self else { return }
                self.backgroundImageView.kf.setImage(with: URL(string: url), placeholder: UIImage.placeholderImage)
            })
            .store(in: &cancellableSet)
    }
    
    private func subscribeRoomOwnerState() {
        liveListStore.state
            .subscribe(StatePublisherSelector(keyPath: \LiveListState.currentLive.liveOwner.userID))
            .filter { !$0.isEmpty }
            .receive(on: RunLoop.main)
            .sink { [weak self] ownerId in
                guard let self = self else { return }
                self.barrageDisplayView.setOwnerId(ownerId)
            }
            .store(in: &cancellableSet)
    }
}

// MARK: - SubscribeUserState

extension VoiceRoomRootView {
    private func subscribeUserIsOnSeatState() {
        seatStore.state
            .subscribe(StatePublisherSelector(keyPath: \LiveSeatState.seatList))
            .removeDuplicates()
            .receive(on: RunLoop.main)
            .sink { [weak self] seatList in
                guard let self = self else { return }
                updateButton(seatList)
                updateLinkStatus(seatList)
            }
            .store(in: &cancellableSet)

        seatStore.liveSeatEventPublisher
            .receive(on: RunLoop.main)
            .sink { [weak self] event in
                guard let self = self else { return }
                switch event {
                    case .onLocalMicrophoneClosedByAdmin:
                        toastService.showToast( .mutedAudioText)
                    case .onLocalMicrophoneOpenedByAdmin(policy: _):
                        toastService.showToast(.unmutedAudioText)
                    default:
                        break
                }
            }
            .store(in: &cancellableSet)
    }
    
    private func updateButton(_ seatList: [SeatInfo]) {
        guard let seatInfo = seatList.first(where: { $0.userInfo.userID == selfInfo.userID }) else {
            muteMicrophoneButton.isHidden = true
            return
        }
        muteMicrophoneButton.isHidden = false
        muteMicrophoneButton.isSelected = seatInfo.userInfo.microphoneStatus == .off
    }
        
    private func updateLinkStatus(_ seatList: [SeatInfo]) {
        isLinked = seatList.contains(where: { $0.userInfo.userID == selfInfo.userID })
    }
    
    private func subscribeLinkStatus() {
        $isLinked
            .receive(on: RunLoop.main)
            .removeDuplicates()
            .sink { [weak self] isLinked in
                guard let self = self else { return }
                if isLinked {
                    muteMicrophone(mute: false)
                    startMicrophone()
                } else {
                    stopMicrophone()
                }
            }
            .store(in: &cancellableSet)
    }
    
    private func operateDevice(_ seatList: [SeatInfo]) {
        if seatList.contains(where: { $0.userInfo.userID == selfInfo.userID }) {
            muteMicrophone(mute: false)
            startMicrophone()
        } else {
            stopMicrophone()
        }
    }

    private func subscribeCoHostState() {
        coHostStore.coHostEventPublisher
            .receive(on: RunLoop.main)
            .sink { [weak self] event in
                guard let self = self else { return }
                switch event {
                    case .onCoHostRequestReceived(let inviter, let extensionInfo):
                        let titleText = extensionInfo == "needRequestBattle" ? String.battleInvitationText : String.connectionInviteText
                        let alertInfo = VRAlertInfo(description: String.localizedReplace(titleText, replace: inviter.userName),
                                                    imagePath: inviter.avatarURL,
                                                    cancelButtonInfo: (String.rejectText, .cancelTextColor),
                                                    defaultButtonInfo: (String.acceptText, .defaultTextColor)) { [weak self] alertPanel in
                            guard let self = self else { return }
                            coHostStore.rejectHostConnection(fromHostLiveID: inviter.liveID) { [weak self] result in
                                guard let self = self else { return }
                                switch result {
                                    case .success():
                                        break
                                    case .failure(let error):
                                        let err = InternalError(errorInfo: error)
                                        handleErrorMessage(err.localizedMessage)
                                }
                            }
                            routerManager.router(action: .dismiss(.alert, completion: nil))
                        } defaultClosure: { [weak self] alertPanel in
                            guard let self = self else { return }
                            coHostStore.acceptHostConnection(fromHostLiveID: inviter.liveID) { [weak self] result in
                                guard let self = self else { return }
                                switch result {
                                    case .success():
                                        if extensionInfo == "needRequestBattle" {
                                            var userIdList: [String] = [inviter.userID]
                                            requestBattle(userIdList: userIdList)
                                        }
                                        routerManager.router(action: .dismiss(.alert, completion: nil))
                                        break
                                    case .failure(let error):
                                        let err = InternalError(errorInfo: error)
                                        handleErrorMessage(err.localizedMessage)
                                }
                            }
                            routerManager.router(action: .dismiss(.alert, completion: nil))
                        } timeoutClosure: { [weak self] alertPanel in
                            guard let self = self else { return }
                            routerManager.router(action: .dismiss(.alert, completion: nil))
                        }
                        routerManager.router(action: .present(.alert(info: alertInfo,10)))
                    case .onCoHostRequestRejected(let invitee):
                        toastService.showToast(String.localizedReplace(.requestRejectedText, replace: invitee.userName.isEmpty ? invitee.userID : invitee.userName))
                    case .onCoHostRequestTimeout(let inviter,let invitee):
                        if inviter.userID == TUIRoomEngine.getSelfInfo().userId {
                            toastService.showToast(.requestTimeoutText)
                        }
                    case .onCoHostRequestCancelled(let inviter,let invitee):
                        if invitee?.userID == TUIRoomEngine.getSelfInfo().userId {
                            routerManager.router(action: .dismiss(.alert, completion: nil))
                            let message = String.localizedReplace(.coHostcanceledText, replace: inviter.userName)
                            toastService.showToast(message)
                        }
                    case .onCoHostRequestAccepted(let invitee):
                        routerManager.router(action: .dismiss(.alert, completion: nil))
                    default:
                        break
                }
            }
            .store(in: &cancellableSet)

#if !RTCube_APPSTORE
        coHostStore.state.subscribe(StatePublisherSelector(keyPath: \CoHostState.connected))
            .receive(on: RunLoop.main)
            .dropFirst()
            .sink { [weak self] connected in
                guard let self = self else { return }
                if connected.count > 0 {
                    ktvView?.removeFromSuperview()
                    ktvView = nil
                    seatGridView.snp.remakeConstraints { make in
                        make.top.equalTo(self.topView.snp.bottom).offset(40.scale375())
                        make.height.equalTo(230.scale375())
                        make.left.right.equalToSuperview()
                    }
                    karaokeManager.exit()
                } else {
                    if ktvView != nil { return }
                    ktvView = KtvView(karaokeManager: karaokeManager, isOwner: isOwner, isKTV: prepareStore.state.layoutType == .KTVRoom)
                    guard let ktvView = ktvView else { return }
                    addSubview(ktvView)
                    if prepareStore.state.layoutType == .KTVRoom {
                        seatGridView.snp.remakeConstraints { make in
                            make.top.equalTo(ktvView.snp.bottom).offset(20.scale375())
                            make.height.equalTo(230.scale375())
                            make.left.right.equalToSuperview()
                        }

                        ktvView.snp.remakeConstraints { make in
                            make.top.equalTo(self.topView.snp.bottom).offset(20.scale375())
                            make.height.equalTo(168.scale375())
                            make.left.equalToSuperview().offset(16.scale375())
                            make.right.equalToSuperview().offset(-16.scale375())
                        }
                    } else {
                        ktvView.snp.remakeConstraints { make in
                            make.top.equalTo(self.seatGridView.snp.bottom).offset(20.scale375())
                            make.trailing.equalToSuperview().inset(20.scale375())
                            make.width.equalTo(160.scale375())
                            make.height.equalTo(137.scale375())
                        }
                    }
                    karaokeManager.show()
                }
            }
            .store(in: &cancellableSet)
#endif
    }

    private func subscribeBattleState() {
        battleStore.battleEventPublisher
            .receive(on: RunLoop.main)
            .sink { [weak self] event in
                guard let self = self else { return }
                switch event {
                    case .onBattleRequestReceived( let battleID, let inviter, _):
                        let alertInfo = VRAlertInfo(description: .localizedReplace(.battleInvitationText, replace: inviter.userName),
                                                    imagePath: inviter.avatarURL,
                                                    cancelButtonInfo: (String.rejectText, .cancelTextColor),
                                                    defaultButtonInfo: (String.acceptText, .defaultTextColor)) { [weak self] alertPanel in
                            guard let self = self else { return }
                            battleStore.rejectBattle(battleID: battleID) { [weak self] result in
                                guard let self = self else { return }
                                switch result {
                                    case .success():
                                        break
                                    case .failure(let error):
                                        let err = InternalError(errorInfo: error)
                                        handleErrorMessage(err.localizedMessage)
                                }
                            }
                            routerManager.router(action: .dismiss(.alert, completion: nil))
                        } defaultClosure: { [weak self] alertPanel in
                            guard let self = self else { return }
                            battleStore.acceptBattle(battleID: battleID) { [weak self] result in
                                guard let self = self else { return }
                                switch result {
                                    case .success():
                                        break
                                    case .failure(let error):
                                        let err = InternalError(errorInfo: error)
                                        handleErrorMessage(err.localizedMessage)
                                }
                            }
                            routerManager.router(action: .dismiss(.alert, completion: nil))
                        } timeoutClosure: { [weak self] alertPanel in
                            guard let self = self else { return }
                            routerManager.router(action: .dismiss(.alert, completion: nil))
                        }
                        routerManager.router(action: .present(.alert(info: alertInfo,10)))
                    case .onBattleRequestReject(battleID: let battleID, let inviter, let invitee):
                        if inviter.userID == selfId {
                            let message = String.localizedReplace(.battleInvitationRejectText, replace: invitee.userName)
                            toastService.showToast(message)
                        }
                    case .onBattleRequestTimeout(let battleID, let inviter, let invitee):
                        if inviter.userID == selfId {
                            toastService.showToast(.battleInvitationTimeoutText)
                        }
                    case .onBattleRequestCancelled(let battleID, let inviter, let invitee):
                        if invitee.userID == selfId {
                            toastService.showToast(.localizedReplace(.battleInviterCancelledText, replace: "\(inviter.userName)"))
                            routerManager.router(action: .dismiss(.alert, completion: nil))
                        }
                    case .onBattleStarted(let battleInfo,let inviter,let invitees):
                        if inviter.userID == selfId {
                            routerManager.router(action: .dismiss(.alert, completion: nil))
                        }
                    default:
                        break
                }
            }.store(in: &cancellableSet)
    }
}

// MARK: - SubscribeAudienceState
extension VoiceRoomRootView {
    private func subscribeAudienceState() {
        audienceStore.liveAudienceEventPublisher
            .receive(on: RunLoop.main)
            .sink { [weak self] event in
                guard let self = self else { return }
                switch event {
                    case .onAudienceMessageDisabled(audience: let user, isDisable: let isDisable):
                        guard user.userID == selfInfo.userID else { break }
                        if isDisable {
                            toastService.showToast(.disableChatText)
                        } else {
                            toastService.showToast(.enableChatText)
                        }
                    default: break
                }
            }
            .store(in: &cancellableSet)
    }
}


// MARK: - TopViewDelegate

extension VoiceRoomRootView: VRTopViewDelegate {
    func topView(_ topView: VRTopView, tap event: VRTopView.TapEvent, sender: Any?) {
        switch event {
        case .stop:
            if isOwner {
                anchorStopButtonClick()
            } else {
                audienceLeaveButtonClick()
            }
        case .roomInfo:
            routerManager.router(action: .present(.roomInfo))
        case .audienceList:
            routerManager.router(action: .present(.recentViewer))
        }
    }
    
    private func anchorStopButtonClick() {
        var title: String = ""
        var items: [ActionItem] = []
        let lineConfig = ActionItemDesignConfig(lineWidth: 1, titleColor: .warningTextColor)
        lineConfig.backgroundColor = .bgOperateColor
        lineConfig.lineColor = .g3.withAlphaComponent(0.3)

        let selfUserId = TUIRoomEngine.getSelfInfo().userId
        let isSelfInCoHostConnection = coHostStore.state.value.coHostStatus == .connected
        let isSelfInBattle = battleStore.state.value.currentBattleInfo?.battleID != nil

        if isSelfInBattle {
            title = .endLiveOnBattleText
            let endBattleItem = ActionItem(title: .endLiveBattleText, designConfig: lineConfig, actionClosure: { [weak self] _ in
                guard let self = self ,let battleID = battleStore.state.value.currentBattleInfo?.battleID else { return }
                battleStore.exitBattle(battleID: battleID, completion: { [weak self] result in
                    guard let self = self else { return }
                    switch result {
                        case .success():
                            break
                        case .failure(let error):
                            let err = InternalError(errorInfo: error)
                            handleErrorMessage(err.localizedMessage)
                    }
                })
                self.routerManager.router(action: .dismiss())
            })
            items.append(endBattleItem)
        } else if isSelfInCoHostConnection {
            title = .endLiveOnConnectionText
            let endConnectionItem = ActionItem(title: .endLiveDisconnectText, designConfig: lineConfig, actionClosure: { [weak self] _ in
                guard let self = self else { return }
                coHostStore.exitHostConnection()
                self.routerManager.router(action: .dismiss())
            })
            items.append(endConnectionItem)
        } else {
            let alertInfo = VRAlertInfo(description: .confirmEndLiveText,
                                        imagePath: nil,
                                        cancelButtonInfo: (String.cancelText, .cancelTextColor),
                                        defaultButtonInfo: (String.confirmCloseText, .warningTextColor)) { alertPanel in
                self.routerManager.router(action: .dismiss(.alert))
            } defaultClosure: { [weak self] alertPanel in
                guard let self = self else { return }
                self.stopVoiceRoom()
                routerManager.router(action: .dismiss(.alert, completion: nil))
            }
            routerManager.router(action: .present(.alert(info: alertInfo)))
            return
        }

        let designConfig = ActionItemDesignConfig(lineWidth: 1, titleColor: .defaultTextColor)
        designConfig.backgroundColor = .bgOperateColor
        designConfig.lineColor = .g3.withAlphaComponent(0.3)
        let text: String = liveListStore.state.value.currentLive.keepOwnerOnSeat == false ? .confirmExitText : .confirmCloseText
        let endLiveItem = ActionItem(title: text, designConfig: designConfig, actionClosure: { [weak self] _ in
            guard let self = self else { return }
            battleStore.exitBattle(battleID: battleStore.state.value.currentBattleInfo?.battleID ?? "",completion: { [weak self] result in
                guard let self = self else { return }
                switch result {
                    case .success():
                        break
                    case .failure(let error):
                        break
                }
            })

            self.stopVoiceRoom()
            self.routerManager.router(action: .dismiss())
        })
        items.append(endLiveItem)
        routerManager.router(action: .present(.listMenu(ActionPanelData(title: title, items: items, cancelText: .cancelText, cancelColor: .bgOperateColor,
                                                                        cancelTitleColor: .defaultTextColor),.center)))
    }


    private func audienceLeaveButtonClick() {
        let selfUserId = TUIRoomEngine.getSelfInfo().userId
        if !seatStore.state.value.seatList.contains(where: { $0.userInfo.userID == selfUserId }) {
            leaveRoom()
            routerManager.router(action: .exit)
            return
        }
        var items: [ActionItem] = []
        let lineConfig = ActionItemDesignConfig(lineWidth: 1, titleColor: .warningTextColor)
        lineConfig.backgroundColor = .bgOperateColor
        lineConfig.lineColor = .g3.withAlphaComponent(0.3)

        let title: String = .exitLiveOnLinkMicText
        let endLinkMicItem = ActionItem(title: .exitLiveLinkMicDisconnectText, designConfig: lineConfig, actionClosure: { [weak self] _ in
            guard let self = self else { return }
            seatStore.leaveSeat { [weak self] result in
                guard let self = self else { return }
                if case .failure(let error) = result {
                    let err = InternalError(errorInfo: error)
                    handleErrorMessage(err.localizedMessage)
                }
            }

            routerManager.router(action: .dismiss())
        })
        items.append(endLinkMicItem)
        
        let designConfig = ActionItemDesignConfig(lineWidth: 1, titleColor: .defaultTextColor)
        designConfig.backgroundColor = .bgOperateColor
        designConfig.lineColor = .g3.withAlphaComponent(0.3)
        let endLiveItem = ActionItem(title: .confirmExitText, designConfig: designConfig, actionClosure: { [weak self] _ in
            guard let self = self else { return }
            leaveRoom()
            routerManager.router(action: .dismiss())
            routerManager.router(action: .exit)
        })
        items.append(endLiveItem)
        routerManager.router(action: .present(.listMenu(ActionPanelData(title: title, items: items, cancelText: .cancelText, cancelColor: .bgOperateColor,
                                                                        cancelTitleColor: .defaultTextColor),.center)))
    }
    
    private func leaveRoom() {
        liveListStore.leaveLive { [weak self] result in
            guard let self = self else { return }
            switch result {
            case .success():
                imStore.resetState()
            case .failure(let error):
                let err = InternalError(errorInfo: error)
                handleErrorMessage(err.localizedMessage)
            }
        }
    }

    private func requestBattle(userIdList: [String]) {
        let config = BattleConfig(duration: 30, needResponse: false, extensionInfo: "")
        battleStore.requestBattle(config: config, userIDList: userIdList, timeout: 0) { [weak self] result in
            guard let self else { return }
            switch result {
                case .success:
                    routerManager.router(action: .dismiss(.alert, completion: nil))
                    break
                case .failure(let error):
                    let err = InternalError(errorInfo: error)
                    handleErrorMessage(err.localizedMessage)
            }
        }
    }
}

extension VoiceRoomRootView {
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

// MARK: - SeatGridViewObserver
extension VoiceRoomRootView {
    private func setupliveEventListener() {
        liveListStore.liveListEventPublisher
            .receive(on: RunLoop.main)
            .sink { [weak self] event in
                guard let self = self else { return }
                
                switch event {
                case .onLiveEnded(liveID: let liveID, reason: _, message: _):
                    guard self.liveID == liveID else { return }
                    onRoomDismissed(roomId: liveID)
                case  .onKickedOutOfLive(liveID: let liveID, reason: let reason, message: let message):
                    onKickedOutOfRoom(roomId: liveID, reason: reason, message: message)
                }
            }
            .store(in: &cancellableSet)
    }
    
    private func onKickedOutOfRoom(roomId: String, reason: LiveKickedOutReason, message: String) {
        guard reason != .byLoggedOnOtherDevice else { return }
        isOwner ? routeToAnchorView() : routeToAudienceView()
        handleErrorMessage(.kickedOutText)
        DispatchQueue.main.asyncAfter(deadline: .now() + 1) { [weak self] in
            guard let self = self else { return }
            routerManager.router(action: .exit)
        }
    }
    
    private func onRoomDismissed(roomId: String) {
        if isOwner {
            routeToAnchorView()
            showAnchorEndView()
        } else {
            routeToAudienceView()
            showAudienceEndView()
        }
    }
    
    private func setupGuestEventListener() {
        coGuestStore.guestEventPublisher
            .receive(on: RunLoop.main)
             .sink { [weak self] event in
                 guard let self = self else { return }
                 
                 switch event {
                 case .onHostInvitationReceived(hostUser: let hostUser):
                     onSeatRequestReceived(type: .inviteToTakeSeat, userInfo: hostUser)
                 case .onHostInvitationCancelled(hostUser: let hostUser):
                     onSeatRequestCancelled(type: .inviteToTakeSeat, userInfo: hostUser)
                 case .onGuestApplicationResponded(isAccept: let isAccept, hostUser: _):
                     if !isAccept {
                         toastService.showToast(.takeSeatApplicationRejected)
                     }
                 case .onGuestApplicationNoResponse(reason: let reason):
                     if reason == .timeout {
                         toastService.showToast(.takeSeatApplicationTimeout)
                     }
                 case .onKickedOffSeat(seatIndex: let seatIndex, hostUser: let handleUser):
                     onKickedOffSeat(seatIndex: seatIndex, userInfo: handleUser)
                 }
             }
             .store(in: &cancellableSet)
     }
    
    func onSeatRequestReceived(type: SGRequestType, userInfo: LiveUserInfo) {
        guard type == .inviteToTakeSeat else { return }

        let liveOwner = liveListStore.state.value.currentLive.liveOwner
        guard !userInfo.userID.isEmpty else { return }
        guard !liveOwner.userID.isEmpty else { return }
        let alertInfo = VRAlertInfo(description: String.localizedReplace(.inviteLinkText, replace: "\(liveOwner.userName)"),
                                    imagePath: liveOwner.avatarURL,
                                    cancelButtonInfo: (String.rejectText, .cancelTextColor),
                                    defaultButtonInfo: (String.acceptText, .defaultTextColor)) { [weak self] _ in
            guard let self = self else { return }
            coGuestStore.rejectInvitation(inviterID: userInfo.userID) { [weak self] result in
                guard let self = self else { return }
                switch result {
                case .success(()):
                    self.routerManager.router(action: .dismiss(.alert))
                case .failure(let error):
                    self.routerManager.router(action: .dismiss(.alert))
                    let err = InternalError(errorInfo: error)
                    handleErrorMessage(err.localizedMessage)
                }
            }
        } defaultClosure: { [weak self] _ in
            guard let self = self else { return }
            coGuestStore.acceptInvitation(inviterID: userInfo.userID) { [weak self] result in
                guard let self = self else { return }
                switch result {
                case .success(()):
                    self.routerManager.router(action: .dismiss(.alert))
                case .failure(let error):
                    self.routerManager.router(action: .dismiss(.alert))
                    let err = InternalError(errorInfo: error)
                    handleErrorMessage(err.localizedMessage)
                }
            }
        } timeoutClosure: { [weak self] alertPanel in
            guard let self = self else { return }
            routerManager.router(action: .dismiss(.alert, completion: nil))
        }
        routerManager.router(action: .present(.alert(info: alertInfo,10)))
    }
    
    func onSeatRequestCancelled(type: SGRequestType, userInfo: LiveUserInfo) {
        guard type == .inviteToTakeSeat else { return }
        routerManager.router(action: .dismiss(.alert))
    }
    
    private func onKickedOffSeat(seatIndex: Int, userInfo: LiveUserInfo) {
        if !coHostStore.state.value.connected.isEmpty && seatIndex > KSGConnectMaxSeatCount{
            handleErrorMessage(.onKickOutByConnectText)
        } else {
            handleErrorMessage(.onKickedOutOfSeatText)
        }
    }
}

extension VoiceRoomRootView: SeatGridViewObserver {
    func onSeatViewClicked(seatView: UIView, seatInfo: TUISeatInfo) {
        let menus = generateOperateSeatMenuData(seat: seatInfo)
        if menus.isEmpty {
            return
        }
        let data = ActionPanelData(items: menus, cancelText: .cancelText)
        routerManager.router(action: .present(.listMenu(data)))
    }
}

// MARK: - Invite/Lock seat
extension VoiceRoomRootView {
    private func generateOperateSeatMenuData(seat: TUISeatInfo) -> [ActionItem] {
        if isOwner {
            return generateRoomOwnerOperateSeatMenuData(seat: seat)
        } else {
            return generateNormalUserOperateSeatMenuData(seat: seat)
        }
    }
    
    private func generateRoomOwnerOperateSeatMenuData(seat: TUISeatInfo) -> [ActionItem] {
        var menus: [ActionItem] = []
        if (seat.userId ?? "").isEmpty {
            if !seat.isLocked {
                let inviteTakeSeat = ActionItem(title: String.inviteText, designConfig: designConfig())
                inviteTakeSeat.actionClosure = { [weak self] _ in
                    guard let self = self else { return }
                    routerManager.router(action: .dismiss(.panel, completion: { [weak self] in
                        guard let self = self else { return }
                        routerManager.router(action: .present(.linkInviteControl(seat.index)))
                    }))
                }
                menus.append(inviteTakeSeat)
            }
            
            let lockSeatItem = ActionItem(title: seat.isLocked ? String.unLockSeat : String.lockSeat, designConfig: designConfig())
            lockSeatItem.actionClosure = { [weak self] _ in
                guard let self = self else { return }
                lockSeat(seat: seat)
                routerManager.router(action: .dismiss())
            }
            menus.append(lockSeatItem)
            return menus
        }
        
        let isSelf = seat.userId == selfInfo.userID
        if !isSelf {
            routerManager.router(action: .present(.userControl(imStore, seat)))
        }
        return menus
    }
    
    private func generateNormalUserOperateSeatMenuData(seat: TUISeatInfo) -> [ActionItem] {
        var menus: [ActionItem] = []
        let isOnSeat = seatStore.state.value.seatList.contains { $0.userInfo.userID == selfInfo.userID}
        if (seat.userId ?? "").isEmpty && !seat.isLocked {
            let takeSeatItem = ActionItem(title: .takeSeat, designConfig: designConfig())
            takeSeatItem.actionClosure = { [weak self] _ in
                guard let self = self else { return }
                if isOnSeat {
                    moveToSeat(index: seat.index)
                } else {
                    takeSeat(index: seat.index)
                }
                routerManager.router(action: .dismiss())
            }
            menus.append(takeSeatItem)
            return menus
        }
        
        if !(seat.userId ?? "").isEmpty && seat.userId != selfInfo.userID {
            routerManager.router(action: .present(.userControl(imStore, seat)))
        }
        return menus
    }
    
    private func designConfig() -> ActionItemDesignConfig {
        let designConfig = ActionItemDesignConfig(lineWidth: 1, titleColor: .g2)
        designConfig.backgroundColor = .white
        designConfig.lineColor = .g8
        return designConfig
    }
    
    private func lockSeat(seat: TUISeatInfo) {
        let lockSeat = TUISeatLockParams()
        lockSeat.lockAudio = seat.isAudioLocked
        lockSeat.lockVideo = seat.isVideoLocked
        lockSeat.lockSeat = !seat.isLocked
        
        // 暂时使用roomengine实现
        TUIRoomEngine.sharedInstance().lockSeatByAdmin(seat.index, lockMode: lockSeat) {
        } onError: { [weak self] error, message in
            guard let self = self else { return }
            let err = InternalError(code: error.rawValue, message: message)
            handleErrorMessage(err.localizedMessage)
        }
    }
    
    private func takeSeat(index: Int) {
        if viewStore.state.isApplyingToTakeSeat {
            toastService.showToast(.repeatRequest)
            return
        }
        viewStore.onSentTakeSeatRequest()
        coGuestStore.applyForSeat(seatIndex: index, timeout: kSGDefaultTimeout, extraInfo: nil) { [weak self] result in
            guard let self = self else { return }
            viewStore.onRespondedTakeSeatRequest()
            if case .failure(let error) = result {
                let err = InternalError(errorInfo: error)
                handleErrorMessage(err.localizedMessage)
            }
        }
    }
    
    private func moveToSeat(index: Int) {
        let selfId = selfInfo.userID
        seatStore.moveUserToSeat(userID: selfId, targetIndex: index, policy: .abortWhenOccupied) { [weak self] result in
            guard let self = self else { return }
            if case .failure(let error) = result {
                let err = InternalError(errorInfo: error)
                handleErrorMessage(err.localizedMessage)
            }
        }
    }
    
    private func handleErrorMessage(_ message: String) {
        toastService.showToast(message)
    }
}


// MARK: - BarrageStreamViewDelegate

extension VoiceRoomRootView: BarrageStreamViewDelegate {
    func barrageDisplayView(_ barrageDisplayView: BarrageStreamView, createCustomCell barrage: Barrage) -> UIView? {
        guard let type = barrage.extensionInfo?["TYPE"], type == "GIFTMESSAGE" else {
            return nil
        }
        return GiftBarrageCell(barrage: barrage)
    }
    
    func onBarrageClicked(user: LiveUserInfo) {
    }
}

// MARK: - GiftPlayViewDelegate

extension VoiceRoomRootView: GiftPlayViewDelegate {
    func giftPlayView(_ giftPlayView: GiftPlayView, onReceiveGift gift: Gift, giftCount: Int, sender: LiveUserInfo) {
        let receiver = TUIUserInfo()
        let liveOwner = liveListStore.state.value.currentLive.liveOwner
        receiver.userId = liveOwner.userID
        receiver.userName = liveOwner.userName
        receiver.avatarUrl = liveOwner.avatarURL
        if receiver.userId == selfInfo.userID {
            receiver.userName = .meText
        }
        
        var barrage = Barrage()
        barrage.textContent = "gift"
        barrage.sender = sender
        barrage.extensionInfo = [
            "TYPE": "GIFTMESSAGE",
            "gift_name": gift.name,
            "gift_count": "\(giftCount)",
            "gift_icon_url": gift.iconURL,
            "gift_receiver_username": receiver.userName
        ]
        barrageStore.appendLocalTip(message: barrage)
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

extension VoiceRoomRootView: TUIRoomObserver {
    func onError(error errorCode: TUIError, message: String) {
        if errorCode == .success {
            return
        }
        if errorCode == .audioCaptureDeviceUnavailable {
            return
        }
        let error = InternalError(code: errorCode.rawValue, message: message)
        handleErrorMessage(error.localizedMessage)
    }
}

extension VoiceRoomRootView: SGHostAndBattleViewDelegate {
    func onClickCoHostView(seatInfo: SeatInfo,type: VRCoHostUserManagerPanelType) {
        routerManager.router(action: .present(.coHostUserControl(seatInfo,type)))
    }

    func createCoHostView(seatInfo: SeatInfo, isInvite: Bool) -> UIView? {

        let isOwner = TUIRoomEngine.getSelfInfo().userId == liveListStore.state.value.currentLive.liveOwner.userID
        let isSelfOnSeat = seatInfo.userInfo.userID == TUIRoomEngine.getSelfInfo().userId

        if seatInfo.userInfo.userID == "" && isInvite{
            let view = VRCoHostInviteView(seatInfo: seatInfo)
            view.didTap = { [weak self] in
                guard let self = self else {return}
                if isOwner {
                    self.onClickCoHostView(seatInfo: seatInfo,type: .inviteAndLockSeat)
                } else if !seatInfo.isLocked{
                    let menu = generateNormalUserOperateSeatMenuData(seat: TUISeatInfo(from: seatInfo))
                    let data = ActionPanelData(items: menu, cancelText: .cancelText)
                    routerManager.router(action: .present(.listMenu(data)))
                }
            }
            return view
        } else if seatInfo.userInfo.userID == ""{
            let view = VRCoHostEmptyView(seatInfo: seatInfo)
            return view
        } else {
            let view = VRCoHostView(seatInfo: seatInfo, routerManager: routerManager)
            view.didTap = { [weak self] in
                guard let self = self else {return}
                if isOwner && seatInfo.userInfo.liveID == liveID{
                    self.onClickCoHostView(
                        seatInfo: seatInfo,
                        type: .muteAndKick
                    )
                } else if isSelfOnSeat {
                    self.onClickCoHostView(seatInfo: seatInfo,type: .mute)
                } else {
                    self.onClickCoHostView(seatInfo: seatInfo,type: .userInfo)
                }
            }
            return view
        }
    }

    func createBattleContainerView() -> UIView? {
        let battleView = VRBattleInfoView(liveID: liveID, routerManager: routerManager)
        battleView.isUserInteractionEnabled = false
        return battleView
    }
}

// MARK: - String
fileprivate extension String {
    static let meText = internalLocalized("Me")
    static let confirmCloseText = internalLocalized("End Live")
    static let confirmEndLiveText = internalLocalized("Are you sure you want to End Live?")
    static let confirmExitText = internalLocalized("Exit Live")
    static let confirmExitLiveText = internalLocalized("Are you sure you want to Exit Live?")
    static let rejectText = internalLocalized("Reject")
    static let agreeText = internalLocalized("Agree")
    static let inviteLinkText = internalLocalized("xxx invites you to take seat")
    static let enterRoomFailedText = internalLocalized("Failed to enter room")
    static let inviteText = internalLocalized("Invite")
    static let lockSeat = internalLocalized("Lock Seat")
    static let takeSeat = internalLocalized("Take Seat")
    static let unLockSeat = internalLocalized("Unlock Seat")
    static let operationSuccessful = internalLocalized("Operation Successful")
    static let takeSeatApplicationRejected = internalLocalized("Take seat application has been rejected")
    static let takeSeatApplicationTimeout = internalLocalized("Take seat application timeout")
    static let repeatRequest = internalLocalized("Already on the seat queue")
    static let onKickedOutOfSeatText = internalLocalized("Kicked out of seat by room owner")
    static let exitLiveOnLinkMicText = internalLocalized("You are currently co-guesting with other streamers. Would you like to [End Co-guest] or [Exit Live] ?")
    static let exitLiveLinkMicDisconnectText = internalLocalized("End Co-guest")
    static let kickedOutText = internalLocalized("You have been kicked out of the room")
    static let cancelText = internalLocalized("Cancel")
    static let comingText: String = internalLocalized("Entered room")
    static let connectionInviteText = internalLocalized("xxx invite you to host together")
    static let acceptText = internalLocalized("Accept")
    static let battleInvitationText = internalLocalized("xxx invite you to battle together")
    static let coHostcanceledText = internalLocalized("xxx canceled request")

    static let endLiveOnConnectionText = internalLocalized("You are currently co-hosting with other streamers. Would you like to [End Co-host] or [End Live] ?")
    static let endLiveDisconnectText = internalLocalized("End Co-host")
    static let endLiveOnLinkMicText = internalLocalized("You are currently co-guesting with other streamers. Would you like to [End Live] ?")
    static let endLiveOnBattleText = internalLocalized("You are currently in PK mode. Would you like to [End PK] or [End Live] ?")
    static let endLiveBattleText = internalLocalized("End PK")
    static let roomDismissText = internalLocalized("Broadcast has been ended")

    static let battleInviterCancelledText = internalLocalized("xxx canceled battle, please try to initiate it again")
    static let battleInvitationRejectText = internalLocalized("xxx rejected battle")
    static let battleInvitationTimeoutText = internalLocalized("Battle request has been timeout")

    static let requestRejectedText = internalLocalized("xxx rejected")
    static let requestTimeoutText = internalLocalized("Invitation has timed out")
    static let tooManyGuestText = internalLocalized("Please note that 6V6 PK only shows the first 6 seats and please limit the number of seats to 6 or fewer")

    static let disableChatText = internalLocalized("Disable Chat")
    static let enableChatText = internalLocalized("Enable Chat")
    static let onKickOutByConnectText = internalLocalized("The connection only displays the first 6 seats. You have been removed.")
    static let mutedAudioText = internalLocalized("The anchor has muted you")
    static let unmutedAudioText = internalLocalized("The anchor has unmuted you")
}
