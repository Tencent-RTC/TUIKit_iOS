//
//  AnchorCoHostState.swift
//  TUILiveKit
//
//  Created by jack on 2024/8/6.
//

import AtomicXCore

enum AnchorConnectionStatus: Int {
    case none
    case inviting
    case connected
}

struct AnchorCoHostUserInfo {
    var liveID: String
    var userInfo: LiveUserInfo = .init()
    var connectionStatus: AnchorConnectionStatus = .none

    init(liveID: String, userInfo: LiveUserInfo, connectionStatus: AnchorConnectionStatus = .none) {
        self.userInfo = userInfo
        self.liveID = liveID
        self.connectionStatus = connectionStatus
    }

    init(seatUserInfo: SeatUserInfo) {
        self.liveID = seatUserInfo.liveID
        var liveUserInfo = LiveUserInfo()
        liveUserInfo.userID = seatUserInfo.userID
        liveUserInfo.avatarURL = seatUserInfo.avatarURL
        liveUserInfo.userName = seatUserInfo.userName
        self.userInfo = liveUserInfo
    }
}

struct AnchorCoHostState {
    var connectedUsers: [AnchorCoHostUserInfo] = []
    var recommendedUsers: [AnchorCoHostUserInfo] = []
    var isApplying = false
}

extension AnchorCoHostUserInfo: Equatable {
    static func ==(lhs: AnchorCoHostUserInfo, rhs: AnchorCoHostUserInfo) -> Bool {
        return lhs.userInfo == rhs.userInfo
            && lhs.connectionStatus == rhs.connectionStatus
            && lhs.liveID == rhs.liveID
    }
}
