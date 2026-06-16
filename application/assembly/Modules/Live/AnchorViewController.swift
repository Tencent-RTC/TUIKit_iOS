//
//  AnchorViewController.swift
//  TUILiveKit
//
//  Created by WesleyLei on 2023/10/11.
//  Copyright © 2023 Tencent. All rights reserved.
//

import AtomicX
import AtomicXCore
import Combine
import Foundation
import Login
import TUICore
import TUILiveKit

class AnchorViewController: UIViewController {
    // MARK: - private property.

    private var cancellableSet = Set<AnyCancellable>()
    private let coreView: LiveCoreView

    private let liveInfo: LiveInfo
    private let behavior: RoomBehavior

    private let anchorView: AnchorView

    /// 9分钟定时器（开播后第9分钟提示剩余1分钟）
    private var remainingTimer: Timer?
    /// 10分钟定时器（开播后第10分钟自动解散房间）
    private var timeOutTimer: Timer?

    init(liveInfo: LiveInfo, coreView: LiveCoreView? = nil, behavior: RoomBehavior = .createRoom) {
        self.liveInfo = liveInfo
        self.behavior = behavior
        if let coreView = coreView {
            self.coreView = coreView
        } else {
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
            self.coreView = LiveCoreView(viewType: .pushView)
        }
        self.anchorView = AnchorView(liveInfo: liveInfo, coreView: self.coreView, behavior: behavior)
        super.init(nibName: nil, bundle: nil)
        initialize()
    }

    init(liveParams: LiveParams, coreView: LiveCoreView? = nil, behavior: RoomBehavior = .createRoom) {
        self.liveInfo = liveParams.liveInfo
        self.behavior = behavior
        if let coreView = coreView {
            self.coreView = coreView
        } else {
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

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    deinit {
        remainingTimer?.invalidate()
        remainingTimer = nil
        timeOutTimer?.invalidate()
        timeOutTimer = nil
        // 房间结束时重置高风险 IP 弹窗标记，确保下次进入新房间可再次弹窗
        RoomRiskIPObserver.shared.resetForNewRoom()
        AudioEffectStore.shared.reset()
        DeviceStore.shared.reset()
        BaseBeautyStore.shared.reset()
        LiveKitLog.info("\(#file)", "\(#line)", "deinit AnchorViewController \(self)")
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        navigationController?.setNavigationBarHidden(true, animated: true)
    }

    override func loadView() {
        view = anchorView
    }

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        super.touchesBegan(touches, with: event)
        view.endEditing(true)
    }

    override func viewWillTransition(to size: CGSize, with coordinator: UIViewControllerTransitionCoordinator) {
        super.viewWillTransition(to: size, with: coordinator)
        let isPortrait = size.width < size.height
        anchorView.updateRootViewOrientation(isPortrait: isPortrait)
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        UIApplication.shared.isIdleTimerDisabled = true
        navigationController?.setNavigationBarHidden(true, animated: true)
        ThemeStore.shared.setMode(.dark)
    }

    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        UIApplication.shared.isIdleTimerDisabled = false
        navigationController?.setNavigationBarHidden(false, animated: true)
    }

    override var shouldAutorotate: Bool {
        return false
    }

    override var supportedInterfaceOrientations: UIInterfaceOrientationMask {
        return .portrait
    }

    // MARK: - 体验时长定时器

    /// 开播后启动9分钟定时器，到期后通过 privacyActionHandler 弹出"剩余1分钟"Toast
    private static let kNineMinuteDuration: TimeInterval = 9 * 60
    /// 开播后启动10分钟定时器，到期后自动解散房间并弹出超时提示
    private static let kTenMinuteDuration: TimeInterval = 10 * 60

    private func startRemainingTimer() {
        remainingTimer?.invalidate()
        remainingTimer = Timer.scheduledTimer(withTimeInterval: Self.kNineMinuteDuration, repeats: false) { [weak self] _ in
            guard self != nil else { return }
            DispatchQueue.main.async {
                AppAssembly.shared.privacyActionHandler?(.showLiveRemainingOneMinToast)
            }
        }
    }

    private func startTimeOutTimer() {
        timeOutTimer?.invalidate()
        timeOutTimer = Timer.scheduledTimer(withTimeInterval: Self.kTenMinuteDuration, repeats: false) { [weak self] _ in
            guard let self = self else { return }
            DispatchQueue.main.async {
                AppAssembly.shared.privacyActionHandler?(.showLiveTimeOutAlert(onDismiss: { [weak self] in
                    guard let self = self else { return }
                    if let nav = self.navigationController {
                        nav.popViewController(animated: true)
                    } else {
                        self.dismiss(animated: true)
                    }
                }))
            }
        }
    }
}

extension AnchorViewController: AnchorViewDelegate {
    func onClickFloatWindow() {
        ThemeStore.shared.setMode(.light)
        FloatWindow.shared.showFloatWindow(controller: self, provider: self)
    }
    
    func onStartLiving() {
        // IOA 登录用户跳过 10 分钟提示
        guard LoginManager.shared.currentUser?.isMoa() != true else { return }
        // 弹出10分钟体验时长提示弹窗
        AppAssembly.shared.privacyActionHandler?(.showLiveTimeLimitAlert)
        // 启动9分钟定时器，到期后弹出"剩余1分钟"Toast
        startRemainingTimer()
        // 启动10分钟定时器，到期后自动解散房间并弹出超时提示
        startTimeOutTimer()
    }
    
    func onEndLiving(state: AnchorState) {
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

extension AnchorViewController: FloatWindowProvider {
    func getRoomId() -> String {
        liveInfo.liveID
    }

    func getOwnerId() -> String {
        LiveListStore.shared.state.value.currentLive.liveOwner.userID
    }

    func getCoreView() -> AtomicXCore.LiveCoreView {
        coreView
    }

    func relayoutCoreView() {
        anchorView.relayoutCoreView()
    }

    func getIsLinking() -> Bool {
        CoGuestStore.create(liveID: liveInfo.liveID).state.value.connected.isOnSeat()
    }
}

extension AnchorViewController: AnchorEndStatisticsViewDelegate {
    func onCloseButtonClick() {
        if let nav = navigationController {
            nav.popViewController(animated: true)
        } else {
            dismiss(animated: true)
        }
    }
}

extension [SeatUserInfo] {
    func isOnSeat(userID: String? = nil) -> Bool {
        if let userID = userID {
            return contains(where: { $0.userID == userID })
        } else {
            let selfUserID = LoginStore.shared.state.value.loginUserInfo?.userID ?? ""
            return contains(where: { $0.userID == selfUserID })
        }
    }
}
