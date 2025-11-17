//
//  AnchorMediaManager.swift
//  TUILIveKit
//
//  Created by jeremiawang on 2024/11/19.
//

import AtomicXCore
import Combine
import Foundation
import RTCCommon
import RTCRoomEngine
import TUICore

class AnchorMediaManager {
    private let observerState = ObservableState<AnchorMediaState>(initialState: AnchorMediaState())
    var mediaState: AnchorMediaState {
        observerState.state
    }
    
    private typealias Context = AnchorManager.Context
    private weak var context: Context?
    private let toastSubject: PassthroughSubject<String, Never>
    private let service: AnchorService = .init()
    private var localVideoViewObservation: NSKeyValueObservation?
    private var cancellableSet: Set<AnyCancellable> = []

    init(context: AnchorManager.Context) {
        self.context = context
        self.toastSubject = context.toastSubject
        initVideoAdvanceSettings()
        subscribeCurrentLive()
    }
    
    deinit {
        enableMultiPlaybackQuality(false)
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

extension AnchorMediaManager {
    func prepareLiveInfoBeforeEnterRoom() {
        enableMultiPlaybackQuality(true)
    }
    
    func onCameraOpened() {
        service.enableGravitySensor(enable: true)
        service.setVideoResolutionMode(.portrait)
    }
    
    func updateVideoQuality(quality: VideoQuality) {
        service.updateVideoQuality(quality)
        observerState.update { state in
            state.videoQuality = quality
        }
    }
    
    func onLeaveLive() {
        enableMultiPlaybackQuality(false)
        unInitVideoAdvanceSettings()
        observerState.update(isPublished: false) { state in
            state = AnchorMediaState()
        }
    }
    
    func subscribeState<Value>(_ selector: StateSelector<AnchorMediaState, Value>) -> AnyPublisher<Value, Never> {
        return observerState.subscribe(selector)
    }
}

// MARK: - Video Setting

extension AnchorMediaManager {
    func enableAdvancedVisible(_ visible: Bool) {
        observerState.update { state in
            state.videoAdvanceSettings.isVisible = visible
        }
    }
   
    func enableMultiPlaybackQuality(_ enable: Bool) {
        TUICore.callService(.TUICore_VideoAdvanceService,
                            method: .TUICore_VideoAdvanceService_EnableMultiPlaybackQuality,
                            param: ["enable": NSNumber(value: enable)])
    }
    
    private func initVideoAdvanceSettings() {
        enableMultiPlaybackQuality(true)
    }
    
    private func unInitVideoAdvanceSettings() {
        enableMultiPlaybackQuality(false)
    }
}

// MARK: - Video Advance API Extension

private extension String {
    static let TUICore_VideoAdvanceService = "TUICore_VideoAdvanceService"
    
    static let TUICore_VideoAdvanceService_EnableMultiPlaybackQuality = "TUICore_VideoAdvanceService_EnableMultiPlaybackQuality"
}
