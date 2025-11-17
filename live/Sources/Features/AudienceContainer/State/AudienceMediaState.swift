//
//  AudienceMediaState.swift
//  TUILiveKit
//
//  Created by jeremiawang on 2024/11/19.
//

import AtomicXCore

struct AudienceMediaState {
    var videoQuality: VideoQuality = .quality1080P

    var playbackQuality: VideoQuality? = nil
    var playbackQualityList: [VideoQuality] = []
    var videoAdvanceSettings: AudienceVideoAdvanceSetting = .init()
}

struct AudienceVideoAdvanceSetting {
    var isVisible: Bool = false

    var isUltimateEnabled: Bool = false

    var isBFrameEnabled: Bool = false

    var isH265Enabled: Bool = false

    var hdrRenderType: AudienceHDRRenderType = .none
}

enum AudienceHDRRenderType: Int {
    case none = 0
    case displayLayer = 1
    case metal = 2
}
