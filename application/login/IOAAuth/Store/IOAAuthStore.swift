//
//  IOAAuthStore.swift
//  login
//

import UIKit
import Combine

class IOAAuthStore: LoginSubStore {
    
    // MARK: - State
    
    @Published private(set) var state = IOAAuthState()
    
    // MARK: - LoginSubStore
    
    private let resultSubject = PassthroughSubject<Result<LoginResult, LoginError>, Never>()
    var resultPublisher: AnyPublisher<Result<LoginResult, LoginError>, Never> {
        resultSubject.eraseToAnyPublisher()
    }
    
    // MARK: - Dependencies
    
    let ioaService = IOAService()
    private let networkService = LoginNetworkService()
    private var logoutCancellable: AnyCancellable?
    
    var onBack: (() -> Void)?
    
    // MARK: - Init
    
    init() {
        logoutCancellable = subscribeLogout()
    }
    
    // MARK: - LoginSubStore
    
    func resetState() {
        state = IOAAuthState()
    }
    
    // MARK: - Public Methods
    
    func showIOALogin(in parentView: UIView?) {
        state.isLoading = true
        
        ioaService.setOnBackButtonTapped { [weak self] in
            self?.state.isLoading = false
            self?.onBack?()
        }
        
        ioaService.showLoginView(in: parentView)
    }
    
    func loginWithTicket(_ ticket: String) {
        state.isFullScreenLoading = true
        state.fullScreenLoadingMessage = LoginLocalize("Demo.TRTC.Login.ioaLoading")
        
        networkService.loginByMOA(ticket: ticket) { [weak self] result in
            guard let self = self else { return }
            self.state.isFullScreenLoading = false
            self.state.isLoading = false
            switch result {
            case .success(let loginResult):
                self.resultSubject.send(.success(loginResult))
            case .failure(let error):
                self.state.toastMessage = error.message
            }
        }
    }
    
    func goBack() {
        ioaService.dismissLoginView()
        onBack?()
    }
}

// MARK: - State

public struct IOAAuthState {
    public var isLoading: Bool = false
    public var isFullScreenLoading: Bool = false
    public var fullScreenLoadingMessage: String = ""
    public var toastMessage: String = ""
}
