//
//  SettingsConfig.swift
//  App-UIKit
//
//  Created by yukiwwwang on 2025/8/13.
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
    var intRoomId: UInt32 = 0
    var strRoomId: String = ""
    var timeout: Int = 30
    var userData: String = ""
    let pushInfo: TUIOfflinePushInfo = {
        let pushInfo: TUIOfflinePushInfo = TUIOfflinePushInfo()
        pushInfo.title = "NEW CALL"
        pushInfo.desc = "You have a new call invitation!"
        // iOS push type: if you want user VoIP, please modify type to TUICallIOSOfflinePushTypeVoIP
        pushInfo.iOSPushType = .apns
        pushInfo.ignoreIOSBadge = false
        pushInfo.iOSSound = "phone_ringing.mp3"
        pushInfo.androidSound = "phone_ringing"
        // OPPO must set a ChannelID to receive push messages. This channelID needs to be the same as the console.
        pushInfo.androidOPPOChannelID = "tuikit"
        // FCM channel ID, you need change PrivateConstants.java and set "fcmPushChannelId"
        pushInfo.androidFCMChannelID = "fcm_push_channel"
        // VIVO message type: 0-push message, 1-System message(have a higher delivery rate)
        pushInfo.androidVIVOClassification = 1
        // HuaWei message type: https://developer.huawei.com/consumer/cn/doc/development/HMSCore-Guides/message-classification-0000001149358835
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
