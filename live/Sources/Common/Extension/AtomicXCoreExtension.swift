//
//  AtomicXCoreExtension.swift
//  TUILiveKit
//
//  Created by gg on 2025/10/21.
//

import AtomicXCore
import RTCRoomEngine

extension LiveCoreView {
    private static var cacheMap: [String: LiveCoreView] = [:]
    private static var cacheOrder: [String] = []
    private static let cacheMaxCount = 10

    static func getCachedCoreView(liveID: String, type: CoreViewType) -> LiveCoreView {
        if let view = cacheMap[liveID] {
            if let index = cacheOrder.firstIndex(of: liveID) {
                cacheOrder.remove(at: index)
            }
            cacheOrder.append(liveID)
            return view
        } else {
            if cacheMap.count >= cacheMaxCount {
                if FloatWindow.shared.isShowingFloatWindow(), let floatLiveID = FloatWindow.shared.getCurrentRoomId() {
                    if let index = cacheOrder.firstIndex(of: floatLiveID) {
                        cacheOrder.remove(at: index)
                        cacheOrder.append(floatLiveID)
                    }
                }
                if let evictKey = cacheOrder.first {
                    cacheOrder.removeFirst()
                    if let evictedView = cacheMap.removeValue(forKey: evictKey) {
                        evictedView.stopPreviewLiveStream(roomId: evictKey)
                        evictedView.safeRemoveFromSuperview()
                    }
                }
            }
            let view = LiveCoreView(viewType: type)
            view.setLiveID(liveID)
            cacheMap[liveID] = view
            cacheOrder.append(liveID)
            return view
        }
    }

    static func removeCachedView(liveID: String) {
        if let view = cacheMap.removeValue(forKey: liveID) {
            view.stopPreviewLiveStream(roomId: liveID)
            view.safeRemoveFromSuperview()
        }
        cacheOrder.removeAll(where: { $0 == liveID })
    }

    static func removeAllCachedViews() {
        for item in cacheMap {
            item.value.stopPreviewLiveStream(roomId: item.key)
            item.value.safeRemoveFromSuperview()
        }
        cacheMap.removeAll()
        cacheOrder.removeAll()
    }
}

extension [SeatUserInfo] {
    func isOnSeat(userID: String? = nil) -> Bool {
        if let userID = userID {
            return contains(where: { $0.userID == userID })
        } else {
            let selfUserID = LoginStore.shared.state.value.loginUserInfo?.userID ?? ""
            return contains(where: { $0.userID == selfUserID })
        }
    }
}

extension SeatUserInfo {
    init(userInfo: LiveUserInfo) {
        self.init()
        userID = userInfo.userID
        userName = userInfo.userName
        avatarURL = userInfo.avatarURL
    }

    init(seatFullInfo: TUISeatFullInfo) {
        self.init()
        userID = seatFullInfo.userId ?? ""
        userName = seatFullInfo.userName ?? ""
        avatarURL = seatFullInfo.userAvatar ?? ""
        liveID = seatFullInfo.roomId
        microphoneStatus = seatFullInfo.userMicrophoneStatus == .opened ? .on : .off
        allowOpenMicrophone = seatFullInfo.userMicrophoneStatus != .closedByAdmin
        cameraStatus = seatFullInfo.userCameraStatus == .opened ? .on : .off
        allowOpenCamera = seatFullInfo.userCameraStatus != .closedByAdmin
    }

    var displayName: String {
        userName.isEmpty ? userID : userName
    }
}

extension SeatInfo {
    init(userInfo: LiveUserInfo) {
        self.init()
        self.userInfo = SeatUserInfo(userInfo: userInfo)
    }

    init(seatFullInfo: TUISeatFullInfo) {
        self.init()
        index = seatFullInfo.seatIndex
        isLocked = seatFullInfo.isSeatLocked
        userInfo = SeatUserInfo(seatFullInfo: seatFullInfo)
        region = RegionInfo(seatFullInfo: seatFullInfo)
    }
}

extension RegionInfo {
    init(seatFullInfo: TUISeatFullInfo) {
        self.init()
        x = CGFloat(seatFullInfo.x)
        y = CGFloat(seatFullInfo.y)
        w = CGFloat(seatFullInfo.width)
        h = CGFloat(seatFullInfo.height)
        zorder = Int(seatFullInfo.zorder)
    }
}

extension VideoQuality {
    func tuiType() -> TUIVideoQuality {
        switch self {
        case .quality360P:
            return .quality360P
        case .quality540P:
            return .quality540P
        case .quality720P:
            return .quality720P
        case .quality1080P:
            return .quality1080P
        }
    }
}

extension LiveUserInfo {
    init(seatUserInfo: SeatUserInfo) {
        self.init()
        userID = seatUserInfo.userID
        userName = seatUserInfo.userName
        avatarURL = seatUserInfo.avatarURL
    }
}

extension MirrorType {
    func toString() -> String {
        switch self {
        case .auto:
            return internalLocalized("mirror_type_auto")
        case .enable:
            return internalLocalized("mirror_type_enable")
        case .disable:
            return internalLocalized("mirror_type_disable")
        }
    }

    func next() -> MirrorType {
        switch self {
        case .auto:
            return .enable
        case .enable:
            return .disable
        case .disable:
            return .auto
        }
    }
}

extension LiveTemplateMode {
    func toPkAtomicType() -> CoHostLayoutTemplate {
        switch self {
        case .verticalFloatDynamic:
            return .hostDynamic1v6
        default:
            return .hostDynamicGrid
        }
    }
}
