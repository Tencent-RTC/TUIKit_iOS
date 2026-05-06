//
//  TUILiveRoomAnchorViewController.swift
//  TUILiveKit
//
//  Created by WesleyLei on 2023/10/11.
//  Copyright © 2023 Tencent. All rights reserved.
//

import Foundation
import TUICore
import RTCRoomEngine
import Combine
import AtomicXCore
import AtomicX

@objcMembers
public class TUILiveRoomAnchorViewController: UIViewController {
    
    // MARK: - private property.
    private var cancellableSet = Set<AnyCancellable>()
    private let coreView: LiveCoreView

    private let liveInfo: LiveInfo
    private let behavior: RoomBehavior
    
    private let anchorView: AnchorView
    
    public init(liveInfo: LiveInfo, coreView: LiveCoreView? = nil, behavior: RoomBehavior = .createRoom) {
        self.liveInfo = liveInfo
        self.behavior = behavior
        if let coreView = coreView {
            self.coreView = coreView
        } else {
            KeyMetrics.setComponent(Constants.ComponentType.liveRoom.rawValue)
            self.coreView = LiveCoreView(viewType: .pushView)
        }
        self.anchorView = AnchorView(liveInfo: liveInfo, coreView: self.coreView, behavior: behavior)
        super.init(nibName: nil, bundle: nil)
        initialize()
    }
    
    public init(liveParams: LiveParams, coreView: LiveCoreView? = nil, behavior: RoomBehavior = .createRoom) {
        self.liveInfo = liveParams.liveInfo
        self.behavior = behavior
        if let coreView = coreView {
            self.coreView = coreView
        } else {
            KeyMetrics.setComponent(Constants.ComponentType.liveRoom.rawValue)
            self.coreView = LiveCoreView(viewType: .pushView)
        }
        self.anchorView = AnchorView(liveParams: liveParams, coreView: self.coreView, behavior: behavior)
        super.init(nibName: nil, bundle: nil)
        initialize()
    }
    
    private func initialize() {
        if FloatWindow.shared.isShowingFloatWindow() {
            FloatWindow.shared.releaseFloatWindow()
        }
        
        anchorView.delegate = self
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    deinit {
        AudioEffectStore.shared.reset()
        DeviceStore.shared.reset()
        BaseBeautyStore.shared.reset()
        LiveKitLog.info("\(#file)", "\(#line)", "deinit TUILiveRoomAnchorViewController \(self)")
#if DEV_MODE
        TestTool.shared.unregisterCaseFrom(self)
#endif
    }
    
    public func stopLive(onSuccess: TUISuccessBlock?, onError: TUIErrorBlock?) {
        LiveListStore.shared.endLive { result in
            switch result {
            case .success(_):
                onSuccess?()
            case .failure(let err):
                onError?(TUIError(rawValue: err.code) ?? .failed, err.message)
            }
        }
    }

    public override func viewDidLoad() {
        super.viewDidLoad()
        navigationController?.setNavigationBarHidden(true, animated: true)
    }
    
    public override func loadView() {
        view = anchorView
    }

    public override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        super.touchesBegan(touches, with: event)
        view.endEditing(true)
    }

    public override func viewWillTransition(to size: CGSize, with coordinator: UIViewControllerTransitionCoordinator) {
        super.viewWillTransition(to: size, with: coordinator)
        let isPortrait = size.width < size.height
        anchorView.updateRootViewOrientation(isPortrait: isPortrait)
    }

    public override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        UIApplication.shared.isIdleTimerDisabled = true
        navigationController?.setNavigationBarHidden(true, animated: true)
    }

    public override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        UIApplication.shared.isIdleTimerDisabled = false
        navigationController?.setNavigationBarHidden(false, animated: true)
    }
    
    public override var shouldAutorotate: Bool {
        return false
    }
    
    public override var supportedInterfaceOrientations: UIInterfaceOrientationMask {
        return .portrait
    }
}

extension TUILiveRoomAnchorViewController: AnchorViewDelegate {
    public func onClickFloatWindow() {
        FloatWindow.shared.showFloatWindow(controller: self, provider: self)
    }
    
    public func onStartLiving() {}
    
    public func onEndLiving(state: AnchorState) {
        let liveDataModel = AnchorEndStatisticsViewInfo(roomId: liveInfo.liveID,
                                                        liveDuration: state.totalDuration,
                                                        viewCount: state.totalViewers,
                                                        messageCount: state.totalMessageSent,
                                                        giftTotalCoins: state.totalGiftCoins,
                                                        giftTotalUniqueSender: state.totalGiftUniqueSenders,
                                                        likeTotalUniqueSender: state.totalLikesReceived,
                                                        liveEndedReason: state.liveEndedReason)
        let anchorEndView = AnchorEndStatisticsView(endViewInfo: liveDataModel)
        anchorEndView.delegate = self
        view.addSubview(anchorEndView)
        anchorEndView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }
    }
}

extension TUILiveRoomAnchorViewController: FloatWindowProvider {
    public func getRoomId() -> String {
        liveInfo.liveID
    }
    
    public func getOwnerId() -> String {
        LiveListStore.shared.state.value.currentLive.liveOwner.userID
    }
    
    public func getCoreView() -> AtomicXCore.LiveCoreView {
        coreView
    }
    
    public func relayoutCoreView() {
        anchorView.relayoutCoreView()
    }
    
    public func getIsLinking() -> Bool {
        CoGuestStore.create(liveID: liveInfo.liveID).state.value.connected.isOnSeat()
    }
}

extension TUILiveRoomAnchorViewController: AnchorEndStatisticsViewDelegate {
    public func onCloseButtonClick() {
        if let nav = navigationController {
            nav.popViewController(animated: true)
        } else {
            dismiss(animated: true)
        }
    }
}
