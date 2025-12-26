//
//  AudienceRouterControlCenter.swift
//  TUILiveKit
//
//  Created by jeremiawang on 2024/11/20.
//

import Combine
import TUICore
import RTCCommon
import RTCRoomEngine
import AtomicXCore
import AtomicX

class AudienceRouterControlCenter {
    private var coreView: LiveCoreView?
    private var rootRoute: AudienceRoute
    private var routerManager: AudienceRouterManager
    private var manager: AudienceStore?
    
    private weak var rootViewController: UIViewController?
    private var cancellableSet = Set<AnyCancellable>()
    private var presentedRouteStack: [AudienceRoute] = []
    private var presentedViewControllerMap: [AudienceRoute: UIViewController] = [:]
    
    private weak var videoLinkSettingPanelView: VideoLinkSettingPanel?

    init(rootViewController: UIViewController, rootRoute: AudienceRoute, routerManager: AudienceRouterManager, manager: AudienceStore? = nil, coreView: LiveCoreView? = nil) {
        self.rootViewController = rootViewController
        self.rootRoute = rootRoute
        self.routerManager = routerManager
        self.manager = manager
        self.coreView = coreView
        routerManager.setRootRoute(route: rootRoute)
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
        routerManager.subscribeRouterState(StateSelector(keyPath: \AudienceRouterState.routeStack))
            .receive(on: RunLoop.main)
            .removeDuplicates()
            .sink { [weak self] routeStack in
                guard let self = self else { return }
                self.comparePresentedVCWith(routeStack: routeStack)
            }
            .store(in: &cancellableSet)
    }
}

// MARK: - Route Handler
extension AudienceRouterControlCenter {
    private func comparePresentedVCWith(routeStack: [AudienceRoute]) {
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
    
    private func handleRouteAction(route: AudienceRoute) {
        if route == rootRoute {
            rootViewController?.presentedViewController?.dismiss(animated: true)
        }
        
        if tryToPresentCachedViewController(route: route) {
            if case .linkSetting(let seatIndex) = route, let panel = videoLinkSettingPanelView {
                panel.updateSeatIndex(seatIndex)
            }
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
    
    private func tryToPresentCachedViewController(route: AudienceRoute) -> Bool {
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
    
    private func handleDismisAndRouteToAction(routeStack: [AudienceRoute]) {
        if routeStack.count == 1 && routeStack.contains(.audience) {
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
        }
        
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
    private func getRouteDefaultView(route: AudienceRoute) -> UIView? {
        if case .custom(let item) = route {
            return item.view
        }
        guard let coreView = coreView, let manager = manager else { return nil }
        var view: UIView?
        switch route {
        case .audioEffect:
            let audioEffect = AudioEffectView()
            audioEffect.backButtonClickClosure = { [weak self] _ in
                guard let self = self else { return }
                self.routerManager.router(action: .dismiss())
            }
            view = audioEffect
        case .linkType(let data, let seatIndex):
            view = LinkMicTypePanel(data: data, routerManager: routerManager, manager: manager, seatIndex: seatIndex)
        case .linkSetting(let seatIndex):
            let panel = VideoLinkSettingPanel(manager: manager, routerManager: routerManager, coreView: coreView, seatIndex: seatIndex)
            videoLinkSettingPanelView = panel
            view = panel
        case .featureSetting:
            view = AudienceSettingPanel(manager: manager, routerManager: routerManager)
        case .videoQualitySelection(let resolutions, let selectedClosure):
            let selection = VideoQualitySelectionPanel(resolutions: resolutions, selectedClosure: selectedClosure)
            selection.cancelClosure = { [weak self] in
                guard let self = self else { return }
                routerManager.router(action: .dismiss())
            }
            view = selection
        case .streamDashboard:
            view = StreamDashboardPanel(liveID: manager.liveID)
        case .beauty:
            if BeautyView.checkIsNeedDownloadResource() {
                return nil
            }
            let beautyView = BeautyView.shared()
            beautyView.backClosure = { [weak self] in
                guard let self = self else { return }
                routerManager.router(action: .dismiss())
            }
            view = beautyView
        case .giftView:
            view = GiftListPanel(roomId: manager.liveID)
        case .userManagement(let user, let type):
            if type == .userInfo {
                view = AudienceUserInfoPanelView(user: user, manager: manager)
            } else {
                view = AudienceUserManagePanelView(user: user, manager: manager, routerManager: routerManager, coreView: coreView, type: type)
            }
        case .netWorkInfo(let networkInfoManager, let isAudience):
            let netWorkInfoView = NetWorkInfoView(liveID: manager.liveID, manager: networkInfoManager, isAudience: isAudience)
            netWorkInfoView.onRequestDismissNetworkPanel = { [weak self] completion in
                self?.routerManager.router(action: .dismiss(.panel, completion: completion))
            }
            view = netWorkInfoView
        case .pip:
            view = PictureInPictureTogglePanel(liveID: manager.liveID)
        default:
            break
        }
        return view
    }
}

// MARK: - Route Staus
extension AudienceRouterControlCenter {
    private func isTempPanel(route: AudienceRoute) -> Bool {
        switch route {
        case .streamDashboard,
             .pip,
             .linkType(_, _),
             .userManagement(_, _),
             .videoQualitySelection(_, _):
            return true
        default:
            return false
        }
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

