//
//  LoginSubStore.swift
//  login
//

import Combine

protocol LoginSubStore: AnyObject {
    var resultPublisher: AnyPublisher<Result<LoginResult, LoginError>, Never> { get }

    func resetState()
}

extension LoginSubStore {
    static var logoutSubject: PassthroughSubject<Void, Never> {
        LoginSubStoreLogoutSignal.shared.subject
    }

    func subscribeLogout() -> AnyCancellable {
        Self.logoutSubject
            .receive(on: RunLoop.main)
            .sink { [weak self] in
                self?.resetState()
            }
    }
}

final class LoginSubStoreLogoutSignal {
    static let shared = LoginSubStoreLogoutSignal()
    let subject = PassthroughSubject<Void, Never>()
    private init() {}
}
