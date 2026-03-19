//
//  AnchorVideoDelegate.swift
//  TUILiveKit
//
//  Created by CY zhao on 2026/1/30.
//

import Foundation
import AtomicXCore

class AnchorVideoDelegate: VideoViewDelegate {
    private var store: AnchorStore
    private var routerManager: AnchorRouterManager
    
    init(store: AnchorStore, routerManager: AnchorRouterManager) {
        self.store = store
        self.routerManager = routerManager
    }
    
    func createCoGuestView(seatInfo: SeatInfo, viewLayer: ViewLayer) -> UIView? {
        switch viewLayer {
        case .foreground:
            if !seatInfo.userInfo.userID.isEmpty {
                return AnchorCoGuestView(seatInfo: seatInfo, store: store, routerManager: routerManager)
            }
            return AnchorEmptySeatView(seatInfo: seatInfo)
        case .background:
            if !seatInfo.userInfo.userID.isEmpty {
                return AnchorBackgroundWidgetView(avatarUrl: seatInfo.userInfo.avatarURL)
            }
            return nil
        }
    }
    
    func createCoHostView(seatInfo: SeatInfo, viewLayer: ViewLayer) -> UIView? {
        switch viewLayer {
        case .foreground:
            if !seatInfo.userInfo.userID.isEmpty {
                return AnchorCoHostView(seatInfo: seatInfo, store: store)
            }
            return AnchorEmptySeatView(seatInfo: seatInfo)
        case .background:
            if !seatInfo.userInfo.userID.isEmpty {
                return AnchorBackgroundWidgetView(avatarUrl: seatInfo.userInfo.avatarURL)
            }
            return nil
        }
    }
    
    func createBattleView(seatInfo: SeatInfo) -> UIView? {
        let battleView = AnchorBattleMemberInfoView(store: store, userId: seatInfo.userInfo.userID)
        battleView.isUserInteractionEnabled = false
        return battleView
    }
    
    func createBattleContainerView() -> UIView? {
        return AnchorBattleInfoView(store: store, routerManager: routerManager)
    }
}
