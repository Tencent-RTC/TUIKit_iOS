//
//  SwiftLoad.swift
//  TUIRoomKit
//
//  Created by adamsfliu on 2026/8/10.
//  Copyright © 2026 Tencent. All rights reserved.
//

import Foundation
import TUICore
import AtomicXCore
import Combine

extension NSObject {
    @objc class func roomSwiftLoad() {
        RoomKitLoginObserver.shared.start()
    }
}

/// Observes login state changes and starts/stops room event listening
/// accordingly. Held as a singleton to keep the Combine subscription alive.
private class RoomKitLoginObserver {
    static let shared = RoomKitLoginObserver()

    private var cancellables = Set<AnyCancellable>()

    private init() {}

    func start() {
        guard cancellables.isEmpty else { return }
        LoginStore.shared.state.subscribe(StatePublisherSelector(keyPath: \.loginStatus))
            .receive(on: RunLoop.main)
            .sink { status in
                if status == .logined {
                    RoomInvitationManager.shared.startRoomEventObserver()
                } else {
                    RoomInvitationManager.shared.stopRoomEventObserver()
                }
            }
            .store(in: &cancellables)
    }
}
