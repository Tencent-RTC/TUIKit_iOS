//
//  AnchorDashboardDefine.swift
//  TUILiveKit
//
//  Created by gg on 2025/6/17.
//

import Foundation
import AtomicXCore

public class AnchorEndStatisticsViewInfo {
    let roomId: String
    let liveDuration: Int
    var viewCount: Int
    let messageCount: Int
    let giftTotalCoins: Int
    let giftTotalUniqueSender: Int
    let likeTotalUniqueSender: Int
    let liveEndedReason: LiveEndedReason

    public init(roomId: String, liveDuration: Int, viewCount: Int, messageCount: Int, giftTotalCoins: Int, giftTotalUniqueSender: Int, likeTotalUniqueSender: Int, liveEndedReason: LiveEndedReason) {
        self.roomId = roomId
        self.liveDuration = liveDuration
        self.viewCount = viewCount
        self.messageCount = messageCount
        self.giftTotalCoins = giftTotalCoins
        self.giftTotalUniqueSender = giftTotalUniqueSender
        self.likeTotalUniqueSender = likeTotalUniqueSender
        self.liveEndedReason = liveEndedReason
    }
}

public protocol AnchorEndStatisticsViewDelegate: AnyObject {
    func onCloseButtonClick()
}

public protocol AudienceEndStatisticsViewDelegate: AnyObject {
    func onCloseButtonClick()
}
