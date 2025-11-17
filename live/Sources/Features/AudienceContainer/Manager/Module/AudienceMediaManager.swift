//
//  AudienceMediaManager.swift
//  TUILIveKit
//
//  Created by jeremiawang on 2024/11/19.
//

import AtomicXCore
import Combine
import Foundation
import RTCCommon
import TUICore
import RTCRoomEngine

class AudienceMediaManager: NSObject {
    private let observerState = ObservableState<AudienceMediaState>(initialState: AudienceMediaState())
    var mediaState: AudienceMediaState {
        observerState.state
    }
    
    private typealias Context = AudienceManager.Context
    private weak var context: Context?
    private let service = AudienceService()
    private var localVideoViewObservation: NSKeyValueObservation?
    private var cancellableSet: Set<AnyCancellable> = []

    init(context: AudienceManager.Context) {
        self.context = context
        super.init()
        initVideoAdvanceSettings()
        subscribeCurrentLive()
        TUIRoomEngine.sharedInstance().addObserver(self)
    }
    
    deinit {
        TUIRoomEngine.sharedInstance().removeObserver(self)
        unInitVideoAdvanceSettings()
    }
    
    func subscribeCurrentLive() {
        context?.liveListStore.state.subscribe(StatePublisherSelector(keyPath: \LiveListState.currentLive))
            .removeDuplicates()
            .dropFirst()
            .receive(on: RunLoop.main)
            .sink { [weak self] currentLive in
                guard let self = self else { return }
                if currentLive.isEmpty {
                    onLeaveLive()
                } else {
                    onJoinLive(liveInfo: currentLive)
                }
            }
            .store(in: &cancellableSet)
        
        context?.deviceStore.state.subscribe(StatePublisherSelector(keyPath: \DeviceState.cameraStatus))
            .removeDuplicates()
            .receive(on: RunLoop.main)
            .sink { [weak self] cameraStatus in
                guard let self = self else { return }
                if cameraStatus == .on {
                    onCameraOpened()
                }
            }
            .store(in: &cancellableSet)
    }
}

// MARK: - Interface

extension AudienceMediaManager {
    func setLocalVideoView(view: UIView) {
        service.setLocalVideoView(view: view)
    }
    
    private func onCameraOpened() {
        service.enableGravitySensor(enable: true)
        service.setVideoResolutionMode(.portrait)
    }
    
    func updateVideoQuality(quality: VideoQuality) {
        service.updateVideoQuality(quality)
        update { state in
            state.videoQuality = quality
        }
    }
    
    private func onJoinLive(liveInfo: LiveInfo) {
        getMultiPlaybackQuality(roomId: liveInfo.liveID)
    }
    
    private func onLeaveLive() {
        unInitVideoAdvanceSettings()
        observerState.update(isPublished: false) { state in
            state = AudienceMediaState()
        }
    }
    
    func subscribeState<Value>(_ selector: StateSelector<AudienceMediaState, Value>) -> AnyPublisher<Value, Never> {
        return observerState.subscribe(selector)
    }
}

// MARK: - Video Setting

extension AudienceMediaManager {
    func enableAdvancedVisible(_ visible: Bool) {
        observerState.update { state in
            state.videoAdvanceSettings.isVisible = visible
        }
    }
    
    private func initVideoAdvanceSettings() {
        enableSwitchPlaybackQuality(true)
    }
    
    private func unInitVideoAdvanceSettings() {
        enableSwitchPlaybackQuality(false)
    }
}

// MARK: - Multi Playback Quality

extension AudienceMediaManager {
    func switchPlaybackQuality(quality: VideoQuality) {
        service.switchPlaybackQuality(quality)
    }
    
    func getMultiPlaybackQuality(roomId: String) {
        service.getMultiPlaybackQuality(roomId: roomId) { [weak self] qualityList in
            guard let self = self else { return }
            self.observerState.update { mediaState in
                mediaState.playbackQualityList = qualityList
                mediaState.playbackQuality = qualityList.first
            }
        }
    }
    
    func enableSwitchPlaybackQuality(_ enable: Bool) {
        TUICore.callService(.TUICore_VideoAdvanceService,
                            method: .TUICore_VideoAdvanceService_EnableSwitchMultiPlayback,
                            param: ["enable": NSNumber(value: enable)])
    }
    
    private func getVideoQuality(width: Int32, height: Int32) -> VideoQuality {
        if (width * height) <= (360 * 640) {
            return .quality360P
        }
        if (width * height) <= (540 * 960) {
            return .quality540P
        }
        if (width * height) <= (720 * 1280) {
            return .quality720P
        }
        return .quality1080P
    }
}

extension AudienceMediaManager {
    private func update(mediaState: (inout AudienceMediaState) -> ()) {
        observerState.update(reduce: mediaState)
    }
}

extension AudienceMediaManager: TUIRoomObserver {
    func onUserVideoSizeChanged(roomId: String, userId: String, streamType: TUIVideoStreamType, width: Int32, height: Int32) {
        guard let context = context else {
            return
        }
        let playbackQuality = getVideoQuality(width: width, height: height)
        guard playbackQuality != mediaState.playbackQuality else {
            return
        }
        guard mediaState.playbackQualityList.count > 1, mediaState.playbackQualityList.contains(playbackQuality) else {
            return
        }
        guard !context.audienceState.isApplying, !context.coGuestState.connected.isOnSeat() else {
            return
        }
        observerState.update { mediaState in
            mediaState.playbackQuality = playbackQuality
        }
    }
}

// MARK: - Video Advance API Extension

private extension String {
    static let TUICore_VideoAdvanceService = "TUICore_VideoAdvanceService"
    
    static let TUICore_VideoAdvanceService_EnableSwitchMultiPlayback = "TUICore_VideoAdvanceService_EnableSwitchMultiPlayback"
}
