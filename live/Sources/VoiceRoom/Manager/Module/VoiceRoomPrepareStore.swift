//
//  VoiceRoomPrepareStore.swift
//  TUILiveKit
//
//  Created by CY zhao on 2025/9/23.
//

import Foundation
import Combine
import AtomicX
import AtomicXCore
import RTCRoomEngine

enum VoiceRoomLayoutType: NSInteger {
    case chatRoom = 0
    case KTVRoom = 1
}

struct VoiceRoomPrepareState {
    var liveInfo: AtomicLiveInfo = {
        var info = AtomicLiveInfo(seatTemplate: .audioSalon(seatCount: 0))
        info.coverURL = Constants.URL.defaultCover
        info.backgroundURL = Constants.URL.defaultBackground
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
            switch layoutType {
            case .KTVRoom:
                state.liveInfo.seatLayoutTemplateID = 50
                state.liveInfo.seatTemplate = .karaoke(seatCount: 0)
            case .chatRoom:
                state.liveInfo.seatLayoutTemplateID = 70
                state.liveInfo.seatTemplate = .audioSalon(seatCount: 0)
            }
        }
    }
    
    func onChangedSeatMode(_ seatMode: TUISeatMode) {
        roomParams.seatMode = seatMode
    }
}

extension VoiceRoomPrepareStore {
    func subscribeState<Value>(_ selector: StatePublisherSelector<VoiceRoomPrepareState, Value>) -> AnyPublisher<Value, Never> {
        observerState.subscribe(selector)
    }
}

private extension VoiceRoomPrepareStore {
    typealias stateUpdateClosure = (inout VoiceRoomPrepareState) -> Void

    func update(roomState: stateUpdateClosure) {
        observerState.update(reduce: roomState)
    }
}

