//
//  VoiceRoomViewStore.swift
//  TUILiveKit
//
//  Created by CY zhao on 2025/9/30.
//

import Foundation
import RTCCommon
import Combine

struct VRViewState {
    var isApplyingToTakeSeat: Bool = false
}

class VoiceRoomViewStore {
    var state: VRViewState {
        observerState.state
    }
    
    private let observerState = ObservableState<VRViewState>(initialState: VRViewState())
    
    func subscribeState<Value>(_ selector: StateSelector<VRViewState, Value>) -> AnyPublisher<Value, Never> {
        observerState.subscribe(selector)
    }
    
    func onSentTakeSeatRequest() {
        update { seatState in
            seatState.isApplyingToTakeSeat = true
        }
    }
    
    func onRespondedTakeSeatRequest() {
        update { seatState in
            seatState.isApplyingToTakeSeat = false
        }
    }
}

extension VoiceRoomViewStore {
    private typealias SeatStateUpdateClosure = (inout VRViewState) -> Void

    private func update(closure: SeatStateUpdateClosure) {
        observerState.update(reduce: closure)
    }
}
