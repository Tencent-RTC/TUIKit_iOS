//
//  VideoLiveKit.swift
//  TUILiveKit-TUILiveKitBundle
//
//  Created by jack on 2024/9/29.
//

import AtomicXCore
import Foundation
import RTCRoomEngine
import TUICore

@objcMembers
public class VideoLiveKit: NSObject {
    private static let sharedInstance = VideoLiveKit()
    
    override private init() {}
    
    private weak var viewController: UIViewController?
    
    public static func createInstance() -> VideoLiveKit {
        return sharedInstance
    }
    
    @MainActor
    public func enableFollowFeature(_ enable: Bool) {
        enableFollow = enable
    }
    
    @MainActor
    public func startLive(roomId: String) {
        if FloatWindow.shared.isShowingFloatWindow() {
            if let ownerId = FloatWindow.shared.getRoomOwnerId(), ownerId == LoginStore.shared.state.value.loginUserInfo?.userID {
                getRootController()?.view.makeToast(message: .pushingToReturnText)
                return
            } else if FloatWindow.shared.getIsLinking() {
                getRootController()?.view.makeToast(message: .pushingToReturnText)
                return
            }
        }
        guard let listManager = TUIRoomEngine.sharedInstance().getExtension(extensionType: .liveListManager) as? TUILiveListManager else { return }
        listManager.getLiveInfo(roomId) { [weak self] liveInfo in
            guard let self = self else { return }
            if liveInfo.keepOwnerOnSeat {
                showPrepareViewController(roomId: roomId)
            } else {
                showAnchorViewController(roomId: roomId)
            }
        } onError: { [weak self] _, _ in
            guard let self = self else { return }
            showPrepareViewController(roomId: roomId)
        }
    }
    
    @MainActor
    public func stopLive(onSuccess: (() -> Void)?, onError: ((ErrorInfo) -> Void)?) {
        guard let vc = viewController as? TUILiveRoomAnchorViewController else {
            onSuccess?()
            return
        }
        vc.stopLive { [weak self] in
            guard let self = self else { return }
            onSuccess?()
            self.viewController = nil
        } onError: { code, message in
            onError?(ErrorInfo(code: code.rawValue, message: message))
        }
    }
    
    @MainActor
    public func joinLive(roomId: String) {
        let viewController = TUILiveRoomAudienceViewController(roomId: roomId)
        viewController.modalPresentationStyle = .fullScreen
        
        getRootController()?.present(viewController, animated: true)
        self.viewController = viewController
    }
    
    @MainActor
    public func leaveLive(onSuccess: (() -> Void)?, onError: ((ErrorInfo) -> Void)?) {
        if FloatWindow.shared.isShowingFloatWindow() {
            FloatWindow.shared.releaseFloatWindow()
            onSuccess?()
        } else if let vc = viewController as? TUILiveRoomAudienceViewController {
            vc.leaveLive { [weak self] in
                guard let self = self else { return }
                self.viewController?.dismiss(animated: true)
                self.viewController = nil
                onSuccess?()
            } onError: { err in
                onError?(err)
            }
        } else if let vc = viewController as? TUILiveRoomAnchorViewController {
            LiveListStore.shared.leaveLive { [weak self] result in
                guard let self = self else { return }
                switch result {
                case .success():
                    self.viewController?.dismiss(animated: true)
                    self.viewController = nil
                    onSuccess?()
                case .failure(let err):
                    onError?(err)
                }
            }
        } else {
            onSuccess?()
        }
    }
    
    var enableFollow: Bool = true
}

// MARK: - Private

extension VideoLiveKit {
    private func getRootController() -> UIViewController? {
        return TUITool.applicationKeywindow().rootViewController
    }

    private func showPrepareViewController(roomId: String) {
        let vc = TUILiveRoomAnchorPrepareViewController(roomId: roomId)
        vc.modalPresentationStyle = .fullScreen
        vc.willStartLive = { [weak self] controller in
            guard let self = self else { return }
            self.viewController = controller
        }
        getRootController()?.present(vc, animated: true)
    }

    private func showAnchorViewController(roomId: String) {
        var liveInfo = LiveInfo()
        liveInfo.liveID = roomId
        let anchorVC = TUILiveRoomAnchorViewController(liveInfo: liveInfo, behavior: .enterRoom)
        anchorVC.modalPresentationStyle = .fullScreen
        getRootController()?.present(anchorVC, animated: true)
    }
}

private extension String {
    static let pushingToReturnText = internalLocalized("Live streaming in progress. Please try again later.")
}
