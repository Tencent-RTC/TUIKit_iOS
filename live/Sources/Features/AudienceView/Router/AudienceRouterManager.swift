//
//  AudienceRouterManager.swift
//  TUILiveKit
//
//  Created by jeremiawang on 2024/11/20.
//

import AtomicX
import Combine
import AtomicXCore

class AudienceRouterManager {
    let observerState = ObservableState<AudienceRouterState>(initialState: AudienceRouterState())
    var routerState: AudienceRouterState {
        observerState.state
    }
    
    func subscribeRouterState<Value>(_ selector: StatePublisherSelector<AudienceRouterState, Value>) -> AnyPublisher<Value, Never> {
        return observerState.subscribe(selector)
    }
    
    func subscribeRouterState() -> AnyPublisher<AudienceRouterState, Never> {
        return observerState.subscribe()
    }
}

extension AudienceRouterManager {
    func router(action: AudienceRouterAction) {
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

extension AudienceRouterManager {
    func update(routerState: ((inout AudienceRouterState) -> Void)) {
        observerState.update(reduce: routerState)
    }
}


extension AudienceRouterManager {
    
    func present(view: UIView, config: RouteItemConfig = .bottomDefault()) {
        let item = RouteItem(view: view, config: config)
        self.router(action: .present(item))
    }
    
    func dismiss(dismissType: AudienceDismissType = .panel, completion: (() -> Void)? = nil) {
        self.router(action: .dismiss(dismissType, completion: completion))
    }
}
