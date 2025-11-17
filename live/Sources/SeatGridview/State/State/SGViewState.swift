//
//  SGViewState.swift
//  SeatGridView
//
//  Created by krabyu on 2024/10/21.
//

public struct SGViewState: StateProvider, Equatable {
    public var layoutConfig: SGSeatViewLayoutConfig = SGSeatViewLayoutConfig()
    public var layoutMode: SGLayoutMode = .grid
    
    public init() {}

    public static func == (lhs: SGViewState, rhs: SGViewState) -> Bool {
        return lhs.layoutConfig == rhs.layoutConfig &&
        lhs.layoutMode == rhs.layoutMode
    }
}
