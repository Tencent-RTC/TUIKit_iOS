//
//  AudioRouteButton.swift
//  Pods
//
//  Created by vincepzhang on 2025/5/12.
//

import AVKit
import AVRouting
import AtomicXCore
import Combine

#if canImport(TXLiteAVSDK_TRTC)
import TXLiteAVSDK_TRTC
#elseif canImport(TXLiteAVSDK_Professional)
import TXLiteAVSDK_Professional
#endif

class CallViewAudioRoutePicker: AVRoutePickerView {
    lazy var changeSpeakerBtn: ControlsButton = {
        var titleKey: String = ""
        if AudioRouteManager.isBluetoothHeadsetActive() {
            titleKey = AudioRouteManager.getCurrentOutputDeviceName() ?? "Bluetooth"
        } else {
            titleKey = deviceStore.state.value.currentAudioRoute == .speakerphone ? "speaker" : "earpiece"
        }
        let imageName: String = "icon_audio_route_picker"
        let changeSpeakerBtn = ControlsButton.create(title: CallKitLocalization.localized(titleKey),
                                                    titleColor: CallConstants.Color_White,
                                                    image: CallKitBundle.getBundleImage(name: imageName),
                                                    imageSize: CallConstants.kBtnSmallSize, buttonAction: { sender in })
        changeSpeakerBtn.isUserInteractionEnabled = false
        return changeSpeakerBtn
    }()
    
    // MARK: Init
    override init(frame: CGRect) {
        super.init(frame: frame)
        subscribeDeviceState()
        NotificationCenter.default.addObserver(self, selector: #selector(handleSystemRouteChange), name: AVAudioSession.routeChangeNotification, object: nil)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
        
    deinit {
        NotificationCenter.default.removeObserver(self)
    }

    @objc private func handleSystemRouteChange() {
        DispatchQueue.main.async {
            self.updateChangeSpeakerButtonTitle()
        }
    }
        
    // MARK: Private
    private let deviceStore = DeviceStore.shared
    private var cancellables = Set<AnyCancellable>()
    private func updateChangeSpeakerButtonTitle() {
        var titleKey: String = ""
        if AudioRouteManager.isBluetoothHeadsetActive() {
            let deviceName = AudioRouteManager.getCurrentOutputDeviceName() ?? "Bluetooth"
            changeSpeakerBtn.updateTitle(title: deviceName)
            return
        }
        if deviceStore.state.value.currentAudioRoute == .speakerphone {
            titleKey = "speakerPhone"
        } else {
            titleKey = "earpiece"
        } 
        changeSpeakerBtn.updateTitle(title:  CallKitLocalization.localized(titleKey))
    }
    
    // MARK: UI Specification Processing
    private var isViewReady: Bool = false
    override func didMoveToWindow() {
        super.didMoveToWindow()
        guard !isViewReady else { return }
        constructViewHierarchy()
        activateConstraints()
        isViewReady = true
    }
}

// MARK: Layout
extension CallViewAudioRoutePicker {
    func constructViewHierarchy() {
        self.subviews.first?.removeFromSuperview()
        addSubview(changeSpeakerBtn)
    }
    
    func activateConstraints() {
        changeSpeakerBtn.snp.makeConstraints { make in
                make.top.leading.trailing.bottom.equalToSuperview()
        }
    }
}

// MARK: Subscribe
extension CallViewAudioRoutePicker {
    func subscribeDeviceState() {
        deviceStore.state.subscribe(StatePublisherSelector(keyPath: \.currentAudioRoute))
            .removeDuplicates()
            .receive(on: RunLoop.main)
            .sink { [weak self] route in
                guard let self = self else { return }
                self.updateChangeSpeakerButtonTitle()
            }
            .store(in: &cancellables)
    }
}
