//
//  AnchorRouterManager.swift
//  TUILiveKit
//
//  Created by jeremiawang on 2024/11/20.
//

import RTCCommon
import Combine
import AtomicX

class AnchorRouterManager {
    let observerState = ObservableState<AnchorRouterState>(initialState: AnchorRouterState())
    var routerState: AnchorRouterState {
        observerState.state
    }
    
    func subscribeRouterState<Value>(_ selector: StateSelector<AnchorRouterState, Value>) -> AnyPublisher<Value, Never> {
        return observerState.subscribe(selector)
    }
    
    func subscribeRouterState() -> AnyPublisher<AnchorRouterState, Never> {
        return observerState.subscribe()
    }
}

extension AnchorRouterManager {
    func router(action: AnchorRouterAction) {
        switch action {
        case .routeTo(let route):
            if let index = routerState.routeStack.lastIndex(of: route) {
                update { routerState in
                    routerState.routeStack.removeSubrange((index+1)..<routerState.routeStack.count)
                }
            }
        case .present(let route):
            if !routerState.routeStack.contains(where: { $0 == route}) {
                update { routerState in
                    routerState.routeStack.append(route)
                }
            }
        case .dismiss(let dimissType, let completion):
            if dimissType == .alert {
                if let currentRoute = routerState.routeStack.last {
                    var shouldDismiss = false
                    
                    switch currentRoute {
                    case .custom(let item):
                        if item.view is AtomicAlertView {
                            shouldDismiss = true
                        }
                    default:
                        break
                    }
                    
                    if shouldDismiss {
                        handleDissmiss(completion: completion)
                    }
                }
            } else {
                handleDissmiss(completion: completion)
            }
        case .exit:
            update { routerState in
                routerState.routeStack = []
            }
        }
    }
    
    func setRootRoute(route: AnchorRoute) {
        if routerState.routeStack.count >= 1 {
            update { routerState in
                routerState.routeStack[0] = route
            }
        } else {
            update { routerState in
                routerState.routeStack.append(route)
            }
        }
    }
    
    func clearDismissEvent() {
        update { routerState in
            routerState.dismissEvent = nil
        }
    }
    
    private func handleDissmiss(completion: (() -> Void)? = nil) {
        update { routerState in
            routerState.dismissEvent = completion
        }
        if routerState.routeStack.count > 1 {
            update { routerState in
                let _ = routerState.routeStack.popLast()
            }
        }
    }
}

extension AnchorRouterManager {
    func update(routerState: ((inout AnchorRouterState) -> Void)) {
        observerState.update(reduce: routerState)
    }
}

extension AnchorRouterManager {
    
    func present(view: UIView, position: ViewPosition = .center) {
        let item = RouteItem(view: view, position: position)
        let route = AnchorRoute.custom(item)
        self.router(action: .present(route))
    }
    
    func dismiss(dismissType: AnchorDismissType = .panel, completion: (() -> Void)? = nil) {
        self.router(action: .dismiss(dismissType, completion: completion))
    }

}
