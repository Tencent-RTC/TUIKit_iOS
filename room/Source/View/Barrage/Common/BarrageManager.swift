//
//  BarrageManager.swift
//  TUILiveKit
//
//  Created by gg on 2025/3/11.
//
import AtomicX
import AtomicXCore
import RTCRoomEngine
import Combine

class BarrageManager: NSObject {
    static let shared = BarrageManager()
    private var cancellableSet = Set<AnyCancellable>()
    private static let stateKey = "__kBarrageManager_state_key__"
    private override init() {
        super.init()
        subscribe()
    }
    
    private func subscribe() {
        RoomStore.shared.state.subscribe(StatePublisherSelector(keyPath: \.currentRoom))
            .removeDuplicates()
            .dropFirst()
            .receive(on: RunLoop.main)
            .sink { currentRoom in
                let roomID = currentRoom?.roomID ?? ""
                if roomID.isEmpty {
                    BarrageManager.shared.inputString = ""
                    BarrageManager.shared.subscribe()
                }
            }
            .store(in: &cancellableSet)
    }
    
    var inputString: String = ""
    let toastSubject = PassthroughSubject<(String,ToastStyle), Never>()
}
