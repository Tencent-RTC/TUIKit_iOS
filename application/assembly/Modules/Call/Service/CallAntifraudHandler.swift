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
        CallStore.shared.state
            .subscribe(StatePublisherSelector<CallState, CallParticipantStatus>(keyPath: \.selfInfo.status))
            .removeDuplicates()
            .receive(on: RunLoop.main)
            .sink { status in
                if status == .accept {
                    guard Bundle.main.bundleIdentifier != "com.tencent.rtc.app" else { return }
                    if let user = LoginManager.shared.getCurrentUser(), user.isMoa() { return }

                    AppAssembly.shared.privacyActionHandler?(.showAntifraudReminder)
                }
            }
            .store(in: &cancellables)
    }

}
