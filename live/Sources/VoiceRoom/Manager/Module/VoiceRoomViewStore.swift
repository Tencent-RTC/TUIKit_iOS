//
//  VoiceRoomViewStore.swift
//  TUILiveKit
//
//  Created by CY zhao on 2025/9/30.
//

import Foundation
import AtomicX
import Combine
import AtomicXCore

struct PendingBattleContext: Equatable {
    let battleID: String
    let inviteeUserIDs: [String]
}

struct VRViewState {
    var isApplyingToTakeSeat: Bool = false
    var pendingBattle: PendingBattleContext? = nil
}

class VoiceRoomViewStore {
    var state: VRViewState {
        observerState.state
    }
    
    private let observerState = ObservableState<VRViewState>(initialState: VRViewState())
    
    func subscribeState<Value>(_ selector: StatePublisherSelector<VRViewState, Value>) -> AnyPublisher<Value, Never> {
        observerState.subscribe(selector)
    }
    
    func onSentTakeSeatRequest() {
        update { state in
            state.isApplyingToTakeSeat = true
        }
    }
    
    func onRespondedTakeSeatRequest() {
        update { state in
            state.isApplyingToTakeSeat = false
        }
    }

    func onBattleRequestSent(battleID: String, inviteeUserIDs: [String]) {
        update { state in
            state.pendingBattle = PendingBattleContext(battleID: battleID, inviteeUserIDs: inviteeUserIDs)
        }
    }

    func onBattleRequestCleared() {
        update { state in
            state.pendingBattle = nil
        }
    }
}

extension VoiceRoomViewStore {
    private typealias StateUpdateClosure = (inout VRViewState) -> Void

    private func update(closure: StateUpdateClosure) {
        observerState.update(reduce: closure)
    }
}
