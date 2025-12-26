//
//  CallView.swift
//  Pods
//
//  Created by vincepzhang on 2025/2/21.
//

import UIKit
import SnapKit
import AtomicXCore
import Combine
import RTCRoomEngine
import SDWebImage

public class CallView: UIView {
    // MARK: Init
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    public override init(frame: CGRect) {
        super.init(frame: frame)
        backgroundColor = .black
        setupCoreViewStaticResources()
        subscribeCallState()
        updateControlsView()
        updateBackgroundAvatar()
    }
    
    // MARK: Private
    private let timerView = TimerView(frame: .zero)
    private let hintView = HintView(frame: .zero)
    private let callCoreView = CallCoreView(frame: .zero)
    private let aiSubtitle = AISubtitle(frame: .zero)
    private let waitingParticipantsView = WaitingParticipantsView(frame: .zero)
    private let singleCallControlsView = SingleCallControlsView(frame: .zero)
    private let multiCallControlsView = MultiCallControlsView(frame: .zero)
    
    private lazy var backgroundAvatarView: UIImageView = {
        let imageView = UIImageView()
        imageView.contentMode = .scaleAspectFill
        imageView.clipsToBounds = true
        return imageView
    }()
    
    private lazy var backgroundBlurView: UIVisualEffectView = {
        let blurEffect = UIBlurEffect(style: .dark)
        let blurView = UIVisualEffectView(effect: blurEffect)
        return blurView
    }()
    
    private var isViewReady: Bool = false
    private var cancellables = Set<AnyCancellable>()
    private let deviceStore = DeviceStore.shared
    private let audioRouteObserver = TRTCAudioRouteObserver.shared
}

// MARK: Layout
extension CallView {
    public override func didMoveToWindow() {
        super.didMoveToWindow()
        guard !isViewReady else { return }
        isViewReady = true
        constructViewHierarchy()
        activateConstraints()
        checkViewVisibility()
    }
    
    private func constructViewHierarchy() {
        addSubview(backgroundAvatarView)
        addSubview(backgroundBlurView)
        addSubview(callCoreView)
        addSubview(waitingParticipantsView)
        addSubview(singleCallControlsView)
        addSubview(multiCallControlsView)
        addSubview(aiSubtitle)
        addSubview(timerView)
        addSubview(hintView)
    }
    
    private func activateConstraints() {
        backgroundAvatarView.snp.remakeConstraints { make in
            make.edges.equalToSuperview()
        }
        
        backgroundBlurView.snp.remakeConstraints { make in
            make.edges.equalToSuperview()
        }
        
        callCoreView.snp.remakeConstraints { make in
            make.edges.equalToSuperview()
        }
        
        waitingParticipantsView.snp.makeConstraints { make in
            make.centerX.equalToSuperview()
            make.width.equalToSuperview()
            make.height.equalTo(65.scale375Width())
            make.centerY.equalToSuperview()
        }
        
        singleCallControlsView.snp.remakeConstraints { make in
            make.leading.trailing.bottom.equalToSuperview()
            make.height.equalTo(260.scale375Height())
        }
        
        multiCallControlsView.snp.remakeConstraints { make in
            make.leading.trailing.bottom.equalToSuperview()
            make.height.equalTo(260.scale375Height())
        }
        
        let activeCall = CallStore.shared.state.value.activeCall
        let isGroupCall = !activeCall.chatGroupId.isEmpty || activeCall.inviteeIds.count > 1
        let isSingleAudioCall = !isGroupCall && activeCall.mediaType == .audio
        let aiSubtitleBottomOffset = isSingleAudioCall ? -144.scale375Height() : -270.scale375Height()
        
        aiSubtitle.snp.makeConstraints { make in
            make.centerX.equalToSuperview()
            make.height.equalTo(200.scale375Height())
            make.width.equalToSuperview().multipliedBy(0.95)
            make.bottom.equalToSuperview().offset(aiSubtitleBottomOffset)
        }
        
        if UIWindow.isPortrait {
            timerView.snp.remakeConstraints { make in
                make.top.equalToSuperview().offset(CallConstants.statusBar_Height + 12.scale375Height())
                make.centerX.equalToSuperview()
                make.height.equalTo(24.scale375Height())
            }
            
            hintView.snp.remakeConstraints { make in
                make.centerX.equalToSuperview()
                make.bottom.equalToSuperview().offset(-300.scale375Height() - 10.scale375Height())
                make.height.equalTo(24.scale375Height())
            }
        } else {
            timerView.snp.remakeConstraints { make in
                make.top.equalToSuperview().offset(10.scale375Height())
                make.centerX.equalToSuperview()
                make.height.equalTo(24.scale375Height())
            }
            
            hintView.snp.remakeConstraints { make in
                make.centerX.equalToSuperview()
                make.bottom.equalToSuperview().offset(-150.scale375Height())
                make.height.equalTo(24.scale375Height())
            }
        }
    }
    
    @objc private func handleOrientationChange() {
        DispatchQueue.main.async { [weak self] in
            self?.activateConstraints()
        }
    }
    
    private func updateControlsView() {
        let activeCall = CallStore.shared.state.value.activeCall
        let isGroupCall = !activeCall.chatGroupId.isEmpty || activeCall.inviteeIds.count > 1
        
        singleCallControlsView.isHidden = isGroupCall
        multiCallControlsView.isHidden = !isGroupCall
        
        if isGroupCall {
            multiCallControlsView.updateViewForCallState()
        } else {
            singleCallControlsView.updateViewForCallState()
        }
        
        checkViewVisibility()
    }
    
    private func checkViewVisibility() {
        let activeCall = CallStore.shared.state.value.activeCall
        let selfInfo = CallStore.shared.state.value.selfInfo
        
        let isCaller = selfInfo.id == activeCall.inviterId
        let isCalledWaiting = !isCaller && selfInfo.status == .waiting
        let isGroupCall = !activeCall.chatGroupId.isEmpty || activeCall.inviteeIds.count > 1
        
        if isGroupCall && isCalledWaiting {
            waitingParticipantsView.isHidden = false
            callCoreView.isHidden = true
        } else {
            waitingParticipantsView.isHidden = true
            callCoreView.isHidden = false
        }
    }
    
    private func updateCamera() {
        let activeCall = CallStore.shared.state.value.activeCall
        let cameraStatus = deviceStore.state.value.cameraStatus
        
        if activeCall.mediaType == .video && cameraStatus == .on {
            deviceStore.openLocalCamera(isFront: deviceStore.state.value.isFrontCamera) { result in
                switch result {
                case .success:
                    Logger.info("CallView - openLocalCamera success in updateCamera.")
                case .failure(let error):
                    Logger.error("CallView - openLocalCamera failed in updateCamera. Code: \(error.code), Message: \(error.message)")
                }
            }
        }
    }
    
    private func updateBackgroundAvatar() {
        let selfInfo = CallStore.shared.state.value.selfInfo
        let avatarURL = selfInfo.avatarURL
        
        if !avatarURL.isEmpty, let url = URL(string: avatarURL) {
            backgroundAvatarView.sd_setImage(with: url, placeholderImage: CallKitBundle.getBundleImage(name: "default_participant_icon"))
        } else {
            backgroundAvatarView.image = CallKitBundle.getBundleImage(name: "default_participant_icon")
        }
    }
}
extension CallView {
    private func setupCoreViewStaticResources() {
        if let defaultImage = CallKitBundle.getBundleImage(name: "default_participant_icon") {
            CallCoreView.defaultAvatarImage = defaultImage
        }
        
        var volumeLevelIcons: [VolumeLevel: String] = [:]
        if let path = getAbsolutePathForBundleImage(name: "icon_mic_off") { volumeLevelIcons[.mute] = path }
        if let path = getAbsolutePathForBundleImage(name: "icon_volume") { volumeLevelIcons[.low] = path }
        if let path = getAbsolutePathForBundleImage(name: "icon_volume") { volumeLevelIcons[.medium] = path }
        if let path = getAbsolutePathForBundleImage(name: "icon_volume") { volumeLevelIcons[.high] = path }
        if let path = getAbsolutePathForBundleImage(name: "icon_volume") { volumeLevelIcons[.peak] = path }
        callCoreView.setVolumeLevelIcons(icons: volumeLevelIcons)
        
        var networkQualityIcons: [NetworkQuality: String] = [:]
        if let path = getAbsolutePathForBundleImage(name: "group_network_low_quality") { networkQualityIcons[.bad] = path }
        callCoreView.setNetworkQualityIcons(icons: networkQualityIcons)
        
        if let bundle = CallKitBundle.getTUICallKitBundle(),
           let waitingAnimation = bundle.path(forResource: "loading", ofType: "gif") {
            callCoreView.setWaitingAnimation(path: waitingAnimation)
        }
    }

    private func handleParticipantsAvatarUpdate(_ participants: [CallParticipantInfo]) {
        var avatarPathsToSet: [String: String] = [:]
        
        for user in participants {
            guard !user.avatarURL.isEmpty, let url = URL(string: user.avatarURL) else { continue }
            
            let cacheKey = SDWebImageManager.shared.cacheKey(for: url)

            if let cachePath = SDImageCache.shared.cachePath(forKey: cacheKey),
               FileManager.default.fileExists(atPath: cachePath) {
                avatarPathsToSet[user.id] = cachePath
            } else {
                SDWebImageDownloader.shared.downloadImage(with: url) { [weak self] image, _, error, finished in
                    guard let self = self, let image = image, finished, error == nil else { return }
                    SDImageCache.shared.store(image, forKey: cacheKey, toDisk: true) {
                        if let newPath = SDImageCache.shared.cachePath(forKey: cacheKey) {
                            DispatchQueue.main.async {
                                self.callCoreView.setParticipantAvatars(avatars: [user.id: newPath])
                            }
                        }
                    }
                }
            }
        }
        
        if !avatarPathsToSet.isEmpty {
            callCoreView.setParticipantAvatars(avatars: avatarPathsToSet)
        }
    }
    
    private func getAbsolutePathForBundleImage(name: String) -> String? {
        guard let image = CallKitBundle.getBundleImage(name: name),
              let data = image.pngData() else { return nil }
        
        let tempDir = NSTemporaryDirectory()
        let fileName = "tuicallkit_res_\(name).png"
        let fullPath = (tempDir as NSString).appendingPathComponent(fileName)
        
        if !FileManager.default.fileExists(atPath: fullPath) {
            try? data.write(to: URL(fileURLWithPath: fullPath))
        }
        return fullPath
    }
}

// MARK: Subscribe
extension CallView {
    func subscribeCallState() {
        let callStateSelector = StatePublisherSelector { (state: CallState) -> (CallParticipantStatus, String, String, String, [String]) in
            let selfInfo = CallStore.shared.state.value.selfInfo
            let activeCall = state.activeCall
            return (selfInfo.status, selfInfo.id, activeCall.inviterId, activeCall.chatGroupId, activeCall.inviteeIds)
        }
        
        CallStore.shared.state.subscribe(callStateSelector)
            .removeDuplicates { prev, current in
                return prev.0 == current.0 &&
                prev.1 == current.1 &&
                prev.2 == current.2 &&
                prev.3 == current.3 &&
                prev.4 == current.4
            }
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in
                self?.updateControlsView()
                self?.updateCamera()
            }
            .store(in: &cancellables)
        
        CallStore.shared.state
            .subscribe(StatePublisherSelector(keyPath: \.allParticipants))
            .removeDuplicates { prev, curr in
                return prev.map { "\($0.id)_\($0.avatarURL)" } == curr.map { "\($0.id)_\($0.avatarURL)" }
            }
            .receive(on: RunLoop.main)
            .sink { [weak self] participants in
                self?.handleParticipantsAvatarUpdate(participants)
            }
            .store(in: &cancellables)
        
        NotificationCenter.default.publisher(for: UIDevice.orientationDidChangeNotification)
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in
                self?.handleOrientationChange()
            }
            .store(in: &cancellables)
    }
}
