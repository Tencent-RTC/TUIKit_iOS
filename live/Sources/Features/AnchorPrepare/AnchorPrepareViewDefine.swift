//
//  AnchorPrepareViewDefine.swift
//  TUILiveKit
//
//  Created by gg on 2025/5/15.
//

import AtomicXCore

public class PrepareState {
    public var roomName: String
    @Published public var coverUrl: String
    @Published public var privacyMode: LiveStreamPrivacyStatus
    @Published public var templateMode: LiveTemplateMode
    @Published public var pkTemplateMode: LiveTemplateMode
    init(roomName: String, coverUrl: String, privacyMode: LiveStreamPrivacyStatus, templateMode: LiveTemplateMode, pkTemplateMode: LiveTemplateMode) {
        self.roomName = roomName
        self.coverUrl = coverUrl
        self.privacyMode = privacyMode
        self.templateMode = templateMode
        self.pkTemplateMode = pkTemplateMode
    }
}

public enum Feature {
    case beauty
    case audioEffect
    case flipCamera
}

public protocol AnchorPrepareViewDelegate: AnyObject {
    func onClickStartButton(state: PrepareState)
    func onClickBackButton()
}

extension LiveTemplateMode {
    func toSeatLayoutTemplate() -> SeatLayoutTemplate {
        switch self {
        case .verticalGridDynamic:
            return .videoDynamicGrid9Seats
        case .verticalFloatDynamic:
            return .videoDynamicFloat7Seats
        case .verticalGridStatic:
            return .videoFixedGrid9Seats
        case .verticalFloatStatic:
            return .videoFixedFloat7Seats
        }
    }
}
