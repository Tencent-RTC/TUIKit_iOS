//
//  AudienceSliderCell.swift
//  TUILiveKit
//
//  Created by jeremiawang on 2024/12/30.
//

import AtomicXCore
import AtomicX
import Combine
import RTCCommon
import TUICore

protocol AudienceListCellDelegate: AnyObject {
    func handleScrollToNewRoom(roomId: String, ownerId: String, manager: AudienceStore, coreView: LiveCoreView, relayoutCoreViewClosure: @escaping () -> Void)
    func showFloatWindow()
    func showAtomicToast(message: String, toastStyle: ToastStyle)
    func disableScrolling()
    func enableScrolling()
    func scrollToNextPage()
    func onRoomDismissed(roomId: String, avatarUrl: String, userName: String)
}

class AudienceSliderCell: UIView {
    weak var delegate: AudienceListCellDelegate?
    weak var rotateScreenDelegate: RotateScreenDelegate?

    private let liveID: String
    private var isViewReady = false
    private var isCurrentShowCell = false
    private weak var routerCenter: AudienceRouterControlCenter?
    
    private lazy var coreView: LiveCoreView = {
        func setComponent() {
            do {
                let jsonObject: [String: Any] = [
                    "api": "component",
                    "component": 21
                ]
                let jsonData = try JSONSerialization.data(withJSONObject: jsonObject, options: [])
                if let jsonString = String(data: jsonData, encoding: .utf8) {
                    LiveCoreView.callExperimentalAPI(jsonString)
                }
            } catch {
                LiveKitLog.error("\(#file)", "\(#line)", "dataReport: \(error.localizedDescription)")
            }
        }
        setComponent()
        let view = LiveCoreView(viewType: .playView)
        view.setLiveID(liveID)
        return view
    }()

    private lazy var manager = AudienceStore(liveID: liveID)
    private let routerManager: AudienceRouterManager
    private var cancellableSet = Set<AnyCancellable>()
    private var isStartedPreload = false
    private var currentLiveOwner: LiveUserInfo?
    
    init(liveInfo: LiveInfo, routerManager: AudienceRouterManager, routerCenter: AudienceRouterControlCenter) {
        self.liveID = liveInfo.liveID
        self.routerManager = routerManager
        self.routerCenter = routerCenter
        self.currentLiveOwner = liveInfo.liveOwner
        super.init(frame: .zero)
        // TODO: gg check this
//        manager.onAudienceSliderCellInit(liveInfo: liveInfo)
        debugPrint("init:\(self)")
    }
    
    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    private lazy var audienceView: AudienceView = {
        let view = AudienceView(roomId: liveID, manager: manager, routerManager: routerManager, coreView: coreView)
        view.rotateScreenDelegate = self
        return view
    }()
    
    override func didMoveToWindow() {
        super.didMoveToWindow()
        guard !isViewReady else { return }
        constructViewHierarchy()
        activateConstraints()
        subscribeSubjects()
        subscribeState()
        subscribeRoomState()
        isViewReady = true
    }
    
    func onViewWillSlideIn() {
        LiveKitLog.info("\(#file)", "\(#line)", "onViewWillSlideIn roomId: \(liveID)")
        audienceView.livingView.isHidden = true
        coreView.startPreviewLiveStream(roomId: liveID, isMuteAudio: true)
        isStartedPreload = true
    }

    func onViewDidSlideIn() {
        LiveKitLog.info("\(#file)", "\(#line)", "onViewDidSlideIn roomId: \(liveID)")
        enterRoom()
        isCurrentShowCell = true
    }
    
    func onViewSlideInCancelled() {
        LiveKitLog.info("\(#file)", "\(#line)", "onViewSlideInCancelled roomId: \(liveID)")
        coreView.stopPreviewLiveStream(roomId: liveID)
    }
    
    func onViewWillSlideOut() {
        LiveKitLog.info("\(#file)", "\(#line)", "onViewWillSlideOut roomId: \(liveID)")
    }
    
    func onViewDidSlideOut() {
        LiveKitLog.info("\(#file)", "\(#line)", "onViewDidSlideOut roomId: \(liveID)")
        if !FloatWindow.shared.isShowingFloatWindow() {
            coreView.stopPreviewLiveStream(roomId: liveID)
            if isCurrentShowCell {
                manager.liveListStore.leaveLive(completion: nil)
                TUICore.notifyEvent(TUICore_PrivacyService_ROOM_STATE_EVENT_CHANGED,
                                    subKey: TUICore_PrivacyService_ROOM_STATE_EVENT_SUB_KEY_END,
                                    object: nil,
                                    param: nil)
            }
            isStartedPreload = false
        }
        isCurrentShowCell = false
    }
    
    func onViewSlideOutCancelled() {
        LiveKitLog.info("\(#file)", "\(#line)", "onViewSlideOutCancelled roomId: \(liveID)")
    }
    
    func enterRoom() {
        delegate?.handleScrollToNewRoom(roomId: liveID, ownerId: manager.liveListState.currentLive.liveOwner.userID,
                                        manager: manager, coreView: coreView)
        { [weak self] in
            guard let self = self else { return }
            audienceView.relayoutCoreView()
        }
        delegate?.disableScrolling()
        audienceView.joinLiveStream { [weak self] result in
            guard let self = self else { return }
            if case .success = result {
                delegate?.enableScrolling()
                currentLiveOwner = manager.liveListState.currentLive.liveOwner
            }
        }
    }
    
    deinit {
        debugPrint("deinit:\(self)")
        if isStartedPreload {
            coreView.stopPreviewLiveStream(roomId: liveID)
        }
    }
}

// MARK: - private func

extension AudienceSliderCell {
    private func constructViewHierarchy() {
        addSubview(audienceView)
    }
    
    private func activateConstraints() {
        audienceView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }
    }
    
    private func subscribeSubjects() {
        manager.toastSubject
            .receive(on: RunLoop.main)
            .sink { [weak self] message,style in
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
    
    private func subscribeState() {
        manager.subscribeState(StatePublisherSelector(keyPath: \CoGuestState.connected))
            .removeDuplicates()
            .combineLatest(manager.subscribeState(StateSelector(keyPath: \AudienceState.isApplying)).removeDuplicates())
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
        
        manager.liveListStore.liveListEventPublisher
            .receive(on: RunLoop.main)
            .sink { [weak self] event in
                guard let self = self else { return }
                switch event {
                    case .onLiveEnded(liveID: let liveID, reason: _, message: _):
                        guard liveID == manager.liveID else { return }
                        delegate?.onRoomDismissed(roomId: liveID,
                                                  avatarUrl: currentLiveOwner?.avatarURL ?? "",
                                                  userName: currentLiveOwner?.userName ?? "")
                    default: break
                }
            }
            .store(in: &cancellableSet)
    }
    
    private func subscribeRoomState() {
        manager.subscribeState(StateSelector(keyPath: \AudienceState.roomVideoStreamIsLandscape))
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
}

extension AudienceSliderCell: RotateScreenDelegate {
    func rotateScreen(isPortrait: Bool) {
        rotateScreenDelegate?.rotateScreen(isPortrait: isPortrait)
    }
}
