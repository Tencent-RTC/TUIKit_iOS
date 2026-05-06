//
//  FloatWindow.swift
//
//  Created by chensshi on 2024/11/15.
//

import SnapKit
import Foundation
import AtomicXCore
import AtomicX
import Combine
import RTCRoomEngine

public protocol FloatWindowProvider: AnyObject {
    func getRoomId() -> String
    func getOwnerId() -> String
    func getIsLinking() -> Bool
    // TODO: (gg) Need to consider the type of VoiceRoom's coreView
    func getCoreView() -> LiveCoreView
    func relayoutCoreView()
}

public class FloatWindow: NSObject {
    public static let shared = FloatWindow()
    private override init() {
        super.init()
        NotificationCenter.default.addObserver(self,selector: #selector(handleLogoutNotification),
                                               name: NSNotification.Name(rawValue: NSNotification.Name.TUILogoutSuccess.rawValue),
                                               object: nil)
    }
    @Published private var isShow : Bool = false
    private var floatView: FloatView?
    private var controller: UIViewController?
    private weak var provider: FloatWindowProvider?
    private var coreView: LiveCoreView?
    @objc private func handleLogoutNotification() {
        if isShow == true {
            releaseFloatWindow()
        }
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }
}

// MARK: -------------- API --------------
public extension FloatWindow {
    @discardableResult
    func showFloatWindow(controller: UIViewController, provider: FloatWindowProvider) -> Bool {
        guard !isShow else { return false }
        
        self.controller = controller
        self.provider = provider
        let coreView = provider.getCoreView()
        self.coreView = coreView
        
        if let nav = controller.navigationController {
            nav.popViewController(animated: true)
        } else {
            controller.dismiss(animated: true)
        }
        
        coreView.safeRemoveFromSuperview()
        
        isShow = true
        LiveKitLog.info("\(#file)", "\(#line)", "FloatWindow show")
        TUIRoomEngine.sharedInstance().addObserver(self)
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) { [weak self] in
            guard let self = self, self.isShow else { return }
            guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
                  let window = windowScene.windows.first(where: { $0.isKeyWindow }) else { return }
            
            let floatView = FloatView(contentView: coreView)
            floatView.layoutSubviews()
            floatView.delegate = self
            window.addSubview(floatView)
            self.floatView = floatView
            
            floatView.isUserInteractionEnabled = false
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { [weak floatView] in
                floatView?.isUserInteractionEnabled = true
            }
        }
        
        return true
    }
    
    @discardableResult
    func resumeLive(atViewController: UIViewController) -> Bool {
        guard isShow, let controller = controller, let dataSource = provider else { return false }
        LiveKitLog.info("\(#file)", "\(#line)", "FloatWindow resume")
        controller.modalPresentationStyle = .fullScreen
        WindowUtils.getCurrentWindow()?.rootViewController?.present(controller, animated: true) {
            dataSource.relayoutCoreView()
        }
        dismiss()
        return true
    }
    
    func releaseFloatWindow() {
        LiveKitLog.info("\(#file)", "\(#line)", "FloatWindow release")
        leaveRoom()
        dismiss()
    }
    
    func isShowingFloatWindow() -> Bool {
        return isShow
    }
    
    func getCurrentRoomId() -> String? {
        guard let dataSource = provider else { return nil }
        return dataSource.getRoomId()
    }
    
    func getRoomOwnerId() -> String? {
        guard let dataSource = provider else { return nil }
        return dataSource.getOwnerId()
    }
    
    func getIsLinking() -> Bool {
        guard let dataSource = provider else { return false }
        return dataSource.getIsLinking()
    }
    
    func subscribeShowingState() -> AnyPublisher<Bool, Never> {
        $isShow.eraseToAnyPublisher()
    }
}

// MARK: -------------- IMPL --------------
private extension FloatWindow {
    func dismiss() {
        controller = nil
        coreView = nil
        floatView?.safeRemoveFromSuperview()
        floatView = nil
        isShow = false
        TUIRoomEngine.sharedInstance().removeObserver(self)
    }
    
    func leaveRoom() {
        let store = LiveListStore.shared
        let state = store.state.value
        if state.currentLive.liveOwner.userID == LoginStore.shared.state.value.loginUserInfo?.userID {
            store.endLive(completion: nil)
        } else {
            store.leaveLive(completion: nil)
        }
    }
}

// MARK: - FloatViewDelegate
extension FloatWindow: FloatViewDelegate {
    func onResume() {
        if let nav = controller?.navigationController {
            resumeLive(atViewController: nav)
        } else if let vc = WindowUtils.getCurrentWindow()?.rootViewController {
            resumeLive(atViewController: vc)
        } else {
            LiveKitLog.info("\(#file)", "\(#line)","FloatWindow onResume cant found controller to present")
            releaseFloatWindow()
        }
    }
}

// MARK: - Observer
extension FloatWindow: TUIRoomObserver {
    public func onRoomDismissed(roomId: String, reason: TUIRoomDismissedReason) {
        WindowUtils.getCurrentWindow()?.rootViewController?.view.showAtomicToast(text: .liveHasStopText, style: .info)
        releaseFloatWindow()
    }
    
    public func onKickedOutOfRoom(roomId: String, reason: TUIKickedOutOfRoomReason, message: String) {
        releaseFloatWindow()
    }
    
    public func onKickedOffLine(message: String) {
        releaseFloatWindow()
    }
}

fileprivate extension String {
    static let liveHasStopText = internalLocalized("common_live_has_stop")
}
