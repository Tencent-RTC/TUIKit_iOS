//
//  SGTypeConvert.swift
//  TUILiveKit
//
//  Created by CY zhao on 2025/9/3.
//

import Foundation
import AtomicXCore
import RTCRoomEngine
import ImSDK_Plus

typealias AtomicLiveInfo = AtomicXCore.LiveInfo

extension AtomicLiveInfo {
    init(from tuiLiveInfo: TUILiveInfo) {
        self.init(seatTemplate: SeatLayoutTemplate(seatLayoutTemplateID: tuiLiveInfo.seatLayoutTemplateId, maxSeatCount: tuiLiveInfo.maxSeatCount))
        liveID = tuiLiveInfo.roomId
        liveName = tuiLiveInfo.name
        notice = tuiLiveInfo.notice
        isMessageDisable = tuiLiveInfo.isMessageDisableForAllUser
        isPublicVisible = tuiLiveInfo.isPublicVisible
        isSeatEnabled = tuiLiveInfo.isSeatEnabled
        keepOwnerOnSeat = tuiLiveInfo.keepOwnerOnSeat
        maxSeatCount = tuiLiveInfo.maxSeatCount
        seatMode = tuiLiveInfo.seatMode == .applyToTake ? .apply : .free
        seatLayoutTemplateID = tuiLiveInfo.seatLayoutTemplateId
        coverURL = tuiLiveInfo.coverUrl
        backgroundURL = tuiLiveInfo.backgroundUrl
        categoryList = tuiLiveInfo.categoryList
        activityStatus = tuiLiveInfo.activityStatus
        totalViewerCount = tuiLiveInfo.viewCount
    }
}

extension SeatLayoutTemplate {
    init(seatLayoutTemplateID: UInt, maxSeatCount: Int = 0) {
        switch seatLayoutTemplateID {
            case 600:
                self = .videoDynamicGrid9Seats
            case 601:
                self = .videoDynamicFloat7Seats
            case 800:
                self = .videoFixedGrid9Seats
            case 801:
                self = .videoFixedFloat7Seats
            case 200:
                self = .videoLandscape4Seats
            case 70:
                self = .audioSalon(seatCount: maxSeatCount)
            case 50:
                self = .karaoke(seatCount: maxSeatCount)
            default:
                self = .videoDynamicGrid9Seats
        }
    }
}

extension TUISeatMode {
    init(from takeSeatMode: TakeSeatMode) {
        switch takeSeatMode {
        case .apply:
            self = .applyToTake
        default:
            self = .freeToTake
        }
    }
}

extension TakeSeatMode {
    init(from tuiSeatMode: TUISeatMode) {
        switch tuiSeatMode {
        case .applyToTake:
            self = .apply
        default:
            self = .free
        }
    }
}
    
extension TUIUserInfo {
    convenience init(from liveUserInfo: LiveUserInfo) {
        self.init()
        userId = liveUserInfo.userID
        userName = liveUserInfo.userName
        avatarUrl = liveUserInfo.avatarURL
    }
    
    convenience init(userId: String) {
        self.init()
        self.userId = userId
    }
    
    convenience init(userFullInfo: V2TIMUserFullInfo) {
        self.init()
        userId = userFullInfo.userID ?? ""
        userName = userFullInfo.nickName ?? ""
        avatarUrl = userFullInfo.faceURL ?? ""
        userRole = TUIRole(rawValue: UInt(userFullInfo.role)) ?? .generalUser
    }
    
    convenience init(seatInfo: TUISeatInfo) {
        self.init()
        userId = seatInfo.userId ?? ""
        userName = seatInfo.userName ?? ""
        avatarUrl = seatInfo.avatarUrl ?? ""
    }
}

extension TUISeatInfo {
    convenience init(from seatInfo: SeatInfo) {
        self.init()
        index = seatInfo.index
        userId = seatInfo.userInfo.userID
        userName = seatInfo.userInfo.userName
        avatarUrl = seatInfo.userInfo.avatarURL
        isLocked = seatInfo.isLocked
        isVideoLocked = !seatInfo.userInfo.allowOpenCamera
        isAudioLocked = !seatInfo.userInfo.allowOpenMicrophone
    }
}

extension TUIKickedOutOfRoomReason {
    init(from liveKickoutReason: LiveKickedOutReason) {
        switch liveKickoutReason {
        case .byAdmin:
            self = .byAdmin
        case .byLoggedOnOtherDevice:
            self = .byLoggedOnOtherDevice
        case .byServer:
            self = .byServer
        case .forNetworkDisconnected:
            self = .forNetworkDisconnected
        case .forJoinRoomStatusInvalidDuringOffline:
            self = .forJoinRoomStatusInvalidDuringOffline
        case .forCountOfJoinedRoomsExceedLimit:
            self = .forCountOfJoinedRoomsExceedLimit
        }
    }
}
