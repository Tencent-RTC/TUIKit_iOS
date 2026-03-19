//
//  VRRouterState.swift
//  TUILiveKit
//
//  Created by krabyu on 2024/11/18.
//

import Foundation
import AtomicXCore
import RTCRoomEngine
import AtomicX

enum VRDismissType {
    case panel
    case alert
}

enum VRRouterAction {
    case routeTo(_ route: RouteItem)
    case present(_ route: RouteItem)
    case dismiss(_ type: VRDismissType = .panel, completion: (() -> Void)? = nil)
    case exit
}

typealias VRRoute = RouteItem

struct VRRouterState {
    var routeStack: [RouteItem] = []
    var dismissEvent: (() -> Void)?
    var shouldExit: Bool = false
}
