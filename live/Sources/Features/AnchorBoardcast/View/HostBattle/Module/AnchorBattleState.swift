//
//  BattleState.swift
//  TUILiveKit
//
//  Created by krabyu on 2024/8/26.
//

import Foundation
import RTCRoomEngine

let anchorBattleDuration: TimeInterval = 30
let anchorBattleRequestTimeout: TimeInterval = 10
let anchorBattleEndInfoDuration: TimeInterval = 5

struct AnchorBattleState {
    var durationCountDown: Int = 0
    var isInWaiting: Bool = false
    var isOnDisplayResult: Bool = false
    var requestBattleID: String = ""
}
