//
//  AnchorRouteState.swift
//  TUILiveKit
//
//  Created by jeremiawang on 2024/11/20.
//

import AtomicXCore
import AtomicX
import Foundation

struct AnchorRouterState {
    var routeStack: [AnchorRoute] = []
    var dismissEvent: (() -> Void)?
    var shouldExit: Bool = false
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

typealias AnchorRoute = RouteItem

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

struct RouteItem: Identifiable, Equatable, Hashable {
    let id: String = UUID().uuidString
    let view: UIView
    let config: RouteItemConfig

    init(view: UIView, config: RouteItemConfig = .bottomDefault()) {
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
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}
