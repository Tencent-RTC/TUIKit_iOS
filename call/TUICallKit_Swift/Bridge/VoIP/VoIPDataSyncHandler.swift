//
//  VoIPDataSyncHandler.swift
//  Pods
//
//  Created by vincepzhang on 2024/11/25.
//

import Foundation
import TUICore
import AtomicX
import UIKit
import AtomicXCore

class VoIPDataSyncHandler {
        
    func onCall(_ method: String, param: [AnyHashable : Any]?) {
        guard let param = param else { return }
        
        if method == TUICore_TUICallingService_SetAudioPlaybackDeviceMethod {
            let key = TUICore_TUICallingService_SetAudioPlaybackDevice_AudioPlaybackDevice
            guard let value = param[key] as? UInt else { return }
            let audioPlaybackDevice: AudioRoute
            if value == 1 {
                audioPlaybackDevice = .earpiece
            } else {
                audioPlaybackDevice = .speakerphone
            }
            
            Logger.info("VoIPDataSyncHandler - onCall - selectAudioPlaybackDevice. route:\(audioPlaybackDevice)")
            DeviceStore.shared.setAudioRoute(audioPlaybackDevice)
            
        } else if method == TUICore_TUICallingService_SetIsMicMuteMethod {
            guard let isMicMute = param[TUICore_TUICallingService_SetIsMicMuteMethod_IsMicMute] as? Bool else {
                return
            }

            if isMicMute {
                Logger.info("VoIPDataSyncHandler - onCall - closeMicrophone")
                DeviceStore.shared.closeLocalMicrophone()
            } else {
                Logger.info("VoIPDataSyncHandler - onCall - openMicrophone")
                DeviceStore.shared.openLocalMicrophone(completion: nil)
            }
        } else if method == TUICore_TUICallingService_HangupMethod {
            if CallStore.shared.state.value.selfInfo.status == .accept {
                Logger.info("VoIPDataSyncHandler - onCall - hangup")
                CallStore.shared.hangup(completion: nil)
            } else {
                Logger.info("VoIPDataSyncHandler - onCall - reject")
                CallStore.shared.reject(completion: nil)
            }
        } else if  method == TUICore_TUICallingService_AcceptMethod {
            Logger.info("VoIPDataSyncHandler - onCall - accept")
            CallStore.shared.accept(completion: nil)
        }
    }
        
    func setVoIPMute(_ mute: Bool) {
        Logger.info("VoIPDataSyncHandler - setVoIPMute. mute:\(mute)")
        TUICore.notifyEvent(TUICore_TUIVoIPExtensionNotify,
                            subKey: TUICore_TUICore_TUIVoIPExtensionNotify_MuteSubKey,
                            object: nil,
                            param: [TUICore_TUICore_TUIVoIPExtensionNotify_MuteSubKey_IsMuteKey: mute])

    }
    
    func closeVoIP() {
        Logger.info("VoIPDataSyncHandler - closeVoIP")
        TUICore.notifyEvent(TUICore_TUIVoIPExtensionNotify,
                            subKey: TUICore_TUICore_TUIVoIPExtensionNotify_EndSubKey,
                            object: nil,
                            param: nil)
    }
    
    func callBegin() {
        Logger.info("VoIPDataSyncHandler - callBegin")
        TUICore.notifyEvent(TUICore_TUIVoIPExtensionNotify,
                            subKey: TUICore_TUICore_TUIVoIPExtensionNotify_ConnectedKey,
                            object: nil,
                            param: nil)
    }
    
    func updateCallInfo(callerId: String, calleeList: [String], groupId: String, mediaType: CallMediaType?) {
        Logger.info("VoIPDataSyncHandler - updateCallInfo")
        let mediaTypeVal = mediaType?.rawValue ?? 2
        TUICore.notifyEvent(TUICore_TUIVoIPExtensionNotify,
                            subKey: TUICore_TUICore_TUIVoIPExtensionNotify_UpdateInfoSubKey,
                            object: nil,
                            param: [TUICore_TUICore_TUIVoIPExtensionNotify_UpdateInfoSubKey_InviterIdKey: callerId,
                                  TUICore_TUICore_TUIVoIPExtensionNotify_UpdateInfoSubKey_InviteeListKey: calleeList,
                                      TUICore_TUICore_TUIVoIPExtensionNotify_UpdateInfoSubKey_GroupIDKey: groupId,
                                    TUICore_TUICore_TUIVoIPExtensionNotify_UpdateInfoSubKey_MediaTypeKey: mediaTypeVal])
    }
}
