//
//  Date+RoomSchedule.swift
//  TUIRoomKit
//
//  Created by adamsfliu on 2026/7/28.
//  Copyright © 2026 Tencent. All rights reserved.
//

import Foundation

extension Date {
    static func roundedUpToNextFiveMinutes(from date: Date) -> Date {
        let step = 5
        let calendar = Calendar.current
        let minute = calendar.component(.minute, from: date)
        let steps = (minute / step) + 1
        let deltaMinutes = steps * step - minute
        let secondsToRemove = calendar.component(.second, from: date)
        let base = calendar.date(byAdding: .second, value: -secondsToRemove, to: date) ?? date
        return calendar.date(byAdding: .minute, value: deltaMinutes, to: base) ?? date
    }
    
    static func secondsSince1970(from date: Date) -> Int {
        return Int(date.timeIntervalSince1970)
    }
    
    static func date(fromSeconds seconds: Int) -> Date {
        guard seconds > 0 else { return Date() }
        return Date(timeIntervalSince1970: TimeInterval(seconds))
    }
}
