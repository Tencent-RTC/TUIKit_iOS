//
//  CallingBellFeature.swift
//  TUICallKit
//
//  Created by vincepzhang on 2022/12/30.
//

import Foundation
import AVFAudio
import RTCRoomEngine
import RTCCommon
import Combine
import AtomicXCore
import TUICore

#if canImport(TXLiteAVSDK_TRTC)
import TXLiteAVSDK_TRTC
#elseif canImport(TXLiteAVSDK_Professional)
import TXLiteAVSDK_Professional
#endif

let CALLKIT_AUDIO_DIAL_ID: Int32 = 48

class CallingBellFeature: NSObject, AVAudioPlayerDelegate {
    enum CallingBellType {
        case CallingBellTypeHangup
        case CallingBellTypeCalled
        case CallingBellTypeDial
    }
    
    override init() {
        super.init()
        registerNotifications()
        subscribeCallState()
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
        cancellables.forEach { $0.cancel() }
        cancellables.removeAll()
    }
    
    var player: AVAudioPlayer?
    var loop: Bool = true
    private var needPlayRingtone: Bool = false;
    private var cancellables = Set<AnyCancellable>()
    private let deviceStore = DeviceStore.shared
    
    func startMusicBasedOnAppState(type: CallingBellType) {
        if UIApplication.shared.applicationState != .background {
            startPlayMusic(type: type)
        } else {
            if TUICore.getService(TUIVoIPExtension_Service) != nil { return }
            needPlayRingtone = true
        }
    }
    
    func registerNotifications() {
        if #available(iOS 13.0, *) {
            NotificationCenter.default.addObserver(self, selector: #selector(appDidBecomeActive),
                                                   name: UIScene.didActivateNotification,
                                                   object: nil)
        } else {
            NotificationCenter.default.addObserver(self, selector: #selector(appDidBecomeActive),
                                                   name: UIApplication.didBecomeActiveNotification,
                                                   object: nil)
        }
    }
    
    @objc func appDidBecomeActive() {
        if needPlayRingtone {
            let _ = startPlayMusic(type: .CallingBellTypeCalled)
            needPlayRingtone = false;
        }
    }
    
    func startPlayMusic(type: CallingBellType) {
        guard let bundle = CallKitBundle.getTUICallKitBundle() else { return }
        switch type {
        case .CallingBellTypeHangup:
            let path = bundle.bundlePath + "/AudioFile" + "/phone_hangup.mp3"
            let url = URL(fileURLWithPath: path)
            return startPlayMusicBySystemPlayer(url: url, loop: false)
        case .CallingBellTypeCalled:
            if TUICallKitImpl.shared.globalState.enableMuteMode {
                return
            }
            var path = bundle.bundlePath + "/AudioFile" + "/phone_ringing.mp3"
            
            if let value = UserDefaults.standard.object(forKey: TUI_CALLING_BELL_KEY) as? String {
                path = value
            }
            
            let url = URL(fileURLWithPath: path)
            return startPlayMusicBySystemPlayer(url: url)
        case .CallingBellTypeDial:
            let path = bundle.bundlePath + "/AudioFile" + "/phone_dialing.m4a"
            startPlayMusicByTRTCPlayer(path: path, id: CALLKIT_AUDIO_DIAL_ID)
            return
        }
    }
    
    func stopPlayMusic() {
        setAudioSessionWith(category: .playAndRecord)
        
        if CallStore.shared.state.value.selfInfo.id == CallStore.shared.state.value.activeCall.inviterId {
            stopPlayMusicByTRTCPlayer(id: CALLKIT_AUDIO_DIAL_ID)
            return
        }
        stopPlayMusicBySystemPlayer()
        needPlayRingtone = false
    }
    
    // MARK: TRTC Audio Player
    private func startPlayMusicByTRTCPlayer(path: String, id: Int32) {
        let mediaType = CallStore.shared.state.value.activeCall.mediaType
        let audioRoute: AudioRoute = mediaType == .audio ? .earpiece : .speakerphone
        deviceStore.setAudioRoute(audioRoute)
        
        let param = TXAudioMusicParam()
        param.id = id
        param.isShortFile = true
        param.path = path
        
        let audioEffectManager = TUICallEngine.createInstance().getTRTCCloudInstance().getAudioEffectManager()
        audioEffectManager.startPlayMusic(param, onStart: nil, onProgress: nil)
        audioEffectManager.setMusicPlayoutVolume(id, volume: 100)
    }
    
    private func stopPlayMusicByTRTCPlayer(id: Int32) {
        let audioEffectManager = TUICallEngine.createInstance().getTRTCCloudInstance().getAudioEffectManager()
        audioEffectManager.stopPlayMusic(id)
    }
    
    // MARK: System AVAudio Player
    private func startPlayMusicBySystemPlayer(url: URL, loop: Bool = true) {
        self.loop = loop
        
        if player != nil {
            stopPlayMusicBySystemPlayer()
        }
        
        setAudioSessionForRingtone()
        
        do {
            player = try AVAudioPlayer(contentsOf: url)
        } catch let error as NSError {
            print("Error: \(error.localizedDescription)")
            return
        }
        
        guard let prepare = player?.prepareToPlay(), prepare else {
            return
        }
        
        player?.delegate = self
        player?.play()
    }
    
    private func stopPlayMusicBySystemPlayer() {
        player?.stop()
        player = nil
    }
    
    // MARK: AVAudioPlayerDelegate
    func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        if loop {
            player.play()
        } else {
            stopPlayMusicBySystemPlayer()
        }
    }
    
    func audioPlayerDecodeErrorDidOccur(_ player: AVAudioPlayer, error: Error?) {
        if error != nil {
            stopPlayMusicBySystemPlayer()
        }
    }
    
    private func setAudioSessionWith(category: AVAudioSession.Category) {
        let audioSession = AVAudioSession.sharedInstance()
        do {
            try audioSession.setCategory(category, options: [.allowBluetooth, .allowBluetoothA2DP, .mixWithOthers])
            try audioSession.setActive(true)
        } catch {
            Logger.error("Error setting up audio session: \(error)")
        }
    }
    
    private func setAudioSessionForRingtone() {
        let audioSession = AVAudioSession.sharedInstance()
        do {
            try audioSession.setCategory(.playback, options: [.allowBluetooth, .allowBluetoothA2DP, .mixWithOthers])
            try audioSession.overrideOutputAudioPort(.speaker)
            try audioSession.setActive(true)
        } catch {
            Logger.error("Error setting up audio session for ringtone: \(error)")
        }
    }
}

// MARK: Subscribe
extension CallingBellFeature {
    private func subscribeCallState() {
        CallStore.shared.state.subscribe(StatePublisherSelector<CallState, CallParticipantStatus>(keyPath: \.selfInfo.status))
            .removeDuplicates()
            .receive(on: DispatchQueue.main)
            .sink { [weak self] status in
                guard let self = self else { return }
                if status == .accept {
                    self.stopPlayMusic()
                }
            }
            .store(in: &cancellables)
        
        CallStore.shared.callEventPublisher
            .receive(on: DispatchQueue.main)
            .sink { [weak self] event in
                guard let self = self else { return }
                self.handleCallEvent(event)
            }
            .store(in: &cancellables)
    }
    
    private func handleCallEvent(_ event: CallEvent) {
        let isCaller = CallStore.shared.state.value.selfInfo.id == CallStore.shared.state.value.activeCall.inviterId
        
        switch event {
        case .onCallStarted(_, _):
            if isCaller {
                startPlayMusic(type: .CallingBellTypeDial)
            }
        case .onCallReceived(_, _, _):
            if !isCaller {
                startMusicBasedOnAppState(type: .CallingBellTypeCalled)
            }
        case .onCallEnded(_, _, _, _):
            stopPlayMusic()
        }
    }
}
