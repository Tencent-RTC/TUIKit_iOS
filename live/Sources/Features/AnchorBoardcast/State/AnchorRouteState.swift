//
//  AnchorRouteState.swift
//  TUILiveKit
//
//  Created by jeremiawang on 2024/11/20.
//

import AtomicXCore
import Foundation
import RTCCommon

struct AnchorRouterState {
    var routeStack: [AnchorRoute] = []
    var dismissEvent: (() -> Void)?
}

enum AnchorDismissType {
    case panel
    case alert
}

enum AnchorRouterAction {
    case routeTo(_ route: AnchorRoute)
    case present(_ route: AnchorRoute)
    case dismiss(_ type: AnchorDismissType = .panel, completion: (() -> Void)? = nil)
    case exit
}

enum AnchorRoute {
    case anchor
    case liveLinkControl
    case connectionControl
    case featureSetting(_ settingModel: AnchorFeatureClickPanelModel)
    case listMenu(_ data: ActionPanelData, _ layout: ActionPanelLayoutMode = .stickToBottom)
    case audioEffect
    case beauty
    case giftView
    case battleCountdown(_ countdownTime: TimeInterval)
    case alert(info: AnchorAlertInfo)
    case streamDashboard
    case userManagement(_ user: SeatInfo, type: AnchorUserManagePanelType)
    case netWorkInfo(_ manager: NetWorkInfoManager, isAudience: Bool)
    case mirror
}

extension AnchorRoute: Equatable {
    static func == (lhs: AnchorRoute, rhs: AnchorRoute) -> Bool {
        switch (lhs, rhs) {
            case (.anchor, .anchor),
                 (.liveLinkControl, .liveLinkControl),
                 (.connectionControl, .connectionControl),
                 (.audioEffect, .audioEffect),
                 (.beauty, .beauty),
                 (.giftView, .giftView),
                 (.alert, .alert),
                 (.mirror, .mirror),
                 (.streamDashboard, .streamDashboard):
                return true
            case let (.featureSetting(l), .featureSetting(r)):
                return l == r
            case let (.listMenu(lData, lLayout), .listMenu(rData, rLayout)):
                return lData == rData && lLayout == rLayout
            case let (.battleCountdown(l), .battleCountdown(r)):
                return l == r
            case let (.userManagement(l1, l2), .userManagement(r1, r2)):
                return l1 == r1 && l2 == r2
            case let (.netWorkInfo(l1, l2), .netWorkInfo(r1, r2)):
                return l1 == r1 && l2 == r2
            case (.anchor, _),
                 (.liveLinkControl, _),
                 (.connectionControl, _),
                 (.featureSetting, _),
                 (.listMenu, _),
                 (.audioEffect, _),
                 (.beauty, _),
                 (.giftView, _),
                 (.battleCountdown, _),
                 (.alert, _),
                 (.streamDashboard, _),
                 (.userManagement, _),
                 (.mirror, _),
                 (.netWorkInfo, _):
                return false
            default:
                break
        }
    }
}

extension AnchorRoute: Hashable {
    func convertToString() -> String {
        switch self {
            case .anchor:
                return "anchor"
            case .liveLinkControl:
                return "liveLinkControl"
            case .connectionControl:
                return "connectionControl"
            case let .featureSetting(settingModel):
                return "featureSetting" + settingModel.id.uuidString
            case let .listMenu(data, _):
                var result = "listMenu"
                for item in data.items {
                    result += item.id.uuidString
                }
                return result
            case .audioEffect:
                return "audioEffect"
            case .beauty:
                return "beauty"
            case .giftView:
                return "giftView"
            case let .battleCountdown(countdownTime):
                return "battleCountdown \(countdownTime)"
            case let .alert(alertInfo):
                return "alert \(alertInfo.description)"
            case .streamDashboard:
                return "streamDashboard"
            case let .userManagement(user, type):
                return "userManagement \(user.userInfo.userID) type: \(type)"
            case .netWorkInfo:
                return "netWorkInfo"
            case .mirror:
                return "mirror"
        }
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(self.convertToString())
    }
}
