//
//  AudienceRouterControlCenter.swift
//  TUILiveKit
//
//  Created by jeremiawang on 2024/11/20.
//

import Combine
import TUICore
import AtomicX
import RTCRoomEngine
import AtomicXCore

class AudienceRouterControlCenter {
    private var coreView: LiveCoreView?
    private var routerManager: AudienceRouterManager
    private var manager: AudienceStore?
    
    private weak var rootViewController: UIViewController?
    private var cancellableSet = Set<AnyCancellable>()
    private var presentedRouteStack: [RouteItem] = []
    private var presentedViewControllerMap: [RouteItem: UIViewController] = [:]
    
    private weak var videoLinkSettingPanelView: VideoLinkSettingPanel?

    init(rootViewController: UIViewController, routerManager: AudienceRouterManager, manager: AudienceStore? = nil, coreView: LiveCoreView? = nil) {
        self.rootViewController = rootViewController
        self.routerManager = routerManager
        self.manager = manager
        self.coreView = coreView
    }
    
    func handleScrollToNewRoom(manager: AudienceStore, coreView: LiveCoreView) {
        self.manager = manager
        self.coreView = coreView
        self.presentedViewControllerMap.removeAll()
    }
    
    deinit {
        print("deinit \(type(of: self))")
    }
}

// MARK: - Subscription
extension AudienceRouterControlCenter {
    func subscribeRouter() {
        routerManager.subscribeRouterState(StatePublisherSelector(keyPath: \AudienceRouterState.routeStack))
            .receive(on: RunLoop.main)
            .removeDuplicates()
            .sink { [weak self] routeStack in
                guard let self = self else { return }
                self.comparePresentedVCWith(routeStack: routeStack)
            }
            .store(in: &cancellableSet)
        
        routerManager.subscribeRouterState(StatePublisherSelector(keyPath: \AudienceRouterState.shouldExit))
            .receive(on: RunLoop.main)
            .removeDuplicates()
            .sink { [weak self] shouldExit in
                guard let self = self else { return }
                if shouldExit {
                    self.handleExitAction()
                }
            }
            .store(in: &cancellableSet)
    }
}

// MARK: - Route Handler
extension AudienceRouterControlCenter {
    private func comparePresentedVCWith(routeStack: [RouteItem]) {
        if routerManager.routerState.shouldExit {
            if !presentedRouteStack.isEmpty {
                handleDismissAllPanels()
                DispatchQueue.main.async { [weak self] in
                    self?.handleExitAction()
                }
            } else {
                handleExitAction()
            }
            return
        }
        
        if routeStack.isEmpty && !presentedRouteStack.isEmpty {
            handleDismissAllPanels()
            return
        }
        
        if routeStack.count > presentedRouteStack.count {
            if let lastRoute = routeStack.last {
                handleRouteAction(route: lastRoute)
            }
            return
        }
        
        handleDismisAndRouteToAction(routeStack: routeStack)
    }
    
    private func handleDismissAllPanels() {
        if routerManager.routerState.dismissEvent != nil {
            handleDismisAndRouteToAction(routeStack: [])
            return
        }
        while !presentedRouteStack.isEmpty {
            if let route = presentedRouteStack.popLast(), let vc = presentedViewControllerMap[route] {
                vc.dismiss(animated: false)
                presentedViewControllerMap.removeValue(forKey: route)
            }
        }
    }
    
    private func handleExitAction() {
        presentedRouteStack.removeAll()
        presentedViewControllerMap.removeAll()
        exitLiveKit()
    }
    
    private func exitLiveKit() {
        if let navigationController = rootViewController?.navigationController {
            navigationController.popViewController(animated: true)
        } else {
            rootViewController?.dismiss(animated: true)
        }
    }
    
    private func handleRouteAction(route: RouteItem) {
        if tryToPresentCachedViewController(route: route) {
            return
        }
                
        if let view = getRouteDefaultView(route: route) {
            var presentedViewController: UIViewController = UIViewController()
            if let alertView = view as? AtomicAlertView {
                presentedViewController = presentAtomicAlert(alert: alertView, config: route.config)
            } else {
                presentedViewController = presentPopover(view: view, config: route.config)
            }
            presentedRouteStack.append(route)
            presentedViewControllerMap[route] = presentedViewController
        } else {
            routerManager.router(action: .dismiss())
        }
    }
    
    private func tryToPresentCachedViewController(route: RouteItem) -> Bool {
        var isSuccess = false
        if presentedViewControllerMap.keys.contains(route) {
            if let rootViewController = rootViewController,
               let presentedController = presentedViewControllerMap[route] {
                let presentingViewController = getPresentingViewController(rootViewController)
                presentingViewController.present(presentedController, animated: false)
                presentedRouteStack.append(route)
                isSuccess = true
            }
        }
        return isSuccess
    }
    
    private func handleDismisAndRouteToAction(routeStack: [RouteItem]) {
        if BeautyView.isDownloading {
            if let rootVC = rootViewController {
                let vc = getPresentingViewController(rootVC)
                if String(describing: type(of: vc)) == "TransparentPresentationController" {
                    BeautyView.isDownloading = false
                    vc.dismiss(animated: false) { [weak self] in
                        guard let self = self else { return }
                        handleDismisAndRouteToAction(routeStack: routeStack)
                    }
                    return
                }
            }
        }
        
        while routeStack.last != presentedRouteStack.last {
            if presentedRouteStack.isEmpty {
                break
            }
            
            if let route = presentedRouteStack.popLast(), let vc = presentedViewControllerMap[route] {
                if let dismissEvent = routerManager.routerState.dismissEvent {
                    vc.dismiss(animated: true) { [weak self] in
                        guard let self = self else { return }
                        dismissEvent()
                        self.routerManager.clearDismissEvent()
                    }
                    presentedViewControllerMap.removeValue(forKey: route)
                    return
                } else {
                    vc.dismiss(animated: false)
                    presentedViewControllerMap.removeValue(forKey: route)
                }
            }
        }
    }
}

// MARK: - Presenting ViewController
extension AudienceRouterControlCenter {
    private func getPresentingViewController(_ rootViewController: UIViewController) -> UIViewController {
        if let vc = rootViewController.presentedViewController {
            return getPresentingViewController(vc)
        } else {
            return rootViewController
        }
    }
}

// MARK: - Default Route View
extension AudienceRouterControlCenter {
    private func getRouteDefaultView(route: RouteItem) -> UIView? {
        return route.view
    }
}

// MARK: - AtomicPopover

extension AudienceRouterControlCenter {

    private func presentAtomicAlert(alert: AtomicAlertView, config: RouteItemConfig) -> UIViewController {
        var popover: AtomicPopover
        if config.position == .bottom {
            let popoverConfig = AtomicPopover.AtomicPopoverConfig(onBackdropTap: { [weak self] in
                self?.routerManager.router(action: .dismiss())
            })
            popover = AtomicPopover(contentView: alert, configuration: popoverConfig)
        } else {
            var popoverConfig = AtomicPopover.AtomicPopoverConfig.centerDefault()
            popover = AtomicPopover(contentView: alert, configuration: popoverConfig)
        }
        guard let rootViewController = rootViewController else { return UIViewController()}
        let presentingViewController = getPresentingViewController(rootViewController)
        presentingViewController.present(popover, animated: false)

        return popover
    }
    
    private func presentPopover(view: UIView, config: RouteItemConfig) -> UIViewController {
        let position: PopoverPosition = config.position == .bottom ? .bottom : .center
        let animation: PopoverAnimation = config.position == .bottom ? .slideFromBottom : .none

        let popoverConfig = AtomicPopover.AtomicPopoverConfig(
            position: position,
            height: .wrapContent,
            animation: animation,
            backgroundColor: config.backgroundColor,
            onBackdropTap: { [weak self] in
                self?.routerManager.router(action: .dismiss())
            }
        )

        let popover = AtomicPopover(contentView: view, configuration: popoverConfig)

        guard let rootViewController = rootViewController else { return UIViewController() }
        let presentingViewController = getPresentingViewController(rootViewController)
        presentingViewController.present(popover, animated: false)

        return popover
    }
}

