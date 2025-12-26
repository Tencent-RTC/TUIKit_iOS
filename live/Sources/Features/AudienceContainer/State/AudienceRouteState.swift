//
//  AudienceRouteState.swift
//  TUILiveKit
//
//  Created by jeremiawang on 2024/11/20.
//

import Foundation
import AtomicXCore
import RTCCommon

struct AudienceRouterState {
    var routeStack: [AudienceRoute] = []
    var dismissEvent: (() -> Void)?
}

enum AudienceDismissType {
    case panel
    case alert
}

enum AudienceRouterAction {
    case routeTo(_ route: AudienceRoute)
    case present(_ route: AudienceRoute)
    case dismiss(_ type: AudienceDismissType = .panel, completion: (() -> Void)? = nil)
    case exit
}

enum AudienceRoute {
    case audience
    case linkType(_ data: [LinkMicTypeCellData], seatIndex: Int)
    case linkSetting(seatIndex: Int)
    case audioEffect
    case beauty
    case giftView
    case streamDashboard
    case userManagement(_ seatInfo: SeatInfo, type: AudienceUserManagePanelType)
    case netWorkInfo(_ manager: NetWorkInfoManager, isAudience: Bool)
    case featureSetting
    case videoQualitySelection(resolutions: [VideoQuality], selectedClosure: ((VideoQuality) -> Void))
    case pip
    case custom(_ item: RouteItem)
}

extension AudienceRoute: Equatable {
    static func == (lhs: AudienceRoute, rhs: AudienceRoute) -> Bool {
        switch (lhs, rhs) {
            case (.audience,.audience),
                (.linkType, .linkType),
                (.linkSetting, .linkSetting),
                (.featureSetting, .featureSetting),
                (.videoQualitySelection, .videoQualitySelection),
                (.audioEffect,.audioEffect),
                (.beauty, .beauty),
                (.giftView, .giftView),
                (.pip, .pip),
                (.streamDashboard, .streamDashboard):
                return true
            case let (.userManagement(l1, l2), .userManagement(r1, r2)):
                return l1 == r1 && l2 == r2
            case let (.netWorkInfo(l1, l2), .netWorkInfo(r1, r2)):
                return l1 == r1 && l2 == r2
            case let (.custom(l), .custom(r)):
                return l == r
            case (.audience, _),
                (.linkType, _),
                (.linkSetting, _),
                (.featureSetting, _),
                (.videoQualitySelection, _),
                (.audioEffect, _),
                (.beauty, _),
                (.giftView, _),
                (.streamDashboard, _),
                (.pip, _),
                (.userManagement, _),
                (.netWorkInfo, _),
                (.custom, _):
                return false
            default:
                break
        }
    }
}

extension AudienceRoute: Hashable {
    func convertToString() -> String {
        switch self {
            case .audience:
                return "audience"
            case .linkType:
                return "linkType"
            case .linkSetting:
                return "linkSetting"
            case .audioEffect:
                return "audioEffect"
            case .beauty:
                return "beauty"
            case .giftView:
                return "giftView"
            case .streamDashboard:
                return "streamDashboard"
            case .userManagement(let user, let type):
                return "userManagement \(user.userInfo.userID) type: \(type)"
            case .netWorkInfo:
                return "netWorkInfo"
            case .featureSetting:
                return "featureSetting"
            case .videoQualitySelection:
                return "videoQualitySelection"
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
