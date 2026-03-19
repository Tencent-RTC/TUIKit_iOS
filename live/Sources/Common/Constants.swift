//
//  Constants.swift
//  TUILiveKit
//
//  Created by krabyu on 2024/10/23.
//

import Foundation
import RTCRoomEngine

public struct Constants {
    public enum ComponentType: Int {
        case liveRoom = 21
        case voiceRoom = 22
        case coreView = 26
    }
    
    public struct DataReport {
        public static let kDataReportPanelShowLiveRoomBeautyEffect = 190_025
        public static let kDataReportPanelShowLiveRoomBeauty = 190_016
        
        public static let kDataReportLiveGiftSVGASendCount = 190_021
        public static let kDataReportLiveGiftSVGAPlayCount = 190_022
        public static let kDataReportLiveGiftEffectSendCount = 190_023
        public static let kDataReportLiveGiftEffectPlayCount = 190_024
        
        public static let kDataReportVoiceGiftSVGASendCount = 191_021
        public static let kDataReportVoiceGiftSVGAPlayCount = 191_022
        public static let kDataReportVoiceGiftEffectSendCount = 191_023
        public static let kDataReportVoiceGiftEffectPlayCount = 191_024
        
        enum SGMetricsEvent: Int {
            case panelShowSeatGridView = 191026
            case panelHideSeatGridView = 191027
            case methodCallSeatGridViewStartMicrophone = 191028
            case methodCallSeatGridViewStopMicrophone = 191029
            case methodCallSeatGridViewMuteMicrophone = 191030
            case methodCallSeatGridViewUnmuteMicrophone = 191031
            case methodCallSeatGridViewStartRoom = 191032
            case methodCallSeatGridViewStopRoom = 191033
            case methodCallSeatGridViewJoinRoom = 191034
            case methodCallSeatGridViewLeaveRoom = 191035
            case methodCallSeatGridViewUpdateSeatMode = 191036
            case methodCallSeatGridViewResponseRequest = 191037
            case methodCallSeatGridViewCancelRequest = 191038
            case methodCallSeatGridViewTakeSeat = 191039
            case methodCallSeatGridViewMoveToSeat = 191040
            case methodCallSeatGridViewLeaveSeat = 191041
            case methodCallSeatGridViewTakeUserOnSeat = 191042
            case methodCallSeatGridViewKickUserOffSeat = 191043
            case methodCallSeatGridViewLockSeat = 191044
            case methodCallSeatGridViewSetLayoutMode = 191045
            case methodCallSeatGridViewSetSeatViewDelegate = 191046
        }
    }
    
    public struct URL {
        public static let defaultCover = "https://liteav-test-1252463788.cos.ap-guangzhou.myqcloud.com/live/live_cover1.png"
        public static let defaultBackground = "https://liteav-test-1252463788.cos.ap-guangzhou.myqcloud.com/live/voice_room_bg1.png"
    }

    struct JsonName {
        static let gridLayout = "livekit_video_layout_grid"
        static let floatLayout = "livekit_video_layout_float"
    }
}
