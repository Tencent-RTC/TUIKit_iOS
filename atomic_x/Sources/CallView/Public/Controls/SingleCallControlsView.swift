//
//  SingleCallControlsView.swift
//  Pods
//
//  Created by yukiwwwang on 2025/9/25.
//

import UIKit
import RTCRoomEngine
import AtomicXCore
import Combine
import SnapKit

class SingleCallControlsView: UIView {
    
    // MARK: - Init
    override init(frame: CGRect) {
        super.init(frame: frame)
        setup()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    deinit {
        GCDTimer.cancel(timerName: timer) {}
    }
    
    // MARK: Private
    private var cancellables = Set<AnyCancellable>()
    private let deviceStore = DeviceStore.shared
    private var timer = ""
    private var isBlurBackgroundEnabled: Bool = false
    
    private lazy var acceptBtn: ControlsButton = createAcceptButton()
    private lazy var rejectBtn: ControlsButton = createRejectButton()
    private lazy var muteMicBtn: ControlsButton = createMuteMicButton()
    private lazy var closeCameraBtn: ControlsButton = createCloseCameraButton()
    private lazy var audioRouteButton: ControlsButton = createAudioRouteButton()
    private lazy var hangupBtn: ControlsButton = createHangupButton()
    private lazy var switchCameraBtn: ControlsButton = createSwitchCameraButton()
    private lazy var virtualBackgroundButton: ControlsButton = createVirtualBackgroundButton()
    private let audioRoutePickerView = CallViewAudioRoutePicker()
    
    // MARK: - Setup
    private func setup() {
        constructViewHierarchy()
        updateAudioRouteButton()
        subscribeDeviceState()
        
        timer = GCDTimer.start(interval: 1, repeats: true, async: true) { [weak self] in
            DispatchQueue.main.async {
                self?.updateAudioRouteButton()
            }
        }
    }
    
    private func updateMuteAudioButton(mute: Bool) {
        muteMicBtn.updateTitle(title: CallKitLocalization.localized(mute ? "muted" : "unmuted"))
        let imageName = mute ? "icon_mute_on" : "icon_mute"
        if let image = CallKitBundle.getBundleImage(name: imageName) {
            muteMicBtn.updateImage(image: image)
        }
    }
    
    private func updateCameraButton(isOn: Bool) {
        closeCameraBtn.updateTitle(title: CallKitLocalization.localized(isOn ? "cameraOn" : "cameraOff"))
        let imageName = isOn ? "icon_camera_on" : "icon_camera_off"
        if let image = CallKitBundle.getBundleImage(name: imageName) {
            closeCameraBtn.updateImage(image: image)
        }
        
        let state = CallStore.shared.state.value
        let isCaller = state.selfInfo.id == state.activeCall.inviterId
        let isCalleeWaiting = !isCaller && state.selfInfo.status == .waiting
        let isCallerWaiting = isCaller && state.selfInfo.status == .waiting
        guard state.activeCall.mediaType == .video else { return }

        if !isCalleeWaiting && !isCallerWaiting {
            switchCameraBtn.isHidden = !isOn
            virtualBackgroundButton.isHidden = !isOn
        }
    }
    
    private func updateAudioRouteButton(isSpeaker: Bool) {
        audioRouteButton.updateTitle(title: CallKitLocalization.localized(isSpeaker ? "speakerPhone" : "earpiece"))
        let imageName = isSpeaker ? "icon_handsfree_on" : "icon_handsfree"
        if let image = CallKitBundle.getBundleImage(name: imageName) {
            audioRouteButton.updateImage(image: image)
        }
    }
    
    private func updateVirtualBackgroundButton(isOpened: Bool, isSmallIcon: Bool = false) {
        let imageName: String
        if isSmallIcon {
            imageName = "virtual_background"
        } else {
            imageName = isOpened ? "icon_big_virtual_background_on" : "icon_big_virtual_background_off"
        }
        if let image = CallKitBundle.getBundleImage(name: imageName) {
            virtualBackgroundButton.updateImage(image: image)
        }
        let imageSize = isSmallIcon ? CGSize(width: 28.scale375Width(), height: 28.scale375Width()) : CallConstants.kBtnLargeSize
        virtualBackgroundButton.updateImageSize(size: imageSize)
        virtualBackgroundButton.updateTitle(title: isSmallIcon ? nil : CallKitLocalization.localized("blurBackground"))
    }
    
    private func updateSwitchCameraButton(isSmallIcon: Bool = false) {
        let imageName = isSmallIcon ? "switch_camera" : "icon_big_switch_camera"
        if let image = CallKitBundle.getBundleImage(name: imageName) {
            switchCameraBtn.updateImage(image: image)
        }
        let imageSize = isSmallIcon ? CGSize(width: 28.scale375Width(), height: 28.scale375Width()) : CallConstants.kBtnLargeSize
        switchCameraBtn.updateImageSize(size: imageSize)
        switchCameraBtn.updateTitle(title: isSmallIcon ? nil : CallKitLocalization.localized("switchCamera"))
    }
}

// MARK: - Layout
extension SingleCallControlsView {
    private func constructViewHierarchy() {
        addSubview(rejectBtn)
        addSubview(acceptBtn)
        addSubview(muteMicBtn)
        addSubview(audioRouteButton)
        addSubview(closeCameraBtn)
        addSubview(hangupBtn)
        addSubview(switchCameraBtn)
        addSubview(virtualBackgroundButton)
        addSubview(audioRoutePickerView)
    }
    
    func updateViewForCallState() {
        let activeCall = CallStore.shared.state.value.activeCall
        let isVideoCall = activeCall.mediaType == .video
        
        let selfInfo = CallStore.shared.state.value.selfInfo
        let isCaller = selfInfo.id == activeCall.inviterId
        let isCalleeWaiting = !isCaller && selfInfo.status == .waiting
        let isInCall = selfInfo.status == .accept
        
        [acceptBtn, rejectBtn, muteMicBtn, closeCameraBtn, audioRouteButton, hangupBtn, switchCameraBtn, virtualBackgroundButton, audioRoutePickerView].forEach { $0.isHidden = true }
        
        if isCalleeWaiting {
            acceptBtn.isHidden = false
            rejectBtn.isHidden = false
            
            let btnSize = CallConstants.kControlBtnSize
            rejectBtn.snp.remakeConstraints { make in
                make.centerX.equalTo(self).offset(-80.scale375Width())
                make.bottom.equalToSuperview().offset(-40.scale375Height())
                make.size.equalTo(btnSize)
            }
            acceptBtn.snp.remakeConstraints { make in
                make.centerX.equalTo(self).offset(80.scale375Width())
                make.bottom.equalToSuperview().offset(-40.scale375Height())
                make.size.equalTo(btnSize)
            }
            
        } else if isVideoCall {
            hangupBtn.isHidden = false
            if isInCall {
                hangupBtn.updateTitle(title: "")
                
                muteMicBtn.isHidden = false
                closeCameraBtn.isHidden = false
                switchCameraBtn.isHidden = false
                virtualBackgroundButton.isHidden = false
                updateSwitchCameraButton(isSmallIcon: true)
                updateVirtualBackgroundButton(isOpened: isBlurBackgroundEnabled, isSmallIcon: true)

                if AudioRouteManager.isBluetoothHeadsetConnected() {
                    audioRoutePickerView.isHidden = false
                } else {
                    audioRouteButton.isHidden = false
                }
                
                layoutInCallVideoButtons()
            } else {
                hangupBtn.updateTitle(title: CallKitLocalization.localized("cancel"))
                
                switchCameraBtn.isHidden = false
                virtualBackgroundButton.isHidden = false
                closeCameraBtn.isHidden = false
                updateSwitchCameraButton(isSmallIcon: false)
                updateVirtualBackgroundButton(isOpened: isBlurBackgroundEnabled, isSmallIcon: false)
                
                layoutWaitingVideoButtons()
            }
            
        } else {
            hangupBtn.updateTitle(title: CallKitLocalization.localized("hangup"))
            
            muteMicBtn.isHidden = false
            hangupBtn.isHidden = false

            if AudioRouteManager.isBluetoothHeadsetConnected() {
                audioRoutePickerView.isHidden = false
            } else {
                audioRouteButton.isHidden = false
            }
            
            layoutAudioButtons()
        }
    }
    
    private func layoutAudioButtons() {
        let btnSize = CallConstants.kControlBtnSize
        let horizontalOffset = CallConstants.horizontalOffset

        hangupBtn.snp.remakeConstraints { make in
            make.centerX.equalToSuperview()
            make.bottom.equalToSuperview().offset(-40.scale375Height())
            make.size.equalTo(btnSize)
        }
        muteMicBtn.snp.remakeConstraints { make in
            make.centerY.equalTo(hangupBtn)
            make.centerX.equalToSuperview().offset(-horizontalOffset)
            make.size.equalTo(btnSize)
        }
        audioRouteButton.snp.remakeConstraints { make in
            make.centerY.equalTo(hangupBtn)
            make.centerX.equalToSuperview().offset(horizontalOffset)
            make.size.equalTo(btnSize)
        }
        audioRoutePickerView.snp.remakeConstraints { make in
            make.edges.equalTo(audioRouteButton)
        }
    }
    
    private func layoutWaitingVideoButtons() {
        let btnSize = CallConstants.kControlBtnSize
        let horizontalOffset = CallConstants.horizontalOffset

        hangupBtn.snp.remakeConstraints { make in
            make.centerX.equalToSuperview()
            make.bottom.equalToSuperview().offset(-40.scale375Height())
            make.size.equalTo(btnSize)
        }

        virtualBackgroundButton.snp.remakeConstraints { make in
            make.centerX.equalToSuperview()
            make.bottom.equalTo(hangupBtn.snp.top).offset(-30.scale375Height())
            make.size.equalTo(btnSize)
        }
        switchCameraBtn.snp.remakeConstraints { make in
            make.centerY.equalTo(virtualBackgroundButton)
            make.centerX.equalToSuperview().offset(-horizontalOffset)
            make.size.equalTo(btnSize)
        }
        closeCameraBtn.snp.remakeConstraints { make in
            make.centerY.equalTo(virtualBackgroundButton)
            make.centerX.equalToSuperview().offset(horizontalOffset)
            make.size.equalTo(btnSize)
        }
    }
    
    private func layoutInCallVideoButtons() {
        let btnSize = CallConstants.kControlBtnSize
        let horizontalOffset = CallConstants.horizontalOffset

        hangupBtn.snp.remakeConstraints { make in
            make.centerX.equalToSuperview()
            make.bottom.equalToSuperview().offset(-40.scale375Height())
            make.size.equalTo(btnSize)
        }
        
        switchCameraBtn.snp.remakeConstraints { make in
            make.top.equalTo(hangupBtn).offset(16.scale375Width())
            make.centerX.equalToSuperview().offset(horizontalOffset)
            make.size.equalTo(btnSize)
        }
        
        virtualBackgroundButton.snp.remakeConstraints { make in
            make.top.equalTo(hangupBtn).offset(16.scale375Width())
            make.centerX.equalToSuperview().offset(-horizontalOffset)
            make.size.equalTo(btnSize)
        }
        
        audioRouteButton.snp.remakeConstraints { make in
            make.centerX.equalToSuperview()
            make.bottom.equalTo(hangupBtn.snp.top).offset(-30.scale375Height())
            make.size.equalTo(btnSize)
        }
        
        audioRoutePickerView.snp.remakeConstraints { make in
            make.edges.equalTo(audioRouteButton)
        }
        
        muteMicBtn.snp.remakeConstraints { make in
            make.centerY.equalTo(audioRouteButton)
            make.centerX.equalToSuperview().offset(-horizontalOffset)
            make.size.equalTo(btnSize)
        }
        
        closeCameraBtn.snp.remakeConstraints { make in
            make.centerY.equalTo(audioRouteButton)
            make.centerX.equalToSuperview().offset(horizontalOffset)
            make.size.equalTo(btnSize)
        }
    }
    
}

// MARK: Event Action
extension SingleCallControlsView {
    private func acceptTouchEvent(sender: UIButton) {
        CallStore.shared.accept { result in
            switch result {
            case .success:
                Logger.info("SingleCallControlsView - accept success in acceptTouchEvent.")
            case .failure(let error):
                Logger.info("SingleCallControlsView - accept failed in acceptTouchEvent. Code: \(error.code), Message: \(error.message)")
            }
        }
    }
    
    private func rejectTouchEvent(sender: UIButton) {
        CallStore.shared.reject { result in
            switch result {
            case .success:
                Logger.info("SingleCallControlsView - reject success in rejectTouchEvent.")
            case .failure(let error):
                Logger.info("SingleCallControlsView - reject failed in rejectTouchEvent. Code: \(error.code), Message: \(error.message)")
            }
        }
    }
    
    private func muteMicEvent(sender: UIButton) {
        let isMicrophoneOpened = deviceStore.state.value.microphoneStatus == .on
        if isMicrophoneOpened {
            deviceStore.closeLocalMicrophone()
        } else {
            deviceStore.openLocalMicrophone(completion: nil)
        }
    }
    
    private func closeCameraTouchEvent(sender: UIButton) {
        if deviceStore.state.value.cameraStatus == .on {
            deviceStore.closeLocalCamera()
        } else {
            deviceStore.openLocalCamera(isFront: deviceStore.state.value.isFrontCamera) {  result in
                switch result {
                case .success:
                    Logger.info("SingleCallControlsView - openLocalCamera success in closeCameraTouchEvent.")
                case .failure(let error):
                    Logger.error("SingleCallControlsView - openLocalCamera failed in closeCameraTouchEvent. Code: \(error.code), Message: \(error.message)")
                }
            }
        }
    }
    
    private func changeSpeakerEvent(sender: UIButton) {
        let route = deviceStore.state.value.currentAudioRoute
        if route == .speakerphone {
            deviceStore.setAudioRoute(.earpiece)
        } else {
            deviceStore.setAudioRoute(.speakerphone)
        }
    }
    
    private func hangupEvent(sender: UIButton) {
        CallStore.shared.hangup() { result in
            switch result {
            case .success:
                Logger.info("SingleCallControlsView - hangup success")
            case .failure(let error):
                Logger.info("SingleCallControlsView - hangup failed in hangupEvent. Code: \(error.code), Message: \(error.message)")
            }
        }
    }
    
    private func switchCameraTouchEvent(sender: UIButton) {
        deviceStore.switchCamera(isFront: !deviceStore.state.value.isFrontCamera)
    }
    
    private func virtualBackgroundTouchEvent(sender: UIButton) {
        isBlurBackgroundEnabled = !isBlurBackgroundEnabled
        let isInCall = CallStore.shared.state.value.selfInfo.status == .accept
        updateVirtualBackgroundButton(isOpened: isBlurBackgroundEnabled, isSmallIcon: isInCall)

        let level = isBlurBackgroundEnabled ? 3 : 0
        TUICallEngine.createInstance().setBlurBackground(level) { [weak self] code, message in
            if code != 0 {
                Logger.error("Set blur background failed: \(code) \(message ?? "")")
                DispatchQueue.main.async {
                    guard let self = self else { return }
                    self.isBlurBackgroundEnabled = !self.isBlurBackgroundEnabled
                    let isInCall = CallStore.shared.state.value.selfInfo.status == .accept
                    self.updateVirtualBackgroundButton(isOpened: self.isBlurBackgroundEnabled, isSmallIcon: isInCall)
                }
            }
        }
    }
    
    private func updateAudioRouteButton() {
        let isBluetoothConnected = AudioRouteManager.isBluetoothHeadsetConnected()
        AudioRouteManager.enableiOSAvroutePickerViewMode(isBluetoothConnected)
        let shouldShowRouteControl = !audioRouteButton.isHidden || !audioRoutePickerView.isHidden
            
        if shouldShowRouteControl {
            if isBluetoothConnected {
                audioRoutePickerView.isHidden = false
                audioRouteButton.isHidden = true
            } else {
                audioRoutePickerView.isHidden = true
                audioRouteButton.isHidden = false
            }
        }
    }
}

// MARK: Subscribe
extension SingleCallControlsView {
    private func subscribeDeviceState() {
        deviceStore.state
            .subscribe(StatePublisherSelector { $0.microphoneStatus == .off })
            .removeDuplicates()
            .receive(on: RunLoop.main)
            .sink { [weak self] isMuted in
                self?.updateMuteAudioButton(mute: isMuted)
            }
            .store(in: &cancellables)

        deviceStore.state
            .subscribe(StatePublisherSelector { $0.cameraStatus == .on })
            .removeDuplicates()
            .receive(on: RunLoop.main)
            .sink { [weak self] isOpened in
                self?.updateCameraButton(isOn: isOpened)
            }
            .store(in: &cancellables)
        
        deviceStore.state
            .subscribe(StatePublisherSelector(keyPath: \.currentAudioRoute))
            .removeDuplicates()
            .receive(on: RunLoop.main)
            .sink { [weak self] route in
                self?.updateAudioRouteButton(isSpeaker: route == .speakerphone)
            }
            .store(in: &cancellables)
    }
}

// MARK: Create Button
extension SingleCallControlsView {
    private func createAcceptButton() -> ControlsButton {
        ControlsButton.create(
            title: CallKitLocalization.localized("answer"),
            titleColor: CallConstants.Color_White,
            image: CallKitBundle.getBundleImage(name: "icon_dialing"),
            imageSize: CallConstants.kBtnSmallSize
        ) { [weak self] sender in
            self?.acceptTouchEvent(sender: sender)
        }
    }
    
    private func createRejectButton() -> ControlsButton {
        ControlsButton.create(
            title: CallKitLocalization.localized("decline"),
            titleColor: CallConstants.Color_White,
            image: CallKitBundle.getBundleImage(name: "icon_hangup"),
            imageSize: CallConstants.kBtnSmallSize
        ) { [weak self] sender in
            self?.rejectTouchEvent(sender: sender)
        }
    }
    
    private func createMuteMicButton() -> ControlsButton {
        let isMuted = deviceStore.state.value.microphoneStatus == .off
        return ControlsButton.create(
            title: CallKitLocalization.localized(isMuted ? "muted" : "unmuted"),
            titleColor: CallConstants.Color_White,
            image: CallKitBundle.getBundleImage(name: isMuted ? "icon_mute_on" : "icon_mute"),
            imageSize: CallConstants.kBtnSmallSize
        ) { [weak self] sender in
            self?.muteMicEvent(sender: sender)
        }
    }
    
    private func createCloseCameraButton() -> ControlsButton {
        let isCameraOn = deviceStore.state.value.cameraStatus == .on
        return ControlsButton.create(
            title: CallKitLocalization.localized(isCameraOn ? "cameraOn" : "cameraOff"),
            titleColor: CallConstants.Color_White,
            image: CallKitBundle.getBundleImage(name: isCameraOn ? "icon_camera_on" : "icon_camera_off"),
            imageSize: CallConstants.kBtnSmallSize
        ) { [weak self] sender in
            self?.closeCameraTouchEvent(sender: sender)
        }
    }
    
    private func createAudioRouteButton() -> ControlsButton {
        let isSpeaker = deviceStore.state.value.currentAudioRoute == .speakerphone
        let button = ControlsButton.create(
            title: CallKitLocalization.localized(isSpeaker ? "speakerPhone" : "earpiece"),
            titleColor: CallConstants.Color_White,
            image: CallKitBundle.getBundleImage(name: isSpeaker ? "icon_handsfree_on" : "icon_handsfree"),
            imageSize: CallConstants.kBtnSmallSize
        ) { [weak self] sender in
            self?.changeSpeakerEvent(sender: sender)
        }
        
        if DeviceUtils.isPad() {
            button.isUserInteractionEnabled = false
            button.alpha = 0.5
        }
        return button
    }
    
    private func createHangupButton() -> ControlsButton {
        ControlsButton.create(
            title: CallKitLocalization.localized("hangup"),
            titleColor: CallConstants.Color_White,
            image: CallKitBundle.getBundleImage(name: "icon_hangup"),
            imageSize: CallConstants.kBtnLargeSize
        ) { [weak self] sender in
            self?.hangupEvent(sender: sender)
        }
    }
    
    private func createSwitchCameraButton() -> ControlsButton {
        ControlsButton.create(
            title: CallKitLocalization.localized("switchCamera"),
            titleColor: CallConstants.Color_White,
            image: CallKitBundle.getBundleImage(name: "icon_big_switch_camera"),
            imageSize: CallConstants.kBtnLargeSize
        ) { [weak self] sender in
            self?.switchCameraTouchEvent(sender: sender)
        }
    }
    
    private func createVirtualBackgroundButton() -> ControlsButton {
        let isVirtualBgOn = isBlurBackgroundEnabled
        let imageName = isVirtualBgOn ? "icon_big_virtual_background_on" : "icon_big_virtual_background_off"
        return ControlsButton.create(
            title: CallKitLocalization.localized("blurBackground"),
            titleColor: CallConstants.Color_White,
            image: CallKitBundle.getBundleImage(name: imageName),
            imageSize: CallConstants.kBtnLargeSize
        ) { [weak self] sender in
            self?.virtualBackgroundTouchEvent(sender: sender)
        }
    }
}
