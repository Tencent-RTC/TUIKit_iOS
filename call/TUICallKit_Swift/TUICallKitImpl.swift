//
//  TUICallKitImpl.swift
//  TUICallKit
//
//  Created by vincepzhang on 2023/1/4.
//

import Foundation
import TUICore
import UIKit
import RTCCommon
import AtomicXCore
import Combine

// TODO: 移除 RTCRoomEngine 的依赖
import RTCRoomEngine

class TUICallKitImpl: TUICallKit {
    static let shared = TUICallKitImpl()
    private var cancellables = Set<AnyCancellable>()
    private var hasSetDefaultDeviceState = false
    
    let globalState = GlobalState()
    let viewState = ViewState()
    let callingVibratorFeature = CallingVibratorFeature()
    let callingBellFeature = CallingBellFeature()
    let voipDataSyncHandler = VoIPDataSyncHandler()
    var pictureInPictureFeature: PictureInPictureFeature?

    override init() {
        super.init()
        subscribeCallState()
        addNotificationObserver()
        setupCallEventListener()
    }
    
    deinit {
        unSubscribeCallState()
        removeNotificationObserver()
        cancellables.forEach { $0.cancel() }
        cancellables.removeAll()
    }
    
        
    // MARK: Implementation of external interface for TUICallKit
    override func setScreenOrientation(orientation: Int, completion: CompletionClosure?) {
        guard let targetOrientation = Orientation(rawValue: orientation) else {
            completion?(.failure(ErrorInfo(code: ERROR_PARAM_INVALID, message: "Invalid screen orientation value")))
            return
        }
        globalState.orientation = Orientation(rawValue: orientation) ?? .portrait
        completion?(.success(()))
    }
    
    override func setSelfInfo(nickname: String, avatar: String, completion: CompletionClosure?) {
        var userProfile = LoginStore.shared.state.value.loginUserInfo
        userProfile?.nickname = nickname
        userProfile?.avatarURL = avatar
        LoginStore.shared.setSelfInfo(userProfile: userProfile ?? UserProfile(userID: LoginStore.shared.state.value.loginUserInfo?.userID ?? ""), completion: completion)
    }
    
    override func calls(userIdList: [String], callMediaType: CallMediaType, params: CallParams?, completion: CompletionClosure?) {
        if LoginStore.shared.state.value.loginUserInfo?.userID == nil {
            completion?(.failure(ErrorInfo(code: ERROR_INIT_FAIL, message: "call failed, please login")))
            return
        }
        
        if userIdList.count == 1 && userIdList.first == LoginStore.shared.state.value.loginUserInfo?.userID {
            Toast.showToast(TUICallKitLocalize(key: "TUICallKit.calNotCallYourself"))
            completion?(.failure(ErrorInfo(code: ERROR_INIT_FAIL, message: "call failed, not to call self")))
            return
        }
        
        let userIdList = userIdList.filter { $0 != LoginStore.shared.state.value.loginUserInfo?.userID }
        
        if userIdList.isEmpty {
            completion?(.failure(ErrorInfo(code: ERROR_PARAM_INVALID, message: "call failed, invalid params 'userIdList'")))
            return
        }
        
        if userIdList.count >= MAX_USER {
            Toast.showToast(TUICallKitLocalize(key: "TUICallKit.User.Exceed.Limit"))
            completion?(.failure(ErrorInfo(code: ERROR_PARAM_INVALID, message: "groupCall failed, currently supports call with up to 9 people")))
            return
        }
        
        if !Permission.hasPermission(callMediaType: callMediaType, completion: nil) {
             return
        }

        CallStore.shared.calls(participantIds: userIdList, callMediaType: callMediaType, params: params ?? getCallParams(), completion: completion)
    }
    
    override func join(callId: String, completion: CompletionClosure?) {
        CallStore.shared.join(callId: callId, completion: completion)
    }
    
    override func setCallingBell(filePath: String) {
        if filePath.hasPrefix("http") {
            let session = URLSession.shared
            guard let url = URL(string: filePath) else { return }
            let downloadTask = session.downloadTask(with: url) { location, response, error in
                if error != nil {
                    return
                }
                
                if location != nil {
                    if let oldBellFilePath = UserDefaults.standard.object(forKey: TUI_CALLING_BELL_KEY) as? String {
                        do {
                            try FileManager.default.removeItem(atPath: oldBellFilePath)
                        } catch let error {
                            debugPrint("FileManager Error: \(error)")
                        }
                    }
                    guard let location = location else { return }
                    guard let dstDocPath = NSSearchPathForDirectoriesInDomains(.cachesDirectory, .userDomainMask, true).last else { return }
                    let dstPath = dstDocPath + "/" + location.lastPathComponent
                    do {
                        try FileManager.default.moveItem(at: location, to: URL(fileURLWithPath: dstPath))
                    } catch let error {
                        debugPrint("FileManager Error: \(error)")
                    }
                    UserDefaults.standard.set(dstPath, forKey: TUI_CALLING_BELL_KEY)
                    UserDefaults.standard.synchronize()
                }
            }
            downloadTask.resume()
        } else {
            UserDefaults.standard.set(filePath, forKey: TUI_CALLING_BELL_KEY)
            UserDefaults.standard.synchronize()
        }
    }
    
    override func enableMuteMode(enable: Bool) {
        UserDefaults.standard.set(enable, forKey: ENABLE_MUTEMODE_USERDEFAULT)
    }
    
    override func enableFloatWindow(enable: Bool) {
        globalState.enableFloatWindow = enable
    }
    
    override func enableVirtualBackground (enable: Bool) {
        globalState.enableVirtualBackground = enable
        setEnableVirtualBackgroundFramework(enable)
    }
    
    override func enableIncomingBanner (enable: Bool) {
        globalState.enableIncomingBanner = enable
    }
    
    override func callExperimentalAPI(jsonStr: String) {
        // TODO: 替换为 CallStore 的方法
        TUICallEngine.createInstance().callExperimentalAPI(jsonObject: jsonStr)
    }
    
    func enableMultiDeviceAbility(enable: Bool, completion: CompletionClosure?) {
        globalState.enableMultiDeviceAbility = enable
        // TODO: 替换为 CallStore 的方法
        TUICallEngine.createInstance().enableMultiDeviceAbility(enable: enable) {
            completion?(.success(()))
        } fail: { code, message in
            Logger.info("TUICallKitImpl enableMultiDeviceAbility failed.  code: \(code), message: \(message)")
            completion?(.failure(ErrorInfo(code: Int(code), message: message ?? "")))
        }
    }
}

// MARK: Subscribe
extension TUICallKitImpl {
    func addNotificationObserver() {
        NotificationCenter.default.addObserver(self, selector: #selector(loginSuccess(_:)),
                                               name: Notification.Name.TUILoginSuccess,
                                               object: nil)
        NotificationCenter.default.addObserver(self,
                                               selector: #selector(logoutSuccess),
                                               name: NSNotification.Name.TUILogoutSuccess,
                                               object: nil)
        NotificationCenter.default.addObserver(self,
                                               selector: #selector(applicationWillTerminate),
                                               name: UIApplication.willTerminateNotification,
                                               object: nil)
        
        NotificationCenter.default.publisher(for: NSNotification.Name(EVENT_SHOW_TOAST))
            .receive(on: RunLoop.main)
            .sink { [weak self] notification in
                self?.handleShowToast(notification)
            }
            .store(in: &cancellables)
    }
    
    func removeNotificationObserver() {
        NotificationCenter.default.removeObserver(Notification.Name.TUILoginSuccess)
        NotificationCenter.default.removeObserver(Notification.Name.TUILogoutSuccess)
        NotificationCenter.default.removeObserver(UIApplication.willTerminateNotification)
    }
    
    func subscribeCallState() {
        CallStore.shared.state.subscribe(StatePublisherSelector<CallState, CallParticipantStatus>(keyPath: \.selfInfo.status))
            .removeDuplicates()
            .receive(on: RunLoop.main)
            .sink { [weak self] newStatus in
                guard let self = self else { return }
                self.syncVoIPStatus()
                self.handleCallParticipantStatusChanged(newStatus)
            }
            .store(in: &cancellables)
        
        DeviceStore.shared.state.subscribe(StatePublisherSelector<DeviceState, DeviceStatus>(keyPath: \.microphoneStatus))
            .removeDuplicates()
            .receive(on: RunLoop.main)
            .sink { [weak self] newStatus in
                guard let self = self else { return }
                self.voipDataSyncHandler.setVoIPMute(newStatus == .off)
            }
            .store(in: &cancellables)
    }
    
    private func handleCallParticipantStatusChanged(_ newStatus: CallParticipantStatus) {
        switch newStatus {
        case .accept:
            if !hasSetDefaultDeviceState {
                setDefaultDeviceState()
                hasSetDefaultDeviceState = true
            }
        default:
            break
        }
    }
    
    func unSubscribeCallState() {
        cancellables.removeAll()
    }
}

// MARK: Private
extension TUICallKitImpl {
    private func showCallKitViewController(isCaller: Bool) {
        if isCaller {
            if self.viewState.router.value != .floatView {
                WindowManager.shared.showCallingWindow()
                TUICore.notifyEvent(TUICore_PrivacyService_ROOM_STATE_EVENT_CHANGED,
                                    subKey: TUICore_PrivacyService_ROOM_STATE_EVENT_SUB_KEY_START,
                                    object: nil,
                                    param: nil)
            }
        } else {
            if self.globalState.enableIncomingBanner {
                WindowManager.shared.showIncomingBannerWindow()
            } else {
                if self.viewState.router.value != .floatView {
                    WindowManager.shared.showCallingWindow()
                    TUICore.notifyEvent(TUICore_PrivacyService_ROOM_STATE_EVENT_CHANGED,
                                        subKey: TUICore_PrivacyService_ROOM_STATE_EVENT_SUB_KEY_START,
                                        object: nil,
                                        param: nil)
                }
            }
        }
    }
    
    private func closeCallKitViewController() {
        WindowManager.shared.closeWindow()
        TUICore.notifyEvent(TUICore_PrivacyService_ROOM_STATE_EVENT_CHANGED,
                            subKey: TUICore_PrivacyService_ROOM_STATE_EVENT_SUB_KEY_END,
                            object: nil,
                            param: nil)
    }
    
    private func syncVoIPStatus() {
        let selfStatus = CallStore.shared.state.value.selfInfo.status
        let isCalled = CallStore.shared.state.value.selfInfo.id != CallStore.shared.state.value.activeCall.inviterId
        
        if selfStatus == .waiting && isCalled {
            voipDataSyncHandler.updateCallInfo(callerId: CallStore.shared.state.value.activeCall.inviterId, calleeList: CallStore.shared.state.value.activeCall.inviteeIds, groupId: CallStore.shared.state.value.activeCall.chatGroupId, mediaType: CallStore.shared.state.value.activeCall.mediaType)
            
            return
        }
        
        if selfStatus == .none {
            voipDataSyncHandler.closeVoIP()
            return
        }
        
        if selfStatus == .accept {
            voipDataSyncHandler.callBegin()
            return
        }
    }
    
    @objc func handleShowToast(_ notification: Notification) {
        guard let data = notification.object as? String else { return }
        Toast.shared.showToast(message: data)
    }
    
    @objc func logoutSuccess() {
        CallStore.shared.hangup(completion: nil)
        TUICallEngine.destroyInstance()
    }
    
    @objc func loginSuccess(_ notification: Notification) {
        //TODO: CallEngine 的 init 方法下沉至 Store 中完成
        LoginStore.shared.login(sdkAppID: TUILogin.getSdkAppID(), userID: TUILogin.getUserID() ?? "", userSig: TUILogin.getUserSig() ?? "", completion: nil)
        TUICallEngine.createInstance().`init`(TUILogin.getSdkAppID(), userId: TUILogin.getUserID() ?? "", userSig: TUILogin.getUserSig() ?? "") { [weak self] in
            guard let self = self else { return }
            self.enableVirtualBackground(enable: self.globalState.enableVirtualBackground)
            if globalState.enablePictureInPicture {
                pictureInPictureFeature = PictureInPictureFeature()
            }
        } fail: { code, message in
            Logger.error("TUICallKitImpl initEngine failed. code: \(code), message: \(message)")
        }
        
        setFramework()
        setExcludeFromHistoryMessage()
    }
    
    @objc func applicationWillTerminate() {
        let selfInfo = CallStore.shared.state.value.selfInfo
        guard selfInfo.status != .none else { return }
        
        let activeCall = CallStore.shared.state.value.activeCall
        let isCaller = selfInfo.id == activeCall.inviterId
        
        if isCaller {
            CallStore.shared.hangup(completion: nil)
        } else {
            if selfInfo.status == .waiting {
                CallStore.shared.reject(completion: nil)
            } else {
                CallStore.shared.hangup(completion: nil)
            }
        }
    }
    
    private func getCallParams() -> CallParams {
        var callParams = CallParams()
        callParams.timeout = Int(TUI_CALLKIT_SIGNALING_MAX_TIME)
        return callParams
    }
    
    private func setExcludeFromHistoryMessage() {
        if TUICore.getService(TUICore_TUIChatService) == nil {
            return
        }
        
        let jsonParams: [String: Any] = ["api": "setExcludeFromHistoryMessage",
                                         "params": ["excludeFromHistoryMessage": false,],]
        guard let data = try? JSONSerialization.data(withJSONObject: jsonParams,
                                                     options: JSONSerialization.WritingOptions(rawValue: 0)) else {
            return
        }
        guard let paramsString = NSString(data: data, encoding: String.Encoding.utf8.rawValue) as? String else {
            return
        }
        
        //TODO: 替换为 CallStore 中的方法
        TUICallEngine.createInstance().callExperimentalAPI(jsonObject: paramsString)
    }
    
    private func setEnableVirtualBackgroundFramework(_ enableVirtualBackground: Bool) {
        let msgDic: [String: Any] = ["enablevirtualbackground": enableVirtualBackground,
                                     "version": TUICALL_VERSION,
                                     "platform": "iOS",
                                     "framework": "native",
                                     "sdk_app_id": TUILogin.getSdkAppID(),]
        guard let msgData = try? JSONSerialization.data(withJSONObject: msgDic,
                                                        options: JSONSerialization.WritingOptions(rawValue: 0)) else {
            return
        }
        guard let msgString = NSString(data: msgData, encoding: String.Encoding.utf8.rawValue) as? String else {
            return
        }
        let jsonParams: [String: Any] = ["api": "reportOnlineLog",
                                         "params": ["level": 1,
                                                    "msg":msgDic,
                                                    "more_msg":"TUICallkit"],]
        guard let data = try? JSONSerialization.data(withJSONObject: jsonParams,
                                                     options: JSONSerialization.WritingOptions(rawValue: 0)) else {
            return
        }
        guard let paramsString = NSString(data: data, encoding: String.Encoding.utf8.rawValue) as? String else {
            return
        }
        
        //TODO: 替换为 CallStore 中的方法
        TUICallEngine.createInstance().getTRTCCloudInstance().callExperimentalAPI(paramsString)
    }
    
    private func setFramework() {
        var jsonParams: [String: Any]
        if TUICore.getService(TUICore_TUIChatService) == nil {
            jsonParams = ["api": "setFramework",
                          "params": ["framework": FrameworkConstants.framework,
                                     "component": FrameworkConstants.component,
                                     "language": FrameworkConstants.language,],]
        } else {
            jsonParams = ["api": "setFramework",
                          "params": ["framework": FrameworkConstants.framework,
                                     "component": FrameworkConstants.callComponentChat,
                                     "language": FrameworkConstants.language,],]
        }
        
        guard let data = try? JSONSerialization.data(withJSONObject: jsonParams,
                                                     options: JSONSerialization.WritingOptions(rawValue: 0)) else {
            return
        }
        guard let paramsString = NSString(data: data, encoding: String.Encoding.utf8.rawValue) as? String else {
            return
        }
        
        //TODO: 替换为 CallStore 中的方法
        TUICallEngine.createInstance().callExperimentalAPI(jsonObject: paramsString)
    }
}

extension TUICallKitImpl {
    func setupCallEventListener() {
        CallStore.shared.callEventPublisher
            .receive(on: RunLoop.main)
            .sink { [weak self] event in
                guard let self = self else { return }
                self.handleCallEvent(event)
            }
            .store(in: &cancellables)
    }
    
    func handleCallEvent(_ event: CallEvent) {
        switch event {
        case .onCallStarted(_, _):
            if !hasSetDefaultDeviceState {
                setDefaultDeviceState()
                hasSetDefaultDeviceState = true
            }
            showCallKitViewController(isCaller: true)
            
        case .onCallReceived(_, _, _):
            showCallKitViewController(isCaller: false)
            
        case let .onCallEnded(callId: _, mediaType: _, reason: reason, userId: userId):
            hasSetDefaultDeviceState = false
            closeCallKitViewController()
            handleCallEnded(reason: reason, userId: userId)
        }
    }
    
    func handleCallEnded(reason: CallEndReason, userId: String) {
        if CallStore.shared.state.value.selfInfo.id.isEmpty || userId == CallStore.shared.state.value.selfInfo.id {
            return
        }
        let isGroupCall = !CallStore.shared.state.value.activeCall.chatGroupId.isEmpty || CallStore.shared.state.value.activeCall.inviteeIds.count > 1
        if isGroupCall {
            return
        }
        let messageKey: String?
        switch reason {
        case .hangup:
            messageKey = "TUICallKit.otherPartyHangup"
        case .reject:
            messageKey = "TUICallKit.otherPartyReject"
        case .lineBusy:
            messageKey = "TUICallKit.lineBusy"
        case .noResponse:
            messageKey = "TUICallKit.otherPartyNoResponse"
        default:
            messageKey = nil
        }
        guard let messageKey = messageKey else { return }
        let message = TUICallKitLocalize(key: messageKey) ?? ""
        if message.isEmpty { return }
        NotificationCenter.default.post(name: NSNotification.Name(rawValue: EVENT_SHOW_TOAST), object: message)
    }
    
    func setDefaultDeviceState() {
        let activeCall = CallStore.shared.state.value.activeCall
        let mediaType = activeCall.mediaType
        let deviceStore = DeviceStore.shared

        deviceStore.openLocalMicrophone(completion: nil)

        if mediaType == .audio {
            deviceStore.setAudioRoute(.earpiece)
        } else {
            deviceStore.setAudioRoute(.speakerphone)
            deviceStore.openLocalCamera(isFront: true, completion: nil)
        }
    }

}
