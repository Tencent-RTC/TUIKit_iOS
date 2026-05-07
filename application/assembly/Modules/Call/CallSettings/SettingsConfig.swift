//
//  SettingsConfig.swift
//  AppAssembly
//

import Foundation
import TUICore
import RTCRoomEngine

#if canImport(TUICallKit_Swift)
import TUICallKit_Swift
#elseif canImport(TUICallKit)
import TUICallKit
#endif

class SettingsConfig {
    
    static let share = SettingsConfig()
    
    var userId = ""
    var avatar = ""
    var name = ""
    var ringUrl = ""
    
    var mute: Bool = false
    var floatWindow: Bool = true
    var enableVirtualBackground: Bool = true
    var enableIncomingBanner: Bool = true
    var enableAITranscriber: Bool = true
    var intRoomId: UInt32 = 0
    var strRoomId: String = ""
    var timeout: Int = 60
    var userData: String = ""
    let pushInfo: TUIOfflinePushInfo = {
        let pushInfo: TUIOfflinePushInfo = TUIOfflinePushInfo()
        pushInfo.title = "NEW CALL"
        pushInfo.desc = "You have a new call invitation!"
        pushInfo.iOSPushType = .apns
        pushInfo.ignoreIOSBadge = false
        pushInfo.iOSSound = "phone_ringing.mp3"
        pushInfo.androidSound = "phone_ringing"
        pushInfo.androidOPPOChannelID = "tuikit"
        pushInfo.androidFCMChannelID = "fcm_push_channel"
        pushInfo.androidVIVOClassification = 1
        pushInfo.androidHuaWeiCategory = "IM"
        return pushInfo
    }()
    var resolution: TUIVideoEncoderParamsResolution = ._1280_720
    var resolutionMode: TUIVideoEncoderParamsResolutionMode = .portrait
    var rotation: TUIVideoRenderParamsRotation = ._0
    var fillMode: TUIVideoRenderParamsFillMode = .fill
    var beautyLevel: Int = 6
    var is1VN: Bool = true
    var screenOrientation: Int = 0
}
