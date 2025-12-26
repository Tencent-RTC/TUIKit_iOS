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
    var userInfo: SeatUserInfo = .init()
    var connectionStatus: AnchorConnectionStatus = .none

    init(userInfo: SeatUserInfo, connectionStatus: AnchorConnectionStatus = .none) {
        self.userInfo = userInfo
        self.connectionStatus = connectionStatus
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
    }
}
