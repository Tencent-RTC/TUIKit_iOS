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
    @Published public var videoStreamSource: VideoStreamSource
    init(roomName: String, coverUrl: String, privacyMode: LiveStreamPrivacyStatus, templateMode: LiveTemplateMode, pkTemplateMode: LiveTemplateMode, videoStreamSource: VideoStreamSource = .camera) {
        self.roomName = roomName
        self.coverUrl = coverUrl
        self.privacyMode = privacyMode
        self.templateMode = templateMode
        self.pkTemplateMode = pkTemplateMode
        self.videoStreamSource = videoStreamSource
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
        case .horizontalDynamic:
            return .videoLandscape4Seats
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
