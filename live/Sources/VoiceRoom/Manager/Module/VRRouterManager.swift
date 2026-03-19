//
//  VRRouterManager.swift
//  TUILiveKit
//
//  Created by krabyu on 2024/11/18.
//

import AtomicX
import Combine
import AtomicXCore

class VRRouterManager {
    let observerState = ObservableState<VRRouterState>(initialState: VRRouterState())
    var routerState: VRRouterState {
        observerState.state
    }
    
    func subscribeRouterState<Value>(_ selector: StatePublisherSelector<VRRouterState, Value>) -> AnyPublisher<Value, Never> {
        return observerState.subscribe(selector)
    }
    
    func subscribeRouterState() -> AnyPublisher<VRRouterState, Never> {
        return observerState.subscribe()
    }
}

extension VRRouterManager {
    func router(action: VRRouterAction) {
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
                    
                    if currentRoute.view is AtomicAlertView {
                        shouldDismiss = true
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
                routerState.shouldExit = true
                routerState.routeStack = []
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
        if routerState.routeStack.count > 0 {
            update { routerState in
                let _ = routerState.routeStack.popLast()
            }
        }
    }
}

extension VRRouterManager {
    func update(routerState: ((inout VRRouterState) -> Void)) {
        observerState.update(reduce: routerState)
    }
}

extension VRRouterManager {
    
    func present(view: UIView, config: RouteItemConfig = .bottomDefault()) {
        let item = RouteItem(view: view, config: config)
        self.router(action: .present(item))
    }
    
    func dismiss(dismissType: VRDismissType = .panel, completion: (() -> Void)? = nil) {
        self.router(action: .dismiss(dismissType, completion: completion))
    }

}
