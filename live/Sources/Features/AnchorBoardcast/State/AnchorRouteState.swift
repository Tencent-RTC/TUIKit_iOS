//
//  AnchorRouteState.swift
//  TUILiveKit
//
//  Created by jeremiawang on 2024/11/20.
//

import AtomicXCore
import AtomicX
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
    case audioEffect
    case beauty
    case giftView
    case battleCountdown(_ countdownTime: TimeInterval)
    case streamDashboard
    case userManagement(_ user: SeatInfo, type: AnchorUserManagePanelType)
    case netWorkInfo(_ manager: NetWorkInfoManager, isAudience: Bool)
    case mirror
    case pip
    case custom(_ item: RouteItem) //TODO: chengyu暂时新增一个插槽，重构完成后删除
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
                 (.mirror, .mirror),
                 (.pip, .pip),
                 (.streamDashboard, .streamDashboard):
                return true
            case let (.featureSetting(l), .featureSetting(r)):
                return l == r
            case let (.battleCountdown(l), .battleCountdown(r)):
                return l == r
            case let (.userManagement(l1, l2), .userManagement(r1, r2)):
                return l1 == r1 && l2 == r2
            case let (.netWorkInfo(l1, l2), .netWorkInfo(r1, r2)):
                return l1 == r1 && l2 == r2
            case let (.custom(l), .custom(r)):
                return l == r
            case (.anchor, _),
                 (.liveLinkControl, _),
                 (.connectionControl, _),
                 (.featureSetting, _),
                 (.audioEffect, _),
                 (.beauty, _),
                 (.giftView, _),
                 (.battleCountdown, _),
                 (.streamDashboard, _),
                 (.pip, _),
                 (.userManagement, _),
                 (.mirror, _),
                 (.netWorkInfo, _),
                 (.custom, _):
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
            case .audioEffect:
                return "audioEffect"
            case .beauty:
                return "beauty"
            case .giftView:
                return "giftView"
            case let .battleCountdown(countdownTime):
                return "battleCountdown \(countdownTime)"
            case .streamDashboard:
                return "streamDashboard"
            case let .userManagement(user, type):
                return "userManagement \(user.userInfo.userID) type: \(type)"
            case .netWorkInfo:
                return "netWorkInfo"
            case .mirror:
                return "mirror"
            case .pip:
                return "pip"
            case let .custom(item):
                return "custom_\(item.id)"
        }
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(self.convertToString())
    }
}

enum ViewPosition: Equatable {
    case bottom
    case center
}


struct RouteItemConfig {
    let position: ViewPosition

    let backgroundColor: PopoverColor

    init(position: ViewPosition = .center, backgroundColor: PopoverColor = .defaultThemeColor) {
        self.position = position
        self.backgroundColor = backgroundColor
    }

    static func bottomDefault() -> RouteItemConfig {
        return RouteItemConfig(position: .bottom, backgroundColor: .defaultThemeColor)
    }

    static func centerDefault() -> RouteItemConfig {
        return RouteItemConfig(position: .center, backgroundColor: .defaultThemeColor)
    }

    static func centerTransparent() -> RouteItemConfig {
        return RouteItemConfig(position: .center, backgroundColor: .custom(.clear))
    }
}

struct RouteItem: Identifiable, Equatable {
    let id: String = UUID().uuidString
    let view: UIView
    let config: RouteItemConfig

    init(view: UIView, config: RouteItemConfig = .centerDefault()) {
        self.view = view
        self.config = config
    }

    init(view: UIView, position: ViewPosition) {
        self.view = view
        self.config = RouteItemConfig(position: position)
    }
    
    static func == (lhs: RouteItem, rhs: RouteItem) -> Bool {
        return lhs.id == rhs.id
    }
}
