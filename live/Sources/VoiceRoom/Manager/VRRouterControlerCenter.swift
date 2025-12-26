//
//  VRRouterControlerCenter.swift
//  TUILiveKit
//
//  Created by krabyu on 2024/11/18.
//

import Combine
import RTCCommon
import RTCRoomEngine
import RTCCommon
import AtomicX

class VRRouterControlCenter {
    
    private var rootRoute: VRRoute
    private var routerManager: VRRouterManager
    private let liveID: String
    private var toastService: VRToastService
    
    private weak var rootViewController: UIViewController?
    private var cancellableSet = Set<AnyCancellable>()
    private var presentedRouteStack: [VRRoute] = []
    private var presentedViewControllerMap: [VRRoute: UIViewController] = [:]
    
    init(liveID: String,
         rootViewController: UIViewController,
         rootRoute: VRRoute,
         routerManager: VRRouterManager,
         toastService: VRToastService) {
        self.liveID = liveID
        self.rootViewController = rootViewController
        self.rootRoute = rootRoute
        self.routerManager = routerManager
        self.toastService = toastService
        routerManager.setRootRoute(route: rootRoute)
    }
    
    func updateRootRoute(rootRoute: VRRoute) {
        self.rootRoute = rootRoute
        routerManager.setRootRoute(route: rootRoute)
    }
    
    deinit {
        print("deinit \(type(of: self))")
    }
}

// MARK: - Subscription
extension VRRouterControlCenter {
    func subscribeRouter() {
        routerManager.subscribeRouterState(StateSelector(keyPath: \VRRouterState.routeStack))
            .receive(on: RunLoop.main)
            .removeDuplicates()
            .sink { [weak self] routeStack in
                guard let self = self else { return }
                self.comparePresentedVCWith(routeStack: routeStack)
            }
            .store(in: &cancellableSet)
    }
    
    func unSubscribeRouter() {
        cancellableSet.forEach { cancellable in
            cancellable.cancel()
        }
        cancellableSet.removeAll()
    }
}

// MARK: - Route Handler
extension VRRouterControlCenter {
    private func comparePresentedVCWith(routeStack: [VRRoute]) {
        if routeStack.isEmpty {
            handleExitAction()
            return
        }
        
        if routeStack.count > presentedRouteStack.count + 1 {
            if let lastRoute = routeStack.last {
                handleRouteAction(route: lastRoute)
            }
            return
        }
        
        handleDismisAndRouteToAction(routeStack: routeStack)
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
    
    private func handleRouteAction(route: VRRoute) {
        if route == rootRoute {
            rootViewController?.presentedViewController?.dismiss(animated: true)
        }
        
        if tryToPresentCachedViewController(route: route) {
            return
        }
        
        if let view = getRouteDefaultView(route: route) {
            var presentedViewController: UIViewController = UIViewController()
            switch route {
            case .custom(let item):
                if let alertView = item.view as? AtomicAlertView {
                    presentedViewController = presentAtomicAlert(alert: alertView, config: item.config)
                } else {
                    presentedViewController = presentPopover(view: item.view, config: item.config)
                }
            default:
                presentedViewController = presentPopover(view: view, config: .bottomDefault())
            }
            presentedRouteStack.append(route)
            presentedViewControllerMap[route] = presentedViewController
        } else {
            routerManager.router(action: .dismiss())
        }
    }
    
    private func tryToPresentCachedViewController(route: VRRoute) -> Bool {
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
    
    private func handleDismisAndRouteToAction(routeStack: [VRRoute]) {
        while routeStack.last != presentedRouteStack.last {
            if presentedRouteStack.isEmpty {
                break
            }
            
            if let route = presentedRouteStack.popLast(), let vc = presentedViewControllerMap[route] {
                if let dismissEvent = routerManager.routerState.dismissEvent {
                    vc.dismiss(animated: false) { [weak self] in
                        guard let self = self else { return }
                        dismissEvent()
                        self.routerManager.clearDismissEvent()
                    }
                } else {
                    vc.dismiss(animated: false)
                }
                if isTempPanel(route: route) {
                    presentedViewControllerMap[route] = nil
                }
            }
        }
    }
}


// MARK: - Presenting ViewController
extension VRRouterControlCenter {
    private func getPresentingViewController(_ rootViewController: UIViewController) -> UIViewController {
        if let vc = rootViewController.presentedViewController {
            return getPresentingViewController(vc)
        } else {
            return rootViewController
        }
    }
}

// MARK: - Default Route View
extension VRRouterControlCenter {
    private func getRouteDefaultView(route: VRRoute) -> UIView? {
        if case .custom(let item) = route {
            return item.view
        }
        var view: UIView?
        switch route {
        case .voiceLinkControl:
            view = VRSeatManagerPanel(liveID: liveID, toastService: toastService, routerManager: routerManager)
        case .linkInviteControl(let index):
            view = VRSeatInvitationPanel(liveID: liveID, toastService: toastService, routerManager: routerManager, seatIndex: index)
        case .userControl(let imStore, let seatInfo):
            view = VRUserManagerPanel(liveID: liveID, imStore: imStore, toastService: toastService, routerManager: routerManager, seatInfo: seatInfo)
        case .featureSetting(let settingPanelModel):
            view = VRSettingPanel(settingPanelModel: settingPanelModel)
        case .audioEffect:
            let audioEffect = AudioEffectView()
            audioEffect.backButtonClickClosure = { [weak self] _ in
                guard let self = self else { return }
                self.routerManager.router(action: .dismiss())
            }
            view = audioEffect
        case .systemImageSelection(let imageType, let sceneType):
            let imageConfig = VRSystemImageFactory.getImageAssets(imageType: imageType)
            let systemImageSelectionPanel = VRImageSelectionPanel(configs: imageConfig,
                                                                  panelMode: imageType == .cover ? .cover : .background,
                                                                  sceneType: sceneType)
            systemImageSelectionPanel.backButtonClickClosure = { [weak self] in
                guard let self = self else { return }
                self.routerManager.router(action: .dismiss())
            }
            view = systemImageSelectionPanel
        case .prepareSetting(let prepareStore):
            view = VRPrepareSettingPanel(prepareStore: prepareStore, routerManager: routerManager)
        case .alert(let info,let second):
                view = VRAlertPanel(alertInfo: info,autoDismissAfter: second)
        case .giftView:
            view = GiftListPanel(roomId: liveID)
        case .layout(let prepareStore):
            view = VRLayoutPanel(prepareStore: prepareStore, routerManager: routerManager)
        case .connectionControl:
                let panel = interactionInvitePanel(liveID: liveID,toastService: toastService,routerManager: routerManager)
            panel.onClickBack = { [weak self] in
                guard let self = self else { return }
                routerManager.router(action: .dismiss())
            }
            view = panel
        case .coHostUserControl(let seatInfo,let type):
            let panel = CoHostViewManagerPanel(liveID: liveID,seatInfo: seatInfo, routerManager: routerManager, type: type, toastService: toastService)
            view = panel
        default:
            break
        }
        return view
    }
}

// MARK: - Route Staus
extension VRRouterControlCenter {
    private func isTempPanel(route: VRRoute) -> Bool {
        switch route {
            case .alert, .userControl, .coHostUserControl:
            return true
        default:
            return false
        }
    }
}

// MARK: - AtomicPopover
extension VRRouterControlCenter {
    
    private func presentAtomicAlert(alert: AtomicAlertView, config: RouteItemConfig) -> UIViewController {
        var popover: AtomicPopover
        if config.position == .bottom {
            let popoverConfig = AtomicPopover.AtomicPopoverConfig(onBackdropTap: { [weak self] in
                self?.routerManager.router(action: .dismiss())
            })
            popover = AtomicPopover(contentView: alert, configuration: popoverConfig)
        } else {
            let popoverConfig = AtomicPopover.AtomicPopoverConfig.centerDefault()
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
