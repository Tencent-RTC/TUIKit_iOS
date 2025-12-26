//
//  CallingVibrator.swift
//  TUICallKit-Swift
//
//  Created by iveshe on 2024/12/31.
//

import AudioToolbox
import RTCRoomEngine
import RTCCommon
import Combine
import AtomicXCore

class CallingVibratorFeature: NSObject {
    override init() {
        super.init()
        subscribeCallState()
    }

    // MARK: Private
    private static var isVibrating = false;
    private var cancellables = Set<AnyCancellable>()
    
    private static func startVibration() {
        guard !isVibrating else { return }
        isVibrating = true
        vibrate()
    }
    
    private static func vibrate() {
        guard isVibrating else { return }
        
        AudioServicesPlaySystemSound(SystemSoundID(kSystemSoundID_Vibrate))
        
        DispatchQueue.global().asyncAfter(deadline: .now() + 1) {
            vibrate()
        }
    }

    private static func stopVibration() {
        isVibrating = false;
    }
    
    deinit {
        cancellables.forEach { $0.cancel() }
        cancellables.removeAll()
    }
}

// MARK: Subscribe
extension CallingVibratorFeature {
    private func subscribeCallState() {
        CallStore.shared.state.subscribe()
            .receive(on: DispatchQueue.main)
            .sink { [weak self] newState in
                guard self != nil else { return }
                let selfInfo = newState.selfInfo
                let isCalled = selfInfo.id != newState.activeCall.inviterId

                if selfInfo.status == .waiting && isCalled {
                    CallingVibratorFeature.startVibration()
                } else {
                    CallingVibratorFeature.stopVibration()
                }
            }
            .store(in: &cancellables)
    }
}
