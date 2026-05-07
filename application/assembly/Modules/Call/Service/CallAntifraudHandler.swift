//
//  CallAntifraudHandler.swift
//  Call
//

import Combine
import AtomicXCore
import Login

// MARK: - CallAntifraudHandler

final class CallAntifraudHandler {

    static let shared = CallAntifraudHandler()
    private var cancellables = Set<AnyCancellable>()

    private init() {}

    func register() {
        CallStore.shared.state.subscribe(StatePublisherSelector(keyPath: \CallState.selfInfo))
            .removeDuplicates()
            .receive(on: RunLoop.main)
            .sink { selfInfo in
                if selfInfo.status == .accept {
                    guard Bundle.main.bundleIdentifier != "com.tencent.rtc.app" else { return }
                    if let user = LoginManager.shared.getCurrentUser(), user.isMoa() { return }

                    AppAssembly.shared.privacyActionHandler?(.showAntifraudReminder)
                }
            }
            .store(in: &cancellables)
    }

}
