//
//  TUICallKit.swift
//  TUICallKit
//
//  Created by vincepzhang on 2022/12/30.
//

import Foundation
import AtomicXCore

@objc
public class TUICallKit: NSObject {
    /**
     * Create a TUICallKit instance
     */
    @objc
    public static func createInstance() -> TUICallKit {
        return TUICallKitImpl.shared
    }
    
    /**
     * Set user profile
     *
     * @param nickname User name, which can contain up to 500 bytes
     * @param avatar   User profile photo URL, which can contain up to 500 bytes
     * For example: https://liteav.sdk.qcloud.com/app/res/picture/voiceroom/avatar/user_avatar1.png
     */
    public func setSelfInfo(nickname: String, avatar: String, completion: CompletionClosure?) {
        return TUICallKitImpl.shared.setSelfInfo(nickname: nickname, avatar: avatar, completion: completion)
    }
    
    /**
     * calls
     *
     * @param userIdList    List of userId
     * @param callMediaType Call type
     * @param params        Extension param: eg: offlinePushInfo
     */
    public func calls(userIdList: [String], callMediaType: CallMediaType, params: CallParams?, completion: CompletionClosure?) {
        return TUICallKitImpl.shared.calls(userIdList: userIdList, callMediaType: callMediaType, params: params, completion: completion)
    }
  
    /**
     * Join a current call
     *
     * @param callId        current call ID
     * @param callMediaType call type
     */
    public func join(callId: String, completion: CompletionClosure?) {
        return TUICallKitImpl.shared.join(callId: callId, completion: completion)
    }
    
    /**
     * Set the ringtone (preferably shorter than 30s)
     *
     * @param filePath Callee ringtone path
     */
    @objc
    public func setCallingBell(filePath: String) {
        return TUICallKitImpl.shared.setCallingBell(filePath: filePath)
    }
    
    /**
     * Enable the mute mode (the callee doesn't ring)
     */
    @objc public func enableMuteMode(enable: Bool) {
        return TUICallKitImpl.shared.enableMuteMode(enable: enable)
    }
    
    /**
     * Enable the floating window
     */
    @objc
    public func enableFloatWindow(enable: Bool) {
        return TUICallKitImpl.shared.enableFloatWindow(enable: enable)
    }
    
    /**
     * Enable Virtual Background
     */
    @objc
    public func enableVirtualBackground(enable: Bool) {
        return TUICallKitImpl.shared.enableVirtualBackground(enable: enable)
    }
    
    /**
     * Enable Incoming Banner
     */
    @objc
    public func enableIncomingBanner(enable: Bool) {
        return TUICallKitImpl.shared.enableIncomingBanner(enable: enable)
    }

    /**
     * Enable auto-start AI transcription when call is connected
     * @param enable true: AI transcription starts automatically when call connects; false: manual control via button
     * Default value: true
     */
    @objc
    public func enableAITranscriber(enable: Bool) {
        return TUICallKitImpl.shared.enableAITranscriber(enable: enable)
    }
    
    @objc
    public func callExperimentalAPI(jsonStr: String) {
        TUICallKitImpl.shared.callExperimentalAPI(jsonStr: jsonStr)
    }
    
    /**
     * Set the display direction of the CallKit interface. The default value is portrait
     * @param orientation 0-Portrait, 1-LandScape, 2-Auto;   default value: 0
     * Note: You are advised to use portrait mode to avoid abnormal display for small screen devices such as mobile phone
     */
    public func setScreenOrientation(orientation: Int, completion: CompletionClosure?) {
        return TUICallKitImpl.shared.setScreenOrientation(orientation: orientation, completion: completion)
    }
    
}
