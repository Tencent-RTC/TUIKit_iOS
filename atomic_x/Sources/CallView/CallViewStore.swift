//
//  CallViewStore.swift
//  AtomicX
//
//  Created on 2026/3/16.
//

import Foundation
import Combine
import AtomicXCore

struct CallViewState {
    var isShowTranscriberPanel: Bool = CallViewStore.defaultShowTranscriberPanel
}

final class CallViewStore {
    
    static let shared = CallViewStore()
    static let defaultShowTranscriberPanel = true
    
    let observerState: ObservableState<CallViewState> = .init(initialState: CallViewState())
    
    var state: CallViewState {
        observerState.state
    }
    
    private var cancellables = Set<AnyCancellable>()
    
    private init() {
        CallStore.shared.state
            .subscribe(StatePublisherSelector(keyPath: \.selfInfo.status))
            .removeDuplicates()
            .receive(on: RunLoop.main)
            .sink { status in
                if status != .accept {
                    self.reset()
                }
            }
            .store(in: &cancellables)
    }
    
    func toggleTranscriberPanel() {
        observerState.update { state in
            state.isShowTranscriberPanel.toggle()
        }
    }
    
    private func reset() {
        observerState.update { state in
            state = CallViewState()
        }
    }
}
