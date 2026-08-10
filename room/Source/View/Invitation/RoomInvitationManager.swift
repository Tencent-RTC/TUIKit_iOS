//
//  RoomInvitationManager.swift
//  TUIRoomKit
//
//  Created by adamsfliu on 2026/8/5.
//  Copyright © 2026 Tencent. All rights reserved.
//

import UIKit
import Combine
import AtomicXCore
import UserNotifications

// MARK: - RoomInvitationObserver
public protocol RoomInvitationObserver: AnyObject {
    func onCallReceived(roomInfo: RoomInfo, call: RoomCall, extensionInfo: String)
    func onCallCancelled(roomInfo: RoomInfo, call: RoomCall)
    func onRoomEnded(roomInfo: RoomInfo)
    func onScheduledRoomCancelled(roomInfo: RoomInfo, operatorUser: RoomUser)
    func onRemovedFromScheduledRoom(roomInfo: RoomInfo, operatorUser: RoomUser)
}

public extension RoomInvitationObserver {
    func onCallReceived(roomInfo: RoomInfo, call: RoomCall, extensionInfo: String) {}
    func onCallCancelled(roomInfo: RoomInfo, call: RoomCall) {}
    func onRoomEnded(roomInfo: RoomInfo) {}
    func onScheduledRoomCancelled(roomInfo: RoomInfo, operatorUser: RoomUser) {}
    func onRemovedFromScheduledRoom(roomInfo: RoomInfo, operatorUser: RoomUser) {}
}

// MARK: - RoomInvitationManager
public class RoomInvitationManager: NSObject {

    public static let shared = RoomInvitationManager()

    // MARK: - Observers

    private var observers = NSHashTable<AnyObject>.weakObjects()

    // MARK: - State

    private let roomStore = RoomStore.shared
    private var cancellableSet = Set<AnyCancellable>()
    private weak var invitationViewController: RoomInvitationReceivedViewController?
    private lazy var bellFeature = BellFeature()
    private lazy var vibrationFeature = VibrationFeature()

    private override init() {}

    // MARK: - Lifecycle

    public func startRoomEventObserver() {
        guard cancellableSet.isEmpty else { return }
        roomStore.roomEventPublisher
            .receive(on: RunLoop.main)
            .sink { [weak self] event in
                self?.handleRoomEvent(event)
            }
            .store(in: &cancellableSet)
    }

    public func setAPNsCertificateID(_ apnsCertificateID: Int) {
        LoginStore.shared.setCertificateID(apnsCertificateID: apnsCertificateID)
        UNUserNotificationCenter.current().delegate = self
    }

    public func stopRoomEventObserver() {
        cancellableSet.removeAll()
        stopCallingBell()
        stopVibration()
        dismissInvitation()
    }

    public func destroy() {
        stopRoomEventObserver()
        observers.removeAllObjects()
    }

    // MARK: - Observer Management

    public func addObserver(_ observer: RoomInvitationObserver) {
        observers.add(observer as AnyObject)
    }

    public func removeObserver(_ observer: RoomInvitationObserver) {
        observers.remove(observer as AnyObject)
    }

    private func notifyObservers(_ block: (RoomInvitationObserver) -> Void) {
        for observer in observers.allObjects {
            if let obs = observer as? RoomInvitationObserver {
                block(obs)
            }
        }
    }

    // MARK: - Event Handling

    private func handleRoomEvent(_ event: RoomEvent) {
        switch event {
        case .onCallReceived(let roomInfo, let call, let extensionInfo):
            handleCallReceived(roomInfo: roomInfo, call: call, extensionInfo: extensionInfo)
        case .onCallCancelled(let roomInfo, let call):
            handleCallCancelled(roomInfo: roomInfo, call: call)
        case .onRoomEnded(let roomInfo):
            notifyObservers { $0.onRoomEnded(roomInfo: roomInfo) }
        case .onScheduledRoomCancelled(let roomInfo, let operatorUser):
            notifyObservers { $0.onScheduledRoomCancelled(roomInfo: roomInfo, operatorUser: operatorUser) }
        case .onRemovedFromScheduledRoom(let roomInfo, let operatorUser):
            notifyObservers { $0.onRemovedFromScheduledRoom(roomInfo: roomInfo, operatorUser: operatorUser) }
        default:
            break
        }
    }

    private func handleCallReceived(roomInfo: RoomInfo, call: RoomCall, extensionInfo: String) {
        guard invitationViewController == nil else {
            roomStore.rejectCall(roomID: roomInfo.roomID, reason: .rejected) { _ in }
            return
        }
        presentInvitation(roomInfo: roomInfo, call: call)
        notifyObservers { $0.onCallReceived(roomInfo: roomInfo, call: call, extensionInfo: extensionInfo) }
    }

    private func handleCallCancelled(roomInfo: RoomInfo, call: RoomCall) {
        dismissInvitation()
        notifyObservers { $0.onCallCancelled(roomInfo: roomInfo, call: call) }
    }

    // MARK: - Invitation Presentation

    private func presentInvitation(roomInfo: RoomInfo, call: RoomCall) {
        guard invitationViewController == nil else { return }
        guard let topVC = topViewController() else { return }

        let vc = RoomInvitationReceivedViewController(roomInfo: roomInfo, caller: call.caller)
        vc.modalPresentationStyle = .fullScreen
        invitationViewController = vc
        topVC.present(vc, animated: true)
        startCallingBell()
        playVibration()
    }

    public func dismissInvitation() {
        stopCallingBell()
        stopVibration()
        invitationViewController?.dismiss(animated: true)
        invitationViewController = nil
    }

    // MARK: - Public Call Actions

    public func acceptCall(roomInfo: RoomInfo, completion: @escaping (ErrorInfo?) -> Void) {
        stopCallingBell()
        stopVibration()
        roomStore.acceptCall(roomID: roomInfo.roomID) { [weak self] result in
            DispatchQueue.main.async {
                guard let self = self else { return }
                switch result {
                case .success:
                    self.enterRoom(roomInfo: roomInfo)
                    completion(nil)
                case .failure(let error):
                    completion(error)
                }
            }
        }
    }

    public func rejectCall(roomID: String, completion: @escaping (ErrorInfo?) -> Void) {
        stopCallingBell()
        stopVibration()
        roomStore.rejectCall(roomID: roomID, reason: .rejected) { [weak self] result in
            DispatchQueue.main.async {
                guard let self = self else { return }
                switch result {
                case .success:
                    self.dismissInvitation()
                    completion(nil)
                case .failure(let error):
                    completion(error)
                }
            }
        }
    }

    public func enterRoom(roomInfo: RoomInfo) {
        let config = ConnectConfig(autoEnableCamera: false)
        let mainViewController = RoomMainViewController(roomID: roomInfo.roomID,
                                                        behavior: .join,
                                                        config: config)
        invitationViewController?.dismiss(animated: true) { [weak self] in
            guard let self = self else { return }
            if let navi = self.topViewController() as? UINavigationController {
                navi.pushViewController(mainViewController, animated: true)
                return
            }
            
            if let navi = self.topViewController()?.navigationController {
                navi.pushViewController(mainViewController, animated: true)
                return
            }
            
            mainViewController.modalPresentationStyle = .fullScreen
            self.topViewController()?.present(mainViewController, animated: true)
        }
        invitationViewController = nil
    }

    // MARK: - Calling Bell

    private func startCallingBell() {
        bellFeature.playBell()
    }

    private func stopCallingBell() {
        bellFeature.stopBell()
    }

    // MARK: - Vibration

    private func playVibration() {
        vibrationFeature.playVibrate()
    }

    private func stopVibration() {
        vibrationFeature.stopVibrate()
    }

    // MARK: - Utilities

    private func topViewController() -> UIViewController? {
        guard let scene = UIApplication.shared.connectedScenes
            .compactMap({ $0 as? UIWindowScene })
            .first(where: { $0.activationState == .foregroundActive }),
              let window = scene.windows.first(where: { $0.isKeyWindow }),
              let root = window.rootViewController else {
            return nil
        }
        var top = root
        while let presented = top.presentedViewController {
            top = presented
        }
        return top
    }
}

// MARK: - UNUserNotificationCenterDelegate
extension RoomInvitationManager: UNUserNotificationCenterDelegate {
    public func userNotificationCenter(_ center: UNUserNotificationCenter,
                                       willPresent notification: UNNotification,
                                       withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        completionHandler([.banner, .sound, .badge])
    }

    public func userNotificationCenter(_ center: UNUserNotificationCenter,
                                       didReceive response: UNNotificationResponse,
                                       withCompletionHandler completionHandler: @escaping () -> Void) {
        let userInfo = response.notification.request.content.userInfo
        handleNotification(userInfo: userInfo)
        completionHandler()
    }

    private func handleNotification(userInfo: [AnyHashable: Any]) {
        guard let notificationExt = userInfo["ext"] as? String else { return }
        guard let extData = notificationExt.data(using: .utf8),
              let dict = try? JSONSerialization.jsonObject(with: extData) as? [String: Any] else { return }

        guard let roomId = dict["RoomId"] as? String else { return }
        guard let notificationType = dict["NotificationType"] as? String else { return }

        guard LoginStore.shared.state.value.loginStatus == .logined else { return }
        switch notificationType {
        case "conference_will_start":
            getRoomInfo(roomID: roomId) { [weak self] roomInfo in
                guard let self = self else { return }
                enterRoom(roomInfo: roomInfo)
            }
            break
        case "conference_invitation":
            getRoomInfo(roomID: roomId) { [weak self] roomInfo in
                guard let self = self else { return }
                checkPendingCallsAndPresent(roomInfo: roomInfo, cursor: nil)
            }
        default:
            break
        }
    }

    private func getRoomInfo(roomID: String, completion: @escaping (RoomInfo) -> Void) {
        roomStore.getRoomInfo(roomID: roomID) { result in
            DispatchQueue.main.async {
                switch result {
                case .success(let roomInfo):
                    completion(roomInfo)
                case .failure:
                    break
                }
            }
        }
    }

    private func checkPendingCallsAndPresent(roomInfo: RoomInfo, cursor: String?) {
        roomStore.getPendingCalls(roomID: roomInfo.roomID, cursor: cursor) { [weak self] result in
            DispatchQueue.main.async {
                guard let self = self else { return }
                switch result {
                case .success(let (calls, nextCursor)):
                    let selfUserID = LoginStore.shared.state.value.loginUserInfo?.userID ?? ""
                    for call in calls {
                        if call.callee.userID != selfUserID {
                            continue
                        }
                        if call.status == .calling {
                            self.presentInvitation(roomInfo: roomInfo, call: call)
                            return
                        }
                    }
                    if !nextCursor.isEmpty {
                        self.checkPendingCallsAndPresent(roomInfo: roomInfo, cursor: nextCursor)
                    }
                case .failure:
                    break
                }
            }
        }
    }
}
