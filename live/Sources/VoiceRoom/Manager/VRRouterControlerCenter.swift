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
            case .alert(_, _):
                presentedViewController = presentAlert(alertView: view)
            case .listMenu(_, let layout):
                if layout == .center {
                    presentedViewController = presentPopup(view: view, route: route, portraitPosition: .center(horizontalPadding: 47.scale375()))
                } else {
                    presentedViewController = presentPopup(view: view, route: route)
                }
            default:
                presentedViewController = presentPopup(view: view, route: route)
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
                presentingViewController.present(presentedController, animated: supportAnimation(route: route))
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
                    vc.dismiss(animated: supportAnimation(route: route)) { [weak self] in
                        guard let self = self else { return }
                        dismissEvent()
                        self.routerManager.clearDismissEvent()
                    }
                } else {
                    vc.dismiss(animated: supportAnimation(route: route))
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
        case .listMenu(let data, _):
            let actionPanel = ActionPanel(panelData: data)
            actionPanel.cancelActionClosure = { [weak self] in
                guard let self = self else { return }
                self.routerManager.router(action: .dismiss())
            }
            view = actionPanel
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
                let panel = VRCoHostManagerPanel(liveID: liveID,toastService: toastService,routerManager: routerManager)
            panel.onClickBack = { [weak self] in
                guard let self = self else { return }
                routerManager.router(action: .dismiss())
            }
            view = panel
        case .coHostUserControl(let seatInfo,let type):
            let panel = VRCoHostUserManagerPanel(liveID: liveID,seatInfo: seatInfo, routerManager: routerManager, type: type, toastService: toastService)
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
    
    private func supportBlurView(route: VRRoute) -> Bool {
        switch route {
        case .giftView:
            return false
        case .layout:
            return false
        case .listMenu(_, let layout):
            return layout == .center
        default:
            return true
        }
    }
    
    private func supportAnimation(route: VRRoute) -> Bool{
        switch route {
        default:
            return true
        }
    }
    
    private func getSafeBottomViewBackgroundColor(route: VRRoute) -> UIColor {
        var safeBottomViewBackgroundColor = UIColor.g2
        switch route {
        case .listMenu(_, _):
            safeBottomViewBackgroundColor = .white
        case .featureSetting(_), .giftView, .connectionControl:
            safeBottomViewBackgroundColor = .bgOperateColor
        default:
            break
        }
        return safeBottomViewBackgroundColor
    }
}

// MARK: - Popup
extension VRRouterControlCenter {
    private func presentPopup(view: UIView, route: VRRoute, portraitPosition: MenuContainerViewPosition = .bottom) -> UIViewController {
        let safeBottomViewBackgroundColor = getSafeBottomViewBackgroundColor(route: route)
        let menuContainerView = MenuContainerView(contentView: view,
                                                  safeBottomViewBackgroundColor: safeBottomViewBackgroundColor,
                                                  portraitPosition: portraitPosition)
        menuContainerView.blackAreaClickClosure = { [weak self] in
            guard let self = self else { return }
            self.routerManager.router(action: .dismiss())
        }
        guard let rootViewController = rootViewController else { return UIViewController() }
        let presentingViewController = getPresentingViewController(rootViewController)
        let alertTransitionAnimator = AlertTransitionAnimator(duration: 0.5,transitionStyle: .present,transitionPosition: .fade)
        if portraitPosition != .bottom {
            let popupViewController = PopupViewController(contentView: menuContainerView,
                                                          supportBlurView: supportBlurView(route: route),alertTransitionAnimator: alertTransitionAnimator)
            presentingViewController.present(popupViewController, animated: true)
            return popupViewController
        } else  {
            let popupViewController = PopupViewController(contentView: menuContainerView,supportBlurView: supportBlurView(route: route))
            presentingViewController.present(popupViewController, animated: true)
            return popupViewController
        }
    }
}

// MARK: - Alert
extension VRRouterControlCenter {
    private func presentAlert(alertView: UIView) -> UIViewController {
        let alertContainerView = VRAlertContainerView(contentView: alertView)
        let alertTransitionAnimator = AlertTransitionAnimator(duration: 0.2,transitionStyle: .present,transitionPosition: .fade)
        let popupViewController = PopupViewController(contentView: alertContainerView,
                                                      supportBlurView: true,alertTransitionAnimator: alertTransitionAnimator)
        guard let rootViewController = rootViewController else { return UIViewController()}
        let presentingViewController = getPresentingViewController(rootViewController)
        presentingViewController.present(popupViewController, animated: true)

        return popupViewController
    }
}
