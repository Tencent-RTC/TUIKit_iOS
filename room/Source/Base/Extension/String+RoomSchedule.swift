//
//  String+RoomSchedule.swift
//  TUIRoomKit
//
//  Created by adamsfliu on 2026/7/28.
//  Copyright © 2026 Tencent. All rights reserved.
//

import Foundation

extension String {
    /// Human-readable duration string.
    /// - When `hours` is 0, only the minute component is shown (e.g. `30分钟`).
    /// - Otherwise both components are shown (e.g. `1小时 0分钟`).
    static func roomDurationDisplayString(hours: Int, minutes: Int) -> String {
        if hours == 0 {
            return "roomkit_minute_text".localizedReplace("\(minutes)")
        }
        let hourPart = "roomkit_hour_text".localizedReplace("\(hours)")
        let minutePart = "roomkit_minute_text".localizedReplace("\(minutes)")
        return "\(hourPart) \(minutePart)"
    }

    /// Generate a random numeric password of the given length. Each character is a digit `0...9`.
    static func randomNumericPassword(length: Int) -> String {
        guard length > 0 else { return "" }
        var result = ""
        for _ in 0..<length {
            result.append(String(Int.random(in: 0...9)))
        }
        return result
    }
}
