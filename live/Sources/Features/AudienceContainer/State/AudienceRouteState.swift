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
    case linkType(_ data: [LinkMicTypeCellData])
    case linkSetting
    case listMenu(_ data: ActionPanelData,_ layout: ActionPanelLayoutMode = .center)
    case audioEffect
    case beauty
    case giftView
    case alert(info: AudienceAlertInfo)
    case streamDashboard
    case userManagement(_ seatInfo: SeatInfo, type: AudienceUserManagePanelType)
    case netWorkInfo(_ manager: NetWorkInfoManager, isAudience: Bool)
    case featureSetting
    case videoQualitySelection(resolutions: [VideoQuality], selectedClosure: ((VideoQuality) -> Void))
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
                (.alert, .alert),
                (.streamDashboard, .streamDashboard):
                return true
            case let (.listMenu(l1,l2), .listMenu(r1,r2)):
                return l1 == r1 && l2 == r2
            case let (.userManagement(l1, l2), .userManagement(r1, r2)):
                return l1 == r1 && l2 == r2
            case let (.netWorkInfo(l1, l2), .netWorkInfo(r1, r2)):
                return l1 == r1 && l2 == r2
            case (.audience, _),
                (.linkType, _),
                (.linkSetting, _),
                (.featureSetting, _),
                (.videoQualitySelection, _),
                (.listMenu, _),
                (.audioEffect, _),
                (.beauty, _),
                (.giftView, _),
                (.alert, _),
                (.streamDashboard, _),
                (.userManagement, _),
                (.netWorkInfo, _):
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
            case .listMenu(let data,let layout):
                var result = "listMenu"
                data.items.forEach { item in
                    result += item.id.uuidString
                }
                return result
            case .audioEffect:
                return "audioEffect"
            case .beauty:
                return "beauty"
            case .giftView:
                return "giftView"
            case .alert(let alertInfo):
                return "alert \(alertInfo.description)"
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
        }
    }
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(self.convertToString())
    }
}
