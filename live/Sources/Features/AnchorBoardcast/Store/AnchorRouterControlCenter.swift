//
//  AnchorRouterControlCenter.swift
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

class AnchorRouterControlCenter {
    private var coreView: LiveCoreView?
    private var rootRoute: AnchorRoute
    private var routerManager: AnchorRouterManager
    private var store: AnchorStore?
    
    private weak var rootViewController: UIViewController?
    private var cancellableSet = Set<AnyCancellable>()
    private var presentedRouteStack: [AnchorRoute] = []
    private var presentedViewControllerMap: [AnchorRoute: UIViewController] = [:]

    init(rootViewController: UIViewController, rootRoute: AnchorRoute, routerManager: AnchorRouterManager, store: AnchorStore? = nil, coreView: LiveCoreView? = nil) {
        self.rootViewController = rootViewController
        self.rootRoute = rootRoute
        self.routerManager = routerManager
        self.store = store
        self.coreView = coreView
        routerManager.setRootRoute(route: rootRoute)
    }
    
    func handleScrollToNewRoom(store: AnchorStore, coreView: LiveCoreView) {
        self.store = store
        self.coreView = coreView
        self.presentedViewControllerMap.removeAll()
    }
    
    deinit {
        print("deinit \(type(of: self))")
    }
}

// MARK: - Subscription
extension AnchorRouterControlCenter {
    func subscribeRouter() {
        routerManager.subscribeRouterState(StateSelector(keyPath: \AnchorRouterState.routeStack))
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
extension AnchorRouterControlCenter {
    private func comparePresentedVCWith(routeStack: [AnchorRoute]) {
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
    
    private func handleRouteAction(route: AnchorRoute) {
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
                case .battleCountdown:
                    let config = RouteItemConfig.centerTransparent()
                    presentedViewController = presentPopover(view: view, config: config)
                default:
                    let config = RouteItemConfig.bottomDefault()
                    presentedViewController = presentPopover(view: view, config: config)
            }
            presentedRouteStack.append(route)
            presentedViewControllerMap[route] = presentedViewController
        } else {
            routerManager.router(action: .dismiss())
        }
    }
    
    private func tryToPresentCachedViewController(route: AnchorRoute) -> Bool {
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
    
    private func handleDismisAndRouteToAction(routeStack: [AnchorRoute]) {
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
extension AnchorRouterControlCenter {
    private func getPresentingViewController(_ rootViewController: UIViewController) -> UIViewController {
        if let vc = rootViewController.presentedViewController {
            return getPresentingViewController(vc)
        } else {
            return rootViewController
        }
    }
}

// MARK: - Default Route View
extension AnchorRouterControlCenter {
    private func getRouteDefaultView(route: AnchorRoute) -> UIView? {
        if case .custom(let item) = route {
            return item.view
        }
        guard let coreView = coreView, let store = store else { return nil }
        var view: UIView?
        switch route {
        case .liveLinkControl:
            view = AnchorLinkControlPanel(store: store, routerManager: routerManager, coreView: coreView)
        case .connectionControl:
            let panel = AnchorCoHostManagerPanel(store: store)
            panel.onClickBack = { [weak self] in
                guard let self = self else { return }
                routerManager.router(action: .dismiss())
            }
            view = panel
        case .featureSetting(let settingPanelModel):
            view = AnchorSettingPanel(settingPanelModel: settingPanelModel)
        case .audioEffect:
            let audioEffect = AudioEffectView()
            audioEffect.backButtonClickClosure = { [weak self] _ in
                guard let self = self else { return }
                self.routerManager.router(action: .dismiss())
            }
            view = audioEffect
        case .battleCountdown(let countdownTime):
            let countdownView = AnchorBattleCountDownView(countdownTime: countdownTime, store: store)
            countdownView.timeEndClosure = { [weak self] in
                guard let self = self else { return }
                self.routerManager.router(action: .dismiss())
            }
            countdownView.cancelClosure = { [weak self] in
                guard let self = self else { return }
                self.routerManager.router(action: .dismiss())
            }
            view = countdownView
        case .streamDashboard:
            view = StreamDashboardPanel(liveID: store.liveID)
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
            view = GiftListPanel(roomId: store.liveID)
        case .userManagement(let user, let type):
            if type == .userInfo {
                view = AnchorUserInfoPanelView(user: LiveUserInfo(seatUserInfo: user.userInfo), store: store)
            } else {
                view = AnchorUserManagePanelView(user: LiveUserInfo(seatUserInfo: user.userInfo), store: store, routerManager: routerManager, type: type)
            }
        case .netWorkInfo(let networkInfoManager, let isAudience):
            let netWorkInfoView = NetWorkInfoView(
                liveID: store.liveID,
                manager: networkInfoManager,
                isAudience: isAudience
            )
            netWorkInfoView.onRequestDismissNetworkPanel = { [weak self] completion in
                self?.routerManager.router(action: .dismiss(.panel, completion: completion))
            }
            view = netWorkInfoView
        case .mirror:
            let dataSource: [MirrorType] = [.auto, .enable, .disable]
            let panel = BaseSelectionPanel(dataSource: dataSource.map { $0.toString() })
            panel.selectedClosure = { [weak self] index in
                guard let self = self else { return }
                DeviceStore.shared.switchMirror(mirrorType: dataSource[index])
                routerManager.router(action: .dismiss())
            }
            panel.cancelClosure = { [weak self] in
                guard let self = self else { return }
                routerManager.router(action: .dismiss())
            }
            view = panel
        case .pip:
            view = PictureInPictureTogglePanel(liveID: store.liveID)
        default:
            break
        }
        return view
    }
}

// MARK: - Route Staus
extension AnchorRouterControlCenter {
    private func isTempPanel(route: AnchorRoute) -> Bool {
        switch route {
        case .battleCountdown(_),
                .streamDashboard,
                .pip,
                .featureSetting(_),
                .userManagement(_, _):
            return true
        default:
            return false
        }
    }
}

// MARK: - AtomicPopover
extension AnchorRouterControlCenter {
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

