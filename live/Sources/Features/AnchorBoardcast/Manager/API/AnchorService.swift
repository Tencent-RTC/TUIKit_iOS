//
//  AnchorRoomEngineService.swift
//  TUILiveKit
//
//  Created by jeremiawang on 2024/11/19.
//

import RTCRoomEngine
#if canImport(TXLiteAVSDK_TRTC)
    import TXLiteAVSDK_TRTC
#elseif canImport(TXLiteAVSDK_Professional)
    import TXLiteAVSDK_Professional
#endif
import AtomicXCore
import ImSDK_Plus

class AnchorService {
    let roomEngine: TUIRoomEngine
    let liveListManager: TUILiveListManager?
    let liveGiftManager: TUILiveGiftManager?
    let trtcCloud: TRTCCloud
    
    init() {
        self.roomEngine = TUIRoomEngine.sharedInstance()
        self.liveListManager = roomEngine.getExtension(extensionType: .liveListManager) as? TUILiveListManager
        self.liveGiftManager = roomEngine.getExtension(extensionType: .liveGiftManager) as? TUILiveGiftManager
        self.trtcCloud = roomEngine.getTRTCCloud()
    }
    
    func addEngineObserver(_ engineObserver: TUIRoomObserver) {
        roomEngine.addObserver(engineObserver)
    }
    
    func removeEngineObserver(_ engineObserver: TUIRoomObserver) {
        roomEngine.removeObserver(engineObserver)
    }
    
    func addLiveListManagerObserver(_ observer: TUILiveListManagerObserver) {
        liveListManager?.addObserver(observer)
    }
    
    func removeLiveListManagerObserver(_ observer: TUILiveListManagerObserver) {
        liveListManager?.removeObserver(observer)
    }
}

// MARK: - MediaAPI

extension AnchorService {
    func setLocalVideoView(view: UIView) {
        roomEngine.setLocalVideoView(view: view)
    }
    
    func enableGravitySensor(enable: Bool) {
        roomEngine.enableGravitySensor(enable: enable)
    }
    
    func setVideoResolutionMode(_ resolutionMode: TUIResolutionMode) {
        roomEngine.setVideoResolutionMode(streamType: .cameraStream, resolutionMode: resolutionMode)
    }
    
    func updateVideoQuality(_ quality: VideoQuality) {
        roomEngine.updateVideoQuality(quality.tuiType())
    }
    
    func setBeautyStyle(_ style: TXBeautyStyle) {
        trtcCloud.getBeautyManager().setBeautyStyle(style)
    }
}
