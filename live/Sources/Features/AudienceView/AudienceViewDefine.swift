//
//  AudienceViewDefine.swift
//  TUILiveKit
//
//  Created by jeremiawang on 2025/6/20.
//

import AtomicXCore

public protocol AudienceViewDelegate: AnyObject {
    func audienceView(_ audienceView: AudienceView,
                      onCreateLiveView liveView: AudienceLiveView,
                      for liveInfo: LiveInfo)
    func audienceView(_ audienceView: AudienceView,
                      liveViewDidAppear liveView: AudienceLiveView,
                      for liveInfo: LiveInfo)
    func audienceView(_ audienceView: AudienceView,
                      liveViewDidDisappear liveView: AudienceLiveView,
                      for liveInfo: LiveInfo)
    func onClickFloatWindow()
    func onLiveEnded(roomId: String, ownerName: String, ownerAvatarUrl: String)
}

public protocol AudienceViewDataSource: AnyObject {
    typealias LiveListSuccessBlock = (String, [LiveInfo]) -> Void
    typealias LiveListErrorBlock = (Int, String) -> Void
    func fetchLiveList(cursor: String, onSuccess: @escaping LiveListSuccessBlock, onError: @escaping LiveListErrorBlock)
}

public enum AudienceNode {
    case liveInfo
    case topRightButtons
    case networkInfo
    case bottomRightBar
    case barrageInput
}

public enum AudienceBottomItem: Hashable {
    case coGuest
    case more
    case gift
    case like
    case custom(UIView)

    public static func == (lhs: AudienceBottomItem, rhs: AudienceBottomItem) -> Bool {
        switch (lhs, rhs) {
        case (.coGuest, .coGuest),
             (.more, .more),
             (.gift, .gift),
             (.like, .like):
            return true
        case (.custom(let lView), .custom(let rView)):
            return lView === rView
        default:
            return false
        }
    }

    public func hash(into hasher: inout Hasher) {
        switch self {
        case .coGuest:
            hasher.combine(0)
        case .more:
            hasher.combine(1)
        case .gift:
            hasher.combine(2)
        case .like:
            hasher.combine(3)
        case .custom(let view):
            hasher.combine(4)
            hasher.combine(ObjectIdentifier(view))
        }
    }
}

public enum AudienceTopRightItem: Equatable {
    case audienceCount
    case floatWindow
    case close
    case custom(UIView)

    public static func == (lhs: AudienceTopRightItem, rhs: AudienceTopRightItem) -> Bool {
        switch (lhs, rhs) {
        case (.audienceCount, .audienceCount),
             (.floatWindow, .floatWindow),
             (.close, .close):
            return true
        case (.custom(let lView), .custom(let rView)):
            return lView === rView
        default:
            return false
        }
    }
}

public enum AudienceAction: Equatable {
    case showLiveInfo
    case showAudienceList
    case showGiftPanel
    case showCoGuestPanel
    case showMorePanel
    case showFloatWindow
    case exitLive
}
