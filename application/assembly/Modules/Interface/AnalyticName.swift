//
//  AnalyticName.swift
//  AppAssembly
//
//  模块埋点事件名强类型 — 命名空间化的事件名常量
//
//  设计目的：
//    - 用 `struct AnalyticName: RawRepresentable` 替代裸 String，
//      使 `AnalyticEvent.liveEvent(name:)` 等 API 能在编译期约束事件名取值
//    - 静态常量定义在本类型上，调用方可用点语法（如 `.liveShowLiveList`），
//      IDE cmd+click 直接跳转到常量定义点
//
//  与底层桥接：
//    - 与 `AppAnalytics.trackModuleEvent(event:)` / SDK API 边界处通过 `.rawValue` 转回 String
//

import Foundation

/// 强类型事件名（包装 `String` 以约束取值且支持 IDE 跳转）
public struct AnalyticName: RawRepresentable, Hashable {
    public let rawValue: String

    public init(rawValue: String) {
        self.rawValue = rawValue
    }
}

public extension AnalyticName {
    // MARK: - Main Click
    /// 国内版首页点击事件名
    static let rtcubeMainClick = AnalyticName(rawValue: "rtcube_main_click_event")
    /// 海外版首页点击事件名
    static let tencentRTCMainClick = AnalyticName(rawValue: "tencent_rtc_main_click_event")

    // MARK: - Call
    static let callInvite = AnalyticName(rawValue: "call_invite")
    static let callReceived = AnalyticName(rawValue: "call_received")
    static let callAccepted = AnalyticName(rawValue: "call_accepted")
    static let callEnded = AnalyticName(rawValue: "call_ended")

    // MARK: - Live
    static let liveAnchorStart = AnalyticName(rawValue: "live_anchor_start")
    static let liveAnchorEnded = AnalyticName(rawValue: "live_anchor_ended")
    static let liveShowLiveList = AnalyticName(rawValue: "live_show_live_list")
    static let liveToggleColumn = AnalyticName(rawValue: "live_toggle_column")
    static let liveAudienceStart = AnalyticName(rawValue: "live_audience_start")
    static let liveAudienceLeave = AnalyticName(rawValue: "live_audience_leave")

    // MARK: - VoiceRoom
    static let voiceRoomAnchorStart = AnalyticName(rawValue: "voice_room_anchor_start")
    static let voiceRoomAnchorEnded = AnalyticName(rawValue: "voice_room_anchor_ended")
    static let voiceRoomShowLiveList = AnalyticName(rawValue: "voice_room_show_live_list")
    static let voiceRoomAudienceStart = AnalyticName(rawValue: "voice_room_audience_start")
    static let voiceRoomAudienceLeave = AnalyticName(rawValue: "voice_room_audience_leave")

    // MARK: - AIConversation
    static let aiConversationStart = AnalyticName(rawValue: "ai_conversation_start")
    static let aiConversationEnd = AnalyticName(rawValue: "ai_conversation_end")

    // MARK: - Interpretation
    static let interpretationStart = AnalyticName(rawValue: "interpretation_start")
    static let interpretationEnd = AnalyticName(rawValue: "interpretation_end")

    // MARK: - Room
    static let roomCreated = AnalyticName(rawValue: "room_created")
    static let roomJoined = AnalyticName(rawValue: "room_joined")
    static let roomEnded = AnalyticName(rawValue: "room_ended")
    static let roomLeave = AnalyticName(rawValue: "room_leave")
}
