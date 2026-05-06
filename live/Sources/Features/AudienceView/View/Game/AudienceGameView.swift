//
//  AudienceGameView.swift
//  TUILiveKit
//
//  Created on 2026/3/27.
//

import UIKit
import SnapKit
import Combine
import AtomicXCore
import AtomicX

class AudienceGameView: UIView {

    private let liveID: String
    private let manager: AudienceStore
    private let routerManager: AudienceRouterManager
    private var cancellableSet = Set<AnyCancellable>()
    private var lastApplyHashValue: Int?

    // MARK: - Subviews

    private lazy var seatListView: CoGuestSeatListView = {
        let view = CoGuestSeatListView(liveID: liveID) { [weak self] seatInfo in
            self?.handleSeatTap(seatInfo)
        }
        return view
    }()

    // MARK: - Init

    init(liveID: String, manager: AudienceStore, routerManager: AudienceRouterManager) {
        self.liveID = liveID
        self.manager = manager
        self.routerManager = routerManager
        super.init(frame: .zero)
        setupViews()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    // MARK: - Layout

    private func setupViews() {
        addSubview(seatListView)

        seatListView.snp.makeConstraints { make in
            make.centerX.equalToSuperview()
            make.top.bottom.equalToSuperview()
            make.leading.trailing.equalToSuperview()
        }
    }

    // MARK: - Public API

    func showSeatList(_ show: Bool) {
        seatListView.isHidden = !show
    }

    // MARK: - Seat Tap Handling (Internal)

    private func handleSeatTap(_ seatInfo: SeatInfo) {
        if seatInfo.userInfo.userID.isEmpty {
            handleEmptySeatTap(seatInfo)
        } else {
            handleOccupiedSeatTap(seatInfo)
        }
    }

    private func handleEmptySeatTap(_ seatInfo: SeatInfo) {
        let coGuestStatus = manager.coGuestState.connected.isOnSeat()
        let isApplying = manager.audienceState.isApplying
        if coGuestStatus || isApplying { return }

        let isScreenShareLive = manager.liveListState.currentLive.seatTemplate == .videoLandscape4Seats
            && manager.liveListState.currentLive.keepOwnerOnSeat
        if isScreenShareLive {
            let seatIdx = seatInfo.index
            let audioData = [LinkMicTypeCellData(image: internalImage("live_link_audio"),
                                                 text: .audioLinkRequestText,
                                                 action: { [weak self] in
                guard let self = self else { return }
                self.routerManager.router(action: .dismiss())
                self.applyAudioLinkMic(seatIndex: seatIdx)
            })]
            let panel = LinkMicTypePanel(data: audioData, routerManager: routerManager, manager: manager, seatIndex: seatIdx)
            routerManager.present(view: panel)
        } else {
            let data = AudienceRootMenuDataCreator(manager: manager, routerManager: routerManager)
                .generateLinkTypeMenuData(seatIndex: seatInfo.index)
            let panel = LinkMicTypePanel(data: data, routerManager: routerManager, manager: manager, seatIndex: seatInfo.index)
            routerManager.present(view: panel)
        }
    }

    private func handleOccupiedSeatTap(_ seatInfo: SeatInfo) {
        let isSelf = seatInfo.userInfo.userID == manager.loginState.loginUserInfo?.userID
        if isSelf {
            let panel = AudienceUserManagePanelView(user: seatInfo, manager: manager, routerManager: routerManager, type: .mediaAndSeat)
            routerManager.present(view: panel)
        } else {
            let panel = AudienceUserInfoPanelView(user: seatInfo, manager: manager)
            routerManager.present(view: panel, config: .bottomDefault())
        }
    }

    // MARK: - Apply Audio Link Mic

    private func applyAudioLinkMic(seatIndex: Int) {
        manager.willApplying()
        manager.coGuestStore.applyForSeat(seatIndex: seatIndex, timeout: 60, extraInfo: nil) { [weak self] result in
            guard let self = self else { return }
            manager.stopApplying()
            switch result {
            case .failure(let err):
                let error = InternalError(code: err.code, message: err.message)
                manager.toastSubject.send((error.localizedMessage, .error))
            default: break
            }
        }

        clearLastApplyHashValue()

        let cancelable = manager.coGuestStore.guestEventPublisher
            .receive(on: RunLoop.main)
            .sink { [weak self] event in
                guard let self = self else { return }
                switch event {
                case .onGuestApplicationResponded(isAccept: let isAccept, hostUser: _):
                    manager.stopApplying()
                    guard isAccept else { break }
                    manager.deviceStore.openLocalMicrophone(completion: nil)
                    clearLastApplyHashValue()
                case .onGuestApplicationNoResponse(reason: _):
                    manager.stopApplying()
                    clearLastApplyHashValue()
                default: break
                }
            }
        cancelable.store(in: &cancellableSet)
        lastApplyHashValue = cancelable.hashValue
    }

    private func clearLastApplyHashValue() {
        guard let hashValue = lastApplyHashValue else { return }
        for item in cancellableSet.filter({ $0.hashValue == hashValue }) {
            item.cancel()
            cancellableSet.remove(item)
        }
        lastApplyHashValue = nil
    }
}

private extension String {
    static let audioLinkRequestText = internalLocalized("common_text_link_mic_audio")
    static let waitToLinkText = internalLocalized("common_toast_apply_link_mic")
}
