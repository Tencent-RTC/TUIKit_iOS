//
//  AnchorViewDefine.swift
//  TUILiveKit
//
//  Created by gg on 2025/6/20.
//

import Foundation
import AtomicXCore

public class AnchorState {
    public var totalDuration: Int = 0
    public var totalViewers: Int = 0
    public var totalMessageSent: Int = 0
    public var totalGiftCoins: Int = 0
    public var totalGiftUniqueSenders: Int = 0
    public var totalLikesReceived: Int = 0
    public var liveEndedReason: LiveEndedReason = .endedByHost
}

public protocol AnchorViewDelegate: AnyObject {
    func onClickFloatWindow()
    func onEndLiving(state: AnchorState)
    func onStartLiving()
}

public enum RoomBehavior {
    case createRoom
    case enterRoom
}

public enum AnchorNode {
    case liveInfo
    case topRightButtons
    case networkInfo
    case bottomRightBar
    case barrageInput
}

public enum AnchorBottomItem: Hashable {
    case coHost
    case battle
    case coGuest
    case more
    case custom(UIView)

    public static func == (lhs: AnchorBottomItem, rhs: AnchorBottomItem) -> Bool {
        switch (lhs, rhs) {
        case (.coHost, .coHost),
             (.battle, .battle),
             (.coGuest, .coGuest),
            (.more, .more):
            return true
        case (.custom(let lView), .custom(let rView)):
            return lView === rView
        default:
            return false
        }
    }

    public func hash(into hasher: inout Hasher) {
        switch self {
        case .coHost:
            hasher.combine(0)
        case .battle:
            hasher.combine(1)
        case .coGuest:
            hasher.combine(2)
        case .more:
            hasher.combine(3)
        case .custom(let view):
            hasher.combine(6)
            hasher.combine(ObjectIdentifier(view))
        }
    }
}

public enum AnchorTopRightItem: Hashable {
    case audienceCount
    case floatWindow
    case close
    case custom(UIView)

    public static func == (lhs: AnchorTopRightItem, rhs: AnchorTopRightItem) -> Bool {
        switch (lhs, rhs) {
        case (.audienceCount, .audienceCount),
             (.floatWindow, .floatWindow),
             (.close, .close):
            return true
        case (.custom(let lView), .custom(let rView)):
            return lView === rView
        default:
            return false
        }
    }

    public func hash(into hasher: inout Hasher) {
        switch self {
        case .audienceCount:
            hasher.combine(0)
        case .floatWindow:
            hasher.combine(1)
        case .close:
            hasher.combine(2)
        case .custom(let view):
            hasher.combine(3)
            hasher.combine(ObjectIdentifier(view))
        }
    }
}

public enum AnchorAction: Equatable {
    case showLiveInfo
    case showAudienceList
    case showCoGuestPanel
    case showCoHostPanel
    case showMorePanel
    case showFloatWindow
    case requestBattle
    case endLive
}
