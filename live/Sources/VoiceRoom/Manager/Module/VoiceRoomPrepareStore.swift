//
//  VoiceRoomPrepareStore.swift
//  TUILiveKit
//
//  Created by CY zhao on 2025/9/23.
//

import Foundation
import Combine
import RTCCommon
import AtomicXCore
import RTCRoomEngine

enum VoiceRoomLayoutType: NSInteger {
    case chatRoom = 0
    case KTVRoom = 1
}

struct VoiceRoomPrepareState {
    var liveInfo: AtomicLiveInfo = {
        var info = AtomicLiveInfo()
        info.coverURL = "https://liteav-test-1252463788.cos.ap-guangzhou.myqcloud.com/voice_room/voice_room_cover1.png"
        info.backgroundURL = "http://dldir1.qq.com/hudongzhibo/TRTC/TUIKit/VoiceRoom/picture/livekit_voiceroom_background.png"
        info.isSeatEnabled = true
        info.keepOwnerOnSeat = true
        info.seatLayoutTemplateID = 70
        return info
    }()
    var layoutType: VoiceRoomLayoutType = .chatRoom
}

class VoiceRoomPrepareStore {
    private(set) var roomParams = RoomParams()
    
    var state: VoiceRoomPrepareState {
        observerState.state
    }
    
    private let observerState = ObservableState<VoiceRoomPrepareState>(initialState: VoiceRoomPrepareState())
    
    func prepareLiveIdBeforeEnterRoom(liveId: String, roomParams: RoomParams?) {
        update { state in
            state.liveInfo.liveID = liveId
        }
        if let param = roomParams {
            self.roomParams = param
        }
    }
    
    func onSetRoomName(_ name: String) {
        update { state in
            state.liveInfo.liveName = name
        }
    }
    
    func onSetRoomPrivacy(_ mode: LiveStreamPrivacyStatus) {
        update { state in
            state.liveInfo.isPublicVisible = mode == .public
        }
    }
    
    func onSetRoomCoverUrl(_ coverUrl: String) {
        update { state in
            state.liveInfo.coverURL = coverUrl
        }
    }
    
    func onSetRoomBackgroundUrl(_ backgroundUrl: String) {
        update { state in
            state.liveInfo.backgroundURL = backgroundUrl
        }
    }
    
    func onSetlayoutType(layoutType: VoiceRoomLayoutType) {
        update { state in
            state.layoutType = layoutType
        }
    }
    
    func onChangedSeatMode(_ seatMode: TUISeatMode) {
        roomParams.seatMode = seatMode
    }
}

extension VoiceRoomPrepareStore {
    func subscribeState<Value>(_ selector: StateSelector<VoiceRoomPrepareState, Value>) -> AnyPublisher<Value, Never> {
        observerState.subscribe(selector)
    }
}

private extension VoiceRoomPrepareStore {
    typealias stateUpdateClosure = (inout VoiceRoomPrepareState) -> Void

    func update(roomState: stateUpdateClosure) {
        observerState.update(reduce: roomState)
    }
}

