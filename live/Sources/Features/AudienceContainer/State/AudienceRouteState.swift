//
//  AudienceRouteState.swift
//  TUILiveKit
//
//  Created by jeremiawang on 2024/11/20.
//

import Foundation
import AtomicXCore
import AtomicX

struct AudienceRouterState {
    var routeStack: [AudienceRoute] = []
    var dismissEvent: (() -> Void)?
    var shouldExit: Bool = false
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

typealias AudienceRoute = RouteItem
