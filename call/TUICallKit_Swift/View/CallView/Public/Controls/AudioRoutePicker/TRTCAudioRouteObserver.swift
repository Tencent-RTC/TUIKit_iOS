//
//  TRTCAudioRouteObserver.swift
//  Pods
//
//  Created by vincepzhang on 2025/6/3.
//

import RTCRoomEngine
import AtomicXCore

#if canImport(TXLiteAVSDK_TRTC)
import TXLiteAVSDK_TRTC
#elseif canImport(TXLiteAVSDK_Professional)
import TXLiteAVSDK_Professional
#endif

// TODO: 等支持 在RoutePick 模式下支持setAudioRoute 后删除
class TRTCAudioRouteObserver: NSObject, TRTCCloudDelegate {
    static let shared = TRTCAudioRouteObserver()
    private let deviceStore = DeviceStore.shared
    
    override init() {
        super.init()
        TUICallEngine.createInstance().getTRTCCloudInstance().addDelegate(self)
    }
    
    deinit {
        TUICallEngine.createInstance().getTRTCCloudInstance().removeDelegate(self)
    }
    
    func onAudioRouteChanged(_ route: TRTCAudioRoute, from fromRoute: TRTCAudioRoute) {
        guard AudioRouteManager.getIsEnableiOSAvroutePickerViewMode() || route == .modeBluetoothHeadset else { return }
        
        var newDevice: AudioRoute = .speakerphone
        
        switch route {
        case .modeEarpiece:
            newDevice = .earpiece
        case .modeSpeakerphone:
            newDevice = .speakerphone
        case .modeBluetoothHeadset:
            newDevice = .earpiece
        case .modeWiredHeadset:
            newDevice = .earpiece
        default:
            return
        }
        deviceStore.setAudioRoute(newDevice)
    }
        
    func onEnterRoom(_ result: Int) {
        if !AudioRouteManager.getIsEnableiOSAvroutePickerViewMode() { return }
        
        let callStatus = CallStore.shared.state.value.selfInfo.status
        let mediaType = CallStore.shared.state.value.activeCall.mediaType
        
        if callStatus == .none { return }
        
        if mediaType == .video {
            deviceStore.setAudioRoute(.speakerphone)
        }
    }
}
