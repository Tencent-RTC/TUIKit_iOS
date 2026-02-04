//
//  MultiCallControlsView.swift
//  Pods
//
//  Created by yukiwwwang on 2025/9/25.
//

import UIKit
import RTCRoomEngine
import AtomicXCore
import Combine
import SnapKit

enum MultiCallViewMode {
    case expanded
    case collapsed
}

protocol MultiCallControlsViewDelegate: AnyObject {
    func multiCallControlsView(_ view: MultiCallControlsView, didChangeModeHeight height: CGFloat)
}

class MultiCallControlsView: UIView {
    
    weak var delegate: MultiCallControlsViewDelegate?
    
    // MARK: - Init
    override init(frame: CGRect) {
        super.init(frame: frame)
        setup()
        subscribeDeviceState()
        NotificationCenter.default.addObserver(self, selector: #selector(handleOrientationChange), name: UIDevice.orientationDidChangeNotification, object: nil)
        updateAudioRouteButton()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    deinit {
        GCDTimer.cancel(timerName: timer) {}
        NotificationCenter.default.removeObserver(self)
    }
    
    private var isViewReady: Bool = false
    override func didMoveToWindow() {
        super.didMoveToWindow()
        if !isViewReady {
            constructViewHierarchy()
            activateConstraints()
            bindInteraction()
            isViewReady = true
            updateViewForCallState()
            updateAudioRouteButton()
        }
    }
    
    override func layoutSubviews() {
        super.layoutSubviews()
        setContainerViewCorner()
    }
    
    // MARK: Private Properties
    private var cancellables = Set<AnyCancellable>()
    private let deviceStore = DeviceStore.shared
    private var currentMode: MultiCallViewMode = .expanded
    private var timer = ""
    private let containerView = UIView()
    private var isBlurBackgroundEnabled: Bool = false
    
    private lazy var acceptBtn: ControlsButton = createAcceptButton()
    private lazy var rejectBtn: ControlsButton = createRejectButton()
    private lazy var muteMicBtn: ControlsButton = createMuteMicButton()
    private lazy var closeCameraBtn: ControlsButton = createCloseCameraButton()
    private lazy var audioRouteButton: ControlsButton = createAudioRouteButton()
    private lazy var hangupBtn: ControlsButton = createHangupButton()
    private lazy var switchCameraBtn: ControlsButton = createSwitchCameraButton()
    private lazy var virtualBackgroundBtn: ControlsButton = createVirtualBackgroundButton()
    
    private let audioRoutePickerView = CallViewAudioRoutePicker()
    private let matchBtn: UIButton = {
        let btn = UIButton(type: .system)
        btn.setBackgroundImage(CallKitBundle.getBundleImage(name: "icon_match"), for: .normal)
        btn.contentEdgeInsets = UIEdgeInsets(top: 10, left: 10, bottom: 10, right: 10)
        return btn
    }()
    
    private func setup() {
        containerView.backgroundColor = UIColor(hex: "#4F586B")
        containerView.isUserInteractionEnabled = true
        let panGesture = UIPanGestureRecognizer(target: self, action: #selector(handlePanGesture(_:)))
        containerView.addGestureRecognizer(panGesture)
        
        timer = GCDTimer.start(interval: 1, repeats: true, async: true) { [weak self] in
            DispatchQueue.main.async {
                self?.updateAudioRouteButton()
            }
        }
    }
    
    @objc func updateLayoutForOrientation() {
        DispatchQueue.main.async {
            self.activateConstraints()
        }
    }
    
    @objc private func handleOrientationChange() {
        updateLayoutForOrientation()
    }
    
    private func updateMuteAudioButton(mute: Bool) {
        muteMicBtn.updateTitle(title: CallKitLocalization.localized(mute ? "muted" : "unmuted"))
        let imageName = mute ? "icon_mute_on" : "icon_mute"
        if let image = CallKitBundle.getBundleImage(name: imageName) {
            muteMicBtn.updateImage(image: image)
        }
    }
    
    private func updateCloseCameraButton(open: Bool) {
        closeCameraBtn.updateTitle(title: CallKitLocalization.localized(open ? "cameraOn" : "cameraOff"))
        let imageName = open ? "icon_camera_on" : "icon_camera_off"
        if let image = CallKitBundle.getBundleImage(name: imageName) {
            closeCameraBtn.updateImage(image: image)
        }
        
        let isCaller = CallStore.shared.state.value.selfInfo.id == CallStore.shared.state.value.activeCall.inviterId
        let isCalledWaiting = !isCaller && CallStore.shared.state.value.selfInfo.status == .waiting
        if !isCalledWaiting && currentMode == .expanded {
            switchCameraBtn.isHidden = !open
            virtualBackgroundBtn.isHidden = !open
        }
    }
    
    private func updateAudioRouteButton(isSpeaker: Bool) {
        audioRouteButton.updateTitle(title: CallKitLocalization.localized(isSpeaker ? "speakerPhone" : "earpiece"))
        let imageName = isSpeaker ? "icon_handsfree_on" : "icon_handsfree"
        if let image = CallKitBundle.getBundleImage(name: imageName) {
            audioRouteButton.updateImage(image: image)
        }
    }
    
    private func updateVirtualBackgroundButton(isOpened: Bool) {
        if let image = CallKitBundle.getBundleImage(name: "virtual_background") {
            virtualBackgroundBtn.updateImage(image: image)
        }
    }
    
    private func updateSwitchCameraButton() {
        if let image = CallKitBundle.getBundleImage(name: "switch_camera") {
            switchCameraBtn.updateImage(image: image)
        }
    }
    
    private func setContainerViewCorner() {
        let maskLayer = CAShapeLayer()
        let height = self.currentMode == .collapsed ? CallConstants.groupSmallFunctionViewHeight : CallConstants.groupFunctionViewHeight
        maskLayer.path = UIBezierPath(
            roundedRect: CGRect(x: 0, y: 0, width: self.containerView.bounds.width, height: height),
            byRoundingCorners: [.topLeft, .topRight],
            cornerRadii: CGSize(width: 20, height: 20)
        ).cgPath
        self.containerView.layer.mask = maskLayer
    }
}

// MARK: Layout
extension MultiCallControlsView {
    private func constructViewHierarchy() {
        addSubview(containerView)
        addSubview(acceptBtn)
        addSubview(rejectBtn)
        addSubview(muteMicBtn)
        addSubview(audioRouteButton)
        addSubview(closeCameraBtn)
        addSubview(hangupBtn)
        addSubview(switchCameraBtn)
        addSubview(virtualBackgroundBtn)
        addSubview(audioRoutePickerView)
        addSubview(matchBtn)
    }
    
    private func activateConstraints() {
        let btnSize = 60.scale375Width()
        let btnSpacing: CGFloat = CallConstants.horizontalOffset

        rejectBtn.snp.remakeConstraints { make in
            make.centerX.equalTo(self).offset(-80.scale375Width())
            make.top.bottom.equalTo(self)
            make.size.equalTo(CallConstants.kControlBtnSize)
        }
        
        acceptBtn.snp.remakeConstraints { make in
            make.centerX.equalTo(self).offset(80.scale375Width())
            make.top.bottom.equalTo(self)
            make.size.equalTo(CallConstants.kControlBtnSize)
        }
        
        let containerHeight: CGFloat = currentMode == .collapsed ? CallConstants.groupSmallFunctionViewHeight : CallConstants.groupFunctionViewHeight
        let containerLeading: CGFloat = 30.scale375Width()
        let containerTrailing: CGFloat = -30.scale375Width()
        
        containerView.snp.remakeConstraints { make in
            make.leading.equalTo(safeAreaLayoutGuide.snp.leading).offset(UIWindow.isPortrait ? 0 : containerLeading)
            make.trailing.equalTo(safeAreaLayoutGuide.snp.trailing).offset(UIWindow.isPortrait ? 0 : containerTrailing)
            make.bottom.equalToSuperview()
            make.height.equalTo(containerHeight)
        }
        
        hangupBtn.snp.remakeConstraints { make in
            make.bottom.equalToSuperview().offset(-CallConstants.groupFunctionBottomHeight)
            make.centerX.equalToSuperview()
            make.size.equalTo(btnSize)
        }
        
        audioRouteButton.snp.remakeConstraints { make in
            make.bottom.equalTo(hangupBtn.snp.top).offset(-50.scale375Height())
            make.centerX.equalTo(containerView.snp.centerX)
            make.size.equalTo(btnSize)
        }
        
        audioRoutePickerView.snp.remakeConstraints { make in
            make.edges.equalTo(audioRouteButton)
        }
        
        closeCameraBtn.snp.remakeConstraints { make in
            make.centerY.equalTo(audioRouteButton)
            make.centerX.equalTo(containerView.snp.centerX).offset(btnSpacing)
            make.size.equalTo(btnSize)
        }
        
        muteMicBtn.snp.remakeConstraints { make in
            make.centerY.equalTo(audioRouteButton)
            make.centerX.equalTo(containerView.snp.centerX).offset(-btnSpacing)
            make.size.equalTo(btnSize)
        }
        
        matchBtn.snp.remakeConstraints { make in
            make.centerY.equalTo(hangupBtn)
            make.leading.equalTo(containerView.snp.leading).offset(16.scale375Width())
            make.size.equalTo(28.scale375Width())
        }
        
        virtualBackgroundBtn.snp.remakeConstraints { make in
            make.top.equalTo(hangupBtn).offset(16.scale375Width())
            make.centerX.equalTo(containerView.snp.centerX).offset(-btnSpacing)
            make.size.equalTo(btnSize)
        }
        
        switchCameraBtn.snp.remakeConstraints { make in
            make.top.equalTo(hangupBtn).offset(16.scale375Width())
            make.centerX.equalTo(containerView.snp.centerX).offset(btnSpacing)
            make.size.equalTo(btnSize)
        }
    }
    
    func updateViewForCallState() {
        guard isViewReady else { return }
        let isCaller = CallStore.shared.state.value.selfInfo.id == CallStore.shared.state.value.activeCall.inviterId
        let isCalledWaiting = !isCaller && CallStore.shared.state.value.selfInfo.status == .waiting

        [acceptBtn, rejectBtn, muteMicBtn, closeCameraBtn, audioRouteButton, hangupBtn, switchCameraBtn, virtualBackgroundBtn, matchBtn, audioRoutePickerView].forEach { $0.isHidden = true }
        containerView.isHidden = true
        
        if isCalledWaiting {
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
        } else {
            containerView.isHidden = false
            hangupBtn.isHidden = false
            muteMicBtn.isHidden = false
            closeCameraBtn.isHidden = false
            matchBtn.isHidden = false
            
            let isCameraOn = deviceStore.state.value.cameraStatus == .on
            switchCameraBtn.isHidden = !isCameraOn
            virtualBackgroundBtn.isHidden = !isCameraOn
            
            if AudioRouteManager.isBluetoothHeadsetConnected() {
                audioRoutePickerView.isHidden = false
            } else {
                audioRouteButton.isHidden = false
            }
            
            refreshButton()
        }
    }
    
    private func refreshButton() {
        let btnSize = 60.scale375Width()
        let btnSpacing: CGFloat = CallConstants.horizontalOffset
        
        hangupBtn.snp.remakeConstraints { make in
            make.bottom.equalToSuperview().offset(-CallConstants.groupFunctionBottomHeight)
            make.centerX.equalToSuperview()
            make.size.equalTo(btnSize)
        }
        
        audioRouteButton.snp.remakeConstraints { make in
            make.bottom.equalTo(hangupBtn.snp.top).offset(-50.scale375Height())
            make.centerX.equalTo(containerView.snp.centerX)
            make.size.equalTo(btnSize)
        }
        
        audioRoutePickerView.snp.remakeConstraints { make in
            make.edges.equalTo(audioRouteButton)
        }
        
        closeCameraBtn.snp.remakeConstraints { make in
            make.centerY.equalTo(audioRouteButton)
            make.centerX.equalTo(containerView.snp.centerX).offset(btnSpacing)
            make.size.equalTo(btnSize)
        }
        
        muteMicBtn.snp.remakeConstraints { make in
            make.centerY.equalTo(audioRouteButton)
            make.centerX.equalTo(containerView.snp.centerX).offset(-btnSpacing)
            make.size.equalTo(btnSize)
        }
        
        matchBtn.snp.remakeConstraints { make in
            make.centerY.equalTo(hangupBtn)
            make.leading.equalTo(containerView.snp.leading).offset(16.scale375Width())
            make.size.equalTo(28.scale375Width())
        }
        
        virtualBackgroundBtn.snp.remakeConstraints { make in
            make.top.equalTo(hangupBtn).offset(16.scale375Width())
            make.centerX.equalTo(containerView.snp.centerX).offset(-btnSpacing)
            make.size.equalTo(btnSize)
        }
        
        switchCameraBtn.snp.remakeConstraints { make in
            make.top.equalTo(hangupBtn).offset(16.scale375Width())
            make.centerX.equalTo(containerView.snp.centerX).offset(btnSpacing)
            make.size.equalTo(btnSize)
        }
    }
    
    private func updateAudioRouteButton() {
        let isCaller = CallStore.shared.state.value.selfInfo.id == CallStore.shared.state.value.activeCall.inviterId
        let isCalledWaiting = !isCaller && CallStore.shared.state.value.selfInfo.status == .waiting

        if isCalledWaiting {
            audioRoutePickerView.isHidden = true
            audioRouteButton.isHidden = true
            return
        }
        
        if AudioRouteManager.isBluetoothHeadsetConnected() {
            audioRoutePickerView.isHidden = false
            audioRouteButton.isHidden = true
            AudioRouteManager.enableiOSAvroutePickerViewMode(true)
        } else {
            audioRoutePickerView.isHidden = true
            audioRouteButton.isHidden = false
            AudioRouteManager.enableiOSAvroutePickerViewMode(false)
        }
    }
}

// MARK: Event Action
extension MultiCallControlsView {
    private func bindInteraction() {
        matchBtn.addTarget(self, action: #selector(matchTouchEvent(sender:)), for: .touchUpInside)
    }
    
    private func acceptTouchEvent(sender: UIButton) {
        CallStore.shared.accept { result in
            switch result {
            case .success:
                Logger.info("MultiCallControlsView - accept success in acceptTouchEvent.")
            case .failure(let error):
                Logger.info("MultiCallControlsView - accept failed in acceptTouchEvent. Code: \(error.code), Message: \(error.message)")
            }
        }
    }
    
    private func rejectTouchEvent(sender: UIButton) {
        CallStore.shared.reject { result in
            switch result {
            case .success:
                Logger.info("MultiCallControlsView - reject success in rejectTouchEvent.")
            case .failure(let error):
                Logger.info("MultiCallControlsView - reject failed in rejectTouchEvent. Code: \(error.code), Message: \(error.message)")
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
            deviceStore.openLocalCamera(isFront: deviceStore.state.value.isFrontCamera) { result in
                switch result {
                case .success:
                    Logger.info("MultiCallControlsView - openLocalCamera success in closeCameraTouchEvent.")
                case .failure(let error):
                    Logger.error("MultiCallControlsView - openLocalCamera failed in closeCameraTouchEvent. Code: \(error.code), Message: \(error.message)")
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
        CallStore.shared.hangup { result in
            switch result {
            case .success:
                Logger.info("MultiCallControlsView - hangup success")
            case .failure(let error):
                Logger.info("MultiCallControlsView - hangup failed in hangupEvent. Code: \(error.code), Message: \(error.message)")
            }
        }
    }
    
    private func switchCameraTouchEvent(sender: UIButton) {
        deviceStore.switchCamera(isFront: !deviceStore.state.value.isFrontCamera)
    }
    
    private func virtualBackgroundTouchEvent(sender: UIButton) {
        isBlurBackgroundEnabled = !isBlurBackgroundEnabled
        updateVirtualBackgroundButton(isOpened: isBlurBackgroundEnabled)
        
        let level = isBlurBackgroundEnabled ? 3 : 0
        TUICallEngine.createInstance().setBlurBackground(level) { [weak self] code, message in
            if code != 0 {
                Logger.error("Set blur background failed: \(code) \(message ?? "")")
                DispatchQueue.main.async {
                    guard let self = self else { return }
                    self.isBlurBackgroundEnabled = !self.isBlurBackgroundEnabled
                    self.updateVirtualBackgroundButton(isOpened: self.isBlurBackgroundEnabled)
                }
            }
        }
    }
    
    @objc private func matchTouchEvent(sender: UIButton) {
        if currentMode == .collapsed {
            setExpansion()
        } else {
            setNonExpansion()
        }
    }
    
    @objc private func handlePanGesture(_ gesture: UIPanGestureRecognizer) {
        let scale = gesture.translation(in: containerView).y / 105
        if gesture.state == .ended {
            if scale > 0 {
                scale > 0.5 ? setNonExpansion() : setExpansion()
            } else {
                scale < -0.5 ? setExpansion() : setNonExpansion()
            }
        }
    }
}

// MARK: Subscribe
extension MultiCallControlsView {
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
                self?.updateCloseCameraButton(open: isOpened)
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

// MARK: Creat Button
extension MultiCallControlsView {
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
            title: nil,
            titleColor: CallConstants.Color_White,
            image: CallKitBundle.getBundleImage(name: "icon_hangup"),
            imageSize: CallConstants.kBtnLargeSize
        ) { [weak self] sender in
            self?.hangupEvent(sender: sender)
        }
    }
    
    private func createSwitchCameraButton() -> ControlsButton {
        let imageSize = CGSize(width: 28.scale375Width(), height: 28.scale375Width())
        return ControlsButton.create(
            title: nil,
            titleColor: CallConstants.Color_White,
            image: CallKitBundle.getBundleImage(name: "switch_camera"),
            imageSize: imageSize
        ) { [weak self] sender in
            self?.switchCameraTouchEvent(sender: sender)
        }
    }
    
    private func createVirtualBackgroundButton() -> ControlsButton {
        let imageSize = CGSize(width: 28.scale375Width(), height: 28.scale375Width())
        return ControlsButton.create(
            title: nil,
            titleColor: CallConstants.Color_White,
            image: CallKitBundle.getBundleImage(name: "virtual_background"),
            imageSize: imageSize
        ) { [weak self] sender in
            self?.virtualBackgroundTouchEvent(sender: sender)
        }
    }
}

// MARK: Expansion
extension MultiCallControlsView {
    private func setNonExpansion() {
        guard currentMode != .collapsed else { return }
        currentMode = .collapsed
        activateConstraints()
        delegate?.multiCallControlsView(self, didChangeModeHeight: CallConstants.groupSmallFunctionViewHeight)
        
        let alpha: CGFloat = 0.0
        let scale: CGFloat = 2.0 / 3.0
        
        let muteMicOffsetX = 20.scale375Width()
        let changeSpeakerOffsetX = -10.scale375Width()
        let closeCameraOffsetX = -45.scale375Width()
        let hangupOffsetX = 140.scale375Width()
        let hangupTranslationOffsetY = -(CallConstants.groupFunctionBaseControlBtnHeight + 28.scale375Height())
        let titleLabelTranslationOffsetY = -12.scale375Width()
        
        switchCameraBtn.isHidden = true
        virtualBackgroundBtn.isHidden = true
        
        UIView.animate(withDuration: CallConstants.groupFunctionAnimationDuration, animations: {
            self.muteMicBtn.titleLabel.alpha = alpha
            self.audioRouteButton.titleLabel.alpha = alpha
            self.closeCameraBtn.titleLabel.alpha = alpha
            
            self.muteMicBtn.titleLabel.transform = CGAffineTransform(translationX: 0, y: titleLabelTranslationOffsetY)
            self.audioRouteButton.titleLabel.transform = CGAffineTransform(translationX: 0, y: titleLabelTranslationOffsetY)
            self.closeCameraBtn.titleLabel.transform = CGAffineTransform(translationX: 0, y: titleLabelTranslationOffsetY)
            
            self.muteMicBtn.button.transform = CGAffineTransform(scaleX: scale, y: scale)
            self.audioRouteButton.button.transform = CGAffineTransform(scaleX: scale, y: scale)
            self.closeCameraBtn.button.transform = CGAffineTransform(scaleX: scale, y: scale)
            self.hangupBtn.button.transform = CGAffineTransform(scaleX: scale, y: scale)
            
            self.muteMicBtn.transform = CGAffineTransform(translationX: muteMicOffsetX, y: -hangupTranslationOffsetY)
            self.audioRouteButton.transform = CGAffineTransform(translationX: changeSpeakerOffsetX, y: -hangupTranslationOffsetY)
            self.audioRoutePickerView.transform = CGAffineTransform(translationX: changeSpeakerOffsetX, y: -hangupTranslationOffsetY)
            self.closeCameraBtn.transform = CGAffineTransform(translationX: closeCameraOffsetX, y: -hangupTranslationOffsetY)
            self.hangupBtn.transform = CGAffineTransform(translationX: hangupOffsetX, y: -2.scale375Height())
            self.matchBtn.transform = CGAffineTransform.identity
            
            self.layoutIfNeeded()
        }, completion: { _ in
            self.setContainerViewCorner()
        })
        
        let rotationAnimation = CABasicAnimation(keyPath: "transform.rotation.z")
        rotationAnimation.toValue = NSNumber(value: Double.pi)
        rotationAnimation.duration = CallConstants.groupFunctionAnimationDuration
        rotationAnimation.fillMode = .forwards
        rotationAnimation.isRemovedOnCompletion = false
        matchBtn.layer.add(rotationAnimation, forKey: "rotationAnimation")
    }
    
    private func setExpansion() {
        guard currentMode != .expanded else { return }
        currentMode = .expanded
        activateConstraints()
        delegate?.multiCallControlsView(self, didChangeModeHeight: CallConstants.groupFunctionViewHeight)
        
        let isCameraOn = deviceStore.state.value.cameraStatus == .on
        switchCameraBtn.isHidden = !isCameraOn
        virtualBackgroundBtn.isHidden = !isCameraOn
        
        UIView.animate(withDuration: CallConstants.groupFunctionAnimationDuration, animations: {
            self.muteMicBtn.titleLabel.alpha = 1
            self.audioRouteButton.titleLabel.alpha = 1
            self.closeCameraBtn.titleLabel.alpha = 1
            
            self.muteMicBtn.titleLabel.transform = CGAffineTransform.identity
            self.audioRouteButton.titleLabel.transform = CGAffineTransform.identity
            self.closeCameraBtn.titleLabel.transform = CGAffineTransform.identity
            
            self.muteMicBtn.button.transform = CGAffineTransform.identity
            self.audioRouteButton.button.transform = CGAffineTransform.identity
            self.closeCameraBtn.button.transform = CGAffineTransform.identity
            self.hangupBtn.button.transform = CGAffineTransform.identity
            
            self.muteMicBtn.transform = CGAffineTransform.identity
            self.audioRouteButton.transform = CGAffineTransform.identity
            self.audioRoutePickerView.transform = CGAffineTransform.identity
            self.closeCameraBtn.transform = CGAffineTransform.identity
            self.hangupBtn.transform = CGAffineTransform.identity
            self.matchBtn.transform = CGAffineTransform.identity
            
            self.layoutIfNeeded()
        }, completion: { _ in
            self.setContainerViewCorner()
        })
        
        let rotationAnimation = CABasicAnimation(keyPath: "transform.rotation.z")
        rotationAnimation.toValue = NSNumber(value: 0.0)
        rotationAnimation.duration = CallConstants.groupFunctionAnimationDuration
        rotationAnimation.fillMode = .forwards
        rotationAnimation.isRemovedOnCompletion = true
        matchBtn.layer.add(rotationAnimation, forKey: "rotationAnimation")
    }
}
