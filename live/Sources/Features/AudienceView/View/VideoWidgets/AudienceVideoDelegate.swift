//
//  AudienceVideoDelegate.swift
//  TUILiveKit
//
//  Created by CY zhao on 2026/3/15.
//

import Foundation
import AtomicXCore

class AudienceVideoDelegate: VideoViewDelegate {
    private let manager: AudienceStore
    private let routerManager: AudienceRouterManager
    private let coreView: LiveCoreView
    private let menuCreator: AudienceRootMenuDataCreator

    init(manager: AudienceStore, routerManager: AudienceRouterManager, coreView: LiveCoreView) {
        self.manager = manager
        self.routerManager = routerManager
        self.coreView = coreView
        self.menuCreator = AudienceRootMenuDataCreator(manager: manager, routerManager: routerManager)
    }

    func createCoGuestView(seatInfo: SeatInfo, viewLayer: ViewLayer) -> UIView? {
        let isScreenShareLive = manager.liveListState.currentLive.seatTemplate == .videoLandscape4Seats
            && manager.liveListState.currentLive.keepOwnerOnSeat
        if isScreenShareLive {
            return nil
        }
        switch viewLayer {
        case .foreground:
            if !seatInfo.userInfo.userID.isEmpty {
                return AudienceCoGuestView(seatInfo: seatInfo, manager: manager, routerManager: routerManager, coreView: coreView)
            }
            return AudienceEmptySeatView(seatInfo: seatInfo, manager: manager, routerManager: routerManager, coreView: coreView, menuCreator: menuCreator)
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
            return AudienceEmptySeatView(seatInfo: seatInfo, manager: manager, routerManager: routerManager, coreView: coreView, menuCreator: menuCreator)
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
        return AudienceBattleInfoView(manager: manager, routerManager: routerManager, isOwner: true, coreView: coreView)
    }
}
