//
//  VoiceRoomState.swift
//  SeatGridView
//
//  Created by abyyxwang on 2024/11/7.
//

import Combine
import Foundation
import AtomicXCore

public class ObservableState<State>: ObservableObject {
    
    public typealias StateUpdateClosure = (inout State) -> Void
    
    @Published public private(set) var state: State
    
    internal private(set) var stateHash = UUID()
    
    public init(initialState: State) {
        state = initialState
    }
    
    public func update(isPublished: Bool = true, reduce: StateUpdateClosure) {
        if isPublished {
            let oldState = state
            var newState = oldState
            reduce(&newState)
            stateHash = UUID()
            state = newState
        } else {
            reduce(&state)
        }
        
    }
    
    public func subscribe<Value: Equatable>(_ selector: StatePublisherSelector<State, Value>) -> AnyPublisher<Value, Never> {
        $state.map { selector.map($0, stateHash: self.stateHash) }.removeDuplicates().eraseToAnyPublisher()
    }
    
    public func subscribe<Value>(_ selector: StatePublisherSelector<State, Value>) -> AnyPublisher<Value, Never> {
        $state.map { selector.map($0, stateHash: self.stateHash) }.eraseToAnyPublisher()
    }
    
    public func subscribe() -> AnyPublisher<State, Never> {
        $state.eraseToAnyPublisher()
    }
}

